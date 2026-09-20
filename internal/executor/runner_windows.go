//go:build windows
// +build windows

package executor

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
)

func sysProcAttrForGroup() *syscall.SysProcAttr {
	// On Windows we cannot create a Unix-style process group, but we can ask
	// the new process to be created in its own console group so taskkill /T
	// can terminate the whole tree.
	return &syscall.SysProcAttr{
		CreationFlags: syscall.CREATE_NEW_PROCESS_GROUP,
	}
}

func shellCommand(script string) (*exec.Cmd, error) {
	// Git Bash is the only supported shell for shell tasks. The explicit setting
	// wins, then PATH, then the two conventional Git for Windows locations.
	var candidates []string
	if configured := os.Getenv("CRONOVA_BASH_PATH"); configured != "" {
		candidates = append(candidates, configured)
	}
	if bash, err := exec.LookPath("bash.exe"); err == nil {
		candidates = append(candidates, bash)
	}
	programFiles := os.Getenv("ProgramFiles")
	if programFiles == "" {
		programFiles = `C:\Program Files`
	}
	for _, root := range []string{programFiles, os.Getenv("ProgramW6432")} {
		if root != "" {
			candidates = append(candidates, filepath.Join(root, "Git", "usr", "bin", "bash.exe"))
			candidates = append(candidates, filepath.Join(root, "Git", "bin", "bash.exe"))
		}
	}
	seen := map[string]bool{}
	for _, candidate := range candidates {
		if candidate == "" || seen[candidate] {
			continue
		}
		seen[candidate] = true
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return exec.Command(candidate, "-lc", script), nil
		}
	}
	return nil, fmt.Errorf("Git for Windows Bash was not found; install Git for Windows or set CRONOVA_BASH_PATH to bash.exe")
}

func wrapCommandForState(command string, stateEnabled bool, exitFilePath string) string {
	if !stateEnabled {
		return command
	}
	// Bash: run command, capture exit code, write it to sidecar, then exit.
	return fmt.Sprintf("(\n%s\n)\n__cronova_ec=$?\nprintf '%%s' \"$__cronova_ec\" > %q\nexit \"$__cronova_ec\"", command, exitFilePath)
}

func killGroup(cmd *exec.Cmd) {
	if cmd.Process == nil {
		return
	}
	_ = exec.Command("taskkill", "/T", "/F", "/PID", fmt.Sprint(cmd.Process.Pid)).Run()
}

func killGroupByPgid(pgid int) {
	if pgid <= 0 {
		return
	}
	// pgid is just the process id on Windows; taskkill /T kills the tree.
	_ = exec.Command("taskkill", "/T", "/F", "/PID", fmt.Sprint(pgid)).Run()
}
