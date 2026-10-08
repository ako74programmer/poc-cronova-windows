//go:build windows
// +build windows

package main

import (
	"fmt"
	"golang.org/x/sys/windows/svc"
)

func runWindowsService(name string, runConsole func() error) error {
	isService, err := svc.IsWindowsService()
	if err != nil {
		return fmt.Errorf("detect Windows service context: %w", err)
	}
	if !isService {
		return runConsole()
	}
	return svc.Run(name, &windowsServiceHandler{run: runConsole})
}

type windowsServiceHandler struct {
	run func() error
}

func (h *windowsServiceHandler) Execute(_ []string, requests <-chan svc.ChangeRequest, changes chan<- svc.Status) (bool, uint32) {
	const accepted = svc.AcceptStop | svc.AcceptShutdown
	changes <- svc.Status{State: svc.StartPending}

	changes <- svc.Status{State: svc.Running, Accepts: accepted}

	errCh := make(chan error, 1)
	go func() {
		errCh <- h.run()
	}()

	stopRequested := false
	for {
		select {
		case req := <-requests:
			switch req.Cmd {
			case svc.Interrogate:
				changes <- req.CurrentStatus
			case svc.Stop, svc.Shutdown:
				if !stopRequested {
					stopRequested = true
					changes <- svc.Status{State: svc.StopPending, Accepts: 0}
					serviceStop()
				}
			case svc.Pause, svc.Continue:
			default:
			}
		case runErr := <-errCh:
			if runErr != nil {
				return false, 1
			}
			return false, 0
		}
	}
}
