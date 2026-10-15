package aiwiki

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ako74programmer/poc-cronova-windows/internal/model"
	"github.com/ako74programmer/poc-cronova-windows/internal/store"
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

type runtimeStoreStub struct {
	store.Store
	run             *model.DagRun
	tasks           []*model.TaskInstance
	recentRuns      []*model.DagRun
	providers       []*model.AIProvider
	getRunCalls     int
	recentRunsCalls int
	lastRecentLimit int
}

func (s *runtimeStoreStub) GetDagRun(_ context.Context, runID string) (*model.DagRun, error) {
	s.getRunCalls++
	if s.run == nil || s.run.RunID != runID {
		return nil, store.ErrNotFound
	}
	return s.run, nil
}

func (s *runtimeStoreStub) ListTaskInstances(_ context.Context, runID string) ([]*model.TaskInstance, error) {
	if s.run == nil || s.run.RunID != runID {
		return nil, store.ErrNotFound
	}
	return s.tasks, nil
}

func (s *runtimeStoreStub) ListAIProviders(_ context.Context) ([]*model.AIProvider, error) {
	return s.providers, nil
}

func (s *runtimeStoreStub) RecentRuns(_ context.Context, limit int) ([]*model.DagRun, error) {
	s.recentRunsCalls++
	s.lastRecentLimit = limit
	if limit >= 0 && len(s.recentRuns) > limit {
		return s.recentRuns[:limit], nil
	}
	return s.recentRuns, nil
}

func setupRuntimeWiki(t *testing.T, logContents string) (*Wiki, *runtimeStoreStub) {
	t.Helper()
	dir := t.TempDir()
	now := time.Now().UTC()
	logPath := filepath.Join(dir, "extract.log")
	if logContents != "" {
		if err := os.WriteFile(logPath, []byte(logContents), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	run := &model.DagRun{RunID: "etl__r1", DagID: "etl", LogicalDate: now, State: model.RunFailed, TriggerType: model.TriggerManual, StartedAt: &now, FinishedAt: &now}
	stub := &runtimeStoreStub{
		run:        run,
		recentRuns: []*model.DagRun{run},
		tasks:      []*model.TaskInstance{{RunID: "etl__r1", TaskID: "extract", State: model.TaskFailed, TryNumber: 2, MaxRetries: 3, Pool: "default", LogPath: logPath, StartedAt: &now, FinishedAt: &now}},
	}
	wiki, err := New(stub)
	if err != nil {
		t.Fatal(err)
	}
	return wiki, stub
}

func TestDocumentationModeDoesNotReadRuntimeData(t *testing.T) {
	wiki, stub := setupRuntimeWiki(t, "private runtime log")
	answer := wiki.AskWithModeHistory(context.Background(), "What is the status of run etl__r1?", "en", ModeDocumentation, nil)
	if stub.getRunCalls != 0 || stub.recentRunsCalls != 0 {
		t.Fatalf("documentation mode accessed runtime store: get=%d recent=%d", stub.getRunCalls, stub.recentRunsCalls)
	}
	for _, source := range answer.Sources {
		if source.Type == "runtime" || source.Type == "runtime_log" {
			t.Fatalf("documentation mode returned runtime evidence: %+v", source)
		}
	}
	if !strings.Contains(answer.Answer, "Run analysis") {
		t.Fatalf("documentation mode did not direct the user to the runtime mode: %s", answer.Answer)
	}
}

func TestRunListIntentIsExplicitAndDoesNotCaptureDefinitions(t *testing.T) {
	for _, question := range []string{
		"Jakie masz runy w bazie?",
		"Pokaż ostatnie runy",
		"Show recent runs",
		"What runs are in the database?",
	} {
		if !isRunListRequest(question) {
			t.Errorf("expected run-list request: %q", question)
		}
	}
	for _, question := range []string{
		"What is a run in Cronova?",
		"Which runs failed?",
		"Jaki jest stan runu etl__r1?",
	} {
		if isRunListRequest(question) {
			t.Errorf("unexpected run-list classification: %q", question)
		}
	}
}

func TestRunAnalysisListsAtMostTenRunsAndOffersExplicitSelection(t *testing.T) {
	wiki, stub := setupRuntimeWiki(t, "must not read logs for list")
	stub.recentRuns = nil
	for i := 0; i < 12; i++ {
		now := time.Now().UTC()
		stub.recentRuns = append(stub.recentRuns, &model.DagRun{
			RunID: fmt.Sprintf("etl__r%02d", i), DagID: "etl", LogicalDate: now,
			State: model.RunSuccess, TriggerType: model.TriggerManual, StartedAt: &now, FinishedAt: &now,
		})
	}
	answer := wiki.AskWithModeHistory(context.Background(), "Jakie masz runy w bazie?", "pl", ModeRunAnalysis, nil)
	if stub.recentRunsCalls != 1 || stub.lastRecentLimit != 10 {
		t.Fatalf("RecentRuns called %d times with limit %d; want once with limit 10", stub.recentRunsCalls, stub.lastRecentLimit)
	}
	if len(answer.Sources) != 10 || len(answer.Actions) != 10 {
		t.Fatalf("expected 10 runtime sources and selection actions, got %d sources, %d actions", len(answer.Sources), len(answer.Actions))
	}
	if !strings.Contains(answer.Answer, "etl__r00") || !strings.Contains(answer.Answer, "etl__r09") || strings.Contains(answer.Answer, "etl__r10") {
		t.Fatalf("recent-run response did not respect the 10-run limit: %s", answer.Answer)
	}
	for i, source := range answer.Sources {
		if source.Type != "runtime" || source.Section != "Recent runs" || answer.Actions[i].Type != "inspect_run" || answer.Actions[i].RunID == "" {
			t.Fatalf("run row %d lacks a runtime source or explicit selection action: source=%+v action=%+v", i, source, answer.Actions[i])
		}
	}
	if stub.getRunCalls != 0 || strings.Contains(answer.Answer, "must not read logs") {
		t.Fatalf("run listing unexpectedly fetched a run detail or log: %s", answer.Answer)
	}
}

func TestRunAnalysisDoesNotFallBackToDocumentation(t *testing.T) {
	wiki, stub := setupRuntimeWiki(t, "")
	answer := wiki.AskWithModeHistory(context.Background(), "Jak ustawić retry dla taska?", "pl", ModeRunAnalysis, nil)
	if len(answer.Sources) != 0 || stub.getRunCalls != 0 || stub.recentRunsCalls != 0 {
		t.Fatalf("run analysis unexpectedly searched docs/runtime without a Run ID or list request: %+v", answer)
	}
	if !strings.Contains(answer.Answer, "podaj Run ID") {
		t.Fatalf("run analysis did not explain how to continue: %s", answer.Answer)
	}
}

func TestAskReadsRunStatusButDoesNotReadLogsByDefault(t *testing.T) {
	wiki, _ := setupRuntimeWiki(t, "DO_NOT_INCLUDE_WITHOUT_LOG_REQUEST\n")
	answer := wiki.AskWithModeHistory(context.Background(), "What is the status of run etl__r1?", "en", ModeRunAnalysis, nil)
	if !strings.Contains(answer.Answer, "failed") || !strings.Contains(answer.Answer, "extract") {
		t.Fatalf("runtime status/task details missing: %s", answer.Answer)
	}
	if strings.Contains(answer.Answer, "DO_NOT_INCLUDE_WITHOUT_LOG_REQUEST") {
		t.Fatal("logs were read although the question did not ask for logs")
	}
	if len(answer.Sources) != 1 || answer.Sources[0].Type != "runtime" || answer.Sources[0].Path != "runs/etl__r1" {
		t.Fatalf("unexpected runtime sources: %+v", answer.Sources)
	}
	if len(answer.Actions) != 0 {
		t.Fatalf("runtime answer offered mutating actions: %+v", answer.Actions)
	}
}

func TestAskReadsOnlyRequestedRedactedLogTail(t *testing.T) {
	logText := "start\npassword=super-secret\napi-token=another-secret\nAuthorization: Bearer very.secret.token\nerror: disk unavailable\n"
	wiki, _ := setupRuntimeWiki(t, logText)
	answer := wiki.AskWithModeHistory(context.Background(), "Show logs for task extract in run etl__r1", "en", ModeRunAnalysis, nil)
	if !strings.Contains(answer.Answer, "error: disk unavailable") {
		t.Fatalf("requested log tail not included: %s", answer.Answer)
	}
	if strings.Contains(answer.Answer, "super-secret") || strings.Contains(answer.Answer, "another-secret") || strings.Contains(answer.Answer, "very.secret.token") {
		t.Fatalf("log redaction failed: %s", answer.Answer)
	}
	if !strings.Contains(answer.Answer, "[REDACTED]") {
		t.Fatalf("expected visible redaction marker: %s", answer.Answer)
	}
	if len(answer.Sources) != 2 || answer.Sources[1].Type != "runtime_log" {
		t.Fatalf("expected run and log sources: %+v", answer.Sources)
	}
}

func TestRuntimeFallbackMarksTruncatedEvidence(t *testing.T) {
	wiki, _ := setupRuntimeWiki(t, "")
	answer := wiki.answerRuntime(context.Background(), "status", nil, []Chunk{
		{Section: "large data", Text: strings.Repeat("x", 12001)},
		{Section: "later data", Text: "must be marked omitted"},
	})
	if !strings.Contains(answer.Answer, "Fragment ucięto") || !strings.Contains(answer.Answer, "Dalsze dane pominięto") {
		t.Fatalf("truncation was not disclosed: %s", answer.Answer[len(answer.Answer)-150:])
	}
}

func TestAskReportsUnknownRunID(t *testing.T) {
	wiki, _ := setupRuntimeWiki(t, "")
	answer := wiki.AskWithModeHistory(context.Background(), "Show status for run etl__missing", "en", ModeRunAnalysis, nil)
	if !strings.Contains(answer.Answer, "Run `etl__missing` was not found") {
		t.Fatalf("unexpected answer for unknown run: %s", answer.Answer)
	}
}

func TestAskUsesRunIDFromHistoryForFollowUp(t *testing.T) {
	wiki, _ := setupRuntimeWiki(t, "")
	answer := wiki.AskWithModeHistory(context.Background(), "Dlaczego?", "pl", ModeRunAnalysis, []Message{
		{Role: "user", Content: "Sprawdź run etl__r1"},
		{Role: "assistant", Content: "Run etl__r1 ma status failed."},
	})
	if !strings.Contains(answer.Answer, "etl__r1") || !strings.Contains(answer.Answer, "failed") {
		t.Fatalf("follow-up did not use the run from history: %s", answer.Answer)
	}
}

func TestAskReadsLogsFromRunIDInPunctuatedRuntimeHistory(t *testing.T) {
	wiki, _ := setupRuntimeWiki(t, "error: disk unavailable\n")
	runID := "etl__r1"
	answer := wiki.AskWithModeHistory(context.Background(), "Pokaż logi taska extract z tego runu", "pl", ModeRunAnalysis, []Message{
		{Role: "user", Content: "Jaki jest stan runu " + runID + "?"},
		{Role: "assistant", Content: "Cronova runtime data was shown for " + runID + "."},
	})
	if !strings.Contains(answer.Answer, "disk unavailable") {
		t.Fatalf("follow-up log request did not use the run from history: %s", answer.Answer)
	}
	if len(answer.Sources) < 2 || answer.Sources[1].Type != "runtime_log" {
		t.Fatalf("follow-up log request did not include a runtime-log source: %+v", answer.Sources)
	}
}

func TestAskPassesRuntimeEvidenceToConfiguredProvider(t *testing.T) {
	var received string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req chatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Errorf("decode request: %v", err)
		}
		for _, msg := range req.Messages {
			received += msg.Content
		}
		writeChatResponse(w, "Run etl__r1 failed; task extract also failed.")
	}))
	defer server.Close()
	wiki, stub := setupRuntimeWiki(t, "LOG_CONTENT_MUST_NOT_BE_SENT_WITHOUT_REQUEST")
	stub.providers = []*model.AIProvider{{ID: "test", Name: "test", BaseURL: server.URL, Model: "test-model", Default: true}}
	answer := wiki.AskWithModeHistory(context.Background(), "Explain run etl__r1", "en", ModeRunAnalysis, nil)
	if !strings.Contains(answer.Answer, "task extract") {
		t.Fatalf("unexpected model answer: %s", answer.Answer)
	}
	if !strings.Contains(received, "Run ID: etl__r1") || !strings.Contains(received, "Task extract: state=failed") {
		t.Fatalf("provider did not receive the live runtime fields: %s", received)
	}
	if strings.Contains(received, "LOG_CONTENT_MUST_NOT_BE_SENT_WITHOUT_REQUEST") {
		t.Fatal("provider received log contents although the question did not request logs")
	}
}

func TestAskSendsOnlyRedactedLogExcerptToProvider(t *testing.T) {
	var received string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req chatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Errorf("decode request: %v", err)
		}
		for _, msg := range req.Messages {
			received += msg.Content
		}
		writeChatResponse(w, "The log reports a disk error.")
	}))
	defer server.Close()
	wiki, stub := setupRuntimeWiki(t, "password=not-for-model\nerror: disk unavailable\n")
	stub.providers = []*model.AIProvider{{ID: "test", Name: "test", BaseURL: server.URL, Model: "test-model", Default: true}}
	_ = wiki.AskWithModeHistory(context.Background(), "Show logs for task extract in run etl__r1", "en", ModeRunAnalysis, nil)
	if strings.Contains(received, "not-for-model") || !strings.Contains(received, "[REDACTED]") {
		t.Fatalf("provider did not receive a redacted log excerpt: %s", received)
	}
	if !strings.Contains(received, "error: disk unavailable") {
		t.Fatalf("provider did not receive the requested log evidence: %s", received)
	}
}

func TestRequestedRunIDAmbiguityAndFollowUpGate(t *testing.T) {
	if id, ambiguous := requestedRunID("Compare etl__r1 and etl__r2", nil); id != "" || !ambiguous {
		t.Fatalf("expected ambiguous run IDs, got id=%q ambiguous=%v", id, ambiguous)
	}
	if id, ambiguous := requestedRunID("What is a DAG?", []Message{{Role: "user", Content: "run etl__r1"}}); id != "" || ambiguous {
		t.Fatalf("unrelated question unexpectedly reused prior run ID: id=%q ambiguous=%v", id, ambiguous)
	}
	if id, ambiguous := requestedRunID("Jaki jest stan?", []Message{{Role: "user", Content: "Sprawdź run etl__r1"}}); id != "etl__r1" || ambiguous {
		t.Fatalf("Polish runtime follow-up did not reuse run ID: id=%q ambiguous=%v", id, ambiguous)
	}
	if id, ambiguous := requestedRunID("Jaki jest stan runu etl__r1.", nil); id != "etl__r1" || ambiguous {
		t.Fatalf("trailing sentence punctuation became part of Run ID: id=%q ambiguous=%v", id, ambiguous)
	}
	if !taskIDMentioned("pokaż logi taska extract", "extract") || taskIDMentioned("pokaż logi taska extract_data", "extract") {
		t.Fatal("task ID matching did not respect token boundaries")
	}
	if !logRequestPattern.MatchString("Pokaż logi taska") || !logRequestPattern.MatchString("show logs") || logRequestPattern.MatchString("pokaż katalog") {
		t.Fatal("log request detection did not respect Polish/English word boundaries")
	}
}
