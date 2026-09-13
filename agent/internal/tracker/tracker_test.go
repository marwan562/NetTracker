package tracker

import (
	"testing"
	"time"
)

func sampleAt(t time.Time, up, down uint64) NetworkSample {
	return NetworkSample{Timestamp: t, UploadBytes: up, DownloadBytes: down}
}

func TestCounterDelta(t *testing.T) {
	if got := counterDelta(150, 100); got != 50 {
		t.Fatalf("100 -> 150 = 50, got %d", got)
	}
	if got := counterDelta(20, 150); got != 0 {
		t.Fatalf("150 -> 20 should re-baseline to 0, got %d", got)
	}
}

func TestFirstSampleGeneratesNoUsage(t *testing.T) {
	now := time.Now()
	tr := NewTracker(now, nil)
	d := tr.Observe(sampleAt(now, 1000, 2000))
	if d.UploadBytes != 0 || d.DownloadBytes != 0 {
		t.Fatalf("first sample must generate no usage, got %+v", d)
	}
	snap := tr.Snapshot()
	if snap.SessionUploadBytes != 0 || snap.TodayDownloadBytes != 0 {
		t.Fatalf("totals must be zero after first sample, got %+v", snap)
	}
}

func TestNormalAccumulationAndRate(t *testing.T) {
	now := time.Now()
	tr := NewTracker(now, nil)
	tr.Observe(sampleAt(now, 1000, 2000))
	tr.Observe(sampleAt(now.Add(time.Second), 1100, 2200))
	snap := tr.Snapshot()
	if snap.SessionUploadBytes != 100 || snap.SessionDownloadBytes != 200 {
		t.Fatalf("expected 100/200, got %+v", snap)
	}
	if snap.CurrentUploadRate == 0 || snap.CurrentDownloadRate == 0 {
		t.Fatalf("expected nonzero rates, got %+v", snap)
	}
}

func TestLargeGapRebaselines(t *testing.T) {
	now := time.Now()
	tr := NewTracker(now, nil)
	tr.Observe(sampleAt(now, 1000, 1000))
	d := tr.Observe(sampleAt(now.Add(90*time.Second), 5000, 5000))
	if d.UploadBytes != 0 || d.DownloadBytes != 0 {
		t.Fatalf("large gap must re-baseline with zero delta, got %+v", d)
	}
	snap := tr.Snapshot()
	if snap.SessionUploadBytes != 0 || snap.SessionDownloadBytes != 0 {
		t.Fatalf("gap must not charge usage, got %+v", snap)
	}
	tr.Observe(sampleAt(now.Add(91*time.Second), 5100, 5200))
	snap = tr.Snapshot()
	if snap.SessionUploadBytes != 100 || snap.SessionDownloadBytes != 200 {
		t.Fatalf("post-gap sample should accumulate normally, got %+v", snap)
	}
}

func TestCounterResetRebaselines(t *testing.T) {
	now := time.Now()
	tr := NewTracker(now, nil)
	tr.Observe(sampleAt(now, 1000, 1000))
	tr.Observe(sampleAt(now.Add(time.Second), 1150, 1200))
	d := tr.Observe(sampleAt(now.Add(2*time.Second), 20, 30))
	if d.UploadBytes != 0 || d.DownloadBytes != 0 {
		t.Fatalf("counter reset must yield zero delta, got %+v", d)
	}
	snap := tr.Snapshot()
	if snap.SessionUploadBytes != 150 || snap.SessionDownloadBytes != 200 {
		t.Fatalf("reset must preserve prior totals without underflow, got %+v", snap)
	}
}

func TestDayRollover(t *testing.T) {
	day1 := time.Date(2026, 9, 13, 23, 59, 58, 0, time.Local)
	tr := NewTracker(day1, nil)
	tr.Observe(sampleAt(day1, 1000, 1000))
	tr.Observe(sampleAt(day1.Add(time.Second), 1100, 1200))
	day2 := day1.Add(3 * time.Second)
	d := tr.Observe(sampleAt(day2, 2000, 2000))
	if d.UploadBytes != 0 || d.DownloadBytes != 0 {
		t.Fatalf("rollover sample must not carry delta, got %+v", d)
	}
	snap := tr.Snapshot()
	if snap.TodayUploadBytes != 0 || snap.TodayDownloadBytes != 0 {
		t.Fatalf("new day starts at zero, got %+v", snap)
	}
	if snap.SessionUploadBytes != 100 || snap.SessionDownloadBytes != 200 {
		t.Fatalf("session survives rollover, got %+v", snap)
	}
	h := tr.HistoryCopy()
	if h["2026-09-13"].UploadBytes != 100 || h["2026-09-13"].DownloadBytes != 200 {
		t.Fatalf("previous day preserved, got %+v", h["2026-09-13"])
	}
}

func TestReset(t *testing.T) {
	now := time.Now()
	history := map[string]DailyUsage{dayKey(now.AddDate(0, 0, -1)): {UploadBytes: 999, DownloadBytes: 999}}
	tr := NewTracker(now, history)
	tr.Observe(sampleAt(now, 100, 100))
	tr.Observe(sampleAt(now.Add(time.Second), 200, 200))
	tr.Reset()
	snap := tr.Snapshot()
	if snap.SessionUploadBytes != 0 || snap.TodayDownloadBytes != 0 {
		t.Fatalf("reset must zero session and today, got %+v", snap)
	}
	h := tr.HistoryCopy()
	if h[dayKey(now.AddDate(0, 0, -1))].UploadBytes != 999 {
		t.Fatalf("reset must preserve prior days")
	}
}

func TestRebaselineEvent(t *testing.T) {
	now := time.Now()
	tr := NewTracker(now, nil)
	tr.Observe(sampleAt(now, 1000, 1000))
	tr.Rebaseline()
	d := tr.Observe(sampleAt(now.Add(time.Second), 5000, 5000))
	if d.UploadBytes != 0 || d.DownloadBytes != 0 {
		t.Fatalf("pending rebaseline must discard delta, got %+v", d)
	}
}
