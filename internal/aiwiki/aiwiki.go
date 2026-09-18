// Package aiwiki provides a small RAG-backed helper for the cronova console
// AI chat. It embeds a pre-built knowledge base and answers user questions
// with explain + sources + actions.
package aiwiki

import (
	_ "embed"
	"encoding/json"
	"strings"
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
	kb KnowledgeBase
}

// New loads the embedded knowledge base.
func New() (*Wiki, error) {
	var kb KnowledgeBase
	if err := json.Unmarshal(knowledgeBaseJSON, &kb); err != nil {
		return nil, err
	}
	return &Wiki{kb: kb}, nil
}

// Ask answers a user question using keyword retrieval and a canned template.
// It does not call an external LLM; the answer is assembled from the top
// matching chunks so the feature works offline and with zero config.
func (w *Wiki) Ask(question string) Answer {
	q := strings.ToLower(question)
	terms := tokenize(q)

	type scored struct {
		Chunk
		score int
	}
	var hits []scored
	for _, c := range w.kb.Chunks {
		score := scoreChunk(c, terms)
		if score > 0 {
			hits = append(hits, scored{Chunk: c, score: score})
		}
	}

	// Sort by score descending.
	for i := 0; i < len(hits); i++ {
		for j := i + 1; j < len(hits); j++ {
			if hits[j].score > hits[i].score {
				hits[i], hits[j] = hits[j], hits[i]
			}
		}
	}

	if len(hits) == 0 {
		return Answer{
			Answer: "Nie znalazłem dokładnej odpowiedzi w bazie wiedzy. Spróbuj zapytać inaczej, np. 'Jak zrobić DAG?' lub 'Co to jest retry?'.",
			Actions: []Action{
				{Type: "open_editor", Label: "Przeglądaj DAG-i", Path: "dags/"},
			},
		}
	}

	top := hits[0]
	answer := buildAnswer(question, top.Chunk)

	sources := []Source{}
	seen := map[string]bool{}
	for _, h := range hits {
		key := h.Type + "|" + h.Source + "|" + h.Section
		if seen[key] || len(sources) >= 3 {
			continue
		}
		seen[key] = true
		sources = append(sources, Source{
			Type:    h.Type,
			Path:    h.Source,
			Section: h.Section,
		})
	}

	actions := suggestActions(top.Chunk)

	return Answer{
		Answer:  answer,
		Sources: sources,
		Actions: actions,
	}
}

func tokenize(s string) []string {
	// Very small stop-word list for Polish/English mixed queries.
	stop := map[string]bool{
		"jak": true, "co": true, "to": true, "jest": true, "w": true, "z": true,
		"a": true, "the": true, "is": true, "what": true, "how": true, "do": true,
	}
	var out []string
	for _, w := range strings.Fields(strings.TrimSpace(s)) {
		w = strings.Trim(w, "?.,!;:")
		if w == "" || stop[w] {
			continue
		}
		out = append(out, w)
	}
	return out
}

func scoreChunk(c Chunk, terms []string) int {
	text := strings.ToLower(c.Text)
	section := strings.ToLower(c.Section)
	score := 0
	for _, t := range terms {
		if strings.Contains(section, t) {
			score += 3
		}
		if strings.Contains(text, t) {
			score += 1
		}
		for _, topic := range c.Topics {
			if topic == t {
				score += 2
			}
		}
	}
	return score
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

func suggestActions(c Chunk) []Action {
	actions := []Action{}
	src := strings.ToLower(c.Source)
	switch {
	case strings.HasPrefix(src, "dags/"):
		dagID := strings.TrimSuffix(strings.TrimPrefix(src, "dags/"), ".yaml")
		actions = append(actions,
			Action{Type: "trigger_dag", Label: "Uruchom ten DAG", DagID: dagID},
			Action{Type: "open_editor", Label: "Zobacz DAG", Path: c.Source},
		)
	case strings.HasPrefix(src, "docs/") || src == "readme.md":
		actions = append(actions, Action{Type: "open_editor", Label: "Otwórz dokumentację", Path: c.Source})
	}
	return actions
}
