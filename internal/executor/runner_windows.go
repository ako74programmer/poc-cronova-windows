//go:build windows
// +build windows

package executor

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
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

func shellCommand(script string) *exec.Cmd {
	// Prefer Git Bash on Windows so Unix-style DAG commands (set -e, here-docs,
	// curl, mvn, java, python3) work out of the box. WSL's bash is in PATH before
	// Git's, but it cannot exec on this filesystem, so look for Git Bash explicitly first.
	gitBash := `C:\Program Files\Git\bin\bash.exe`
	if _, err := os.Stat(gitBash); err == nil {
		return exec.Command(gitBash, "-c", script)
	}
	if bash, err := exec.LookPath("bash"); err == nil && bash != "" {
		return exec.Command(bash, "-c", script)
	}
	return exec.Command("cmd.exe", "/C", script)
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
	_ = exec.Command("taskkill", "/T", "/F", "/PID", strconv.Itoa(cmd.Process.Pid)).Run()
}

func killGroupByPgid(pgid int) {
	if pgid <= 0 {
		return
	}
	// pgid is just the process id on Windows; taskkill /T kills the tree.
	_ = exec.Command("taskkill", "/T", "/F", "/PID", strconv.Itoa(pgid)).Run()
}

