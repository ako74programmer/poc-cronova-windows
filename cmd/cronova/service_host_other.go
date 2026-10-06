//go:build !windows
// +build !windows

package main

func runWindowsService(_ string, runConsole func() error) error {
	return runConsole()
}

func installServiceSignalRelay() (func(), error) {
	return func() {}, nil
}
