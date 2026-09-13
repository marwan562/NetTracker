// Package collector samples cumulative system network counters.
package collector

import (
	"context"

	"nettracker-agent/internal/tracker"

	"github.com/shirou/gopsutil/v3/net"
)

// Collector samples cumulative system network counters.
type Collector interface {
	Sample(ctx context.Context) (tracker.NetworkSample, error)
}

// GoPsutilCollector reads aggregate interface counters via gopsutil.
// IOCounters(false) is system-wide usage, not Internet-only accounting.
type GoPsutilCollector struct {
	Clock func() tracker.NetworkSample
}

// Sample returns the current cumulative upload/download bytes.
func (c *GoPsutilCollector) Sample(ctx context.Context) (tracker.NetworkSample, error) {
	select {
	case <-ctx.Done():
		return tracker.NetworkSample{}, ctx.Err()
	default:
	}
	counters, err := net.IOCounters(false)
	if err != nil {
		return tracker.NetworkSample{}, err
	}
	var up, down uint64
	for _, io := range counters {
		up += io.BytesSent
		down += io.BytesRecv
	}
	return SampleNow(up, down), nil
}
