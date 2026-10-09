# Techniczny opis DAG-a `sdlc_springboot_template_crud`

## Zakres i status analizy

Dokument opisuje definicję [`dags/sdlc_springboot_template_crud.yaml`](../dags/sdlc_springboot_template_crud.yaml) (wcześniej opisywaną jako `sdlc_springboot`), skrypty PowerShell wywoływane przez ten DAG oraz ich kontrakty wejścia/wyjścia.

To jest **analiza statyczna kodu**, a nie raport wykonania. Weryfikacja Javy, Mavena, Pythona i konfiguracji providera AI wymaga uruchomienia na Windowsie.

## 1. Cel przepływu

DAG tworzy lokalny projekt Spring Boot z wersjonowanego template’u [`templates/springboot-simple`](../templates/springboot-simple), sprawdza jego kompilowalność, dodaje prosty REST CRUD przez skonfigurowanego providera AI, uruchamia pętlę kompilacji i automatycznej naprawy, a na końcu testy Maven.

## 2. Definicja i parametry wykonania

| Pole | Wartość |
|---|---|
| `dag_id` | `sdlc_springboot_template_crud` |
| `schedule` | `0 2 * * *` |
| `start_date` | `2026-09-01` |
| `catchup` | `false` |
| `max_active_runs` | `1` |
| `default_retries` | nie ustawione |

Wszystkie taski mają `type: powershell` i nie ustawiają timeoutów.

## 3. Graf zależności

```mermaid
flowchart LR
  A[copy_template_to_workspace] --> B[maven_compile]
  B --> C[ai_generate_java_maven_feature]
  C --> D[java_maven_compile_fix_loop]
  D --> E[maven_test]
```

## 4. Przepływ krok po kroku

### 4.1. `copy_template_to_workspace` — odtworzenie projektu z template’u

```powershell
& .\internal\scripts\copy-template-to-workspace.ps1 -t springboot-simple -w workspaces/springboot -p app -c
```

[`copy-template-to-workspace.ps1`](../internal/scripts/copy-template-to-workspace.ps1) — parametry `-Template/-t` (wymagany), `-Workspace/-w`, `-Project/-p`, `-Clean/-c`:

1. wymaga katalogu `templates\<Template>`;
2. przy `-c` usuwa `workspaces/springboot/app`;
3. kopiuje całą zawartość template’u (z plikami ukrytymi) do katalogu docelowego.

Template zawiera `pom.xml`, `DemoApplication.java` i `DemoApplicationTests.java` w pakiecie `com.example.demo` (w repozytorium znajduje się również katalog `target/`, który jest kopiowany razem z template’em).

### 4.2. `maven_compile` — kompilacja czystego projektu

```powershell
& .\internal\scripts\maven-compile.ps1 -w workspaces/springboot -p app
```

`mvn -B -Dmaven.repo.local=<repo>\.m2\repository -DskipTests compile`; diagnostyka toolchainu w `app\toolchain-runtime.txt`.

### 4.3. `ai_generate_java_maven_feature` — generowanie CRUD

```powershell
& .\internal\scripts\ai-java-mvn-generate-feature.ps1 -f prompts/springboot_crud.txt -w workspaces/springboot -p app -k com.example.demo -r default -y python
```

[`ai-java-mvn-generate-feature.ps1`](../internal/scripts/ai-java-mvn-generate-feature.ps1) buduje prompt z [`prompts/springboot_crud.txt`](../prompts/springboot_crud.txt), reguł generatora i `pom.xml`, zapisuje go do `.tmp\ai_feature_prompt.txt` i uruchamia [`ai_generate_feature.py`](../internal/scripts/ai_generate_feature.py). Odpowiedź AI (JSON `ścieżka → zawartość`, opcjonalnie `pom_xml`) jest zapisywana do projektu.

### 4.4. `java_maven_compile_fix_loop` — kompilacja i warunkowa naprawa przez AI

```powershell
& .\internal\scripts\java-maven-compile-fix-loop.ps1 -LoopWorkspace workspaces/springboot -LoopProject app -LoopPackage com.example.demo -LoopProvider default -LoopPython python
```

[`java-maven-compile-fix-loop.ps1`](../internal/scripts/java-maven-compile-fix-loop.ps1): do 3 iteracji (`-LoopIterations`) `mvn -B -DskipTests test-compile`, log `.tmp\compile.log`. Po błędzie (poza ostatnią iteracją) przygotowuje prompt reviewera i wywołuje [`ai-review-java-maven-errors.ps1`](../internal/scripts/ai-review-java-maven-errors.ps1), który uruchamia `internal/scripts/ai/review_fix_v2.py`. Sukces kompilacji kończy task kodem `0`, błąd w ostatniej iteracji — wyjątkiem.

### 4.5. `maven_test` — testy Maven

```powershell
& .\internal\scripts\maven-test.ps1 -w workspaces/springboot -p app
```

`mvn -B -Dmaven.repo.local=... test`.

## 5. Wspólne elementy i dane środowiskowe

### `internal/scripts/common/toolchain.ps1`

- `Set-JavaMavenToolchain` — `JAVA_HOME` z `CRONOVA_JAVA_HOME`/`JAVA_HOME`, `MAVEN_HOME` z `CRONOVA_MAVEN_HOME`/`MAVEN_HOME`, dopisanie `bin` do `PATH`;
- `Get-ConfiguredCommand` — `python` (`CRONOVA_PYTHON`), `maven` (`bin\mvn.cmd`), `java` (`bin\java.exe`), fallback do `PATH`;
- `Write-ToolchainRuntime`, `Invoke-Native`, `Resolve-RepoPath`.

### Konfiguracja AI

[`internal/scripts/common/ai-provider.ps1`](../internal/scripts/common/ai-provider.ps1): `CRONOVA_AI_BASE_URL` + `CRONOVA_AI_MODEL` (+ `CRONOVA_AI_TOKEN`) mają pierwszeństwo; w przeciwnym razie odczyt tabeli `ai_providers` z `CRONOVA_DB` (domyślnie `data\cronova.db`) — rekord o podanym id lub `is_default=1` dla `default`.

### Katalogi robocze i efekty uboczne

| Lokalizacja | Zawartość |
|---|---|
| `workspaces/springboot/app` | projekt (odtwarzany w każdym runie) |
| `.m2/repository` | lokalny cache Maven |
| `.tmp/` | prompty, żądania/odpowiedzi AI, `compile.log` |

## 6. Ocena reużywalności — model „klocków LEGO”

### Werdykt

**Tak.** DAG to pięć wywołań ogólnych skryptów; specyfika projektu leży w parametrach i pliku promptu.

### Macierz klocków

| Klocek | Reużywalność | Granica |
|---|---|---|
| `copy-template-to-workspace.ps1` | Wysoka — dowolny katalog w `templates/` | Kopiuje też artefakty buildu obecne w template |
| `maven-compile.ps1`, `maven-test.ps1` | Wysoka dla Maven | Stały cache `.m2` w repozytorium |
| `ai-java-mvn-generate-feature.ps1` | Wysoka — prompt z pliku | Reguły nastawione na Java/Maven/Spring |
| `java-maven-compile-fix-loop.ps1` | Średnia | Prompt reviewera zaszyty w skrypcie |

### Ograniczenia reużywalności

1. Niedeterministyczny wynik AI; pętla obejmuje tylko błędy kompilacji.
2. Wspólny katalog `.tmp/` dla wszystkich DAG-ów AI.
3. Brak timeoutów w DAG-u.

## 7. Różnica względem opisanych DAG-ów

- [`sdlc_springboot_startio`](SDLC_SPRINGBOOT_STARTIO.md) — identyczny przepływ, ale szkielet z Spring Initializr (`fetch-springboot-project.ps1`).
- [`sdlc_maven_luhn`](SDLC_MAVEN_LUHN_TECHNICAL.md) — szkielet z archetypu Maven i prompt Luhn.
- [`sdlc_springboot_rest`](SDLC_SPRINGBOOT_REST_TECHNICAL.md) — bez AI, sterowany konfiguracją YAML i Maven Wrapperem.

## 8. Wniosek

DAG jest deklaratywną kompozycją reużywalnych skryptów PowerShell z `internal/scripts/`, współdzielonych z pozostałymi przepływami Maven/AI.
