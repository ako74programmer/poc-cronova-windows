//go:build windows
// +build windows

package main

import (
	"fmt"
	"net"
	"strings"
)

// Windows uses loopback TCP instead of a Unix socket. Use -sock 127.0.0.1:PORT
// and pass the same tcp://127.0.0.1:PORT target to cronova. Binding to loopback
// is mandatory because this endpoint executes arbitrary task commands.
func defaultSocketPath() string { return "127.0.0.1:0" }

func listenExecutorSocket(address string) (net.Listener, func(), error) {
	if address == "" {
		return nil, nil, fmt.Errorf("executor endpoint must be 127.0.0.1:port")
	}
	host, _, err := net.SplitHostPort(address)
	if err != nil || !strings.EqualFold(host, "127.0.0.1") {
		return nil, nil, fmt.Errorf("Windows executor endpoint must bind to 127.0.0.1, got %q", address)
	}
	lis, err := net.Listen("tcp", address)
	if err != nil {
		return nil, nil, fmt.Errorf("listen loopback executor endpoint: %w", err)
	}
	return lis, func() {}, nil
}
