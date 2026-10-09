package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

const (
	serviceName         = "Cronova"
	serviceExecutorName = "CronovaExecutor"
	binDst              = `C:\Program Files\Cronova\cronova.exe`
	binExecutor         = `C:\Program Files\Cronova\cronova-executor.exe`
)

// Service operations talk to the Service Control Manager directly and wait for
// the real service state, so "started" means RUNNING (and still RUNNING after a
// short settle period), not merely "SCM accepted the start request".
var (
	serviceStateTimeout = 30 * time.Second
	serviceSettle       = 3 * time.Second
)

func cmdService(action string) error {
	switch action {
	case "start", "stop", "restart":
		if err := ensureRoot(action); err != nil {
			return err
		}
	}
	switch action {
	case "start":
		return startServices()
	case "stop":
		return stopServices()
	case "restart":
		return restartService()
	case "status":
		return printServiceStatus()
	default:
		return fmt.Errorf("unknown service action %q", action)
	}
}

// ensureRoot fails fast when the process is not elevated: every SCM write and
// the swap of binaries under Program Files need an administrator token.
func ensureRoot(action string) error {
	if windows.GetCurrentProcessToken().IsElevated() {
		return nil
	}
	return fmt.Errorf("cronova %s requires administrator rights: run it from an elevated PowerShell (Run as administrator)", action)
}

func withService(name string, fn func(*mgr.Service) error) error {
	m, err := mgr.Connect()
	if err != nil {
		return fmt.Errorf("connect to Service Control Manager: %w", err)
	}
	defer m.Disconnect()
	s, err := m.OpenService(name)
	if err != nil {
		return fmt.Errorf("open service %s: %w", name, err)
	}
	defer s.Close()
	return fn(s)
}

// queryServiceReadOnly works without elevation (status, install detection):
// mgr.Connect asks for SC_MANAGER_ALL_ACCESS, which a standard user is denied.
func queryServiceReadOnly(name string) (svc.Status, error) {
	h, err := windows.OpenSCManager(nil, nil, windows.SC_MANAGER_CONNECT)
	if err != nil {
		return svc.Status{}, fmt.Errorf("connect to Service Control Manager: %w", err)
	}
	defer windows.CloseServiceHandle(h)
	n, err := windows.UTF16PtrFromString(name)
	if err != nil {
		return svc.Status{}, err
	}
	sh, err := windows.OpenService(h, n, windows.SERVICE_QUERY_STATUS)
	if err != nil {
		return svc.Status{}, err
	}
	s := &mgr.Service{Name: name, Handle: sh}
	defer s.Close()
	return s.Query()
}

func serviceInstalled() bool {
	_, err := queryServiceReadOnly(serviceName)
	return err == nil
}

func waitServiceState(s *mgr.Service, want svc.State, timeout time.Duration) (svc.State, error) {
	deadline := time.Now().Add(timeout)
	for {
		st, err := s.Query()
		if err != nil {
			return 0, err
		}
		if st.State == want {
			return st.State, nil
		}
		if want == svc.Running && st.State == svc.Stopped {
			return st.State, fmt.Errorf("service stopped while starting (exit code %d, service exit code %d)", st.Win32ExitCode, st.ServiceSpecificExitCode)
		}
		if time.Now().After(deadline) {
			return st.State, fmt.Errorf("timed out after %s in state %s", timeout, stateName(st.State))
		}
		time.Sleep(250 * time.Millisecond)
	}
}

func startOne(name string) error {
	return withService(name, func(s *mgr.Service) error {
		st, err := s.Query()
		if err != nil {
			return fmt.Errorf("query %s: %w", name, err)
		}
		if st.State != svc.Running {
			if err := s.Start(); err != nil && !errors.Is(err, windows.ERROR_SERVICE_ALREADY_RUNNING) {
				return fmt.Errorf("start %s: %w", name, err)
			}
		}
		if _, err := waitServiceState(s, svc.Running, serviceStateTimeout); err != nil {
			return fmt.Errorf("start %s: %w — check Event Viewer (System log) and the Cronova logs", name, err)
		}
		// A service can reach RUNNING and crash right after (bad config, port in use).
		time.Sleep(serviceSettle)
		st, err = s.Query()
		if err != nil {
			return fmt.Errorf("query %s: %w", name, err)
		}
		if st.State != svc.Running {
			return fmt.Errorf("start %s: service did not stay running (state %s, exit code %d) — check Event Viewer and the Cronova logs", name, stateName(st.State), st.Win32ExitCode)
		}
		fmt.Printf("cronova: %s RUNNING\n", name)
		return nil
	})
}

func stopOne(name string) error {
	return withService(name, func(s *mgr.Service) error {
		st, err := s.Query()
		if err != nil {
			return fmt.Errorf("query %s: %w", name, err)
		}
		if st.State == svc.Stopped {
			return nil
		}
		if st.State != svc.StopPending {
			if _, err := s.Control(svc.Stop); err != nil && !errors.Is(err, windows.ERROR_SERVICE_NOT_ACTIVE) {
				return fmt.Errorf("stop %s: %w", name, err)
			}
		}
		if _, err := waitServiceState(s, svc.Stopped, serviceStateTimeout); err != nil {
			return fmt.Errorf("stop %s: %w", name, err)
		}
		fmt.Printf("cronova: %s STOPPED\n", name)
		return nil
	})
}

func startServices() error {
	if err := startOne(serviceExecutorName); err != nil {
		return err
	}
	return startOne(serviceName)
}

func stopServices() error {
	if err := stopOne(serviceName); err != nil {
		return err
	}
	return stopOne(serviceExecutorName)
}

func restartService() error {
	if err := stopServices(); err != nil {
		return err
	}
	return startServices()
}

func printServiceStatus() error {
	var firstErr error
	for _, name := range []string{serviceExecutorName, serviceName} {
		st, err := queryServiceReadOnly(name)
		if err != nil {
			fmt.Printf("%-16s not installed (%v)\n", name, err)
			if firstErr == nil {
				firstErr = err
			}
			continue
		}
		fmt.Printf("%-16s %s (pid %d)\n", name, stateName(st.State), st.ProcessId)
	}
	return firstErr
}

func stateName(s svc.State) string {
	switch s {
	case svc.Stopped:
		return "STOPPED"
	case svc.StartPending:
		return "START_PENDING"
	case svc.StopPending:
		return "STOP_PENDING"
	case svc.Running:
		return "RUNNING"
	case svc.ContinuePending:
		return "CONTINUE_PENDING"
	case svc.PausePending:
		return "PAUSE_PENDING"
	case svc.Paused:
		return "PAUSED"
	default:
		return fmt.Sprintf("STATE_%d", s)
	}
}

func deleteOne(name string) {
	_ = stopOne(name)
	_ = withService(name, func(s *mgr.Service) error {
		if err := s.Delete(); err != nil {
			fmt.Fprintf(os.Stderr, "cronova: delete service %s: %v\n", name, err)
		}
		return nil
	})
}

func uninstallWindows(purge bool) error {
	deleteOne(serviceName)
	deleteOne(serviceExecutorName)
	removePath("executor binary", binExecutor)
	removePath("binary", binDst)
	if purge {
		removePath("data", windowsDataDir())
	}
	printUninstallSummary(purge, windowsDataDir())
	return nil
}

func windowsDataDir() string {
	if v := os.Getenv("ProgramData"); v != "" {
		return filepath.Join(v, "Cronova")
	}
	return filepath.Join(`C:\ProgramData`, "Cronova")
}
