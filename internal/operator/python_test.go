package operator

import (
	"bytes"
	"context"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunPython(t *testing.T) {
	if _, err := resolvePython(); err != nil {
		t.Skip("no python interpreter available")
	}
	var out bytes.Buffer
	if code := RunPython(context.Background(), "import os\nprint('hi', 2 + 2)", &out); code != 0 {
		t.Fatalf("exit = %d, want 0; out:\n%s", code, out.String())
	}
	if !strings.Contains(out.String(), "hi 4") {
		t.Fatalf("out = %q, want it to contain 'hi 4'", out.String())
	}
	// a non-zero sys.exit propagates as the task exit code (retry-aware)
	out.Reset()
	if code := RunPython(context.Background(), "import sys\nsys.exit(3)", &out); code != 3 {
		t.Fatalf("exit = %d, want 3", code)
	}
	// a raised exception is a non-zero exit
	out.Reset()
	if code := RunPython(context.Background(), "raise ValueError('boom')", &out); code == 0 {
		t.Fatalf("exit = %d, want non-zero for an exception; out:\n%s", code, out.String())
	}
}

func TestResolvePythonSkipsWindowsAppsAlias(t *testing.T) {
	alias := filepath.Join(t.TempDir(), "Microsoft", "WindowsApps")
	if !isWindowsAppsAlias(alias) {
		t.Fatalf("%s should be treated as the Store alias dir", alias)
	}
	if isWindowsAppsAlias(filepath.Join(t.TempDir(), "Python313")) {
		t.Fatal("regular Python dir must not be skipped")
	}
}
