# Windows-only test — `sdlc_springboot` PowerShell modules

## Cel

Testujemy tylko DAG `sdlc_springboot` po migracji jego pięciu skryptów Bash do pięciu niezależnych skryptów PowerShell.

Nie testować w tej iteracji:

- `sdlc_fullstack`;
- `start-dev`;
- `start.cmd`;
- Git Bash;
- WSL;
- pozostałych DAG-ów.

## Przygotowanie

W klasycznym `cmd.exe`:

```bat
cd /d C:\ścieżka\do\poc-cronova-windows

git pull --ff-only origin feature/windows-cmd-runtime-sdlc-2026-09-26
git status --short
```

Agent pracuje już na właściwej gałęzi. Należy pobrać całą aktualną zawartość tej gałęzi przez `git pull`. Nie wykonywać `switch`, `reset`, nie wskazywać ani nie wybierać pojedynczego commitu. Repozytorium powinno być czyste przed startem testu. Nie tworzyć commitów i nie modyfikować kodu podczas testu.

## Uruchomienie

```bat
app.cmd start
```

Nie ustawiaj `CRONOVA_TASK_ENV_ALLOWLIST`. Na Windows `app.cmd` i Cronova automatycznie przekazują wymagane zmienne toolchainu do tasków.

`app.cmd` powinien zbudować `cronova.exe` z aktualnego working tree, wykryć toolchain Windows i uruchomić usługę z autoryzacją.

Otworzyć:

```text
http://127.0.0.1:8090
```

Zalogować się:

```text
login: admin
hasło: admin123
```

## Test DAG-a

W UI uruchomić ręcznie wyłącznie:

```text
sdlc_springboot
```

Oczekiwana struktura DAG-a:

```text
scaffold
  → compile_skeleton
  → ai_add_crud
  → compile_loop
  → tests
```

Każdy task powinien mieć typ `powershell` i uruchamiać osobny plik `.ps1`:

```text
internal/scripts/copy-template-to-workspace.ps1
internal/scripts/compile-project.ps1
internal/scripts/ai-generate-crud.ps1
internal/scripts/ai-review-fix-loop.ps1
internal/scripts/run-tests.ps1
```

## Raport

```text
BRANCH=feature/windows-cmd-runtime-sdlc-2026-09-26
START_COMMAND=app.cmd start
AUTH_ENABLED=
LOGIN_SCREEN_VISIBLE=
LOGIN_RESULT=
DAG=sdlc_springboot
RESULT=
FAILED_TASK=
ERROR=

SCAFFOLD=
COMPILE_SKELETON=
AI_ADD_CRUD=
COMPILE_LOOP=
TESTS=

TASK_RUNTIME=powershell.exe
GIT_BASH_USED=no
WSL_USED=no
REPO_CHANGES=
COMMITS_MADE=none
```

Jeżeli test się nie powiedzie, zatrzymać się na pierwszym failed tasku i przesłać jego pełny log. Nie naprawiać kodu na Windows i nie przechodzić do następnego DAG-a.
