package aiwiki

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ako74programmer/poc-cronova-windows/internal/model"
)

func TestGenerateAnswerAppendsChatCompletionsToBaseURL(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/chat/completions" {
			t.Errorf("request path = %q, want /v1/chat/completions", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Errorf("request method = %q, want POST", r.Method)
		}
		var body struct {
			Model string `json:"model"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Errorf("decode request body: %v", err)
		}
		if body.Model != "test-model" {
			t.Errorf("request model = %q, want test-model", body.Model)
		}
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"generated answer"}}]}`))
	}))
	defer server.Close()

	client := NewLLMClient(&model.AIProvider{
		BaseURL: server.URL + "/v1/",
		Model:   "test-model",
	})
	answer, err := client.GenerateAnswer(context.Background(), "question", []Chunk{{Source: "docs/example.md", Section: "Example", Text: "Grounded context."}})
	if err != nil {
		t.Fatalf("GenerateAnswer() error: %v", err)
	}
	if answer != "generated answer" {
		t.Fatalf("GenerateAnswer() = %q, want generated answer", answer)
	}
}

func TestChatCompletionsURLPreservesExplicitEndpoint(t *testing.T) {
	for _, baseURL := range []string{
		"https://example.test/v1/chat/completions",
		"https://example.test/v1/completions",
	} {
		got, err := chatCompletionsURL(baseURL)
		if err != nil {
			t.Fatalf("chatCompletionsURL(%q) error: %v", baseURL, err)
		}
		if got != baseURL {
			t.Errorf("chatCompletionsURL(%q) = %q, want unchanged", baseURL, got)
		}
	}
}

func TestChatCompletionsURLPreservesQuery(t *testing.T) {
	got, err := chatCompletionsURL("https://example.test/v1/?key=value")
	if err != nil {
		t.Fatalf("chatCompletionsURL() error: %v", err)
	}
	want := "https://example.test/v1/chat/completions?key=value"
	if got != want {
		t.Errorf("chatCompletionsURL() = %q, want %q", got, want)
	}
}
