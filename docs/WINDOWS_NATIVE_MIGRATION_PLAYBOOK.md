# Windows-native SDLC migration playbook

## Cel

Przepisywać istniejące działające skrypty `.sh` na natywne skrypty `.ps1` dla Windows, zachowując:

- ten sam DAG i ten sam graf zależności;
- te same identyfikatory tasków;
- te same timeouty i semantykę retry;
- te same parametry wejściowe i wartości domyślne;
- te same artefakty, ścieżki robocze i kody wyjścia;
- modułowość: jeden skrypt `.ps1` odpowiada jednemu skryptowi `.sh`.

Nie tworzyć monolitycznego dispatchera typu `Invoke-Sdlc.ps1` jako zamiennika wielu niezależnych klocków.

## Kolejność następnych DAG-ów

Pierwszy DAG to `sdlc_springboot`. Następne migracje wykonujemy krok po kroku w tej kolejności:

1. `sdlc_maven_luhn`
2. `sdlc_springboot_rest`
3. `sdlc_angular`
4. `sdlc_fullstack`

W repozytorium istnieje również `sdlc_springboot_startio.yaml`. Nie należy mieszać go do bieżącej kolejności bez osobnej decyzji; technicznie jest podobny do `sdlc_springboot` i może być wykonany jako dodatkowy DAG po ustabilizowaniu pierwszej grupy.

### Aktualny stan plików DAG

| Kolejność | DAG | Stan | Charakterystyka |
|---:|---|---|---|
| 0 | `sdlc_springboot` | w trakcie walidacji Windows | 5 modularnych tasków Maven/AI/test |
| 1 | `sdlc_maven_luhn` | Bash | Maven archetype, compile, AI feature, review loop, tests |
| 2 | `sdlc_springboot_rest` | Bash | config, OpenAPI, scaffold, compile, unit tests, package |
| 3 | `sdlc_angular` | Bash | validate, scaffold, install, lint, unit tests, build, smoke |
| 4 | `sdlc_fullstack` | PowerShell, do przebudowy | obecnie używa monolitu `Invoke-Sdlc.ps1`; nie traktować jako wzorca |
| dodatkowy | `sdlc_springboot_startio` | Bash | wariant Spring Initializr, podobny przepływ AI |

## Podsumowanie pracy nad `sdlc_springboot`

### Zachowany DAG

Graf pozostał taki sam:

```text
scaffold
  -> compile_skeleton
  -> ai_add_crud
  -> compile_loop
  -> tests
```

Zachowane zostały identyfikatory tasków, zależności i timeouty. Zmieniono typ tasków z `shell` na `powershell`, a każde wywołanie Bash zastąpiono osobnym plikiem `.ps1`.

### Utworzone moduły

| Bash | PowerShell |
|---|---|
| `internal/scripts/copy-template-to-workspace` | `internal/scripts/copy-template-to-workspace.ps1` |
| `internal/scripts/compile-project` | `internal/scripts/compile-project.ps1` |
| `internal/scripts/ai-generate-crud` | `internal/scripts/ai-generate-crud.ps1` |
| `internal/scripts/ai-review-fix-loop` | `internal/scripts/ai-review-fix-loop.ps1` |
| `internal/scripts/run-tests` | `internal/scripts/run-tests.ps1` |

Wspólna logika została umieszczona w helperach:

- `internal/scripts/common/toolchain.ps1`
- `internal/scripts/common/ai-provider.ps1`

Helpery nie zastępują modułów tasków; wspierają ich wspólne operacje.

### Faktyczny postęp potwierdzony raportem Windows

Raport agenta potwierdził:

```text
scaffold         success
compile_skeleton success
ai_add_crud      success
```

`ai_add_crud` przestał zgłaszać brak providera po poprawie sposobu przechwytywania wyniku procesu Python.

Następny błąd wystąpił w `compile_loop`, w wywołaniu Maven przez potok PowerShell. Ten potok został zastąpiony `Start-Process` z osobnymi plikami stdout/stderr i obsługą kodu wyjścia.

Na podstawie dostępnego raportu nie wolno twierdzić, że cały DAG zakończył się sukcesem, dopóki agent Windows nie prześle wyniku `tests=success`.

## Zasady obowiązkowe dla kolejnych migracji

### 1. Zaczynać od referencji `.sh`

Przed napisaniem `.ps1`:

1. przeczytać cały skrypt `.sh`;
2. przeczytać helpery, których używa;
3. wypisać parametry, wartości domyślne, ścieżki, komendy i kody wyjścia;
4. utworzyć tabelę Bash → PowerShell;
5. dopiero wtedy zmienić DAG.

Nie wolno upraszczać zachowania tylko dlatego, że PowerShell ma inną składnię.

### 2. Jeden skrypt `.sh` = jeden skrypt `.ps1`

Nie scalać kilku tasków w jeden dispatcher. Każdy moduł musi być możliwy do uruchomienia osobno z tym samym kontraktem parametrów.

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
Start-Process -FilePath $program -ArgumentList ... -Wait -PassThru \
  -RedirectStandardOutput $stdoutFile \
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

```bat
cd /d C:\ścieżka\do\repo
 git pull --ff-only origin feature/windows-cmd-runtime-sdlc-2026-09-26
 git status --short
 set CRONOVA_TASK_ENV_ALLOWLIST=
 app.cmd start
```

Agent nie wykonuje `switch`, `reset`, nie wybiera pojedynczego commita, nie poprawia kodu i zatrzymuje test na pierwszym błędzie.

## Procedura dla każdego następnego DAG-a

### Faza A — inwentaryzacja

- odczytać DAG;
- odczytać wszystkie wskazane `.sh`;
- odczytać helpery;
- sporządzić mapę task → skrypt → parametry;
- nie zmieniać jeszcze DAG-a.

### Faza B — implementacja modułów

- napisać osobny `.ps1` dla każdego `.sh`;
- zachować parametry i wartości domyślne;
- użyć wspólnych helperów tylko dla rzeczywiście wspólnych operacji;
- nie tworzyć monolitu;
- nie zmieniać logiki biznesowej.

### Faza C — testy sandboxowe

- parsowanie wszystkich `.ps1`;
- test każdego modułu osobno;
- porównanie argumentów i artefaktów z `.sh`;
- testy błędów i kodów wyjścia;
- testy Go i kompilacja Windows.

### Faza D — zmiana DAG-a

Zmienić wyłącznie:

- `type: shell` → `type: powershell`;
- `bash path/to/script.sh` → odpowiedni `powershell path/to/script.ps1`;
- separatory ścieżek i składnię argumentów.

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
