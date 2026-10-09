package scheduler

import "testing"

func TestUniqueRunTimeStrictlyIncreases(t *testing.T) {
	prev := uniqueRunTime()
	for i := 0; i < 10000; i++ {
		next := uniqueRunTime()
		if !next.After(prev) {
			t.Fatalf("iteration %d: %v not after %v", i, next, prev)
		}
		prev = next
	}
}
