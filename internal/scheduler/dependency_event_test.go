package scheduler

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/ako74programmer/poc-cronova-windows/internal/executor"
	"github.com/ako74programmer/poc-cronova-windows/internal/model"
)

func TestDependencyEventRetriesAfterGlobalQueueCapacityReturns(t *testing.T) {
	s := newTestScheduler(t)
	s.opts.MaxQueuedRunsGlobal = 1
	ctx := context.Background()
	logical := time.Now().UTC().Truncate(time.Second)

	mkDAG := func(id string, after []string) *model.DAG {
		return &model.DAG{
			DagID: id, MaxActiveRuns: 1, StartDate: logical, TriggerAfter: after,
			Tasks: []model.Task{{ID: "task", Command: "echo ok", Pool: model.DefaultPoolName}},
		}
	}
	for _, dag := range []*model.DAG{
		mkDAG("event_up", nil),
		mkDAG("event_down", []string{"event_up"}),
		mkDAG("queue_blocker", nil),
	} {
		if err := s.registerDAG(ctx, dag); err != nil {
			t.Fatal(err)
		}
	}

	// An existing running downstream must not suppress a dependency run. The
	// queued->running gate, not event delivery, owns max_active_runs enforcement.
	existingLogical := logical.Add(-time.Hour)
	if err := s.store.CreateDagRun(ctx, &model.DagRun{
		RunID: "event_down__active", DagID: "event_down", LogicalDate: existingLogical,
		State: model.RunRunning, TriggerType: model.TriggerManual,
	}); err != nil {
		t.Fatal(err)
	}
	if err := s.store.CreateDagRun(ctx, &model.DagRun{
		RunID: "queue_blocker__queued", DagID: "queue_blocker", LogicalDate: logical,
		State: model.RunQueued, TriggerType: model.TriggerManual,
	}); err != nil {
		t.Fatal(err)
	}
	if err := s.store.CreateDagRun(ctx, &model.DagRun{
		RunID: "event_up__success", DagID: "event_up", LogicalDate: logical,
		State: model.RunRunning, TriggerType: model.TriggerManual,
	}); err != nil {
		t.Fatal(err)
	}
	if err := s.store.UpdateDagRunSuccess(ctx, "event_up__success", &logical, &logical); err != nil {
		t.Fatal(err)
	}

	s.processPendingDependencyEvents(ctx)
	if runs, _ := s.store.ListDagRuns(ctx, "event_down", 10); len(runs) != 1 {
		t.Fatalf("downstream runs while queue full = %d, want only existing active run", len(runs))
	}
	if events, _ := s.store.ListPendingEvents(ctx, model.EventSourceDependency, 10); len(events) != 1 {
		t.Fatalf("pending events while queue full = %d, want 1", len(events))
	}

	// Moving the blocker out of queued state releases admission capacity. The
	// next delivery creates a queued downstream even though another run of that
	// DAG is still active, and then consumes the event.
	if err := s.store.UpdateDagRunState(ctx, "queue_blocker__queued", model.RunRunning, &logical, nil); err != nil {
		t.Fatal(err)
	}
	s.processPendingDependencyEvents(ctx)
	runs, err := s.store.ListDagRuns(ctx, "event_down", 10)
	if err != nil || len(runs) != 2 {
		t.Fatalf("downstream runs after capacity returns = %+v, err=%v", runs, err)
	}
	var dependency *model.DagRun
	for _, run := range runs {
		if run.LogicalDate.Equal(logical) {
			dependency = run
		}
	}
	if dependency == nil || dependency.State != model.RunQueued || dependency.TriggerType != model.TriggerDependency {
		t.Fatalf("dependency run = %+v, want queued dependency run", dependency)
	}
	if events, _ := s.store.ListPendingEvents(ctx, model.EventSourceDependency, 10); len(events) != 0 {
		t.Fatalf("pending events after delivery = %d, want 0", len(events))
	}
}

func TestDependencyTriggerMatchesManualRunsBySyncKey(t *testing.T) {
	s := newTestScheduler(t)
	ctx := context.Background()
	for _, dag := range []*model.DAG{
		{DagID: "sync_up_a", MaxActiveRuns: 1, StartDate: time.Now().UTC(), Tasks: []model.Task{{ID: "a", Command: "echo a", Pool: model.DefaultPoolName}}},
		{DagID: "sync_up_b", MaxActiveRuns: 1, StartDate: time.Now().UTC(), Tasks: []model.Task{{ID: "b", Command: "echo b", Pool: model.DefaultPoolName}}},
		{DagID: "sync_down", MaxActiveRuns: 1, StartDate: time.Now().UTC(), TriggerAfter: []string{"sync_up_a", "sync_up_b"}, Tasks: []model.Task{{ID: "d", Command: "echo d", Pool: model.DefaultPoolName}}},
	} {
		if err := s.registerDAG(ctx, dag); err != nil {
			t.Fatal(err)
		}
	}

	params := map[string]string{dependencySyncParam: "stack-20261004"}
	runA, err := s.TriggerManual(ctx, "sync_up_a", params)
	if err != nil {
		t.Fatal(err)
	}
	s.driveToTerminal(t, ctx, runA, 20)

	runs, err := s.store.ListDagRuns(ctx, "sync_down", 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(runs) != 0 {
		t.Fatalf("downstream should wait for both upstreams, got %d run(s)", len(runs))
	}

	runB, err := s.TriggerManual(ctx, "sync_up_b", params)
	if err != nil {
		t.Fatal(err)
	}
	s.driveToTerminal(t, ctx, runB, 20)

	var dependency *model.DagRun
	for i := 0; i < 40; i++ {
		s.tickOnce(ctx)
		s.WaitInflight()
		runs, err = s.store.ListDagRuns(ctx, "sync_down", 10)
		if err != nil {
			t.Fatal(err)
		}
		if len(runs) > 0 && runs[0].State.IsTerminal() {
			dependency = runs[0]
			break
		}
	}
	if dependency == nil {
		t.Fatal("downstream run was never created")
	}
	if dependency.TriggerType != model.TriggerDependency {
		t.Fatalf("downstream trigger = %s, want dependency", dependency.TriggerType)
	}
	if dependency.State != model.RunSuccess {
		t.Fatalf("downstream state = %s, want success", dependency.State)
	}
	if dependency.Params[dependencySyncParam] != "" {
		t.Fatalf("downstream params should stay empty, got %q", dependency.Params[dependencySyncParam])
	}
}

type stickyRunningExecutor struct {
	stateDir string
	ref      string
}

func (s stickyRunningExecutor) Launch(_ context.Context, spec executor.Spec) (string, error) {
	s.ref = spec.TaskRunID
	return spec.TaskRunID, nil
}

func (s stickyRunningExecutor) Probe(_ context.Context, _ string) (executor.Status, error) {
	return executor.Status{Phase: executor.PhaseRunning}, nil
}

func (s stickyRunningExecutor) Cancel(_ context.Context, _ string) error { return nil }

func (s stickyRunningExecutor) StateDir() string { return s.stateDir }

func TestAwaitCompletionRecoversPersistedExitCode(t *testing.T) {
	stateDir := t.TempDir()
	logDir := filepath.Join(t.TempDir(), "logs")
	ref := "run/task/1"
	if err := os.WriteFile(filepath.Join(stateDir, "run_task_1.json.exit"), []byte("0\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	st := newStore(t)
	execStub := stickyRunningExecutor{stateDir: stateDir, ref: ref}
	s := New(st, execStub, Options{LogDir: logDir, Tick: 5 * time.Millisecond, PollInterval: 5 * time.Millisecond})
	ctx := context.Background()
	dag := &model.DAG{
		DagID: "recover_finish", MaxActiveRuns: 1, StartDate: time.Now().UTC(),
		Tasks: []model.Task{{ID: "task", Command: "echo ok", Pool: model.DefaultPoolName}},
	}
	if err := s.registerDAG(ctx, dag); err != nil {
		t.Fatal(err)
	}
	run := &model.DagRun{RunID: "recover_finish__manual", DagID: dag.DagID, LogicalDate: time.Now().UTC(), State: model.RunRunning, TriggerType: model.TriggerManual}
	snapshotRun(run, dag)
	if err := st.CreateDagRun(ctx, run); err != nil {
		t.Fatal(err)
	}
	ti := &model.TaskInstance{
		RunID: run.RunID, TaskID: "task", State: model.TaskRunning, TryNumber: 1,
		MaxRetries: 1, Pool: model.DefaultPoolName, ExecutorRef: ref,
		LogPath: filepath.Join(logDir, "recover_finish", run.RunID, "task.log"),
	}
	now := time.Now().UTC()
	ti.StartedAt = &now
	if err := st.CreateTaskInstance(ctx, ti); err != nil {
		t.Fatal(err)
	}

	done := make(chan struct{})
	go func() {
		s.awaitCompletion(ctx, ti)
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("awaitCompletion did not recover persisted exit code")
	}
	updated, err := st.GetTaskInstance(ctx, ti.ID)
	if err != nil {
		t.Fatal(err)
	}
	if updated.State != model.TaskSuccess {
		t.Fatalf("task state = %s, want success", updated.State)
	}
}

func TestRecoverCompletedLogExitCode(t *testing.T) {
	logPath := filepath.Join(t.TempDir(), "playwright_e2e.log")
	content := "=== cronova task x started at 2026-10-04T20:57:27Z ===\n2 passed (4.2s)\nStopped frontend PID 19740\nStopped backend PID 12608\n"
	if err := os.WriteFile(logPath, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	exitCode, ok := recoverCompletedLogExitCode(logPath)
	if !ok {
		t.Fatal("expected completed log to be recognized")
	}
	if exitCode != 0 {
		t.Fatalf("exit code = %d, want 0", exitCode)
	}
}
