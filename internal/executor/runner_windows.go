//go:build windows
// +build windows

package executor

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

var jobByPID sync.Map // map[int]windows.Handle

func sysProcAttrForGroup() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{CreationFlags: windows.CREATE_NEW_PROCESS_GROUP}
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

func shellCommand(script string) (*exec.Cmd, error) {
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
	return fmt.Sprintf("(\n%s\n)\n__cronova_ec=$?\nprintf '%%s' \"$__cronova_ec\" > %q\nexit \"$__cronova_ec\"", command, exitFilePath)
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
