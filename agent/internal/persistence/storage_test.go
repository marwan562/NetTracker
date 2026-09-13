package persistence

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"nettracker-agent/internal/tracker"
)

func TestSaveLoadRoundTrip(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "history.json")
	history := map[string]tracker.DailyUsage{
		"2026-09-13": {UploadBytes: 47448064, DownloadBytes: 327994368},
	}
	if err := Save(path, history); err != nil {
		t.Fatalf("save: %v", err)
	}
	loaded, err := Load(path)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if loaded["2026-09-13"] != history["2026-09-13"] {
		t.Fatalf("round-trip mismatch: %+v", loaded)
	}
}

func TestLoadMissingReturnsEmpty(t *testing.T) {
	loaded, err := Load(filepath.Join(t.TempDir(), "nope.json"))
	if err != nil || len(loaded) != 0 {
		t.Fatalf("missing file should yield empty history, got %+v, %v", loaded, err)
	}
}

func TestLoadCorruptBacksUpAndRecovers(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "history.json")
	_ = os.WriteFile(path, []byte("{not json"), 0o600)
	loaded, err := Load(path)
	if err == nil {
		t.Fatalf("expected corruption error")
	}
	if len(loaded) != 0 {
		t.Fatalf("corrupt load should return empty history")
	}
	entries, _ := os.ReadDir(dir)
	found := false
	for _, e := range entries {
		if len(e.Name()) > len("history.json") {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected corrupt backup file")
	}
}

func TestNoTmpFileLeftAfterSave(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sub", "history.json")
	if err := Save(path, map[string]tracker.DailyUsage{}); err != nil {
		t.Fatalf("save: %v", err)
	}
	if _, err := os.Stat(path + ".tmp"); !os.IsNotExist(err) {
		t.Fatalf("tmp file must not remain after atomic save")
	}
}

func TestLast7DaysExactCount(t *testing.T) {
	now := time.Date(2026, 9, 13, 12, 0, 0, 0, time.Local)
	history := map[string]tracker.DailyUsage{
		"2026-09-13": {UploadBytes: 10, DownloadBytes: 20},
		"2026-09-11": {UploadBytes: 30, DownloadBytes: 40},
	}
	days := Last7Days(history, now)
	if len(days) != 7 {
		t.Fatalf("expected exactly 7 entries, got %d", len(days))
	}
	if !days[6].IsToday || days[6].Date != "2026-09-13" {
		t.Fatalf("last entry must be today, got %+v", days[6])
	}
	if days[6].UploadBytes != 10 || days[6].DownloadBytes != 20 {
		t.Fatalf("today totals wrong: %+v", days[6])
	}
	if days[0].Date != "2026-09-07" || days[0].UploadBytes != 0 {
		t.Fatalf("missing days must be zero-filled, got %+v", days[0])
	}
	found := false
	for _, d := range days {
		if d.Date == "2026-09-11" && d.UploadBytes == 30 {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected 2026-09-11 entry in range")
	}
}
