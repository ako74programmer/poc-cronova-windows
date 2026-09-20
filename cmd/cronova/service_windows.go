//go:build windows
// +build windows

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

const (
	serviceName         = "Cronova"
	serviceExecutorName = "CronovaExecutor"
	binDst              = `C:\Program Files\Cronova\cronova.exe`
	binExecutor         = `C:\Program Files\Cronova\cronova-executor.exe`
	// Kept only so legacy, unreachable non-Windows uninstall helpers still
	// compile in the package; no Windows command uses these values.
	systemdUnit             = ""
	systemdExecutorUnit     = ""
	systemdUnitPath         = ""
	systemdExecutorUnitPath = ""
	launchdLabel            = ""
	launchdExecutorLabel    = ""
	launchdPlist            = ""
	launchdExecutorPlist    = ""
)

func cmdService(action string) error {
	switch action {
	case "start":
		if err := sc("start", serviceExecutorName); err != nil {
			return err
		}
		return sc("start", serviceName)
	case "stop":
		if err := sc("stop", serviceName); err != nil {
			return err
		}
		return sc("stop", serviceExecutorName)
	case "restart":
		if err := sc("stop", serviceName); err != nil {
			return err
		}
		return sc("start", serviceName)
	case "status":
		return sc("query", serviceName)
	default:
		return fmt.Errorf("unknown service action %q", action)
	}
}

func sc(args ...string) error {
	cmd := exec.Command("sc.exe", args...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("Windows Service Control Manager command %q failed: %w", args[0], err)
	}
	return nil
}

// Windows service installation and update require an elevated PowerShell/admin
// context. We deliberately do not emulate elevation with sudo.
func ensureRoot(action string) error { return nil }

func serviceInstalled() bool {
	return exec.Command("sc.exe", "query", serviceName).Run() == nil
}

func restartService() error {
	if err := sc("stop", serviceName); err != nil {
		return err
	}
	return sc("start", serviceName)
}

func uninstallWindows(purge bool) error {
	_ = sc("stop", serviceName)
	_ = sc("delete", serviceName)
	_ = sc("stop", serviceExecutorName)
	_ = sc("delete", serviceExecutorName)
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

func run(name string, args ...string) error { return exec.Command(name, args...).Run() }
func launchdLoaded() bool                   { return false }
func launchdJobLoaded(string) bool          { return false }
