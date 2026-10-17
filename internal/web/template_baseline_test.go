package web

import (
	"io/fs"
	"strings"
	"testing"
)

// TestStarterTemplateBaseline documents the current expert-mode starter
// contract. The starters are plain
// JavaScript data consumed by the browser, so this test intentionally checks
// the source contract rather than trying to execute the whole DOM builder.
func TestStarterTemplateBaseline(t *testing.T) {
	src, err := fs.ReadFile(FS(), "builder.js")
	if err != nil {
		t.Fatalf("read embedded builder.js: %v", err)
	}
	text := string(src)

	if !strings.Contains(text, "const WORKFLOW_TEMPLATES = [") {
		t.Fatal("builder.js no longer contains the shared starter template catalog")
	}
	if !strings.Contains(text, "const DAG_TEMPLATES = WORKFLOW_TEMPLATES.map") {
		t.Fatal("expert starter catalog is not derived from the shared catalog")
	}
	if !strings.Contains(text, "const NV_TEMPLATES = Object.fromEntries") {
		t.Fatal("novice starter catalog is not derived from the shared catalog")
	}
	if strings.Contains(text, "const NV_TEMPLATES = {") {
		t.Fatal("novice starter definitions are duplicated outside the shared catalog")
	}
	if !strings.Contains(text, "function expertTemplateGroupsHtml()") || !strings.Contains(text, "DAG_TEMPLATES.filter((tp) => tp.category === category)") {
		t.Fatal("expert starter modal no longer renders category groups from the catalog")
	}

	for _, key := range []string{"key: \"blank\"", "key: \"etl\"", "key: \"report\"", "key: \"fanout\"", "key: \"build\"", "key: \"quality_gate\""} {
		if got := strings.Count(text, key); got != 1 {
			t.Errorf("starter %q occurs %d times, want exactly once", key, got)
		}
	}

	checks := []struct {
		name string
		want string
	}{
		{"blank has no tasks", "key: \"blank\", category: \"general\", name: \"tpl_blank\", desc: \"tpl_blank_d\", tasks: []"},
		{"build is software delivery", "key: \"build\", category: \"sdlc\", name: \"tpl_build\""},
		{"quality gate is software delivery", "key: \"quality_gate\", category: \"sdlc\", name: \"tpl_quality_gate\""},
		{"etl extract task", "{ id: \"extract\", type: \"powershell\", command: \"Write-Output extract {{ logical_date }}; Start-Sleep 1\" }"},
		{"etl transform dependency", "{ id: \"transform\", type: \"powershell\", command: \"Write-Output transform; Start-Sleep 1\", deps: [\"extract\"] }"},
		{"etl load dependency", "{ id: \"load\", type: \"powershell\", command: \"Write-Output load run={{ run_id }}; Start-Sleep 1\", deps: [\"transform\"] }"},
		{"report schedule", "key: \"report\", category: \"general\", name: \"tpl_report\", desc: \"tpl_report_d\", schedule: \"0 8 * * *\""},
		{"report fetch task", "{ id: \"fetch\", type: \"powershell\", command: \"Write-Output fetch data for {{ logical_date }}; Start-Sleep 1\" }"},
		{"report render dependency", "{ id: \"render\", type: \"powershell\", command: \"Write-Output render report; Start-Sleep 1\", deps: [\"fetch\"] }"},
		{"fanout start task", "{ id: \"start\", type: \"powershell\", command: \"Write-Output start; Start-Sleep 1\" }"},
		{"fanout branch A dependency", "{ id: \"branch_a\", type: \"powershell\", command: \"Write-Output branch A; Start-Sleep 1\", deps: [\"start\"] }"},
		{"fanout branch B dependency", "{ id: \"branch_b\", type: \"powershell\", command: \"Write-Output branch B; Start-Sleep 1\", deps: [\"start\"] }"},
		{"fanout join dependencies", "{ id: \"join\", type: \"powershell\", command: \"Write-Output join; Start-Sleep 1\", deps: [\"branch_a\", \"branch_b\"] }"},
		{"build task", "{ id: \"build\", type: \"powershell\", command: \"Write-Output 'Build step - replace with your build command'\" }"},
		{"test depends on build", "{ id: \"test\", type: \"powershell\", command: \"Write-Output 'Test step - replace with your test command'\", deps: [\"build\"] }"},
		{"package depends on test", "{ id: \"package\", type: \"powershell\", command: \"Write-Output 'Package step - replace with your package command'\", deps: [\"test\"] }"},
		{"quality lint task", "{ id: \"lint\", type: \"powershell\", command: \"Write-Output 'Lint check - replace with your lint command'\" }"},
		{"quality unit tests task", "{ id: \"unit_tests\", type: \"powershell\", command: \"Write-Output 'Unit tests - replace with your test command'\" }"},
		{"quality security scan task", "{ id: \"security_scan\", type: \"powershell\", command: \"Write-Output 'Security scan - replace with your scan command'\" }"},
		{"quality gate joins all checks", "{ id: \"quality_gate\", type: \"powershell\", command: \"Write-Output 'Quality gate passed'\", deps: [\"lint\", \"unit_tests\", \"security_scan\"] }"},
	}
	for _, check := range checks {
		if !strings.Contains(text, check.want) {
			t.Errorf("%s: builder.js does not contain %q", check.name, check.want)
		}
	}
}
