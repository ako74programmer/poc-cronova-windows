package api

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/zoyluo/cronova/internal/model"
	"github.com/zoyluo/cronova/internal/scheduler/parser"
)

// consoleRoundTrip feeds a GET /api/dags/{id} body through the real console
// code (views.js: editorTaskFrom -> taskTypeOptionsHtml -> dagSpecFrom) in
// Node and returns the spec the editor would POST plus the rendered <select>
// option HTML per task.
const consoleRoundTrip = `
const vm = require("vm"), fs = require("fs");
const ctx = { console, document: { addEventListener() {}, querySelectorAll() { return []; }, getElementById() { return null; }, documentElement: {} },
  localStorage: { getItem() { return null; }, setItem() {} }, navigator: {}, location: { hash: "" } };
ctx.window = ctx; vm.createContext(ctx);
// esc lives in base.js (needs browser globals); same definition as there.
vm.runInContext("var esc = (s) => String(s ?? \"\").replace(/[&<>\"]/g, (c) => ({ \"&\": \"&amp;\", \"<\": \"&lt;\", \">\": \"&gt;\", '\"': \"&quot;\" }[c]));", ctx);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), ctx, { filename: "views.js" });
const dag = JSON.parse(fs.readFileSync(0, "utf8"));
ctx.__dag = dag;
const out = vm.runInContext(` + "`" + `(() => {
  const tasks = __dag.tasks.map(editorTaskFrom);
  const selects = tasks.map((tk) => taskTypeOptionsHtml(tk.type));
  const spec = dagSpecFrom({ dag: { dag_id: __dag.dag_id, schedule: "", start_date: "", definition_hash: __dag.definition_hash }, tasks });
  return { spec, selects };
})()` + "`" + `, ctx);
process.stdout.write(JSON.stringify(out));
`

func runConsole(t *testing.T, dagJSON []byte) (spec map[string]any, selects []string) {
	t.Helper()
	node, err := exec.LookPath("node")
	if err != nil {
		t.Skip("node not on PATH; console round-trip needs Node.js")
	}
	_, file, _, _ := runtime.Caller(0)
	views := filepath.Join(filepath.Dir(file), "..", "web", "static", "views.js")
	script := filepath.Join(t.TempDir(), "roundtrip.js")
	if err := os.WriteFile(script, []byte(consoleRoundTrip), 0o600); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(node, script, views)
	cmd.Stdin = strings.NewReader(string(dagJSON))
	out, err := cmd.Output()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			t.Fatalf("node: %v\n%s", err, ee.Stderr)
		}
		t.Fatal(err)
	}
	var res struct {
		Spec    map[string]any `json:"spec"`
		Selects []string       `json:"selects"`
	}
	if err := json.Unmarshal(out, &res); err != nil {
		t.Fatalf("decode node output: %v\n%s", err, out)
	}
	return res.Spec, res.Selects
}

// TestConsolePowerShellTaskRoundTrip: YAML -> GET (editor) -> console model ->
// <select> -> save -> YAML keeps every task's type and command identical, and
// the type selector marks the real type (not the first option).
func TestConsolePowerShellTaskRoundTrip(t *testing.T) {
	h, st, trig, _ := setup(t)
	const src = `dag_id: rt
tasks:
  - id: ps
    type: powershell
    command: "Write-Output \"{{ logical_date }}\"; if ($LASTEXITCODE) { exit 3 }"
  - id: implicit
    command: "Get-ChildItem -Force | Select-Object -First 1"
    deps: [ps]
  - id: py
    type: python
    command: "print('hi')"
    deps: [implicit]
`
	if _, err := parser.Parse([]byte(src)); err != nil {
		t.Fatalf("seed yaml invalid: %v", err)
	}
	if err := st.UpsertDAG(context.Background(), &model.DAG{DagID: "rt", DefinitionYAML: src, MaxActiveRuns: 1}); err != nil {
		t.Fatal(err)
	}
	rec := do(h, "GET", "/api/dags/rt", "", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET = %d: %s", rec.Code, rec.Body)
	}

	spec, selects := runConsole(t, rec.Body.Bytes())

	wantTypes := []string{"powershell", "powershell", "python"}
	for i, sel := range selects {
		want := `<option value="` + wantTypes[i] + `" selected>`
		if !strings.Contains(sel, want) || strings.Count(sel, "selected") != 1 {
			t.Errorf("task %d select does not mark %q as the only selected option:\n%s", i, wantTypes[i], sel)
		}
	}

	body, _ := json.Marshal(spec)
	if rec := do(h, "POST", "/api/dags/build", string(body), nil); rec.Code != http.StatusOK {
		t.Fatalf("save = %d: %s", rec.Code, rec.Body)
	}
	before, _ := parser.Parse([]byte(src))
	after, err := parser.Parse([]byte(trig.createdYML))
	if err != nil {
		t.Fatalf("saved yaml invalid: %v\n%s", err, trig.createdYML)
	}
	if len(after.Tasks) != len(before.Tasks) {
		t.Fatalf("task count %d -> %d", len(before.Tasks), len(after.Tasks))
	}
	for i := range before.Tasks {
		b, a := before.Tasks[i], after.Tasks[i]
		if a.ID != b.ID || a.Type != b.Type || a.Command != b.Command {
			t.Errorf("task %d changed: %s/%s %q -> %s/%s %q", i, b.ID, b.Type, b.Command, a.ID, a.Type, a.Command)
		}
	}
}

// A legacy/unknown type must stay selected (shown as unsupported) instead of
// the browser silently picking the first option.
func TestConsoleUnknownTaskTypeNotSilentlyConverted(t *testing.T) {
	dag := []byte(`{"dag_id":"x","tasks":[{"id":"old","type":"shell","command":"echo hi"}]}`)
	spec, selects := runConsole(t, dag)
	if !strings.Contains(selects[0], `<option value="shell" selected disabled>`) || strings.Contains(selects[0], `value="powershell" selected`) {
		t.Fatalf("unknown type rendered wrongly:\n%s", selects[0])
	}
	task := spec["tasks"].([]any)[0].(map[string]any)
	if task["type"] != "shell" {
		t.Fatalf("editor model rewrote type to %v", task["type"])
	}
}
