// Package aiwiki provides a small RAG-backed helper for the cronova console
// AI chat. It embeds a pre-built knowledge base and answers user questions
// with explain + sources + actions.
package aiwiki

import (
	"context"
	_ "embed"
	"encoding/json"
	"strings"

	"github.com/zoyluo/cronova/internal/model"
	"github.com/zoyluo/cronova/internal/store"
)

//go:embed knowledge-base.json
var knowledgeBaseJSON []byte

// Chunk is one piece of knowledge.
type Chunk struct {
	ID      string   `json:"id"`
	Type    string   `json:"type"`
	Source  string   `json:"source"`
	Section string   `json:"section"`
	Text    string   `json:"text"`
	Topics  []string `json:"topics"`
}

// KnowledgeBase holds all chunks.
type KnowledgeBase struct {
	Chunks []Chunk `json:"chunks"`
}

// Answer is the response returned by the chat endpoint.
type Answer struct {
	Answer  string   `json:"answer"`
	Sources []Source `json:"sources"`
	Actions []Action `json:"actions"`
}

// Source points to a document, DAG, or script.
type Source struct {
	Type    string `json:"type"`
	Path    string `json:"path"`
	Section string `json:"section,omitempty"`
}

// Action is something the user can do from the chat response.
type Action struct {
	Type    string `json:"type"`
	Label   string `json:"label"`
	DagID   string `json:"dag_id,omitempty"`
	Path    string `json:"path,omitempty"`
	Command string `json:"command,omitempty"`
}

// Wiki loads the embedded knowledge base.
type Wiki struct {
	kb     KnowledgeBase
	index  *bm25Index
	store  store.Store
	llm    *LLMClient
}

// New loads the embedded knowledge base and builds the BM25 index.
// If a store is provided, Wiki will look up a configured AI provider for LLM answers.
func New(st store.Store) (*Wiki, error) {
	var kb KnowledgeBase
	if err := json.Unmarshal(knowledgeBaseJSON, &kb); err != nil {
		return nil, err
	}
	return &Wiki{kb: kb, index: newBM25Index(kb.Chunks), store: st}, nil
}

// Ask answers a user question using BM25 retrieval and, if an AI provider is
// configured, an LLM-generated answer. Falls back to canned templates when no
// provider is available so the feature works offline and with zero config.
// The lang parameter requests a documentation language ("pl" or "en") for
// open_docs actions; it defaults to "en".
func (w *Wiki) Ask(ctx context.Context, question, lang string) Answer {
	// Ensure the LLM client is up to date before answering.
	w.refreshLLM(ctx)

	hits := w.index.search(question, 5)

	if len(hits) == 0 {
		return Answer{
			Answer: "Nie znalazłem dokładnej odpowiedzi w bazie wiedzy. Spróbuj zapytać inaczej, np. 'Jak zrobić DAG?' lub 'Co to jest retry?'.",
			Actions: []Action{
				{Type: "open_editor", Label: "Przeglądaj DAG-i", Path: "dags/"},
			},
		}
	}

	var answer string
	if w.llm != nil {
		chunks := make([]Chunk, 0, len(hits))
		for _, h := range hits {
			chunks = append(chunks, h.chunk)
		}
		if generated, err := w.llm.GenerateAnswer(ctx, question, chunks); err == nil && generated != "" {
			answer = generated
		}
	}
	if answer == "" {
		answer = buildAnswer(question, hits[0].chunk)
	}

	sources := []Source{}
	seen := map[string]bool{}
	for _, h := range hits {
		key := h.chunk.Type + "|" + h.chunk.Source + "|" + h.chunk.Section
		if seen[key] || len(sources) >= 3 {
			continue
		}
		seen[key] = true
		sources = append(sources, Source{
			Type:    h.chunk.Type,
			Path:    h.chunk.Source,
			Section: h.chunk.Section,
		})
	}

	actions := suggestActions(hits[0].chunk, lang)

	return Answer{
		Answer:  answer,
		Sources: sources,
		Actions: actions,
	}
}

// refreshLLM looks up the default AI provider from the store and creates an LLM client.
func (w *Wiki) refreshLLM(ctx context.Context) {
	if w.store == nil {
		return
	}
	providers, err := w.store.ListAIProviders(ctx)
	if err != nil || len(providers) == 0 {
		w.llm = nil
		return
	}
	var p *model.AIProvider
	for _, prov := range providers {
		if prov.Default {
			p = prov
			break
		}
	}
	if p == nil {
		p = providers[0]
	}
	w.llm = NewLLMClient(p)
}

func buildAnswer(question string, c Chunk) string {
	// Simple templated answer. A future version can call an LLM here.
	switch {
	case strings.Contains(strings.ToLower(question), "retry"):
		return "W cronova retry ustawiasz w definicji taska polem `retries`. Możesz też dodać `retry_delay` i `timeout`. Zobacz przykład w źródle."
	case strings.Contains(strings.ToLower(question), "dag") && strings.Contains(strings.ToLower(question), "zrobi"):
		return "DAG to plik YAML w katalogu `dags/`. Definiujesz `dag_id`, `schedule`, listę `tasks` i ich `deps`. Źródło pokazuje przykład."
	case strings.Contains(strings.ToLower(question), "schedule") || strings.Contains(strings.ToLower(question), "harmonogram"):
		return "Harmonogram ustawiasz polem `schedule` w DAG-u. Może to być cron (`0 2 * * *`) lub interwał (`@every 30s`)."
	case strings.Contains(strings.ToLower(question), "project") || strings.Contains(strings.ToLower(question), "projekt"):
		return "Własne skrypty wrzucasz jako project w UI (task editor → Project), a potem wskazujesz `project: nazwa` w shell tasku."
	case strings.Contains(strings.ToLower(question), "ai") || strings.Contains(strings.ToLower(question), "mcp"):
		return "cronova ma wbudowany MCP server (`cronova mcp`) oraz AI-SDLC workflow'y, w których AI generuje kod i naprawia błędy kompilacji."
	default:
		return "Oto informacja z bazy wiedzy: " + c.Section + ". Szczegóły znajdziesz w źródle."
	}
}

func suggestActions(c Chunk, lang string) []Action {
	actions := []Action{}
	src := strings.ToLower(c.Source)
	switch {
	case strings.HasPrefix(src, "dags/"):
		dagID := strings.TrimSuffix(strings.TrimPrefix(src, "dags/"), ".yaml")
		actions = append(actions,
			Action{Type: "trigger_dag", Label: "Uruchom ten DAG", DagID: dagID},
			Action{Type: "open_dag_runs", Label: "Historia runów", DagID: dagID},
			Action{Type: "show_logs", Label: "Pokaż logi", DagID: dagID},
			Action{Type: "copy_command", Label: "Kopiuj komendę CLI", Command: "cronova trigger " + dagID},
		)
	case strings.HasPrefix(src, "docs/") || src == "readme.md":
		path := c.Source
		if strings.HasPrefix(path, "docs/") {
			path = strings.TrimPrefix(path, "docs/")
		}
		if lang == "pl" {
			path = strings.TrimSuffix(path, ".md") + ".pl.md"
		}
		actions = append(actions,
			Action{Type: "open_docs", Label: "Otwórz dokumentację", Path: "/doc/" + path},
		)
	}
	return actions
}
