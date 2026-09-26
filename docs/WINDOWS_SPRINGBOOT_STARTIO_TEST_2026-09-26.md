# Test Windows — DAG `sdlc_springboot_startio`

## Cel

Zweryfikować na natywnym Windows, że:

1. poprawka wspólnego resolvera Pythona działa w Git Bash;
2. `CRONOVA_PYTHON` przekazane z `start.cmd` trafia do tasków Cronova i jest użyte przez `scaffold` mimo generycznego `python`/`-y`;
3. projekt zostaje pobrany ze Spring Initializr, kompiluje się, przechodzi pętlę review/fix i testy;
4. Windows Go build/test i runtime Cronova na tym branchu działają.

To jest **test weryfikacyjny**. Nie poprawiaj kodu, DAG-ów, skryptów ani konfiguracji repo podczas testu; nie twórz commitów. Gdy którykolwiek krok nie przejdzie, zatrzymaj się i przekaż raport oraz logi.

## Oczekiwany branch

```text
feature/windows-cmd-runtime-sdlc-2026-09-26
```

Po checkout zapisz commit (`git rev-parse HEAD`) do raportu. Test dotyczy commita, który zawiera ten plik instrukcji oraz poprawkę Pythona. Nie testuj starszego commita.

## 1. Aktualizacja kodu

W klasycznym `cmd.exe`:

```bat
git status --short
git fetch origin
git switch feature/windows-cmd-runtime-sdlc-2026-09-26
git pull --ff-only origin feature/windows-cmd-runtime-sdlc-2026-09-26
git rev-parse HEAD
git status --short --branch
```

Jeśli przed aktualizacją albo po niej są **niezacommitowane zmiany w źródłach**, zatrzymaj się i przekaż ich listę — nie stashuj, nie resetuj i nie nadpisuj ich.

Przed buildem sprawdź w PowerShell, czy działa już `cronova.exe` z tego repo. Jeśli tak, potwierdź PID, ścieżkę i command line, a następnie zamknij wyłącznie tę instancję w jej oknie startowym. Nie zabijaj procesów po samej nazwie i nie zatrzymuj niepowiązanej usługi.

## 2. Weryfikacja Go na Windows

Z katalogu głównego repo uruchom polecenia zgodne z Windows jobem CI:

```bat
go version
gofmt -l .
go mod verify
go vet ./...
go test ./...
set CGO_ENABLED=0
go build -trimpath -o cronova.exe ./cmd/cronova
go build -trimpath -o cronova-executor.exe ./cmd/cronova-executor
```

`gofmt -l .` powinno nie wypisać plików. Zapisz exit code każdego polecenia. Jeśli Go test/build nie przejdzie, przerwij — nie przechodź do pełnego DAG-a i nie zmieniaj kodu.

## 3. Sprawdzenie środowiska Windows

Użyj JDK/Maven/Pythona z prawdziwymi plikami wykonywalnymi. Przyjmij ścieżki swojej maszyny; **nie kopiuj literalnie placeholderów**. Przykład w `cmd.exe`:

```bat
set "JAVA_HOME=C:\ścieżka\do\jdk-25"
set "MAVEN_HOME=C:\ścieżka\do\apache-maven"
set "CRONOVA_JAVA_HOME=%JAVA_HOME%"
set "CRONOVA_MAVEN_HOME=%MAVEN_HOME%"
set "CRONOVA_BASH_PATH=C:\Program Files\Git\bin\bash.exe"
set "CRONOVA_PYTHON=C:\ścieżka\do\python.exe"
set "PATH=%JAVA_HOME%\bin;%MAVEN_HOME%\bin;%PATH%"

where java
where mvn
where python
where bash
java -version
mvn -version
python --version
```

`CRONOVA_PYTHON` musi wskazywać na rzeczywisty `python.exe`, nie alias z `WindowsApps`. `start.cmd` wykrywa tę zmienną lub próbuje znaleźć Python przez `where`; jawna ścieżka eliminuje niejednoznaczność. Upewnij się, że `mvn -version` pokazuje oczekiwany JDK.

**Nie ustawiaj `CRONOVA_TASK_ENV_ALLOWLIST`.** Windows runner ma przekazywać `CRONOVA_PYTHON` oraz bezpieczne zmienne toolchain bez ręcznej allowlisty.

## 4. Uruchomienie serwera

Przed uruchomieniem sprawdź, czy nie działa już inny Cronova. Jeżeli działa, potwierdź PID/ścieżkę i zatrzymaj tylko właściwy proces — nie zabijaj procesów po samej nazwie. Nie usuwaj bazy danych, lease’ów ani logów.

`start.cmd` kompiluje się wcześniej; teraz uruchom je w **tym samym oknie `cmd.exe`** z ustawionymi zmiennymi:

```bat
start.cmd
```

Oczekiwane są m.in. linie z `CRONOVA_BASH_PATH` i `CRONOVA_PYTHON`. Serwer konsoli powinien nasłuchiwać na `http://127.0.0.1:8090`.

W drugim oknie `cmd.exe`, z katalogu repo, sprawdź procesy i DAG:

```bat
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'cronova|cmd|bash' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine | Format-List"
cronova dags
```

Potwierdź, że widoczny jest `sdlc_springboot_startio` i nie działa drugi niezamierzony scheduler.

## 5. Ostrzeżenie o workspace i uruchomienie DAG-a

`scaffold` ma opcję `-C`, która **usuwa docelowy katalog** `workspaces/springboot-startio/app` przed ponownym rozpakowaniem. Najpierw sprawdź ten katalog. Jeśli istnieją w nim potrzebne pliki lub lokalne zmiany, zatrzymaj się i zgłoś to; nie kasuj ich. Jeśli to wyłącznie wynik wcześniejszego testu i można go odtworzyć, zachowaj kopię przed triggerem.

DAG ma harmonogram `02:00 UTC`, ale możesz uruchomić jeden przebieg ręcznie:

```bat
cronova trigger sdlc_springboot_startio
```

Zapisz zwrócony `run_id`. Monitoruj go do terminalnego stanu:

```bat
cronova runs sdlc_springboot_startio -n 3
```

Odświeżaj `cronova runs` aż run osiągnie stan `success` lub `failed`. Szczegóły i logi tasków otwórz w lokalnej konsoli `http://127.0.0.1:8090`, logując się istniejącym kontem — nie zmieniaj konfiguracji uwierzytelniania ani nie konfiguruj tokena/`CRONOVA_SERVER` tylko na potrzeby tego testu. Wykonuj trigger poza godziną 02:00 UTC, aby nie nakładał się na uruchomienie harmonogramowe.

Oczekiwana kolejność tasków:

```text
scaffold -> compile_skeleton -> ai_add_crud -> compile_loop -> tests
```

Nie uruchamiaj dodatkowych przebiegów równolegle. Łączne timeouty poszczególnych tasków mogą wynieść do 40 minut. `ai_add_crud` wywołuje skonfigurowany provider AI; `compile_loop` może wykonać dodatkowe wywołania AI, jeśli kompilacja się nie powiedzie — użycie zależy od rozliczeń Twojego providera.

## 6. Kryteria sukcesu i logi

Sukces pełnego przebiegu wymaga stanu `success` dla całego runu i wszystkich pięciu tasków. Dodatkowo:

- log `scaffold` pokazuje `Using Python: ...` i kończy się pobraniem/rozpakowaniem Spring Boot. Ścieżka w logu może być znormalizowana do formatu Git Bash (`/c/...`); potwierdź, że wskazuje ten sam plik wykonywalny co `CRONOVA_PYTHON`;
- istnieje `workspaces/springboot-startio/app/pom.xml`;
- wygenerowane klasy CRUD istnieją w `src/main/java/com/example/demo/model/Item.java` oraz `.../api/ItemController.java`;
- `compile_skeleton` i `compile_loop` kończą się sukcesem;
- `tests` kończy się sukcesem.

Zanotuj wynik runu i stan każdego taska; pobierz lub skopiuj logi wszystkich pięciu tasków z konsoli. W szczególności dla `scaffold` raportuj, czy użył dokładnie wartości `CRONOVA_PYTHON` z konfiguracji startowej. Nie wklejaj tokenów AI ani haseł; jeśli ścieżka lokalna zawiera prywatną nazwę użytkownika, możesz ją zamaskować.

## 7. Szablon raportu

```text
BRANCH=
COMMIT=
GO_VERSION=

GO_CHECKS:
gofmt=
go_mod_verify=
go_vet=
go_test=
build_cronova=
build_executor=

PROCESS:
cronova_pid=
parent_pid=
command_line=
multiple_cronova_processes=

TOOLS:
java_path=
java_version=
mvn_path=
mvn_version=
python_path=
python_version=
bash_path=
CRONOVA_PYTHON_in_start_cmd=<masked if needed>
CRONOVA_TASK_ENV_ALLOWLIST=<unset or value>

DAG:
dag_visible=
run_id=
run_state=
scaffold_state=
scaffold_using_python=
compile_skeleton_state=
ai_add_crud_state=
compile_loop_state=
tests_state=
project_pom_exists=
item_java_exists=
item_controller_java_exists=

LOGS:
<attach/export full logs for every task; redact tokens/passwords only>

REPO_CHANGES=none
COMMITS_MADE=none
```

Przy pierwszym błędzie przerwij dalsze testowanie, nie poprawiaj niczego na Windowsie i dołącz log taska oraz powyższy raport z wynikami osiągniętymi do miejsca błędu.
