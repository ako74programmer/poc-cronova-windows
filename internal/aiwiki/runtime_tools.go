package aiwiki

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"

	"github.com/ako74programmer/poc-cronova-windows/internal/model"
	"github.com/ako74programmer/poc-cronova-windows/internal/scheduler/parser"
	"github.com/ako74programmer/poc-cronova-windows/internal/store"
)

const maxRecentRunToolLimit = 10

func (w *Wiki) executeRuntimeTool(ctx context.Context, name string, raw json.RawMessage) (string, []Source, error) {
	if w.store == nil {
		return "", nil, fmt.Errorf("Cronova runtime store is unavailable")
	}
	switch name {
	case "list_recent_runs":
		var args struct {
			Limit int `json:"limit"`
		}
		if err := decodeToolArguments(raw, &args); err != nil {
			return "", nil, err
		}
		limit := args.Limit
		if limit == 0 {
			limit = maxRecentRunToolLimit
		}
		if limit < 1 || limit > maxRecentRunToolLimit {
			return "", nil, fmt.Errorf("limit must be between 1 and %d", maxRecentRunToolLimit)
		}
		runs, err := w.store.RecentRuns(ctx, limit)
		if err != nil {
			return "", nil, err
		}
		items := make([]map[string]any, 0, len(runs))
		sources := make([]Source, 0, len(runs))
		for _, run := range runs {
			if run == nil || run.RunID == "" {
				continue
			}
			items = append(items, map[string]any{
				"run_id": run.RunID, "dag_id": run.DagID, "state": run.State,
				"trigger": run.TriggerType, "logical_date": run.LogicalDate.UTC().Format("2006-01-02T15:04:05Z"),
				"started_at": formatRuntimeTime(run.StartedAt), "finished_at": formatRuntimeTime(run.FinishedAt),
			})
			sources = append(sources, Source{Type: "runtime", Path: "runs/" + run.RunID, Section: "Recent runs"})
		}
		return marshalToolResult(map[string]any{"runs": items, "returned": len(items), "limit": limit}), sources, nil

	case "find_recent_task":
		var args struct {
			TaskID string `json:"task_id"`
			Limit  int    `json:"limit"`
		}
		if err := decodeToolArguments(raw, &args); err != nil {
			return "", nil, err
		}
		args.TaskID = strings.TrimSpace(args.TaskID)
		if args.TaskID == "" || len(args.TaskID) > 128 {
			return "", nil, fmt.Errorf("task_id is required and must not exceed 128 characters")
		}
		limit := args.Limit
		if limit == 0 {
			limit = maxRecentRunToolLimit
		}
		if limit < 1 || limit > maxRecentRunToolLimit {
			return "", nil, fmt.Errorf("limit must be between 1 and %d", maxRecentRunToolLimit)
		}
		runs, err := w.store.RecentRuns(ctx, limit)
		if err != nil {
			return "", nil, err
		}
		matches := make([]map[string]any, 0)
		sources := make([]Source, 0)
		for _, run := range runs {
			if run == nil || run.RunID == "" {
				continue
			}
			tasks, err := w.store.ListTaskInstances(ctx, run.RunID)
			if err != nil {
				if errors.Is(err, store.ErrNotFound) {
					continue
				}
				return "", nil, err
			}
			for _, task := range tasks {
				if task == nil || task.TaskID != args.TaskID {
					continue
				}
				matches = append(matches, map[string]any{
					"run_id": run.RunID, "dag_id": run.DagID, "run_state": run.State,
					"task_id": task.TaskID, "task_state": task.State, "try_number": task.TryNumber,
				})
				sources = append(sources, Source{Type: "runtime", Path: "runs/" + run.RunID, Section: "Task " + task.TaskID + " instance"})
			}
		}
		return marshalToolResult(map[string]any{"task_id": args.TaskID, "matches": matches, "returned": len(matches), "runs_scanned": len(runs)}), sources, nil

	case "inspect_run":
		var args struct {
			RunID string `json:"run_id"`
		}
		if err := decodeToolArguments(raw, &args); err != nil {
			return "", nil, err
		}
		runID, err := validateToolIdentifier("run_id", args.RunID, 256)
		if err != nil {
			return "", nil, err
		}
		chunks, err := w.runtimeContext(ctx, runID, false, "")
		if err != nil {
			return "", nil, err
		}
		return marshalToolResult(map[string]any{"run_id": runID, "snapshot": chunks[0].Text}), []Source{{Type: "runtime", Path: "runs/" + runID, Section: chunks[0].Section}}, nil

	case "inspect_task":
		var args struct {
			RunID  string `json:"run_id"`
			TaskID string `json:"task_id"`
		}
		if err := decodeToolArguments(raw, &args); err != nil {
			return "", nil, err
		}
		runID, err := validateToolIdentifier("run_id", args.RunID, 256)
		if err != nil {
			return "", nil, err
		}
		taskID, err := validateToolIdentifier("task_id", args.TaskID, 128)
		if err != nil {
			return "", nil, err
		}
		run, task, err := w.findTask(ctx, runID, taskID)
		if err != nil {
			return "", nil, err
		}
		result := map[string]any{
			"run_id": run.RunID, "dag_id": run.DagID, "task_id": task.TaskID,
			"state": task.State, "try_number": task.TryNumber, "max_retries": task.MaxRetries,
			"pool": task.Pool,
		}
		section := "Task " + task.TaskID + " instance"
		if run.DefinitionYAML != "" {
			dag, parseErr := parser.Parse([]byte(run.DefinitionYAML))
			if parseErr == nil {
				for _, definition := range dag.Tasks {
					if definition.ID == taskID {
						result["configured_type"] = definition.Type
						result["configured_command"] = redactLog(definition.Command)
						result["definition_source"] = "immutable run definition"
						section = "Task " + task.TaskID + " definition and instance"
						break
					}
				}
			} else {
				result["definition_note"] = "The immutable run definition could not be parsed."
			}
		}
		if _, ok := result["configured_command"]; !ok {
			result["definition_note"] = "No matching task definition was available in the immutable run snapshot; only the stored task instance is shown."
		}
		return marshalToolResult(result), []Source{{Type: "runtime", Path: "runs/" + runID, Section: section}}, nil

	case "get_task_logs":
		var args struct {
			RunID  string `json:"run_id"`
			TaskID string `json:"task_id"`
		}
		if err := decodeToolArguments(raw, &args); err != nil {
			return "", nil, err
		}
		runID, err := validateToolIdentifier("run_id", args.RunID, 256)
		if err != nil {
			return "", nil, err
		}
		taskID, err := validateToolIdentifier("task_id", args.TaskID, 128)
		if err != nil {
			return "", nil, err
		}
		_, task, err := w.findTask(ctx, runID, taskID)
		if err != nil {
			return "", nil, err
		}
		logText, err := readLogTail(task.LogPath, 8192)
		if err != nil {
			return marshalToolResult(map[string]any{
				"run_id": runID, "task_id": taskID, "try_number": task.TryNumber,
				"error": "Log file is not available.",
			}), []Source{{Type: "runtime_log", Path: "runs/" + runID, Section: "Task " + taskID + " log"}}, nil
		}
		return marshalToolResult(map[string]any{
			"run_id": runID, "task_id": taskID, "try_number": task.TryNumber,
			"log_tail_redacted": logText, "max_bytes": 8192,
		}), []Source{{Type: "runtime_log", Path: "runs/" + runID, Section: "Task " + taskID + " log (redacted tail)"}}, nil
	default:
		return "", nil, fmt.Errorf("unknown read-only runtime tool %q", name)
	}
}

func (w *Wiki) findTask(ctx context.Context, runID, taskID string) (*model.DagRun, *model.TaskInstance, error) {
	run, err := w.store.GetDagRun(ctx, runID)
	if err != nil {
		return nil, nil, err
	}
	tasks, err := w.store.ListTaskInstances(ctx, runID)
	if err != nil {
		return nil, nil, err
	}
	var match *model.TaskInstance
	for _, task := range tasks {
		if task == nil || task.TaskID != taskID {
			continue
		}
		if match == nil || task.TryNumber > match.TryNumber {
			match = task
		}
	}
	if match == nil {
		return nil, nil, fmt.Errorf("task %q was not found in run %q", taskID, runID)
	}
	return run, match, nil
}

func validateToolIdentifier(name, value string, maxLength int) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" || len(value) > maxLength {
		return "", fmt.Errorf("%s is required and must not exceed %d characters", name, maxLength)
	}
	for _, r := range value {
		if r < 0x20 || r == 0x7f {
			return "", fmt.Errorf("%s contains invalid control characters", name)
		}
	}
	return value, nil
}

func decodeToolArguments(raw json.RawMessage, target any) error {
	if len(raw) == 0 || string(raw) == "null" {
		raw = json.RawMessage(`{}`)
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return fmt.Errorf("invalid tool arguments: %w", err)
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return fmt.Errorf("invalid tool arguments: unexpected trailing JSON")
	}
	return nil
}

func marshalToolResult(value any) string {
	encoded, err := json.Marshal(value)
	if err != nil {
		return `{"error":"Could not encode tool result."}`
	}
	return string(encoded)
}
