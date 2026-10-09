# Windows-native SDLC migration playbook

## Cel i status

Migracja SDLC do natywnego PowerShell jest **zakończona**: w repozytorium nie ma już skryptów Bash, a wszystkie DAG-i w `dags/` używają wyłącznie `type: powershell` i wywołują skrypty `.ps1`. Playbook dokumentuje przyjęte zasady i obowiązuje przy dodawaniu lub zmianie kolejnych klocków.

Zasady projektowe:

- jeden task DAG-a = jedno wywołanie modułowego skryptu `.ps1` w `internal/scripts/`;
- stabilne identyfikatory tasków, graf zależności, timeouty i semantyka retry;
- jawne parametry wejściowe i wartości domyślne;
- przewidywalne artefakty, ścieżki robocze i kody wyjścia.

Nie tworzyć monolitycznego dispatchera jako zamiennika niezależnych klocków. [`scripts/sdlc/Invoke-Sdlc.ps1`](../scripts/sdlc/Invoke-Sdlc.ps1) pozostaje w repozytorium, ale żaden DAG z `dags/` go nie wywołuje.

## Aktualny stan DAG-ów

| DAG | Skrypty | Charakterystyka |
|---|---|---|
| `sdlc_springboot_template_crud` | `copy-template-to-workspace.ps1`, `maven-compile.ps1`, `ai-java-mvn-generate-feature.ps1`, `java-maven-compile-fix-loop.ps1`, `maven-test.ps1` | Template, compile, AI CRUD, review loop, tests |
| `sdlc_springboot_startio` | `fetch-springboot-project.ps1` + jak wyżej | Wariant Spring Initializr |
| `sdlc_maven_luhn` | `generate-maven-archetype.ps1` + jak wyżej | Maven archetype, compile, AI feature, review loop, tests |
| `sdlc_springboot_rest` | `springboot-validate-config.ps1`, `springboot-validate-openapi.ps1`, `springboot-*-from-config.ps1` | Config, OpenAPI, scaffold, compile, unit tests, package |
| `sdlc_springboot_variant` | `resolve-springboot-variant-config.ps1` + skrypty `sdlc_springboot_rest` | Wariant wybierany przez `CRONOVA_PARAM_VARIANT` |
| `sdlc_angular` | `angular-*.ps1` | Validate, scaffold, install, lint, unit tests, build, smoke |
| `sdlc_fullstack` | `fullstack-*.ps1` | Validate, Playwright install, stack E2E, logs, manifest |

Wspólna logika znajduje się w helperach:

- [`internal/scripts/common/toolchain.ps1`](../internal/scripts/common/toolchain.ps1)
- [`internal/scripts/common/ai-provider.ps1`](../internal/scripts/common/ai-provider.ps1)
- [`scripts/sdlc/common/AngularConfig.ps1`](../scripts/sdlc/common/AngularConfig.ps1), [`SpringbootConfig.ps1`](../scripts/sdlc/common/SpringbootConfig.ps1), [`FullstackConfig.ps1`](../scripts/sdlc/common/FullstackConfig.ps1)

Helpery nie zastępują modułów tasków; wspierają ich wspólne operacje.

## Zasady obowiązkowe

### 1. Zaczynać od inwentaryzacji istniejącego kontraktu

Przed zmianą lub dodaniem `.ps1`:

1. przeczytać cały istniejący skrypt i DAG, który go wywołuje;
2. przeczytać helpery, których używa;
3. wypisać parametry, wartości domyślne, ścieżki, komendy i kody wyjścia;
4. dopiero wtedy zmienić DAG.

Nie wolno upraszczać zachowania bez osobnej decyzji.

### 2. Jeden task = jeden skrypt `.ps1`

Nie scalać kilku tasków w jeden dispatcher. Każdy moduł musi być możliwy do uruchomienia osobno z tym samym kontraktem parametrów. Dozwolone są skrypty kompozycyjne, które jedynie wywołują istniejące moduły (np. `fullstack-run-stack-e2e.ps1`).
### 3. Nie używać potoków PowerShell do natywnych programów Windows

Dla `java.exe`, `mvn.cmd`, `python.exe` i podobnych programów nie stosować wzorców typu:

```powershell
& $program ... 2>&1 | Tee-Object ...
```

W tym środowisku powodowało to błędy:

```text
Cannot run a document in the middle of a pipeline
```

Stosować:

```powershell
Start-Process -FilePath $program -ArgumentList ... -Wait -PassThru `
  -RedirectStandardOutput $stdoutFile `
  -RedirectStandardError $stderrFile
```

Następnie połączyć stdout/stderr do logu i użyć jawnego `ExitCode`.

### 4. Nie zakładać, że `$LASTEXITCODE` istnieje

Przy `Set-StrictMode` odwołanie do niezainicjalizowanej zmiennej może zakończyć task błędem. Preferować `Start-Process` i `$process.ExitCode`. Jeśli konieczne jest `$LASTEXITCODE`, najpierw bezpiecznie sprawdzić jego istnienie.

### 5. Nie ukrywać błędów diagnostycznych

Nie stosować bez uzasadnienia:

```powershell
2>$null
```

Jeżeli lookup providera, Python albo SQLite zawiedzie, log musi pokazać program, bazę, argumenty niebędące sekretami i kod wyjścia. Tokeny i hasła muszą pozostać ukryte.

### 6. Ścieżki ustalać stabilnie

Root repozytorium wyznaczać raz, przy ładowaniu helpera, a nie polegać na niejednoznacznym `$PSScriptRoot` wewnątrz funkcji po dot-source. Ścieżki względne muszą być rozwiązywane względem repozytorium, nie przypadkowego katalogu roboczego procesu.

### 7. Środowisko toolchainu zachować jawnie

Sprawdzać zgodność:

- `CRONOVA_PYTHON`;
- `CRONOVA_JAVA_HOME`;
- `CRONOVA_MAVEN_HOME`;
- `CRONOVA_WINDOWS_PATH`;
- `CRONOVA_DB`;
- `PATH`.

Nie zakładać, że zmienna obecna w terminalu jest obecna w tasku. Weryfikować `buildEnv()` i raportować faktyczne wartości bez sekretów.

### 8. Provider AI sprawdzać na trzech poziomach

1. ręczny probe Python + SQLite;
2. bezpośrednie wywołanie funkcji PowerShell;
3. task uruchomiony przez Cronova.

Dopiero różnica między tymi poziomami wskazuje miejsce problemu. Nie zakładać, że brak providera w komunikacie oznacza brak konfiguracji.

### 9. Testować w sandboxie przed agentem Windows

Każda zmiana musi przejść w sandboxie:

- parser PowerShell (`[scriptblock]::Create(...)`);
- test helperów na danych testowych;
- test modułów z atrapami Maven/Java/Python/AI;
- `git diff --check`;
- testy Go dotkniętych pakietów;
- kompilację `GOOS=windows GOARCH=amd64`.

Sandboxowy test nie zastępuje Windows. Wynik należy opisywać precyzyjnie: co sprawdzono, a czego sandbox nie potwierdza.

### 10. Agent Windows testuje tylko aktualną gałąź

Instrukcja dla agenta:

```powershell
Set-Location C:\ścieżka\do\repo
git pull --ff-only origin feature/windows-cmd-runtime-sdlc-2026-09-26
git status --short
.\scripts\windows\app.ps1 start
```

Na Windows nie ustawiaj `CRONOVA_TASK_ENV_ALLOWLIST`. [app.ps1](../scripts/windows/app.ps1) wykrywa toolchain, a `buildEnv()` automatycznie przekazuje bezpieczne zmienne Java/Maven/Python/PATH do tasków.

Agent nie wykonuje `switch`, `reset`, nie wybiera pojedynczego commita, nie poprawia kodu i zatrzymuje test na pierwszym błędzie.

Agent Windows jest tylko wykonawcą testu. Nie prowadzi diagnozy i nie szuka przyczyny po stronie kodu. Ma uruchomić wskazany DAG, zebrać statusy oraz pełny log pierwszego failed taska i przekazać raport. Diagnoza, implementacja poprawki i testy sandboxowe należą do procesu repozytorium.

## Procedura dla nowego lub zmienianego DAG-a

### Faza A — inwentaryzacja

- odczytać DAG;
- odczytać wszystkie wywoływane `.ps1`;
- odczytać helpery;
- sporządzić mapę task → skrypt → parametry.

### Faza B — implementacja modułów

- napisać osobny `.ps1` dla każdej operacji;
- jawnie zdefiniować parametry i wartości domyślne;
- użyć wspólnych helperów tylko dla rzeczywiście wspólnych operacji;
- nie tworzyć monolitu.

### Faza C — testy sandboxowe

- parsowanie wszystkich `.ps1`;
- test każdego modułu osobno;
- testy błędów i kodów wyjścia;
- testy Go i kompilacja Windows.

### Faza D — zmiana DAG-a

- `type: powershell`;
- `command` wywołuje skrypt operatorem `&`, np. `& .\internal\scripts\maven-compile.ps1 -w workspaces/springboot -p app`;
- ścieżki względne wobec repozytorium.

Nie zmieniać grafu, nazw tasków, timeoutów ani zależności bez osobnej decyzji.
### Faza E — test Windows

Agent wykonuje DAG od początku. Raport musi zawierać:

```text
DAG=
SCAFFOLD=
COMPILE=
AI=
LOOP=
TESTS=
FAILED_TASK=
ERROR=
TASK_RUNTIME=
GIT_BASH_USED=
WSL_USED=
REPO_CHANGES=
```

## Zasada komunikacji i wiarygodności

Obowiązuje bez wyjątków:

> Opieramy się wyłącznie na sprawdzonych danych z kodu, testów sandboxowych i raportów agenta Windows. Nie zmyślamy przyczyn, wyników ani stopnia ukończenia. Jeżeli brakuje danych, prosimy agenta Windows o konkretny raport diagnostyczny zamiast zgadywać.

W szczególności:

- nie twierdzić, że DAG przeszedł, jeśli nie ma raportu wszystkich tasków;
- nie twierdzić, że poprawka działa na Windows tylko dlatego, że działa w sandboxie;
- nie twierdzić, że provider jest niedostępny bez sprawdzenia bazy i środowiska taska;
- nie wysyłać kolejnej poprawki do testu bez lokalnego testu kontraktowego;
- każdą hipotezę oznaczać jako hipotezę i potwierdzać ją osobnym testem.
