package scheduler

import (
	"sync"
	"time"
)

var (
	runTimeMu   sync.Mutex
	lastRunTime time.Time
)

// uniqueRunTime returns the current UTC time, strictly increasing across calls.
// Windows clock reads can repeat within the same tick, which would give two
// manual triggers the same nanosecond-based run ID.
func uniqueRunTime() time.Time {
	runTimeMu.Lock()
	defer runTimeMu.Unlock()
	now := time.Now().UTC()
	if !now.After(lastRunTime) {
		now = lastRunTime.Add(time.Nanosecond)
	}
	lastRunTime = now
	return now
}
