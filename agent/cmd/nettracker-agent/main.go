// Command nettracker-agent is the Go measurement engine: it samples system
// network counters every second, aggregates session/daily totals, checkpoints
// atomically about once a minute, and serves snapshots over a Unix socket.
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"nettracker-agent/internal/collector"
	"nettracker-agent/internal/config"
	"nettracker-agent/internal/ipc"
	"nettracker-agent/internal/persistence"
	agentsync "nettracker-agent/internal/sync"
	"nettracker-agent/internal/tracker"
)

func main() {
	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	cfg := config.Default()

	history, err := persistence.Load(cfg.HistoryPath)
	if err != nil {
		log.Warn("history load recovered with fresh state", "err", err)
		history = make(map[string]tracker.DailyUsage)
	}

	tr := tracker.NewTracker(time.Now(), history)
	col := &collector.GoPsutilCollector{}
	syncClient := agentsync.NewClient(os.Getenv("NETTRACKER_SYNC_ENDPOINT"), log)
	_ = syncClient

	app := &app{
		tracker:   tr,
		collector: col,
		cfg:       cfg,
		log:       log,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := app.run(ctx); err != nil {
		log.Error("agent exited", "err", err)
		os.Exit(1)
	}
}

type app struct {
	tracker   *tracker.Tracker
	collector collector.Collector
	cfg       config.Config
	log       *slog.Logger
}

func (a *app) run(ctx context.Context) error {
	srv := ipc.NewServer(a.cfg.SocketPath, a, a.log)
	go func() {
		if err := srv.Serve(ctx); err != nil {
			a.log.Warn("ipc server stopped", "err", err)
		}
	}()

	sampleTicker := time.NewTicker(a.cfg.SampleInterval)
	defer sampleTicker.Stop()
	checkpointTicker := time.NewTicker(a.cfg.CheckpointEvery)
	defer checkpointTicker.Stop()

	a.log.Info("agent started",
		"history", a.cfg.HistoryPath,
		"socket", a.cfg.SocketPath)

	for {
		select {
		case <-ctx.Done():
			a.checkpoint("shutdown")
			return nil
		case t := <-sampleTicker.C:
			sample, err := a.collector.Sample(ctx)
			if err != nil {
				a.log.Warn("sample failed, continuing", "err", err, "at", t)
				continue
			}
			a.tracker.Observe(sample)
		case <-checkpointTicker.C:
			a.checkpoint("periodic")
		}
	}
}

// checkpoint snapshots history without holding the tracker lock during I/O.
func (a *app) checkpoint(reason string) {
	if !a.tracker.IsDirty() {
		return
	}
	history := a.tracker.HistoryCopy()
	if err := persistence.Save(a.cfg.HistoryPath, history); err != nil {
		a.log.Warn("checkpoint failed, will retry", "err", err, "reason", reason)
		return
	}
	a.tracker.MarkClean()
	a.log.Debug("checkpoint saved", "reason", reason)
}

// Snapshot implements ipc.Handler.
func (a *app) Snapshot() tracker.UsageSnapshot { return a.tracker.Snapshot() }

// Last7Days implements ipc.Handler.
func (a *app) Last7Days() []persistence.DayEntry {
	return persistence.Last7Days(a.tracker.HistoryCopy(), time.Now())
}

// Reset implements ipc.Handler.
func (a *app) Reset() {
	a.tracker.Reset()
	a.checkpoint("reset")
}

// Rebaseline implements ipc.Handler.
func (a *app) Rebaseline(reason string) {
	a.log.Info("re-baselining counters", "reason", reason)
	a.tracker.Rebaseline()
}
