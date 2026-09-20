//go:build !windows
// +build !windows

package main

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"syscall"
)

func defaultSocketPath() string {
	return filepath.Join("/tmp", fmt.Sprintf("cronova-%d", os.Getuid()), "executor.sock")
}

func listenExecutorSocket(sock string) (net.Listener, func(), error) {
	if sock == "" || !filepath.IsAbs(sock) {
		return nil, nil, fmt.Errorf("socket path must be absolute")
	}
	dir := filepath.Dir(sock)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, nil, fmt.Errorf("create socket directory: %w", err)
	}
	fi, err := os.Stat(dir)
	if err != nil {
		return nil, nil, fmt.Errorf("stat socket directory: %w", err)
	}
	if !fi.IsDir() || fi.Mode().Perm()&0o077 != 0 {
		return nil, nil, fmt.Errorf("socket directory %s must be private (mode 0700)", dir)
	}
	if st, ok := fi.Sys().(*syscall.Stat_t); !ok || int(st.Uid) != os.Geteuid() {
		return nil, nil, fmt.Errorf("socket directory %s must be owned by uid %d", dir, os.Geteuid())
	}
	if err := os.Remove(sock); err != nil && !os.IsNotExist(err) {
		return nil, nil, fmt.Errorf("remove stale socket: %w", err)
	}
	lis, err := net.Listen("unix", sock)
	if err != nil {
		return nil, nil, err
	}
	cleanup := func() { _ = os.Remove(sock) }
	if err := os.Chmod(sock, 0o600); err != nil {
		_ = lis.Close()
		cleanup()
		return nil, nil, fmt.Errorf("secure socket: %w", err)
	}
	return lis, cleanup, nil
}
