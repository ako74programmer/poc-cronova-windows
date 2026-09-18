package aiwiki

import (
	"strings"
	"testing"
)

func TestNew(t *testing.T) {
	wiki, err := New()
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}
	if len(wiki.kb.Chunks) == 0 {
		t.Fatal("expected non-empty knowledge base")
	}
}

func TestAskRetry(t *testing.T) {
	wiki, err := New()
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}
	ans := wiki.Ask("Jak ustawić retry dla taska?")
	if ans.Answer == "" {
		t.Fatal("expected non-empty answer")
	}
	if !strings.Contains(strings.ToLower(ans.Answer), "retry") {
		t.Fatalf("expected answer to mention retry, got: %s", ans.Answer)
	}
	if len(ans.Sources) == 0 {
		t.Fatal("expected at least one source")
	}
}

func TestAskUnknown(t *testing.T) {
	wiki, err := New()
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}
	ans := wiki.Ask("xyzabc123 notfound")
	if ans.Answer == "" {
		t.Fatal("expected fallback answer")
	}
}
