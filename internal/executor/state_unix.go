//go:build !windows
// +build !windows

package executor

import "syscall"

func processGroupAlive(pgid int) bool {
	if pgid <= 0 {
		return false
	}
	return syscall.Kill(-pgid, 0) == nil
}
