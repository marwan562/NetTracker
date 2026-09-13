package ipc

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"time"

	"nettracker-agent/internal/persistence"
	"nettracker-agent/internal/tracker"
)

// Handler exposes the agent operations the socket server can invoke.
type Handler interface {
	Snapshot() tracker.UsageSnapshot
	Last7Days() []persistence.DayEntry
	Reset()
	Rebaseline(reason string)
}

// Server is a Unix domain socket server speaking newline-delimited JSON.
type Server struct {
	path    string
	handler Handler
	log     *slog.Logger
}

// NewServer creates a socket server bound to path.
func NewServer(path string, h Handler, log *slog.Logger) *Server {
	if log == nil {
		log = slog.Default()
	}
	return &Server{path: path, handler: h, log: log}
}

// Serve accepts connections until ctx is cancelled.
func (s *Server) Serve(ctx context.Context) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return fmt.Errorf("mkdir socket dir %s: %w", filepath.Dir(s.path), err)
	}
	if testConn, err := net.DialTimeout("unix", s.path, 300*time.Millisecond); err == nil {
		_ = testConn.Close()
		return fmt.Errorf("agent socket %s already in use by running instance", s.path)
	}
	_ = os.Remove(s.path)
	lc := net.ListenConfig{}
	l, err := lc.Listen(ctx, "unix", s.path)
	if err != nil {
		return fmt.Errorf("listen unix %s: %w", s.path, err)
	}
	defer func() { _ = l.Close() }()
	defer func() { _ = os.Remove(s.path) }()

	go func() {
		<-ctx.Done()
		_ = l.Close()
	}()

	for {
		conn, err := l.Accept()
		if err != nil {
			select {
			case <-ctx.Done():
				return nil
			default:
				s.log.Warn("accept failed", "err", err)
				continue
			}
		}
		go s.serveConn(conn)
	}
}

func (s *Server) serveConn(conn net.Conn) {
	defer func() { _ = conn.Close() }()
	_ = conn.SetDeadline(time.Now().Add(10 * time.Second))
	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	w := bufio.NewWriter(conn)
	defer func() { _ = w.Flush() }()
	for scanner.Scan() {
		line := scanner.Bytes()
		var req Request
		if err := json.Unmarshal(line, &req); err != nil {
			writeResp(w, Response{Version: CurrentVersion, Type: TypeError, Error: "malformed request"})
			_ = w.Flush()
			continue
		}
		if req.Version != CurrentVersion {
			writeResp(w, Response{Version: CurrentVersion, Type: TypeError, Error: "unsupported version"})
			_ = w.Flush()
			continue
		}
		writeResp(w, s.dispatch(req))
		_ = w.Flush()
	}
}

func (s *Server) dispatch(req Request) Response {
	switch req.Type {
	case TypeSnapshot:
		snap := s.handler.Snapshot()
		return Response{
			Version: CurrentVersion,
			Type:    TypeSnapshot,
			Session: &tracker.DailyUsage{
				UploadBytes:   snap.SessionUploadBytes,
				DownloadBytes: snap.SessionDownloadBytes,
			},
			Today: &tracker.DailyUsage{
				UploadBytes:   snap.TodayUploadBytes,
				DownloadBytes: snap.TodayDownloadBytes,
			},
			UploadRate:   snap.CurrentUploadRate,
			DownloadRate: snap.CurrentDownloadRate,
		}
	case TypeHistory:
		return Response{
			Version: CurrentVersion,
			Type:    TypeHistory,
			Days:    s.handler.Last7Days(),
		}
	case TypeReset:
		s.handler.Reset()
		return Response{Version: CurrentVersion, Type: TypeOK, OK: true}
	case TypeNetworkChanged, TypeSleep, TypeWake:
		s.handler.Rebaseline(req.Type)
		return Response{Version: CurrentVersion, Type: TypeOK, OK: true}
	default:
		return Response{Version: CurrentVersion, Type: TypeError, Error: "unknown request type"}
	}
}

// HandleRequest exposes dispatch for unit tests without sockets.
func HandleRequest(h Handler, req Request) Response {
	s := &Server{handler: h, log: slog.Default()}
	return s.dispatch(req)
}

func writeResp(w *bufio.Writer, resp Response) {
	data, err := json.Marshal(resp)
	if err != nil {
		return
	}
	_, _ = w.Write(data)
	_ = w.WriteByte('\n')
}
