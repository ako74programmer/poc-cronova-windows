package aiwiki

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/ako74programmer/poc-cronova-windows/internal/model"
)

type chatRequest struct {
	Messages []struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	} `json:"messages"`
}

func writeChatResponse(w http.ResponseWriter, content string) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = fmt.Fprintf(w, `{"choices":[{"message":{"content":%q}}]}`, content)
}

func TestAskExpansionFindsInstallDocsWithTypoAndFollowUpHistory(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		var req chatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Errorf("decode request: %v", err)
		}
		if calls == 1 {
			var foundHistory bool
			for _, msg := range req.Messages {
				if msg.Role == "user" && strings.Contains(msg.Content, "poprzednia rozmowa") {
					foundHistory = true
				}
			}
			if !foundHistory {
				t.Errorf("query expansion did not receive conversation history: %+v", req.Messages)
			}
			writeChatResponse(w, `["install Cronova per-user without admin rights", "setup.cmd UAC declined per-user"]`)
			return
		}
		var sawPrior, sawDocs bool
		for _, msg := range req.Messages {
			if strings.Contains(msg.Content, "poprzednia rozmowa") {
				sawPrior = true
			}
			if strings.Contains(msg.Content, "without admin rights") || strings.Contains(msg.Content, "UAC is declined") {
				sawDocs = true
			}
		}
		if !sawPrior {
			t.Errorf("answer generation did not receive conversation history")
		}
		if !sawDocs {
			t.Errorf("answer generation did not receive retrieved documentation context")
		}
		writeChatResponse(w, "Cronova installs per-user when elevation is declined.")
	}))
	defer server.Close()

	wiki, err := New(nil)
	if err != nil {
		t.Fatal(err)
	}
	wiki.llm = NewLLMClient(&model.AIProvider{BaseURL: server.URL, Model: "test-model"})
	answer := wiki.AskWithHistory(context.Background(),
		"jak zainstalwać cronova jako użytkownik bez praw administratora?", "pl",
		[]Message{{Role: "user", Content: "poprzednia rozmowa: instalacja per-user"}, {Role: "assistant", Content: "Mowa o instalacji bez uprawnień administratora."}},
	)
	if calls != 2 {
		t.Fatalf("LLM calls = %d, want query expansion + grounded answer", calls)
	}
	if !strings.Contains(answer.Answer, "installs per-user") {
		t.Fatalf("unexpected generated answer: %s", answer.Answer)
	}
	found := false
	for _, source := range answer.Sources {
		if source.Path == "docs/DEPLOY.md" && strings.Contains(source.Section, "Quick install for recipients") {
			found = true
		}
	}
	if !found {
		t.Fatalf("answer sources do not identify per-user install documentation: %+v", answer.Sources)
	}
}

func TestAskDoesNotGenerateGeneralAnswerWithoutRelevantSource(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		writeChatResponse(w, `[]`)
	}))
	defer server.Close()
	wiki, err := New(nil)
	if err != nil {
		t.Fatal(err)
	}
	wiki.llm = NewLLMClient(&model.AIProvider{BaseURL: server.URL, Model: "test-model"})
	answer := wiki.Ask(context.Background(), "xyzabc123 notfound", "en")
	if calls != 1 {
		t.Fatalf("LLM calls = %d, want only query expansion (no ungrounded answer request)", calls)
	}
	if len(answer.Sources) != 0 || !strings.Contains(strings.ToLower(answer.Answer), "nie znalazłem") {
		t.Fatalf("expected explicit no-source response, got %+v", answer)
	}
}

func TestAskFallsBackToOriginalSearchWhenExpansionFails(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			http.Error(w, "temporary provider error", http.StatusBadGateway)
			return
		}
		writeChatResponse(w, "Retry settings are documented in this source.")
	}))
	defer server.Close()
	wiki, err := New(nil)
	if err != nil {
		t.Fatal(err)
	}
	wiki.llm = NewLLMClient(&model.AIProvider{BaseURL: server.URL, Model: "test-model"})
	answer := wiki.Ask(context.Background(), "Jak ustawić retry dla taska?", "pl")
	if calls != 2 {
		t.Fatalf("LLM calls = %d, want failed expansion plus grounded answer", calls)
	}
	if len(answer.Sources) == 0 || !strings.Contains(strings.ToLower(answer.Answer), "retry") {
		t.Fatalf("original query was not used after expansion failure: %+v", answer)
	}
}

func TestAskShowsSourceAndReportsAnswerGenerationFailure(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			writeChatResponse(w, `["retry task retries"]`)
			return
		}
		http.Error(w, "temporary answer failure", http.StatusBadGateway)
	}))
	defer server.Close()
	wiki, err := New(nil)
	if err != nil {
		t.Fatal(err)
	}
	wiki.llm = NewLLMClient(&model.AIProvider{BaseURL: server.URL, Model: "test-model"})
	answer := wiki.Ask(context.Background(), "Jak ustawić retry dla taska?", "pl")
	if calls != 2 {
		t.Fatalf("LLM calls = %d, want query expansion and attempted grounded answer", calls)
	}
	if !strings.Contains(answer.Answer, "generowanie odpowiedzi przez AI nie powiodło się") || !strings.Contains(strings.ToLower(answer.Answer), "retry") {
		t.Fatalf("expected explicit model failure and source excerpt, got: %s", answer.Answer)
	}
	if len(answer.Sources) == 0 {
		t.Fatal("expected sources for source-excerpt fallback")
	}
}

func TestBoundedHistoryDropsInvalidRolesAndLimitsSize(t *testing.T) {
	long := strings.Repeat("a", 1300)
	input := []Message{{Role: "system", Content: "do not pass"}, {Role: "user", Content: long}}
	got := boundedHistory(input)
	if len(got) != 1 || got[0].Role != "user" {
		t.Fatalf("boundedHistory() = %+v", got)
	}
	if len(got[0].Content) > 1200 {
		t.Fatalf("history content length = %d, want at most 1200", len(got[0].Content))
	}
}
