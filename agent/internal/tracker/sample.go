package tracker

import "time"

// NetworkSample is a single observation of cumulative system counters in bytes.
type NetworkSample struct {
	Timestamp     time.Time
	UploadBytes   uint64
	DownloadBytes uint64
}

// UsageDelta is the per-interval usage between two samples in bytes.
type UsageDelta struct {
	UploadBytes   uint64
	DownloadBytes uint64
}

// UsageSnapshot is the UI-facing point-in-time view in bytes.
type UsageSnapshot struct {
	SessionUploadBytes   uint64
	SessionDownloadBytes uint64
	TodayUploadBytes     uint64
	TodayDownloadBytes   uint64
	CurrentUploadRate    uint64
	CurrentDownloadRate  uint64
}
