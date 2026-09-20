//go:build !windows
// +build !windows

package executor

import (
	"fmt"
	"os/exec"
	"syscall"
)

func sysProcAttrForGroup() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{Setpgid: true}
}

func shellCommand(script string) (*exec.Cmd, error) {
	return exec.Command("sh", "-c", script), nil
}

func wrapCommandForState(command string, stateEnabled bool, exitFilePath string) string {
	if !stateEnabled {
		return command
	}
	return fmt.Sprintf("(\n%s\n)\n__cronova_ec=$?\nprintf '%%d' \"$__cronova_ec\" > %q\nexit \"$__cronova_ec\"", command, exitFilePath)
}

func killGroup(cmd *exec.Cmd) {
	if cmd.Process == nil {
		return
	}
	_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
}

func killGroupByPgid(pgid int) {
	if pgid > 0 {
		_ = syscall.Kill(-pgid, syscall.SIGKILL)
	}
}
