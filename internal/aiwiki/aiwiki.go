// Package aiwiki provides a small RAG-backed helper for the cronova console
// AI chat. It embeds a pre-built knowledge base and answers user questions
// with explain + sources + actions.
package aiwiki

import (
	"context"
	_ "embed"
	"encoding/json"
	"strings"

	"github.com/ako74programmer/poc-cronova-windows/internal/model"
	"github.com/ako74programmer/poc-cronova-windows/internal/store"
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

// Message is one prior user/assistant turn used only to resolve follow-up references.
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
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
	kb    KnowledgeBase
	index *bm25Index
	store store.Store
	llm   *LLMClient
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

// Ask answers a user question using BM25 retrieval and, if configured, an LLM.
// The lang parameter controls documentation actions and defaults to English.
func (w *Wiki) Ask(ctx context.Context, question, lang string) Answer {
	return w.AskWithHistory(ctx, question, lang, nil)
}

// AskWithHistory answers a question using retrieved documentation and bounded
// conversation context. History resolves follow-up references but is not treated
// as factual evidence in place of retrieved sources.
func (w *Wiki) AskWithHistory(ctx context.Context, question, lang string, history []Message) Answer {
	w.refreshLLM(ctx)
	queries := []string{question}
	if w.llm != nil {
		if expanded, err := w.llm.ExpandQueriesWithHistory(ctx, question, boundedHistory(history)); err == nil {
			queries = append(queries, expanded...)
		}
	}
	queries = uniqueQueries(queries)
	hits := w.searchQueries(queries, 8)
	if len(hits) == 0 || !isRelevant(strings.Join(queries, " "), hits) {
		return Answer{
			Answer:  "Nie znalazłem odpowiedzi w dokumentacji cronova. Spróbuj zadać pytanie inaczej albo podać nazwę funkcji, pola lub pliku.",
			Actions: []Action{{Type: "open_editor", Label: "Przeglądaj DAG-i", Path: "dags/"}},
		}
	}

	var answer string
	generationFailed := false
	if w.llm != nil {
		chunks := make([]Chunk, 0, len(hits))
		for _, h := range hits {
			chunks = append(chunks, h.chunk)
		}
		generated, err := w.llm.GenerateAnswerWithHistory(ctx, question, chunks, boundedHistory(history))
		if err == nil && strings.TrimSpace(generated) != "" {
			answer = strings.TrimSpace(generated)
		} else {
			generationFailed = true
		}
	}
	if answer == "" {
		answer = sourceExcerptAnswer(hits[0].chunk, generationFailed, question)
	}

	sources := []Source{}
	seen := map[string]bool{}
	for _, h := range hits {
		key := h.chunk.Type + "|" + h.chunk.Source + "|" + h.chunk.Section
		if seen[key] || len(sources) >= 3 {
			continue
		}
		seen[key] = true
		sources = append(sources, Source{Type: h.chunk.Type, Path: h.chunk.Source, Section: h.chunk.Section})
	}
	return Answer{Answer: answer, Sources: sources, Actions: suggestActions(hits[0].chunk, lang)}
}

func (w *Wiki) searchQueries(queries []string, topN int) []scoredChunk {
	byID := make(map[string]scoredChunk)
	for _, query := range queries {
		for rank, hit := range w.index.search(query, topN) {
			id := hit.chunk.ID
			if id == "" {
				id = hit.chunk.Source + "|" + hit.chunk.Section
			}
			if previous, ok := byID[id]; ok {
				if hit.score < previous.score {
					hit.score = previous.score
				}
				hit.score += 0.02 / float64(rank+1)
			}
			byID[id] = hit
		}
	}
	results := make([]scoredChunk, 0, len(byID))
	for _, hit := range byID {
		results = append(results, hit)
	}
	for i := 0; i < len(results); i++ {
		for j := i + 1; j < len(results); j++ {
			if results[j].score > results[i].score {
				results[i], results[j] = results[j], results[i]
			}
		}
	}
	if topN > 0 && len(results) > topN {
		results = results[:topN]
	}
	return results
}

func uniqueQueries(queries []string) []string {
	seen := make(map[string]bool)
	result := make([]string, 0, len(queries))
	for _, query := range queries {
		query = strings.TrimSpace(query)
		key := strings.ToLower(query)
		if query == "" || seen[key] {
			continue
		}
		seen[key] = true
		if len(result) < 5 {
			result = append(result, query)
		}
	}
	return result
}

func boundedHistory(history []Message) []Message {
	const maxMessages = 8
	const maxContent = 1200
	start := len(history) - maxMessages
	if start < 0 {
		start = 0
	}
	out := make([]Message, 0, len(history)-start)
	for _, msg := range history[start:] {
		role := strings.ToLower(strings.TrimSpace(msg.Role))
		if role != "user" && role != "assistant" {
			continue
		}
		content := strings.TrimSpace(msg.Content)
		contentRunes := []rune(content)
		if len(contentRunes) > maxContent {
			content = string(contentRunes[:maxContent])
		}
		if content != "" {
			out = append(out, Message{Role: role, Content: content})
		}
	}
	return out
}

func sourceExcerptAnswer(c Chunk, generationFailed bool, question string) string {
	text := strings.TrimSpace(c.Text)
	textRunes := []rune(text)
	if len(textRunes) > 1200 {
		lower := strings.ToLower(text)
		position := -1
		for _, term := range tokenizeBM25(translateQueryPLToEN(question)) {
			if len(term) < 4 {
				continue
			}
			if at := strings.Index(lower, term); at >= 0 {
				runeAt := len([]rune(lower[:at]))
				if position < 0 || runeAt < position {
					position = runeAt
				}
			}
		}
		start := 0
		if position > 250 {
			start = position - 250
		}
		end := start + 1200
		if end > len(textRunes) {
			end = len(textRunes)
		}
		if end < len(textRunes) {
			text = strings.TrimSpace(string(textRunes[start:end])) + "…"
		} else {
			text = strings.TrimSpace(string(textRunes[start:end]))
		}
	}
	prefix := "AI nie jest skonfigurowane. Znalazłem pasujący fragment dokumentacji:"
	if generationFailed {
		prefix = "Znalazłem pasujący fragment dokumentacji, ale generowanie odpowiedzi przez AI nie powiodło się. Oto fragment:"
	}
	return prefix + "\n\n" + c.Source + " — " + c.Section + "\n" + text
}

// isRelevant decides whether the top BM25 hit is strong enough to base an
// answer on. Very generic terms (java, python, sql) match many chunks by
// accident, so we require either a decent score or a direct topic match.
func isRelevant(question string, hits []scoredChunk) bool {
	if len(hits) == 0 {
		return false
	}
	top := hits[0]
	if top.score < 1.5 {
		return false
	}
	q := strings.ToLower(question)
	// If the question contains only generic words and no cronova-specific
	// terms, treat it as off-topic regardless of BM25 score.
	if !hasCronovaTerm(q) {
		return false
	}
	// If the user asks about a programming language or generic technology,
	// only accept chunks that actually explain it in the cronova context.
	genericTech := []string{"java", "python", "javascript", "go", "rust", "c++", "html", "css"}
	for _, term := range genericTech {
		if strings.Contains(q, term) {
			text := strings.ToLower(top.chunk.Text + " " + top.chunk.Section)
			return strings.Contains(text, term)
		}
	}
	return true
}

// hasCronovaTerm checks whether the question contains any term that clearly
// anchors it to the cronova domain.
func hasCronovaTerm(q string) bool {
	terms := []string{"cronova", "dag", "task", "retry", "schedule", "timeout",
		"pool", "log", "run", "trigger", "worker", "executor", "mcp", "ai-sdlc",
		"workspace", "project", "shell", "command", "yaml", "config", "install"}
	for _, t := range terms {
		if strings.Contains(q, t) {
			return true
		}
	}
	return false
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
	}
	return actions
}
