// Package tracker provides aggregation, rollover, and re-baselining for network samples.
package tracker

import (
	"sync"
	"time"
)

// maxSampleGap bounds how far apart two samples may be before the interval is
// treated as a lifecycle/scheduling gap (sleep, suspension, stall) and the
// tracker re-baselines instead of attributing usage.
const maxSampleGap = 5 * time.Second

// dayKey returns the local-date key (YYYY-MM-DD) for aggregation.
func dayKey(t time.Time) string {
	return t.Local().Format("2006-01-02")
}

// Tracker owns session totals, daily totals, current rate, and re-baselining.
// It is safe for concurrent use; the agent event loop is the single writer and
// IPC handlers are readers. Disk I/O must happen outside the lock: callers
// snapshot state first, then persist.
type Tracker struct {
	mu sync.RWMutex

	currentDay string

	sessionUploadBytes   uint64
	sessionDownloadBytes uint64

	todayUploadBytes   uint64
	todayDownloadBytes uint64

	currentUploadRate   uint64
	currentDownloadRate uint64

	lastSample  NetworkSample
	initialized bool

	pendingRebaseline bool

	// history maps dayKey -> accumulated totals, including today.
	history map[string]DailyUsage

	dirty bool
}

// DailyUsage mirrors persistence schema: exact integer bytes.
type DailyUsage struct {
	UploadBytes   uint64 `json:"upload_bytes"`
	DownloadBytes uint64 `json:"download_bytes"`
}

// NewTracker creates a tracker, seeding today's accumulators from persisted
// history so restarts continue the day instead of resetting it.
func NewTracker(now time.Time, history map[string]DailyUsage) *Tracker {
	if history == nil {
		history = make(map[string]DailyUsage)
	}
	day := dayKey(now)
	seed := history[day]
	t := &Tracker{
		currentDay:         day,
		todayUploadBytes:   seed.UploadBytes,
		todayDownloadBytes: seed.DownloadBytes,
		history:            history,
		dirty:              false,
	}
	t.history[day] = DailyUsage{
		UploadBytes:   t.todayUploadBytes,
		DownloadBytes: t.todayDownloadBytes,
	}
	return t
}

// Observe folds one cumulative sample into session/day totals.
// It returns the delta attributed to this interval (zero on first sample,
// gaps, resets, and rollovers that re-baseline).
func (t *Tracker) Observe(s NetworkSample) UsageDelta {
	t.mu.Lock()
	defer t.mu.Unlock()

	day := dayKey(s.Timestamp)

	if !t.initialized {
		t.initialized = true
		t.lastSample = s
		if day != t.currentDay {
			t.rolloverLocked(day)
		} else {
			t.currentDay = day
		}
		t.pendingRebaseline = false
		t.currentUploadRate = 0
		t.currentDownloadRate = 0
		return UsageDelta{}
	}

	if day != t.currentDay {
		t.rolloverLocked(day)
		t.lastSample = s
		t.pendingRebaseline = false
		t.currentUploadRate = 0
		t.currentDownloadRate = 0
		return UsageDelta{}
	}

	if t.pendingRebaseline {
		t.lastSample = s
		t.pendingRebaseline = false
		t.currentUploadRate = 0
		t.currentDownloadRate = 0
		t.dirty = true
		return UsageDelta{}
	}

	elapsed := s.Timestamp.Sub(t.lastSample.Timestamp)
	if elapsed <= 0 || elapsed > maxSampleGap {
		t.lastSample = s
		t.currentUploadRate = 0
		t.currentDownloadRate = 0
		return UsageDelta{}
	}

	if s.UploadBytes < t.lastSample.UploadBytes || s.DownloadBytes < t.lastSample.DownloadBytes {
		t.lastSample = s
		t.currentUploadRate = 0
		t.currentDownloadRate = 0
		return UsageDelta{}
	}

	up := counterDelta(s.UploadBytes, t.lastSample.UploadBytes)
	down := counterDelta(s.DownloadBytes, t.lastSample.DownloadBytes)

	secs := elapsed.Seconds()
	if secs > 0 {
		t.currentUploadRate = uint64(float64(up) / secs)
		t.currentDownloadRate = uint64(float64(down) / secs)
	}

	t.sessionUploadBytes += up
	t.sessionDownloadBytes += down
	t.todayUploadBytes += up
	t.todayDownloadBytes += down
	t.history[t.currentDay] = DailyUsage{
		UploadBytes:   t.todayUploadBytes,
		DownloadBytes: t.todayDownloadBytes,
	}
	t.lastSample = s
	if up != 0 || down != 0 {
		t.dirty = true
	}
	return UsageDelta{UploadBytes: up, DownloadBytes: down}
}

// rolloverLocked preserves the old day (already in history), starts the new
// day at zero, and marks state dirty so the checkpoint persists the new entry.
// Callers must hold t.mu.
func (t *Tracker) rolloverLocked(newDay string) {
	t.currentDay = newDay
	t.todayUploadBytes = 0
	t.todayDownloadBytes = 0
	t.currentUploadRate = 0
	t.currentDownloadRate = 0
	if _, ok := t.history[newDay]; !ok {
		t.history[newDay] = DailyUsage{}
	} else {
		seed := t.history[newDay]
		t.todayUploadBytes = seed.UploadBytes
		t.todayDownloadBytes = seed.DownloadBytes
	}
	t.dirty = true
}

// Rebaseline forces the next Observe to discard its delta (sleep/wake,
// network path change). Safe to call from any goroutine.
func (t *Tracker) Rebaseline() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.pendingRebaseline = true
	t.currentUploadRate = 0
	t.currentDownloadRate = 0
}

// Reset clears the session and today's accumulators per defined semantics:
// previous days are preserved, today is zeroed.
func (t *Tracker) Reset() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.sessionUploadBytes = 0
	t.sessionDownloadBytes = 0
	t.todayUploadBytes = 0
	t.todayDownloadBytes = 0
	t.currentUploadRate = 0
	t.currentDownloadRate = 0
	t.history[t.currentDay] = DailyUsage{}
	t.dirty = true
}

// Snapshot returns the UI-facing totals and rates.
func (t *Tracker) Snapshot() UsageSnapshot {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return UsageSnapshot{
		SessionUploadBytes:   t.sessionUploadBytes,
		SessionDownloadBytes: t.sessionDownloadBytes,
		TodayUploadBytes:     t.todayUploadBytes,
		TodayDownloadBytes:   t.todayDownloadBytes,
		CurrentUploadRate:    t.currentUploadRate,
		CurrentDownloadRate:  t.currentDownloadRate,
	}
}

// IsDirty reports whether state changed since the last checkpoint.
func (t *Tracker) IsDirty() bool {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return t.dirty
}

// MarkClean clears the dirty flag after a successful checkpoint.
func (t *Tracker) MarkClean() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.dirty = false
}

// HistoryCopy returns a copy of the day map for persistence without holding
// the lock during disk I/O.
func (t *Tracker) HistoryCopy() map[string]DailyUsage {
	t.mu.RLock()
	defer t.mu.RUnlock()
	out := make(map[string]DailyUsage, len(t.history))
	for k, v := range t.history {
		out[k] = v
	}
	return out
}

// CurrentDay returns the tracker's active local day key.
func (t *Tracker) CurrentDay() string {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return t.currentDay
}
