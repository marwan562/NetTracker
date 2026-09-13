package persistence

import (
	"testing"
	"time"

	"nettracker-agent/internal/tracker"
)

func TestLastNDays(t *testing.T) {
	now, err := time.Parse("2006-01-02", "2026-04-10")
	if err != nil {
		t.Fatalf("parse time: %v", err)
	}

	history := map[string]tracker.DailyUsage{
		"2026-04-10": {UploadBytes: 100, DownloadBytes: 200},
		"2026-04-09": {UploadBytes: 50, DownloadBytes: 70},
		"2026-04-07": {UploadBytes: 30, DownloadBytes: 40},
	}

	days := LastNDays(history, now, 7)
	if len(days) != 7 {
		t.Fatalf("expected 7 days, got %d", len(days))
	}

	// Verify order is chronological
	for i := 1; i < len(days); i++ {
		if days[i].Date <= days[i-1].Date {
			t.Fatalf("expected strictly increasing dates: %s after %s", days[i].Date, days[i-1].Date)
		}
	}

	// Last item should be today
	last := days[len(days)-1]
	if !last.IsToday || last.Date != "2026-04-10" || last.UploadBytes != 100 || last.DownloadBytes != 200 {
		t.Fatalf("unexpected today entry: %+v", last)
	}

	// Test fallback when n <= 0
	defDays := LastNDays(history, now, 0)
	if len(defDays) != 7 {
		t.Fatalf("expected 7 days for n<=0, got %d", len(defDays))
	}

	// Test 14 days
	fourteenDays := LastNDays(history, now, 14)
	if len(fourteenDays) != 14 {
		t.Fatalf("expected 14 days, got %d", len(fourteenDays))
	}
}

func TestLast7Days(t *testing.T) {
	now := time.Now()
	days := Last7Days(nil, now)
	if len(days) != 7 {
		t.Fatalf("expected 7 entries, got %d", len(days))
	}
	if !days[6].IsToday {
		t.Fatalf("expected last entry to be today, got %+v", days[6])
	}
}
