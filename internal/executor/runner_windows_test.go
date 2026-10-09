package executor

import (
	"path/filepath"
	"strings"
	"testing"
)

func TestWindowsTaskCommandUsesPowerShell(t *testing.T) {
	for _, taskType := range []string{"", "powershell", "jar"} {
		t.Run(taskType, func(t *testing.T) {
			cmd, err := taskCommand(taskType, "Write-Output ok")
			if err != nil {
				t.Fatalf("taskCommand: %v", err)
			}
			if got := filepath.Base(cmd.Path); !strings.EqualFold(got, "powershell.exe") {
				t.Fatalf("executable = %q, want powershell.exe", got)
			}
			joined := strings.Join(cmd.Args, " ")
			if !strings.Contains(joined, "-NoProfile") || !strings.Contains(joined, "Write-Output ok") {
				t.Fatalf("unexpected PowerShell arguments: %q", joined)
			}
		})
	}
}

func TestWindowsOperatorTaskUsesPowerShellCallOperator(t *testing.T) {
	cmd, err := taskCommand("python", `"C:\Cronova\cronova.exe" run-op python`)
	if err != nil {
		t.Fatalf("taskCommand: %v", err)
	}
	if got := filepath.Base(cmd.Path); !strings.EqualFold(got, "powershell.exe") {
		t.Fatalf("executable = %q, want powershell.exe", got)
	}
	if got := cmd.Args[len(cmd.Args)-1]; !strings.HasPrefix(got, "& ") {
		t.Fatalf("operator command = %q, want PowerShell call operator prefix", got)
	}
}

func TestWindowsTaskCommandRejectsUnknownType(t *testing.T) {
	if _, err := taskCommand("shell", "echo not supported"); err == nil {
		t.Fatal("unknown task type should not fall back to a shell")
	}
}
