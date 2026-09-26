//go:build windows
// +build windows

package executor

import "testing"

func TestPinGitBashCommand(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{
			name: "plain dag command",
			in:   "bash scripts/sdlc/angular/validate.sh --config configs/sdlc-angular.yaml",
			want: "/usr/bin/bash scripts/sdlc/angular/validate.sh --config configs/sdlc-angular.yaml",
		},
		{
			name: "state wrapper",
			in:   "(\nbash internal/scripts/run-tests -w workspaces/app\n)\nprintf '%s' \"$code\"",
			want: "(\n/usr/bin/bash internal/scripts/run-tests -w workspaces/app\n)\nprintf '%s' \"$code\"",
		},
		{
			name: "unrelated command",
			in:   "echo bash scripts/example.sh",
			want: "echo bash scripts/example.sh",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := pinGitBashCommand(tc.in); got != tc.want {
				t.Fatalf("pinGitBashCommand() = %q, want %q", got, tc.want)
			}
		})
	}
}
