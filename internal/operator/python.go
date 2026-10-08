package operator

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// RunPython executes inline Python code with `python -c`, streaming
// stdout+stderr to out. The code is passed as an argv
// element, not through a shell, so it needs no quoting/escaping. The child
// inherits this process's env (the injected CRONOVA_* task vars), and ctx bounds
// it (the scheduler kills the run-op group on timeout/cancel). The exit code is
// the interpreter's, so a Python error/non-zero exit fails the task (retry-aware).
func RunPython(ctx context.Context, code string, out io.Writer) int {
	bin, err := resolvePython()
	if err != nil {
		fmt.Fprintln(out, "python: no Python interpreter found (set CRONOVA_PYTHON or put python.exe on PATH)")
		return 1
	}
	cmd := exec.CommandContext(ctx, bin, "-c", code)
	cmd.Stdout = out
	cmd.Stderr = out
	if err := cmd.Run(); err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			return ee.ExitCode()
		}
		fmt.Fprintf(out, "python: %v\n", err)
		return 1
	}
	return 0
}

// resolvePython prefers CRONOVA_PYTHON, then python.exe on PATH. The Microsoft
// Store "App Execution Alias" stubs under ...\Microsoft\WindowsApps are skipped:
// they do not run Python and exit with 9009.
func resolvePython() (string, error) {
	if p := strings.TrimSpace(os.Getenv("CRONOVA_PYTHON")); p != "" {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	for _, dir := range filepath.SplitList(os.Getenv("PATH")) {
		if dir == "" || isWindowsAppsAlias(dir) {
			continue
		}
		candidate := filepath.Join(dir, "python.exe")
		if st, err := os.Stat(candidate); err == nil && !st.IsDir() {
			return candidate, nil
		}
	}
	return "", errors.New("python not found")
}

func isWindowsAppsAlias(dir string) bool {
	return strings.Contains(strings.ToLower(filepath.Clean(dir)), `\microsoft\windowsapps`)
}
