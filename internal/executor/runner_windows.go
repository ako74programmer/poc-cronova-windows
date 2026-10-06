//go:build windows
// +build windows

package executor

import (
	"fmt"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

var jobByPID sync.Map // map[int]windows.Handle

func sysProcAttrForGroup() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{CreationFlags: windows.CREATE_NEW_PROCESS_GROUP}
}

func taskCommand(taskType, script string) (*exec.Cmd, error) {
	switch taskType {
	case "", "shell", "powershell", "jar":
		// "shell" is retained as a deprecated YAML alias; on Windows its command
		// is PowerShell, never Bash. New DAGs should say type: powershell.
	case "http", "python", "sql":
		// The scheduler quotes the Cronova executable for the legacy shell
		// command format. PowerShell's call operator is required to execute a
		// quoted path expression.
		script = "& " + script
	default:
		return nil, fmt.Errorf("unsupported Windows task type %q; use PowerShell", taskType)
	}
	return exec.Command("powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", script), nil
}

func attachProcessGroup(cmd *exec.Cmd) error {
	if cmd == nil || cmd.Process == nil {
		return fmt.Errorf("process has no handle")
	}
	job, err := windows.CreateJobObject(nil, nil)
	if err != nil {
		return fmt.Errorf("create Windows Job Object: %w", err)
	}
	info := windows.JOBOBJECT_EXTENDED_LIMIT_INFORMATION{}
	info.BasicLimitInformation.LimitFlags = windows.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
	if _, err := windows.SetInformationJobObject(job, windows.JobObjectExtendedLimitInformation, uintptr(unsafe.Pointer(&info)), uint32(unsafe.Sizeof(info))); err != nil {
		_ = windows.CloseHandle(job)
		return fmt.Errorf("configure Windows Job Object: %w", err)
	}
	process, err := windows.OpenProcess(windows.PROCESS_SET_QUOTA|windows.PROCESS_TERMINATE, false, uint32(cmd.Process.Pid))
	if err != nil {
		_ = windows.CloseHandle(job)
		return fmt.Errorf("open process for Windows Job Object: %w", err)
	}
	defer windows.CloseHandle(process)
	if err := windows.AssignProcessToJobObject(job, process); err != nil {
		_ = windows.CloseHandle(job)
		return fmt.Errorf("assign process to Windows Job Object: %w", err)
	}
	jobByPID.Store(cmd.Process.Pid, job)
	return nil
}

func releaseProcessGroup(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	if value, ok := jobByPID.LoadAndDelete(cmd.Process.Pid); ok {
		_ = windows.CloseHandle(value.(windows.Handle))
	}
}

func preserveProcessGroup(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	if value, ok := jobByPID.LoadAndDelete(cmd.Process.Pid); ok {
		job := value.(windows.Handle)
		info := windows.JOBOBJECT_EXTENDED_LIMIT_INFORMATION{}
		if _, err := windows.SetInformationJobObject(job, windows.JobObjectExtendedLimitInformation, uintptr(unsafe.Pointer(&info)), uint32(unsafe.Sizeof(info))); err != nil {
			// Keep the job handle open if the safety flag could not be removed;
			// closing it would otherwise terminate the task unexpectedly.
			jobByPID.Store(cmd.Process.Pid, job)
			return
		}
		_ = windows.CloseHandle(job)
	}
}

func wrapCommandForState(taskType, command string, stateEnabled bool, exitFilePath string) string {
	if !stateEnabled {
		return command
	}
	path := strings.ReplaceAll(exitFilePath, "'", "''")
	return fmt.Sprintf("$ErrorActionPreference = 'Stop'\n$__cronova_ec = 0\ntry { & {\n%s\n}; if ($LASTEXITCODE -ne $null) { $__cronova_ec = $LASTEXITCODE } } catch { Write-Error $_; $__cronova_ec = 1 }\nSet-Content -LiteralPath '%s' -Value $__cronova_ec -NoNewline\nexit $__cronova_ec", command, path)
}

func killGroup(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	if value, ok := jobByPID.Load(cmd.Process.Pid); ok {
		_ = windows.TerminateJobObject(value.(windows.Handle), 1)
		return
	}
	_ = cmd.Process.Kill()
}

func killGroupByPgid(pgid int) {
	if pgid <= 0 {
		return
	}
	if value, ok := jobByPID.Load(pgid); ok {
		_ = windows.TerminateJobObject(value.(windows.Handle), 1)
		return
	}
	if process, err := windows.OpenProcess(windows.PROCESS_TERMINATE, false, uint32(pgid)); err == nil {
		_ = windows.TerminateProcess(process, 1)
		_ = windows.CloseHandle(process)
	}
}
