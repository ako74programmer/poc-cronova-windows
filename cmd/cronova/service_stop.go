package main

import "context"

// serviceStopCtx is cancelled when the Windows Service Control Manager asks
// the process to stop; signal contexts derive from it so service and console
// shutdown share the same path.
var serviceStopCtx, serviceStop = context.WithCancel(context.Background())
