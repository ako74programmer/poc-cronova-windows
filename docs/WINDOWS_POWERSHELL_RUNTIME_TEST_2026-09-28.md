# Windows-only runtime test — PowerShell

## Cel

Zweryfikować produkcyjną ścieżkę użytkownika:

```text
cmd.exe → app.cmd start → cronova.exe → powershell.exe → sdlc_fullstack
```

Git Bash, WSL, `start-dev` i `start.cmd` nie są częścią tego testu.

## Przygotowanie

W klasycznym `cmd.exe`:

```bat
cd /d C:\ścieżka\do\poc-cronova-windows
git fetch origin
git switch feature/windows-cmd-runtime-sdlc-2026-09-26
git pull --ff-only origin feature/windows-cmd-runtime-sdlc-2026-09-26
git rev-parse HEAD
```

Oczekiwany commit zostanie podany po publikacji tej iteracji.

Nie modyfikować plików repozytorium i nie tworzyć commitów podczas testu.

## Uruchomienie użytkownika

Nie używać `start-dev` ani `start.cmd`.

```bat
set CRONOVA_TASK_ENV_ALLOWLIST=
app.cmd start
```

Oczekiwane zachowanie:

- `app.cmd` wykrywa Python, Node, npm, Java i Maven;
- Cronova uruchamia się na `http://127.0.0.1:8090`;
- produkcyjny start wymaga logowania;
- taski typu `powershell` są uruchamiane przez `powershell.exe -NoProfile -NonInteractive`;
- nie jest wymagany Git Bash, WSL, `cygpath` ani `/usr/bin`.

## Logowanie i DAG

Otworzyć:

```text
http://127.0.0.1:8090
```

Zalogować się:

```text
login: admin
hasło: admin123
```

W konsoli uruchomić ręcznie DAG:

```text
sdlc_fullstack
```

Oczekiwany wynik: `success`.

## Raport

```text
BRANCH=feature/windows-cmd-runtime-sdlc-2026-09-26
COMMIT=

START_COMMAND=app.cmd start
AUTH_ENABLED=
LOGIN_SCREEN_VISIBLE=
LOGIN_RESULT=

POWERSHELL_EXE=
POWERSHELL_VERSION=
CRONOVA_PYTHON=
CRONOVA_NODE=
CRONOVA_NPM=
CRONOVA_JAVA_HOME=
CRONOVA_MAVEN_HOME=

DAG=sdlc_fullstack
RESULT=
FAILED_TASK=
ERROR=

TASK_TYPE=powershell
GIT_BASH_USED=no
WSL_USED=no
REPO_CHANGES=none
COMMITS_MADE=none
```

Jeśli test zakończy się błędem, zatrzymać się na pierwszym nieudanym tasku i dołączyć pełny log tego taska. Nie wracać do testowania Git Bash ani nie zmieniać kodu na maszynie Windows.
