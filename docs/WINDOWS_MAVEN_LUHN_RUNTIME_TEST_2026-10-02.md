# Windows-only runtime test — `sdlc_maven_luhn`

## Cel

Zweryfikować produkcyjną ścieżkę użytkownika na Windows:

```text
cmd.exe -> app.cmd start -> Cronova auth -> sdlc_maven_luhn
```

DAG został przepisany z Bash na osobne moduły PowerShell. Graf DAG, task IDs, zależności i timeouty mają pozostać takie same.

## Przygotowanie

Na istniejącej gałęzi repozytorium wykonaj:

```bat
cd /d C:\ścieżka\do\poc-cronova-windows
git pull --ff-only origin feature/windows-cmd-runtime-sdlc-2026-09-26
git status --short
app.cmd start
```

Nie ustawiaj `CRONOVA_TASK_ENV_ALLOWLIST`. Na Windows `app.cmd` i Cronova automatycznie przekazują wymagane zmienne toolchainu do tasków.

Nie wykonuj `switch`, `reset` ani wyboru pojedynczego commitu. Nie modyfikuj kodu na Windows.

Jeżeli poprzednia instancja działa:

```bat
taskkill /F /IM cronova.exe
```

## Test DAG-a

1. Otwórz `http://127.0.0.1:8090`.
2. Zaloguj się jako:
   - użytkownik: `admin`
   - hasło: `admin123`
3. Otwórz DAG `sdlc_maven_luhn`.
4. Uruchom ręcznie jeden run.
5. Poczekaj na zakończenie lub zatrzymaj analizę na pierwszym błędzie.

Oczekiwana kolejność:

```text
scaffold
-> compile_skeleton
-> ai_add_feature
-> compile_loop
-> tests
```

## Raport

Prześlij:

```text
DAG=sdlc_maven_luhn
SCAFFOLD=
COMPILE_SKELETON=
AI_ADD_FEATURE=
COMPILE_LOOP=
TESTS=
FAILED_TASK=
ERROR=
TASK_RUNTIME=
GIT_BASH_USED=
WSL_USED=
REPO_CHANGES=
COMMITS_MADE=
```

Przy błędzie prześlij pełny log pierwszego failed taska. Nie przesyłaj tokenów ani haseł.

## Kryterium sukcesu

Test jest sukcesem dopiero, gdy wszystkie pięć tasków ma status `success`, w szczególności:

```text
SCAFFOLD=success
COMPILE_SKELETON=success
AI_ADD_FEATURE=success
COMPILE_LOOP=success
TESTS=success
```
