// Package aiwiki provides a small RAG-backed helper for the cronova console
// AI chat. It embeds a pre-built knowledge base and answers user questions
// with explain + sources + actions.
package aiwiki

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"
	"unicode"

	"github.com/ako74programmer/poc-cronova-windows/internal/model"
	"github.com/ako74programmer/poc-cronova-windows/internal/store"
)

var runIDPattern = regexp.MustCompile(`(?:^|[^A-Za-z0-9_.-])([A-Za-z0-9][A-Za-z0-9_.-]{0,100}__[A-Za-z0-9][A-Za-z0-9_.-]{0,120})(?:$|[^A-Za-z0-9_.-])`)
var logRequestPattern = regexp.MustCompile(`(?i)(^|[^\pL])(?:log(?:i|ach|ów)?|logs?|dziennik(?:i|ów)?|stack[ -]?trace)(?:$|[^\pL])`)
var runFollowUpPattern = regexp.MustCompile(`(?i)\b(?:run|status|state|failed|failure|success|succeeded)\b|\btask(?:s)?\s+(?:failed|timed out|succeeded|success)`)
var polishRunStatePattern = regexp.MustCompile(`(?i)(^|[^\pL])stan(?:$|[^\pL])`)
var bearerSecretPattern = regexp.MustCompile(`(?i)\b(bearer\s+)[A-Za-z0-9._~+/-]+=*`)
var assignmentSecretPattern = regexp.MustCompile(`(?i)("?(?:api[ _-]?(?:key|token)|access[_-]?token|refresh[_-]?token|token|password|passwd|secret|client[_-]?secret)"?\s*[:=]\s*)("[^"]*"|'[^']*'|[^\s,;]+)`)
var flagSecretPattern = regexp.MustCompile(`(?i)(--?(?:api[ _-]?(?:key|token)|access[_-]?token|refresh[_-]?token|token|password|passwd|secret|client[_-]?secret)(?:\s+|=)\s*)("[^"]*"|'[^']*'|[^\s,;]+)`)

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

// ChatMode selects which evidence domain the chat is allowed to query.
type ChatMode string

const (
	ModeDocumentation ChatMode = "documentation"
	ModeRunAnalysis   ChatMode = "run_analysis"
)

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
	RunID   string `json:"run_id,omitempty"`
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
	return w.AskWithModeHistory(ctx, question, lang, ModeDocumentation, history)
}

// AskWithModeHistory answers using only the evidence domain selected by mode.
// An empty or unknown mode fails closed to documentation mode.
func (w *Wiki) AskWithModeHistory(ctx context.Context, question, lang string, mode ChatMode, history []Message) Answer {
	w.refreshLLM(ctx)
	if mode == ModeRunAnalysis {
		return w.askRunAnalysis(ctx, question, lang, boundedAgentHistory(history))
	}
	history = boundedHistory(history)
	if isRuntimeRequest(question, history) {
		if isPolishLanguage(lang) {
			return Answer{Answer: "To pytanie dotyczy danych runtime. Przełącz **Tryb** na **Analiza runów**, aby wyświetlić listę runów lub sprawdzić konkretny Run ID."}
		}
		return Answer{Answer: "This question is about live runtime data. Switch **Mode** to **Run analysis** to list runs or inspect a specific Run ID."}
	}
	queries := []string{question}
	if w.llm != nil {
		if expanded, err := w.llm.ExpandQueriesWithHistory(ctx, question, history); err == nil {
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
		generated, err := w.llm.GenerateAnswerWithHistory(ctx, question, chunks, history)
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

func (w *Wiki) askRunAnalysis(ctx context.Context, question, lang string, history []Message) Answer {
	if w.llm != nil {
		answer, sources, err := w.llm.runAnalysisAgent(ctx, question, history, w.executeRuntimeTool)
		if err != nil {
			if isPolishLanguage(lang) {
				return Answer{Answer: "Nie udało się dokończyć analizy runów przez AI Provider. Sprawdź, czy provider i model obsługują OpenAI-compatible tool/function calling.", Sources: sources}
			}
			return Answer{Answer: "The run-analysis agent could not complete this request. Check that the configured provider and model support OpenAI-compatible tool/function calling.", Sources: sources}
		}
		return Answer{Answer: answer, Sources: sources, Actions: recentRunActions(sources, lang)}
	}
	return w.askRunAnalysisWithoutProvider(ctx, question, lang, history)
}

func recentRunActions(sources []Source, lang string) []Action {
	actions := make([]Action, 0)
	seen := make(map[string]bool)
	label := "Analyze this run"
	if isPolishLanguage(lang) {
		label = "Analizuj ten run"
	}
	for _, source := range sources {
		if source.Section != "Recent runs" || !strings.HasPrefix(source.Path, "runs/") {
			continue
		}
		runID := strings.TrimPrefix(source.Path, "runs/")
		if runID == "" || seen[runID] {
			continue
		}
		seen[runID] = true
		actions = append(actions, Action{Type: "inspect_run", Label: label, RunID: runID})
	}
	return actions
}

func (w *Wiki) askRunAnalysisWithoutProvider(ctx context.Context, question, lang string, history []Message) Answer {
	runID, ambiguous := requestedRunID(question, history)
	if ambiguous {
		if isPolishLanguage(lang) {
			return Answer{Answer: "W pytaniu lub historii jest więcej niż jeden Run ID. Wybierz jeden konkretny run albo poproś o listę najnowszych runów."}
		}
		return Answer{Answer: "The question or conversation contains more than one Run ID. Select one run, or ask for the latest-runs list."}
	}
	if runID != "" {
		chunks, err := w.runtimeContext(ctx, runID, logRequestPattern.MatchString(question), question)
		if err != nil {
			if errors.Is(err, store.ErrNotFound) {
				if isPolishLanguage(lang) {
					return Answer{Answer: fmt.Sprintf("Nie znalazłem runu `%s` w bazie Cronovy.", runID)}
				}
				return Answer{Answer: fmt.Sprintf("Run `%s` was not found in the Cronova database.", runID)}
			}
			if isPolishLanguage(lang) {
				return Answer{Answer: fmt.Sprintf("Nie udało się odczytać danych runu `%s` z Cronovy.", runID)}
			}
			return Answer{Answer: fmt.Sprintf("Could not read run `%s` from Cronova.", runID)}
		}
		return w.answerRuntimeForLang(ctx, question, history, chunks, lang)
	}
	if isRunListRequest(question) {
		chunks, actions, err := w.recentRunsContext(ctx, 10, lang)
		if err != nil {
			if isPolishLanguage(lang) {
				return Answer{Answer: "Nie udało się pobrać listy runów z bazy Cronovy."}
			}
			return Answer{Answer: "Could not retrieve recent runs from the Cronova database."}
		}
		if len(chunks) == 0 {
			if isPolishLanguage(lang) {
				return Answer{Answer: "Nie znaleziono runów dla aktywnych DAG-ów."}
			}
			return Answer{Answer: "No runs were found for active DAGs."}
		}
		answer := w.answerRuntimeForLang(ctx, question, history, chunks, lang)
		answer.Actions = actions
		return answer
	}
	if isPolishLanguage(lang) {
		return Answer{Answer: "W trybie Analiza runów podaj Run ID albo poproś o listę najnowszych runów. Na przykład: „Pokaż ostatnie runy”."}
	}
	return Answer{Answer: "In Run analysis mode, provide a Run ID or ask for the latest-runs list, e.g. “Show recent runs”."}
}

func (w *Wiki) recentRunsContext(ctx context.Context, limit int, lang string) ([]Chunk, []Action, error) {
	if w.store == nil {
		return nil, nil, fmt.Errorf("runtime store is unavailable")
	}
	runs, err := w.store.RecentRuns(ctx, limit)
	if err != nil {
		return nil, nil, err
	}
	chunks := make([]Chunk, 0, len(runs))
	actions := make([]Action, 0, len(runs))
	for i, run := range runs {
		if i >= limit {
			break
		}
		if run == nil || run.RunID == "" {
			continue
		}
		var details strings.Builder
		fmt.Fprintf(&details, "Run ID: %s\nDAG ID: %s\nState: %s\nTrigger: %s\nLogical date (UTC): %s\nStarted at: %s\nFinished at: %s\n",
			run.RunID, run.DagID, run.State, run.TriggerType, run.LogicalDate.UTC().Format(time.RFC3339), formatRuntimeTime(run.StartedAt), formatRuntimeTime(run.FinishedAt))
		chunks = append(chunks, Chunk{ID: "runtime-recent-" + run.RunID, Type: "runtime", Source: "runs/" + run.RunID, Section: "Recent runs", Text: details.String()})
		label := "Inspect this run"
		if isPolishLanguage(lang) {
			label = "Analizuj ten run"
		}
		actions = append(actions, Action{Type: "inspect_run", Label: label, RunID: run.RunID})
	}
	return chunks, actions, nil
}

func isRunListRequest(question string) bool {
	directListWords := map[string]bool{
		"pokaż": true, "pokaz": true, "wyświetl": true, "wyswietl": true,
		"wymień": true, "wymien": true, "lista": true, "list": true,
		"show": true, "display": true, "recent": true, "latest": true,
		"ostatnie": true, "najnowsze": true,
	}
	questionWords := map[string]bool{"jakie": true, "jakich": true, "what": true, "which": true}
	availabilityWords := map[string]bool{
		"masz": true, "macie": true, "have": true, "available": true,
		"dostępne": true, "dostepne": true, "baza": true, "bazie": true,
		"database": true, "databases": true, "ostatnie": true, "najnowsze": true,
		"recent": true, "latest": true, "all": true,
	}
	pluralRunWords := map[string]bool{
		"runy": true, "runów": true, "runow": true, "runs": true, "executions": true,
		"uruchomienia": true, "uruchomień": true, "uruchomien": true,
		"wykonania": true, "wykonań": true, "wykonan": true,
	}
	hasDirectListWord, hasQuestionWord, hasAvailabilityWord, hasPluralRun := false, false, false, false
	for _, token := range strings.FieldsFunc(strings.ToLower(question), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	}) {
		hasDirectListWord = hasDirectListWord || directListWords[token]
		hasQuestionWord = hasQuestionWord || questionWords[token]
		hasAvailabilityWord = hasAvailabilityWord || availabilityWords[token]
		hasPluralRun = hasPluralRun || pluralRunWords[token]
	}
	return hasPluralRun && (hasDirectListWord || (hasQuestionWord && hasAvailabilityWord))
}

func isRuntimeRequest(question string, history []Message) bool {
	runID, ambiguous := requestedRunID(question, history)
	return runID != "" || ambiguous || isRunListRequest(question)
}

func isPolishLanguage(lang string) bool {
	return strings.HasPrefix(strings.ToLower(strings.TrimSpace(lang)), "pl")
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

func (w *Wiki) answerRuntime(ctx context.Context, question string, history []Message, chunks []Chunk) Answer {
	return w.answerRuntimeForLang(ctx, question, history, chunks, "pl")
}

func (w *Wiki) answerRuntimeForLang(ctx context.Context, question string, history []Message, chunks []Chunk, lang string) Answer {
	answer := ""
	generationFailed := false
	if w.llm != nil {
		generated, err := w.llm.GenerateAnswerWithHistory(ctx, question, chunks, history)
		if err == nil && strings.TrimSpace(generated) != "" {
			answer = strings.TrimSpace(generated)
		} else {
			generationFailed = true
		}
	}
	if answer == "" {
		var text strings.Builder
		if isPolishLanguage(lang) {
			if generationFailed {
				text.WriteString("AI nie wygenerowało odpowiedzi. Oto dane runtime znalezione w Cronovie:\n")
			} else {
				text.WriteString("Dane runtime znalezione w Cronovie:\n")
			}
		} else {
			if generationFailed {
				text.WriteString("AI could not generate an answer. Here is the runtime data found in Cronova:\n")
			} else {
				text.WriteString("Runtime data found in Cronova:\n")
			}
		}
		remaining := 12000
		for i, chunk := range chunks {
			if remaining <= 0 {
				if isPolishLanguage(lang) {
					text.WriteString("\n[Dalsze dane pominięto, aby ograniczyć rozmiar odpowiedzi.]\n")
				} else {
					text.WriteString("\n[Additional data omitted to limit the response size.]\n")
				}
				break
			}
			contentRunes := []rune(chunk.Text)
			truncated := len(contentRunes) > remaining
			if len(contentRunes) > remaining {
				contentRunes = contentRunes[:remaining]
			}
			content := string(contentRunes)
			if truncated {
				if isPolishLanguage(lang) {
					content += "\n[Fragment ucięto ze względu na limit rozmiaru odpowiedzi.]"
				} else {
					content += "\n[Excerpt truncated to limit response size.]"
				}
			}
			fmt.Fprintf(&text, "\n%s:\n%s\n", chunk.Section, content)
			remaining -= len(contentRunes)
			if remaining <= 0 && i < len(chunks)-1 {
				if isPolishLanguage(lang) {
					text.WriteString("\n[Dalsze dane pominięto, aby ograniczyć rozmiar odpowiedzi.]\n")
				} else {
					text.WriteString("\n[Additional data omitted to limit the response size.]\n")
				}
				break
			}
		}
		answer = text.String()
	}
	sources := make([]Source, 0, len(chunks))
	for _, chunk := range chunks {
		sources = append(sources, Source{Type: chunk.Type, Path: chunk.Source, Section: chunk.Section})
	}
	return Answer{Answer: answer, Sources: sources, Actions: []Action{}}
}

func requestedRunID(question string, history []Message) (string, bool) {
	ids := runIDsIn(question)
	if len(ids) > 1 {
		return "", true
	}
	if len(ids) == 1 {
		return ids[0], false
	}
	if !isRunFollowUp(question) {
		return "", false
	}
	for i := len(history) - 1; i >= 0; i-- {
		ids = runIDsIn(history[i].Content)
		if len(ids) > 1 {
			return "", true
		}
		if len(ids) == 1 {
			return ids[0], false
		}
	}
	return "", false
}

func runIDsIn(text string) []string {
	seen := map[string]bool{}
	var ids []string
	for _, match := range runIDPattern.FindAllStringSubmatch(text, -1) {
		// Run IDs generated by Cronova end in an alphanumeric timestamp. Since
		// dots are also valid inside DAG IDs, the regex can absorb a sentence's
		// final period; strip that prose punctuation before querying the store.
		id := strings.TrimRight(match[1], ".")
		if id == "" {
			continue
		}
		if !seen[id] {
			seen[id] = true
			ids = append(ids, id)
		}
	}
	return ids
}

func isRunFollowUp(question string) bool {
	q := strings.ToLower(question)
	if logRequestPattern.MatchString(q) || runFollowUpPattern.MatchString(q) || polishRunStatePattern.MatchString(q) {
		return true
	}
	for _, term := range []string{"uruchom", "wynik", "dlaczego", "czemu", "nie powiódł", "nie powiodł", "co z nim", "co z task", "a jak", "a co", "a jaka", "przyczyn", "powod", "poraż", "sukces", "zakończył", "why", "what happened", "what about", "how about", "and why", "to?"} {
		if strings.Contains(q, term) {
			return true
		}
	}
	return false
}

func (w *Wiki) runtimeContext(ctx context.Context, runID string, includeLogs bool, question string) ([]Chunk, error) {
	if w.store == nil {
		return nil, fmt.Errorf("runtime store is unavailable")
	}
	run, err := w.store.GetDagRun(ctx, runID)
	if err != nil {
		return nil, err
	}
	tasks, err := w.store.ListTaskInstances(ctx, runID)
	if err != nil {
		return nil, err
	}
	orderedTasks := make([]*model.TaskInstance, 0, len(tasks))
	for _, task := range tasks {
		if task != nil {
			orderedTasks = append(orderedTasks, task)
		}
	}
	sort.SliceStable(orderedTasks, func(i, j int) bool {
		return runtimeTaskPriority(orderedTasks[i].State) < runtimeTaskPriority(orderedTasks[j].State)
	})
	var details strings.Builder
	fmt.Fprintf(&details, "Run ID: %s\nDAG ID: %s\nState: %s\nTrigger: %s\nLogical date (UTC): %s\nStarted at: %s\nFinished at: %s\nTask count: %d\n",
		run.RunID, run.DagID, run.State, run.TriggerType, run.LogicalDate.UTC().Format(time.RFC3339), formatRuntimeTime(run.StartedAt), formatRuntimeTime(run.FinishedAt), len(orderedTasks))
	const maxTaskRows = 50
	for i, task := range orderedTasks {
		if i == maxTaskRows {
			fmt.Fprintf(&details, "Additional task rows omitted: %d\n", len(orderedTasks)-maxTaskRows)
			break
		}
		fmt.Fprintf(&details, "Task %s: state=%s, try=%d/%d, pool=%s, started_at=%s, finished_at=%s\n",
			task.TaskID, task.State, task.TryNumber, task.MaxRetries, task.Pool, formatRuntimeTime(task.StartedAt), formatRuntimeTime(task.FinishedAt))
	}
	chunks := []Chunk{{ID: "runtime-run-" + run.RunID, Type: "runtime", Source: "runs/" + run.RunID,
		Section: "Run status and task instances", Text: details.String()}}
	if !includeLogs {
		return chunks, nil
	}
	selected := selectLogTasks(orderedTasks, question)
	if len(selected) == 0 {
		chunks = append(chunks, Chunk{ID: "runtime-log-" + run.RunID, Type: "runtime_log", Source: "runs/" + run.RunID,
			Section: "Task logs", Text: "Nie ma jeszcze dostępnego pliku logu taska dla tego runu."})
		return chunks, nil
	}
	for i, task := range selected {
		logText, readErr := readLogTail(task.LogPath, 8192)
		if readErr != nil {
			logText = "(plik logu jest niedostępny)"
		}
		if i == 0 {
			logText += "\n[Limit: w jednym zapytaniu dołączane są maksymalnie 3 fragmenty logów tasków.]"
		}
		chunks = append(chunks, Chunk{ID: "runtime-log-" + run.RunID + "-" + task.TaskID, Type: "runtime_log",
			Source: "runs/" + run.RunID, Section: "Task " + task.TaskID + " log (redacted tail)", Text: logText})
	}
	return chunks, nil
}

func runtimeTaskPriority(state model.TaskState) int {
	switch state {
	case model.TaskFailed, model.TaskTimedOut, model.TaskUpstreamFailed, model.TaskUpForRetry:
		return 0
	case model.TaskRunning:
		return 1
	default:
		return 2
	}
}

func formatRuntimeTime(value *time.Time) string {
	if value == nil || value.IsZero() {
		return "not available"
	}
	return value.UTC().Format(time.RFC3339)
}

func selectLogTasks(tasks []*model.TaskInstance, question string) []*model.TaskInstance {
	const maxLogs = 3
	selected := make([]*model.TaskInstance, 0, maxLogs)
	seen := map[int64]bool{}
	add := func(task *model.TaskInstance) {
		if task != nil && task.LogPath != "" && !seen[task.ID] && len(selected) < maxLogs {
			seen[task.ID] = true
			selected = append(selected, task)
		}
	}
	q := strings.ToLower(question)
	for _, task := range tasks {
		if taskIDMentioned(q, task.TaskID) {
			add(task)
		}
	}
	for _, task := range tasks {
		if task.State == model.TaskFailed || task.State == model.TaskTimedOut {
			add(task)
		}
	}
	for _, task := range tasks {
		add(task)
	}
	return selected
}

func taskIDMentioned(question, taskID string) bool {
	if taskID == "" {
		return false
	}
	wanted := strings.ToLower(taskID)
	for _, token := range strings.FieldsFunc(strings.ToLower(question), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r) && r != '_' && r != '.' && r != '-'
	}) {
		if token == wanted {
			return true
		}
	}
	return false
}

func readLogTail(path string, maxBytes int64) (string, error) {
	if path == "" {
		return "", os.ErrNotExist
	}
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil {
		return "", err
	}
	if !info.Mode().IsRegular() {
		return "", fmt.Errorf("log path is not a regular file")
	}
	start := info.Size() - maxBytes
	if start < 0 {
		start = 0
	}
	if _, err := f.Seek(start, io.SeekStart); err != nil {
		return "", err
	}
	data, err := io.ReadAll(io.LimitReader(f, maxBytes))
	if err != nil {
		return "", err
	}
	return redactLog(strings.ToValidUTF8(string(data), "�")), nil
}

func redactLog(text string) string {
	text = bearerSecretPattern.ReplaceAllString(text, `${1}[REDACTED]`)
	text = assignmentSecretPattern.ReplaceAllString(text, `${1}[REDACTED]`)
	return flagSecretPattern.ReplaceAllString(text, `${1}[REDACTED]`)
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
