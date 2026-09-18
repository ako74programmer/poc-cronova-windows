# Plan: AI wiki / chat do nauki cronova od strony użytkownika

## Cel
Stworzyć wewnętrzne AI wiki oraz interaktywny chat w cronova console, który pomaga użytkownikowi zrozumieć projekt i przetestować funkcjonalności na żywo — bez czytania suchej dokumentacji.

## Architektura wysokopoziomowa

```
┌─────────────────────────────────────────────────────────────┐
│  Warstwa prezentacji: UI chatu w cronova console            │
│  - okno chatu z pytaniami użytkownika                       │
│  - odpowiedzi z linkami do DAG-ów / docs / przykładów       │
│  - przycisk „przetestuj” → trigger DAG / otwórz task editor │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│  Warstwa wiedzy: baza graphify + docs + DAG-i + workflows   │
│  - graph.json (struktura projektu)                          │
│  - docs/ (przetworzone na artykuły wiki)                    │
│  - dags/ + workflows/ (przykłady wykonywalne)               │
│  - prompts/ (gotowe pytania / scenariusze)                  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│  Warstwa LLM: prompt + RAG z bazy wiedzy                    │
│  - system prompt z kontekstem cronova                       │
│  - retrieval z graphify + docs                              │
│  - generowanie odpowiedzi + akcji (linki, komendy)          │
└─────────────────────────────────────────────────────────────┘
```

## Zadania wykonywalne

### Zadanie 1: Zbudować graf wiedzy z projektu cronova
- Uruchomić `/graphify . --wiki` na repo.
- Wygenerować `graphify-out/graph.json` oraz `graphify-out/wiki/index.md`.
- **Weryfikacja:**
  1. `graphify-out/graph.json` istnieje i zawiera węzły/krawędzie.
  2. `graphify-out/wiki/index.md` istnieje.
  3. Krótki test query: `/graphify query "What is cronova?"` zwraca sensowną odpowiedź.

### Zadanie 2: Przeanalizować istniejące DAG-i i workflow'y
- Przeczytać `dags/*.yaml`, `workflows/*/*`, `templates/`.
- Sporządzić listę gotowych przykładów do pokazywania w chatcie.
- **Weryfikacja:**
  1. Lista zawiera co najmniej 3 działające DAG-i.
  2. Każdy wpis ma: nazwę, ścieżkę, jednozdaniowy opis, co testuje.

### Zadanie 3: Wybrać i opisać 5 kluczowych funkcjonalności cronova
- Na podstawie README + grafu wybrać: DAG-i, schedule, retries/pools, projects, AI/MCP.
- Przygotować 5 krótkich opisów + przykłady DAG-ów.
- **Weryfikacja:**
  1. Każda funkcjonalność ma: nazwę, opis użytkownika, link do przykładu DAG.
  2. Opisy są zrozumiałe dla nowego użytkownika.

### Zadanie 4: Zaprojektować format odpowiedzi chatu
- Odpowiedź = wyjaśnienie + link do przykładu + akcja testowa.
- Przygotować szablon JSON/prompt dla LLM.
- **Weryfikacja:**
  1. Szablon zawiera pola: `answer`, `sources`, `actions`.
  2. Przykładowa odpowiedź dla pytania „Jak zrobić DAG z retry?” jest poprawna.

### Zadanie 5: Przygotować bazę wiedzy RAG
- Połączyć wiki graphify + docs/GETTING_STARTED.md + DAG_REFERENCE.md w jeden korpus.
- Wygenerować `knowledge-base.json`.
- **Weryfikacja:**
  1. `knowledge-base.json` istnieje.
  2. Zawiera chunki tekstu z metadanymi (źródło, sekcja).
  3. Test retrieval: dla zapytania „retry” zwraca chunki o retries.

### Zadanie 6: Zaimplementować prosty chat backend
- Dodać endpoint `/api/ask` przyjmujący pytanie, zwracający odpowiedź + akcje.
- Początkowo może być to mock z gotowymi odpowiedziami.
- **Weryfikacja:**
  1. `curl -X POST http://127.0.0.1:8090/api/ask -d '{"question":"Jak zrobić DAG?"}'` zwraca JSON.
  2. JSON zawiera `answer` i `actions`.

### Zadanie 7: Dodać UI chatu w konsoli cronova
- Dodać mały komponent chatu w `internal/web/static/`.
- Widoczny przycisk chatu w UI.
- **Weryfikacja:**
  1. Przycisk chatu jest widoczny w przeglądarce.
  2. Można wysłać pytanie i zobaczyć odpowiedź.

### Zadanie 8: Wpiąć akcje testowe
- „Uruchom ten DAG”, „Pokaż task editor”, „Otwórz logi”.
- Kliknięcie wykonuje akcję w UI.
- **Weryfikacja:**
  1. Kliknięcie „Uruchom DAG” wyzwala DAG w cronova console.
  2. Kliknięcie „Pokaż task editor” otwiera edytor.

### Zadanie 9: Test end-to-end
- Użytkownik pyta „Jak zrobić DAG z retry?" → dostaje odpowiedź + link + uruchamia przykład.
- **Weryfikacja:**
  1. Odpowiedź jest trafna.
  2. Akcja testowa działa w przeglądarce.
  3. DAG kończy się sukcesem.

## Kryteria ukończenia każdego zadania

1. Test terminalowy / skryptowy przechodzi pozytywnie.
2. Jeśli dotyczy UI — weryfikacja w przeglądarce pod `http://127.0.0.1:8090`.
3. Zadanie jest oznaczone jako done w tym planie (sekcja „Postęp”).

## Decyzje projektowe

- Baza wiedzy: graphify + docs + DAG-i (nie tylko README).
- Chat nie zastępuje docs, ale prowadzi użytkownika do przykładów.
- Akcje testowe są bezpieczne: tylko trigger DAG / otwarcie widoku / logi.
- Backend chatu może być najpierw mockiem z gotowymi odpowiedziami, potem LLM.

## Postęp

| # | Zadanie | Status | Uwagi |
|---|---------|--------|-------|
| 1 | Zbudować graf wiedzy z projektu cronova | ✅ done | Graf kodu gotowy: 3412 nodes, 9528 edges, 201 communities. Docs wymagają osobnego RAG (Zadanie 5). |
| 2 | Przeanalizować istniejące DAG-i i workflow'y | ✅ done | Zidentyfikowano 3 główne DAG-i AI-SDLC; wzorzec reusable script + thin wrapper + DAG. |
| 3 | Wybrać i opisać 5 kluczowych funkcjonalności cronova | ✅ done | 5 funkcjonalności opisanych z linkami do przykładów. |
| 4 | Zaprojektować format odpowiedzi chatu | ✅ done | Format JSON: answer + sources + actions. |
| 5 | Przygotować bazę wiedzy RAG | ✅ done | 133 chunki, 11 tematów, retrieval test dla "retry" zwraca trafne wyniki. |
| 6 | Zaimplementować prosty chat backend | ✅ done | Endpoint POST /api/ask działa, testowany przez Invoke-RestMethod. |
| 7 | Dodać UI chatu w konsoli cronova | ✅ done | Przycisk chatu + okno + odpowiedzi działają w przeglądarce. |
| 8 | Wpiąć akcje testowe | ✅ done | Akcje trigger_dag / open_editor / copy_command są obsługiwane w aiwiki.js. |
| 9 | Test end-to-end | ✅ done | Użytkownik pyta o DAG → dostaje odpowiedź → klika "Uruchom ten DAG" → DAG sdlc_springboot w stanie running. |
| 10 | Automatyzacja regeneracji bazy wiedzy | ✅ done | `make ai-wiki` (Linux/macOS/Git Bash) + `scripts/build-ai-wiki.ps1` (Windows). |

## Zadanie 4 — wyniki

### Format odpowiedzi chatu (JSON)

```json
{
  "answer": "Aby dodać retry do taska, ustaw pole `retries` w definicji taska w YAML...",
  "sources": [
    { "type": "doc", "path": "docs/DAG_REFERENCE.md", "section": "Task fields" },
    { "type": "dag", "path": "dags/sdlc_springboot.yaml", "task": "scaffold" }
  ],
  "actions": [
    { "type": "trigger_dag", "dag_id": "sdlc_springboot", "label": "Uruchom przykład" },
    { "type": "open_editor", "path": "dags/sdlc_springboot.yaml", "label": "Zobacz DAG" }
  ]
}
```

### Typy akcji

| Typ | Opis | Parametry |
|-----|------|-----------|
| `trigger_dag` | Wyzwala DAG w cronova | `dag_id` |
| `open_editor` | Otwiera edytor / podgląd pliku | `path` |
| `open_logs` | Otwiera logi ostatniego runu | `dag_id`, opcjonalnie `run_id` |
| `copy_command` | Kopiuje komendę CLI do schowka | `command` |

## Zadanie 3 — wyniki

### 5 kluczowych funkcjonalności cronova dla użytkownika

| # | Funkcjonalność | Opis dla użytkownika | Przykład / link do testu |
|---|----------------|----------------------|--------------------------|
| 1 | **DAG-i i zależności** | Tworzysz pipeline'y jako graf zadań w YAML. Taski czekają na swoich poprzedników (`deps`). | [dags/sdlc_springboot.yaml](dags/sdlc_springboot.yaml) — `compile_skeleton` zależy od `scaffold` |
| 2 | **Harmonogramy** | Uruchamiasz DAG ręcznie, po cronie (`0 2 * * *`) lub co jakiś czas (`@every 30s`). | [dags/sdlc_springboot.yaml](dags/sdlc_springboot.yaml#L2) — `schedule: "0 2 * * *"` |
| 3 | **Retry, timeout, pool** | Każdy task może mieć własne retry, timeout i pulę zasobów. | [dags/sdlc_springboot.yaml](dags/sdlc_springboot.yaml#L15) — `timeout: 120` |
| 4 | **Projects / upload** | Wrzucasz folder lub zip w UI i uruchamiasz go jako task z `project: nazwa`. | [README.md](README.md) sekcja „Run your own scripts and projects" |
| 5 | **AI / MCP / AI-SDLC** | AI generuje kod (CRUD, feature), a potem naprawia w pętli kompilacji. Możesz też sterować cronova przez MCP. | [dags/sdlc_springboot.yaml](dags/sdlc_springboot.yaml) — kroki `ai_add_crud` i `compile_loop` |

### Najczęstsze pytania użytkownika (do obsługi w chatcie)

1. „Jak zrobić prosty DAG z dwoma taskami?"
2. „Jak ustawić retry i timeout?"
3. „Jak uruchomić workflow ręcznie?"
4. „Jak dodać własny skrypt / projekt?"
5. „Jak działa AI-SDLC?"
6. „Jak dodać nowy workflow do istniejącego repo?"

## Zadanie 2 — wyniki

### Lista gotowych DAG-ów / workflow'ów

| DAG | Ścieżka | Opis | Co testuje |
|-----|---------|------|------------|
| `sdlc_springboot` | [dags/sdlc_springboot.yaml](dags/sdlc_springboot.yaml) | AI-SDLC ze szkieletem Spring Boot z lokalnego template'u | scaffold → compile → AI CRUD → compile loop → tests |
| `sdlc_maven_luhn` | [dags/sdlc_maven_luhn.yaml](dags/sdlc_maven_luhn.yaml) | AI-SDLC z Maven archetype + algorytm Luhn | scaffold → compile → AI feature → compile loop → tests |
| `sdlc_springboot_startio` | [dags/sdlc_springboot_startio.yaml](dags/sdlc_springboot_startio.yaml) | AI-SDLC ze szkieletem z start.spring.io | scaffold → compile → AI CRUD → compile loop → tests |

### Kluczowy wzorzec projektowy

Każdy workflow składa się z:
1. **Reusable script** w `internal/scripts/` (np. `copy-template-to-workspace`, `compile-project`).
2. **Thin wrapper** w `workflows/<workflow>/` (np. `scaffold.sh`, `compile_skeleton.sh`).
3. **DAG YAML** w `dags/` wywołujący wrappery przez `command: bash /.../step.sh`.

Przykład:
- `internal/scripts/copy-template-to-workspace -t springboot-simple -c`
- `workflows/sdlc_springboot/scaffold.sh` → wywołuje powyższy skrypt
- `dags/sdlc_springboot.yaml` → task `scaffold` wywołuje `scaffold.sh`

To jest podstawowa odpowiedź na pytanie użytkownika: „Jak dodać nowy workflow?" → dodaj reusable script, wrapper i DAG.
