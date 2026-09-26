# Test Windows runtime — `cmd.exe` → Cronova → Git Bash

Gałąź testowa:

```text
feature/windows-cmd-runtime-sdlc-2026-09-26
```

## Cel

Potwierdzić, że Cronova uruchomiony przez `start.cmd`:

1. działa jako proces potomny `cmd.exe`;
2. używa jawnie wskazanego Git Bash przez `CRONOVA_BASH_PATH`;
3. przekazuje do tasków Java, Maven, Python i Node bez ustawiania ręcznej allowlisty;
4. nie wybiera WSL ani przypadkowego `bash.exe` z `PATH`.

Executor Windows używa wskazanego Git Bash bez trybu login (`bash -c`, nie `bash -lc`).
Dzięki temu pliki startowe Git Bash nie zastępują `PATH` minimalną ścieżką MSYS.
`start.cmd` zachowuje również oryginalny Windows `PATH` w `CRONOVA_WINDOWS_PATH`,
żeby wrapper Maven mógł znaleźć `powershell.exe` i inne systemowe narzędzia.

## Przygotowanie

W repozytorium wykonaj:

```bat
git fetch origin
git switch feature/windows-cmd-runtime-sdlc-2026-09-26
git pull --ff-only origin feature/windows-cmd-runtime-sdlc-2026-09-26
```

Zamknij poprzedni Cronova tylko po potwierdzeniu właściwego PID. Nie usuwaj ręcznie bazy ani lease’u.

## Uruchomienie

Uruchom z klasycznego `cmd.exe`, nie z terminala WSL:

```bat
cd /d C:\ścieżka\do\poc-cronova-windows
set "JAVA_HOME=C:\ścieżka\do\jdk-25"
set "MAVEN_HOME=C:\ścieżka\do\apache-maven"
set "CRONOVA_JAVA_HOME=%JAVA_HOME%"
set "CRONOVA_MAVEN_HOME=%MAVEN_HOME%"
set "CRONOVA_BASH_PATH=C:\Program Files\Git\bin\bash.exe"
set "CRONOVA_PYTHON=C:\ścieżka\do\python.exe"
set "CRONOVA_NODE=C:\ścieżka\do\node.exe"
set "CRONOVA_NPM=C:\ścieżka\do\npm.cmd"
set "PATH=%JAVA_HOME%\bin;%MAVEN_HOME%\bin;%PATH%"
start.cmd
```

Jeżeli Git jest zainstalowany w innym miejscu, ustaw prawdziwą ścieżkę do `bash.exe`. Nie zmieniaj kodu repozytorium tylko dlatego, że lokalna instalacja ma inną ścieżkę.

`start.cmd` powinien wypisać:

```text
[start.cmd] JAVA_HOME=...
[start.cmd] MAVEN_HOME=...
[start.cmd] CRONOVA_BASH_PATH=...
```

## Weryfikacja procesu

W drugim oknie `cmd.exe`:

```bat
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'cronova|cmd|bash' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine | Format-List"
```

Przekaż:

- PID Cronova;
- ParentProcessId;
- command line;
- potwierdzenie, że Cronova został uruchomiony przez `start.cmd`;
- informację, czy działa więcej niż jeden Cronova.

## Weryfikacja narzędzi w terminalu startowym

```bat
where java
where mvn
where python
where node
where bash
java -version
mvn -version
python --version
node --version
```

## Test pipeline’u

Uruchom `sdlc_springboot_rest` w kolejności:

```text
validate_config
validate_openapi
scaffold
compile
unit_tests
package
```

Nie ustawiaj:

```text
CRONOVA_TASK_ENV_ALLOWLIST
```

W tej gałęzi Windows runner przekazuje bezpośrednio bezpieczne zmienne runtime:

```text
JAVA_HOME
MAVEN_HOME
PYTHONHOME
PYTHONPATH
NODE_PATH
NVM_HOME
CRONOVA_JAVA_HOME
CRONOVA_MAVEN_HOME
CRONOVA_BASH_PATH
MSYS2_PATH_TYPE
```

`PATH` jest również przekazywany. Sekrety, w tym `CRONOVA_ADMIN_PASSWORD`, nadal nie mogą być przekazane automatycznie.

`start.cmd` wykrywa Python/Node/npm przez `where`, ale na maszynach z aliasem
WindowsApps należy ustawić `CRONOVA_PYTHON`, `CRONOVA_NODE` i `CRONOVA_NPM`
na rzeczywiste pliki wykonywalne.

## Raport

Przekaż dokładnie:

```text
BRANCH=
COMMIT=

PROCESS:
cronova_pid=
parent_pid=
command_line=
multiple_cronova_processes=
lease_conflict=

TOOLS:
java=
java_version=
mvn=
mvn_version=
python=
python_version=
node=
node_version=
bash=

CRONOVA_TASK_ENV_ALLOWLIST=<unset or value>
TASK_CRONOVA_WINDOWS_PATH=
TASK_RUNTIME_PATH=
TASK_JAVA_HOME=
TASK_MAVEN_HOME=
TASK_CRONOVA_JAVA_HOME=
TASK_CRONOVA_MAVEN_HOME=
TASK_CRONOVA_BASH_PATH=
TASK_COMMAND_V_JAVA=
TASK_COMMAND_V_MVN=
TASK_COMMAND_V_PYTHON=
TASK_COMMAND_V_NODE=

PIPELINE:
validate_config=
validate_openapi=
scaffold=
compile=
unit_tests=
package=
jar=

REPO_CHANGES=none
COMMITS_MADE=none
```

Nie zmieniaj `runner_windows.go`, `runner.go`, `start.cmd` ani DAG-ów podczas testu. Jeśli test nie przejdzie, zatrzymaj się i przekaż log oraz powyższy raport.
