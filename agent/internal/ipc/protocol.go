// Package ipc defines the versioned newline-delimited JSON protocol spoken
// over the Unix domain socket. Version 1 request types: snapshot, history,
// reset, network_changed, sleep, wake.
package ipc

import (
	"nettracker-agent/internal/persistence"
	"nettracker-agent/internal/tracker"
)

// CurrentVersion is the protocol version spoken by this agent.
const CurrentVersion = 1

// Request is a client message. Days is only used for history requests.
type Request struct {
	Version int    `json:"version"`
	Type    string `json:"type"`
	Days    int    `json:"days,omitempty"`
}

// Response is an agent reply. Only fields relevant to Type are populated.
type Response struct {
	Version      int                    `json:"version"`
	Type         string                 `json:"type"`
	Session      *tracker.DailyUsage    `json:"session,omitempty"`
	Today        *tracker.DailyUsage    `json:"today,omitempty"`
	UploadRate   uint64                 `json:"upload_rate,omitempty"`
	DownloadRate uint64                 `json:"download_rate,omitempty"`
	Days         []persistence.DayEntry `json:"days,omitempty"`
	OK           bool                   `json:"ok,omitempty"`
	Error        string                 `json:"error,omitempty"`
}

// Request types.
const (
	TypeSnapshot       = "snapshot"
	TypeHistory        = "history"
	TypeReset          = "reset"
	TypeNetworkChanged = "network_changed"
	TypeSleep          = "sleep"
	TypeWake           = "wake"
	TypeError          = "error"
	TypeOK             = "ok"
)
