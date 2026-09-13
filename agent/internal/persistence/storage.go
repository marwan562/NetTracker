// Package persistence handles atomic checkpointing and historical daily usage queries.
package persistence

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"nettracker-agent/internal/tracker"
)

// FileSchema is the on-disk JSON schema. All values are integer bytes.
type FileSchema struct {
	History map[string]tracker.DailyUsage `json:"history"`
}

// Load reads and validates the history file. Corrupt data is backed up
// alongside the original and an empty history is returned so valid data is
// never destroyed on a bad read.
func Load(path string) (map[string]tracker.DailyUsage, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return make(map[string]tracker.DailyUsage), nil
		}
		return nil, err
	}
	if len(data) == 0 {
		return make(map[string]tracker.DailyUsage), nil
	}
	var schema FileSchema
	if err := json.Unmarshal(data, &schema); err != nil {
		backup := fmt.Sprintf("%s.corrupt-%s.bak", path, time.Now().Format("20060102-150405"))
		_ = os.WriteFile(backup, data, 0o600)
		return make(map[string]tracker.DailyUsage), fmt.Errorf("corrupt history, backed up to %s: %w", backup, err)
	}
	if schema.History == nil {
		schema.History = make(map[string]tracker.DailyUsage)
	}
	return schema.History, nil
}

// Save writes history atomically: tmp file, sync, close, rename.
func Save(path string, history map[string]tracker.DailyUsage) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(FileSchema{History: history}, "", "  ")
	if err != nil {
		return err
	}
	return saveAtomic(path, data)
}

func saveAtomic(path string, data []byte) error {
	tmp := path + ".tmp"
	f, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	if _, err := f.Write(data); err != nil {
		_ = f.Close()
		_ = os.Remove(tmp)
		return err
	}
	if err := f.Sync(); err != nil {
		_ = f.Close()
		_ = os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, path)
}
