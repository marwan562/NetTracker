package persistence

import (
	"sort"
	"time"

	"nettracker-agent/internal/tracker"
)

// DayEntry is one row of the Last 7 Days view.
type DayEntry struct {
	Date          string `json:"date"`
	Label         string `json:"label"`
	UploadBytes   uint64 `json:"upload_bytes"`
	DownloadBytes uint64 `json:"download_bytes"`
	IsToday       bool   `json:"is_today"`
}

// LastNDays returns exactly n entries: today plus (n-1) prior local days.
// Missing days are zero-filled.
func LastNDays(history map[string]tracker.DailyUsage, now time.Time, n int) []DayEntry {
	if n <= 0 {
		n = 7
	}
	now = now.Local()
	out := make([]DayEntry, 0, n)
	for i := n - 1; i >= 0; i-- {
		day := now.AddDate(0, 0, -i)
		key := day.Format("2006-01-02")
		u := history[key]
		label := day.Format("Jan 02")
		isToday := i == 0
		if isToday {
			label = "Today"
		}
		out = append(out, DayEntry{
			Date:          key,
			Label:         label,
			UploadBytes:   u.UploadBytes,
			DownloadBytes: u.DownloadBytes,
			IsToday:       isToday,
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Date < out[j].Date })
	return out
}

// Last7Days returns exactly seven entries: today plus six prior local days.
// Missing days are zero-filled.
func Last7Days(history map[string]tracker.DailyUsage, now time.Time) []DayEntry {
	return LastNDays(history, now, 7)
}
