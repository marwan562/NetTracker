// Package config defines paths and runtime intervals for the agent.
package config

import (
	"os"
	"path/filepath"
	"time"
)

// Config holds agent runtime paths and intervals.
type Config struct {
	HistoryPath     string
	SocketPath      string
	SampleInterval  time.Duration
	CheckpointEvery time.Duration
}

// Default returns App Support paths with sampling every 1s and disk
// checkpoint roughly every 60s. Override via NETTRACKER_* env vars.
func Default() Config {
	base := appSupportDir()
	return Config{
		HistoryPath:     envOr("NETTRACKER_HISTORY", filepath.Join(base, "history.json")),
		SocketPath:      envOr("NETTRACKER_SOCKET", filepath.Join(base, "agent.sock")),
		SampleInterval:  time.Second,
		CheckpointEvery: 60 * time.Second,
	}
}

func appSupportDir() string {
	if home, err := os.UserHomeDir(); err == nil {
		return filepath.Join(home, "Library", "Application Support", "NetTracker")
	}
	return "/tmp/NetTracker"
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
