package ipc

import (
	"testing"
	"time"

	"nettracker-agent/internal/persistence"
	"nettracker-agent/internal/tracker"
)

type fakeHandler struct {
	tr      *tracker.Tracker
	history map[string]tracker.DailyUsage
}

func (f *fakeHandler) Snapshot() tracker.UsageSnapshot { return f.tr.Snapshot() }
func (f *fakeHandler) Last7Days() []persistence.DayEntry {
	return persistence.Last7Days(f.history, time.Now())
}
func (f *fakeHandler) Reset()              { f.tr.Reset() }
func (f *fakeHandler) Rebaseline(_ string) { f.tr.Rebaseline() }

func TestSnapshotRequest(t *testing.T) {
	now := time.Now()
	tr := tracker.NewTracker(now, nil)
	h := &fakeHandler{tr: tr, history: map[string]tracker.DailyUsage{}}
	resp := HandleRequest(h, Request{Version: 1, Type: TypeSnapshot})
	if resp.Type != TypeSnapshot || resp.Session == nil || resp.Today == nil {
		t.Fatalf("bad snapshot response: %+v", resp)
	}
}

func TestHistoryRequest(t *testing.T) {
	tr := tracker.NewTracker(time.Now(), nil)
	h := &fakeHandler{tr: tr, history: map[string]tracker.DailyUsage{}}
	resp := HandleRequest(h, Request{Version: 1, Type: TypeHistory, Days: 7})
	if resp.Type != TypeHistory || len(resp.Days) != 7 {
		t.Fatalf("history must return 7 entries, got %+v", resp)
	}
}

func TestResetRequest(t *testing.T) {
	now := time.Now()
	tr := tracker.NewTracker(now, nil)
	tr.Observe(tracker.NetworkSample{Timestamp: now, UploadBytes: 1, DownloadBytes: 1})
	h := &fakeHandler{tr: tr, history: map[string]tracker.DailyUsage{}}
	resp := HandleRequest(h, Request{Version: 1, Type: TypeReset})
	if !resp.OK {
		t.Fatalf("reset must ack, got %+v", resp)
	}
}

func TestLifecycleEventsRebaseline(t *testing.T) {
	for _, typ := range []string{TypeNetworkChanged, TypeSleep, TypeWake} {
		tr := tracker.NewTracker(time.Now(), nil)
		h := &fakeHandler{tr: tr, history: map[string]tracker.DailyUsage{}}
		resp := HandleRequest(h, Request{Version: 1, Type: typ})
		if !resp.OK {
			t.Fatalf("%s must ack, got %+v", typ, resp)
		}
	}
}

func TestUnknownTypeAndVersion(t *testing.T) {
	tr := tracker.NewTracker(time.Now(), nil)
	h := &fakeHandler{tr: tr, history: map[string]tracker.DailyUsage{}}
	srv := &Server{handler: h}
	if resp := srv.dispatch(Request{Version: 1, Type: "bogus"}); resp.Type != TypeError {
		t.Fatalf("unknown type must error, got %+v", resp)
	}
	if resp := srv.dispatch(Request{Version: 99, Type: TypeSnapshot}); resp.Type != TypeSnapshot {
		t.Fatalf("dispatch is version-agnostic internally, got %+v", resp)
	}
}
