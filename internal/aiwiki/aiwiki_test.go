package aiwiki

import (
	"context"
	"strings"
	"testing"
)

func TestNew(t *testing.T) {
	wiki, err := New(nil)
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}
	if len(wiki.kb.Chunks) == 0 {
		t.Fatal("expected non-empty knowledge base")
	}
}

func TestAskRetry(t *testing.T) {
	wiki, err := New(nil)
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}
	ans := wiki.Ask(context.Background(), "Jak ustawić retry dla taska?", "pl")
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
	wiki, err := New(nil)
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}
	ans := wiki.Ask(context.Background(), "xyzabc123 notfound", "en")
	if ans.Answer == "" {
		t.Fatal("expected fallback answer")
	}
}

func TestBM25Retrieval(t *testing.T) {
	wiki, err := New(nil)
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}
	hits := wiki.index.search("Jak ustawić retry dla taska?", 3)
	if len(hits) == 0 {
		t.Fatal("expected BM25 hits")
	}
	// The top hit should mention retries or task fields.
	top := hits[0].chunk
	text := strings.ToLower(top.Text + " " + top.Section)
	if !strings.Contains(text, "retry") && !strings.Contains(text, "retries") {
		t.Fatalf("expected top hit to be about retries, got section %q", top.Section)
	}
}
