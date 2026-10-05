//go:build windows
// +build windows

package executor

import (
	"os"
	"syscall"

	"golang.org/x/sys/windows"
)

func processGroupAlive(pgid int) bool {
	if pgid <= 0 {
		return false
	}
	p, err := os.FindProcess(pgid)
	if err != nil {
		return false
	}
	h, err := syscall.OpenProcess(syscall.SYNCHRONIZE, false, uint32(p.Pid))
	if err != nil {
		return false
	}
	defer syscall.CloseHandle(h)
	var code uint32
	if err := windows.GetExitCodeProcess(windows.Handle(h), &code); err != nil {
		return false
	}
	return code == 259
}
