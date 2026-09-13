package collector

import (
	"time"

	"nettracker-agent/internal/tracker"
)

// SampleNow stamps cumulative counters with the local clock.
func SampleNow(up, down uint64) tracker.NetworkSample {
	return tracker.NetworkSample{
		Timestamp:     time.Now(),
		UploadBytes:   up,
		DownloadBytes: down,
	}
}
