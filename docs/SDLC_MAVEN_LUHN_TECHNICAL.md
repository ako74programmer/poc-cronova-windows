# Techniczny opis DAG-a `sdlc_maven_luhn`

## Zakres i status analizy

Dokument opisuje definicję [`dags/sdlc_maven_luhn.yaml`](../dags/sdlc_maven_luhn.yaml), prompt [`prompts/luhn.txt`](../prompts/luhn.txt), skrypty PowerShell wykonywane przez taski oraz ocenę reużywalności przepływu. Jest to **analiza statyczna kodu**, a nie raport wykonania.

## 1. Cel przepływu

`sdlc_maven_luhn` jest kompozycyjnym przepływem Maven + AI dla małej funkcji biznesowej:

1. generuje projekt Java przez `maven-archetype-quickstart`;
2. kompiluje czysty projekt;
3. przez providera AI dodaje klasę `Luhn` i testy `LuhnTest`;
4. uruchamia pętlę `test-compile` → naprawa AI (maks. 3 iteracje);
5. uruchamia testy Maven.

## 2. Definicja i parametry wykonania

| Pole | Wartość |
|---|---|
| `dag_id` | `sdlc_maven_luhn` |
| `schedule` | `0 2 * * *` (codziennie o 02:00) |
| `start_date` | `2026-09-01` |
| `catchup` | `false` |
| `max_active_runs` | `1` |
| `default_retries` | nie ustawione (domyślna wartość Cronova) |

Wszystkie taski mają `type: powershell` i nie ustawiają własnych timeoutów.

## 3. Graf zależności

```mermaid
flowchart LR
  A[generate_maven_archetype] --> B[maven_compile]
  B --> C[ai_generate_java_maven_feature]
  C --> D[java_maven_compile_fix_loop]
  D --> E[maven_test]
```

| Task | Komenda |
|---|---|
| `generate_maven_archetype` | `& .\internal\scripts\generate-maven-archetype.ps1 -a maven-archetype-quickstart -g com.example -r luhn -k com.example.luhn -j 21 -w workspaces/sdlc_maven_luhn -p app -C` |
| `maven_compile` | `& .\internal\scripts\maven-compile.ps1 -w workspaces/sdlc_maven_luhn -p app` |
| `ai_generate_java_maven_feature` | `& .\internal\scripts\ai-java-mvn-generate-feature.ps1 -f prompts/luhn.txt -w workspaces/sdlc_maven_luhn -p app -k com.example.luhn -r default -m gpt-5.3-codex -y python` |
| `java_maven_compile_fix_loop` | `& .\internal\scripts\java-maven-compile-fix-loop.ps1 -LoopWorkspace workspaces/sdlc_maven_luhn -LoopProject app -LoopPackage com.example.luhn -LoopProvider default -LoopModel gpt-5.3-codex -LoopPython python` |
| `maven_test` | `& .\internal\scripts\maven-test.ps1 -w workspaces/sdlc_maven_luhn -p app` |

## 4. Przepływ krok po kroku

### 4.1. `generate_maven_archetype`

Skrypt: [`internal/scripts/generate-maven-archetype.ps1`](../internal/scripts/generate-maven-archetype.ps1).

Parametry (aliasy): `-Archetype/-a`, `-ArchetypeVersion/-v`, `-Group/-g`, `-Artifact/-r`, `-Package/-k` (domyślnie `Group`), `-JavaVersion/-j`, `-Workspace/-w`, `-Project/-p`, `-Clean/-C`.

Działanie:

1. przy `-Clean` usuwa `workspaces/sdlc_maven_luhn/app`;
2. ustawia toolchain (`Set-JavaMavenToolchain`) i wyszukuje `mvn.cmd`;
3. wykonuje w tymczasowym katalogu `.archetype-out-<guid>` w workspace:

```powershell
mvn -B archetype:generate -DgroupId=com.example -DartifactId=luhn -Dpackage=com.example.luhn -Dversion=1.0-SNAPSHOT -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false -DoutputDirectory=<tmp>
```

4. kopiuje `<tmp>\luhn` do `workspaces/sdlc_maven_luhn/app` i usuwa katalog tymczasowy.

Parametr `-j 21` jest przyjmowany, ale skrypt nie przekazuje go do Mavena ani nie modyfikuje `pom.xml`.

### 4.2. `maven_compile`

Skrypt: [`internal/scripts/maven-compile.ps1`](../internal/scripts/maven-compile.ps1). Wykonuje w katalogu projektu:

```powershell
mvn -B "-Dmaven.repo.local=<repo>\.m2\repository" -DskipTests compile
```

i zapisuje diagnostykę toolchainu do `app\toolchain-runtime.txt`.

### 4.3. `ai_generate_java_maven_feature`

Skrypt: [`internal/scripts/ai-java-mvn-generate-feature.ps1`](../internal/scripts/ai-java-mvn-generate-feature.ps1).

Parametry: `-PromptFile/-f` (wymagany), `-Workspace/-w`, `-Project/-p`, `-Package/-k`, `-ProviderId/-r`, `-Model/-m`, `-Python/-y`, `-IncludeSources/-s`.

#### Prompt `prompts/luhn.txt`

Wymaga klasy `Luhn` z `isValid(String)`, testów `LuhnTest` z deterministycznymi przypadkami brzegowymi, zachowania `App.java`/`AppTest.java` i unikania regexów z backslashami.

#### Działanie skryptu

1. rozwiązuje Pythona: `-y python`/`python3` → `CRONOVA_PYTHON` → `Get-ConfiguredCommand 'python'`;
2. rozwiązuje providera AI (patrz sekcja 5);
3. wymaga `pom.xml`; przy `-IncludeSources` dołącza wszystkie pliki `*.java`;
4. buduje pełny prompt (treść pliku + reguły: odpowiedź tylko jako JSON `ścieżka → zawartość`, opcjonalny klucz `pom_xml`, brak `<version>` dla zarządzanych zależności, proste testy bez MockMvc itp.);
5. zapisuje `.tmp\ai_feature_prompt.txt` i uruchamia [`internal/scripts/ai_generate_feature.py`](../internal/scripts/ai_generate_feature.py) z argumentami: katalog projektu, plik promptu, `.tmp\ai_feature_request.json`, `.tmp\ai_feature_response.json`, model, base URL i opcjonalnie token.

Helper Pythona wysyła żądanie chat completions, zapisuje surową odpowiedź, usuwa markdownowe ogrodzenia i zapisuje pliki z JSON-a do projektu.

### 4.4. `java_maven_compile_fix_loop`

Skrypt: [`internal/scripts/java-maven-compile-fix-loop.ps1`](../internal/scripts/java-maven-compile-fix-loop.ps1).

Parametry: `-LoopWorkspace`, `-LoopProject`, `-LoopPackage`, `-LoopIterations` (domyślnie `3`), `-LoopProvider`, `-LoopModel`, `-LoopPython`.

W każdej iteracji:

1. `mvn -B -Dmaven.repo.local=... -DskipTests test-compile`, log `.tmp\compile.log`;
2. sukces → koniec z kodem `0`;
3. błąd w ostatniej iteracji → wyjątek `Max iterations reached`;
4. w przeciwnym razie buduje prompt reviewera (`pom.xml`, ostatnie 80 linii logu, wszystkie źródła z `src\main\java` i `src\test\java`) i wywołuje [`ai-review-java-maven-errors.ps1`](../internal/scripts/ai-review-java-maven-errors.ps1), który uruchamia [`internal/scripts/ai/review_fix_v2.py`](../internal/scripts/ai/review_fix_v2.py) i zapisuje poprawione pliki.

W tym DAG-u model jest jawnie ustawiony na `gpt-5.3-codex`, a provider (base URL/token) pochodzi z rekordu domyślnego.

### Ważna granica obecnej reużywalności

Prompt reviewera w pętli jest zaszyty w skrypcie i zawiera reguły specyficzne dla Spring Boot (np. starterów webmvc, `jakarta.validation`). Dla projektu Luhn bez Springa są one nadmiarowe, ale nie blokują działania.

### 4.5. `maven_test`

Skrypt: [`internal/scripts/maven-test.ps1`](../internal/scripts/maven-test.ps1):

```powershell
mvn -B "-Dmaven.repo.local=<repo>\.m2\repository" test
```

## 5. Wspólne elementy i dane środowiskowe

### `internal/scripts/common/toolchain.ps1`

- `Get-RepoRoot`, `Resolve-RepoPath` — ścieżki względem repozytorium;
- `Get-ConfiguredCommand` — `python` (`CRONOVA_PYTHON`), `maven` (`CRONOVA_MAVEN_HOME`/`MAVEN_HOME` → `bin\mvn.cmd`), `java` (`CRONOVA_JAVA_HOME`/`JAVA_HOME` → `bin\java.exe`), z fallbackiem do `PATH`;
- `Set-JavaMavenToolchain` — ustawia `JAVA_HOME`, `MAVEN_HOME` i dopisuje ich `bin` do `PATH`;
- `Write-ToolchainRuntime` — zapis diagnostyki;
- `Invoke-Native`, `ConvertTo-NativeArgumentString` — uruchamianie natywnych programów.

### Konfiguracja AI

[`internal/scripts/common/ai-provider.ps1`](../internal/scripts/common/ai-provider.ps1) (`Resolve-AiProvider`):

1. jeśli ustawione są `CRONOVA_AI_BASE_URL` i `CRONOVA_AI_MODEL` — używa ich (plus `CRONOVA_AI_TOKEN`);
2. w przeciwnym razie odczytuje tabelę `ai_providers` z bazy `CRONOVA_DB` (domyślnie `data\cronova.db`): rekord o podanym `id`, a dla `default` lub braku id — rekord z `is_default=1`;
3. brak providera → błąd z instrukcją konfiguracji w UI lub przez zmienne środowiskowe.

Jawny `-m`/`-LoopModel` ma pierwszeństwo przed modelem z providera.

### Workspace, cache i pliki tymczasowe

| Lokalizacja | Zawartość |
|---|---|
| `workspaces/sdlc_maven_luhn/app` | projekt Maven |
| `.m2/repository` (w repozytorium) | lokalny cache Maven |
| `.tmp/` | prompty, żądania i odpowiedzi AI, `compile.log` |

## 6. Ocena reużywalności — model „klocków LEGO”

### Werdykt

**Tak** — DAG składa się z pięciu wywołań ogólnych skryptów `internal/scripts/*.ps1`, a cała specyfika Luhn znajduje się w parametrach (`-g/-r/-k`, ścieżka workspace) i w pliku promptu.

### Macierz klocków

| Klocek | Reużywalność | Granica |
|---|---|---|
| `generate-maven-archetype.ps1` | Wysoka dla archetypów Maven | `-j` nie jest używany |
| `maven-compile.ps1`, `maven-test.ps1` | Wysoka dla projektów Maven | Stały lokalny cache `.m2` |
| `ai-java-mvn-generate-feature.ps1` | Wysoka — prompt z pliku | Reguły systemowe nastawione na Javę/Maven/Spring |
| `java-maven-compile-fix-loop.ps1` | Średnia | Prompt reviewera zaszyty, z regułami Spring Boot |
| `ai-review-java-maven-errors.ps1` | Średnia | Wymaga `review_fix_v2.py` |

### Ograniczenia i ryzyka

1. Wynik AI jest niedeterministyczny; pętla naprawcza ogranicza się do błędów kompilacji, nie do błędów testów.
2. Pliki `.tmp` są współdzielone między DAG-ami korzystającymi z tych samych skryptów.
3. `-C` usuwa poprzedni projekt przy każdym runie.

## 7. Wniosek końcowy

`sdlc_maven_luhn` jest deklaratywną kompozycją reużywalnych skryptów PowerShell. Zmiana funkcji biznesowej wymaga jedynie nowego promptu i parametrów w DAG-u.
