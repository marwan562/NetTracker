// Package sync implements the optional, opt-in cloud synchronization queue.
// The MVP ships offline-first: local tracking works fully without a backend.
// This client batches aggregated daily summaries and never blocks tracking;
// failures are logged and retried later without affecting local state.
package sync

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"nettracker-agent/internal/persistence"
)

// Client batches aggregated usage to a remote Go backend.
type Client struct {
	endpoint string
	enabled  bool
	http     *http.Client
	log      *slog.Logger
}

// NewClient returns a disabled no-op client when endpoint is empty (default).
func NewClient(endpoint string, log *slog.Logger) *Client {
	if log == nil {
		log = slog.Default()
	}
	return &Client{
		endpoint: endpoint,
		enabled:  endpoint != "",
		http:     &http.Client{Timeout: 15 * time.Second},
		log:      log,
	}
}

// Enabled reports whether cloud sync is configured (opt-in).
func (c *Client) Enabled() bool { return c.enabled }

// Push sends aggregated daily summaries. It is fire-and-forget from the
// tracker's perspective: errors are logged, never fatal.
func (c *Client) Push(ctx context.Context, days []persistence.DayEntry) error {
	if !c.enabled {
		return nil
	}
	body, err := json.Marshal(map[string]any{"days": days})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		c.log.Warn("sync push failed", "err", err)
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode >= 300 {
		c.log.Warn("sync push rejected", "status", resp.StatusCode)
	}
	return nil
}
