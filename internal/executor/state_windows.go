//go:build windows
// +build windows

package executor

import (
	"os"
	"syscall"
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
	_ = syscall.CloseHandle(h)
	return true
}
