package aiwiki

import (
	"os"
	"path/filepath"
	"regexp"
	"testing"
)

// The embedded knowledge base must describe the Windows-only, PowerShell-only
// product. These rules mirror FORBIDDEN in internal/ai-wiki/build_knowledge_base.py
// so a stale or hand-edited knowledge-base.json fails CI even if the generator
// was not re-run.
var forbiddenKB = []struct {
	re  *regexp.Regexp
	why string
}{
	{regexp.MustCompile(`#!/usr/bin/env (ba)?sh`), "Unix shell shebang"},
	{regexp.MustCompile(`(?m)^\s*type:\s*shell\s*$`), "task type: shell"},
	{regexp.MustCompile(`\bsh -c\b`), "sh -c runtime"},
	{regexp.MustCompile(`\bbash\s+(/|\S+\.sh\b)`), "bash script invocation"},
	{regexp.MustCompile(`\S+\.sh\b`), ".sh script reference"},
	{regexp.MustCompile(`curl[^\n|]*\|\s*(sudo\s+)?(ba)?sh`), "curl | sh installer"},
	{regexp.MustCompile(`\b(systemctl|launchctl)\b`), "systemd/launchd"},
	{regexp.MustCompile(`unix:///`), "Unix socket executor target"},
	{regexp.MustCompile(`(?i)\b[a-z]:[/\\]users[/\\][a-z0-9._-]+`), "developer Windows user path"},
	{regexp.MustCompile(`(?i)/c/users/[a-z0-9._-]+/`), "developer Git Bash path"},
	{regexp.MustCompile(`(?i)\bgit bash\b`), "Git Bash runtime"},
}

func TestKnowledgeBaseHasNoForbiddenContent(t *testing.T) {
	wiki, err := New(nil)
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range wiki.kb.Chunks {
		for _, f := range forbiddenKB {
			if m := f.re.FindString(c.Text); m != "" {
				t.Errorf("%s [%s]: %s: %q — fix the source and run scripts/build-ai-wiki.ps1", c.Source, c.Section, f.why, m)
			}
		}
	}
}

func TestKnowledgeBaseSourcesExist(t *testing.T) {
	wiki, err := New(nil)
	if err != nil {
		t.Fatal(err)
	}
	root := filepath.Join("..", "..")
	seen := map[string]bool{}
	for _, c := range wiki.kb.Chunks {
		if seen[c.Source] {
			continue
		}
		seen[c.Source] = true
		if _, err := os.Stat(filepath.Join(root, filepath.FromSlash(c.Source))); err != nil {
			t.Errorf("chunk source %s is not in the repository: %v", c.Source, err)
		}
	}
}
