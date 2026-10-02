# Windows-only runtime test — `sdlc_springboot_startio` (PowerShell-native)

## Cel i zakres

Zweryfikować produkcyjną ścieżkę użytkownika na natywnym Windows:

```text
cmd.exe / PowerShell -> app.cmd start -> Cronova auth -> powershell.exe -> sdlc_springboot_startio
```

DAG został przełączony z Bash na pięć osobnych modułów `.ps1`. Zachowano task IDs, kolejność, zależności, timeouty i wartości/znaczenie argumentów. Agent Windows jest wyłącznie wykonawcą testu: **nie diagnozuje przyczyn, nie interpretuje błędów, nie zmienia skryptów/DAG-a ani nie tworzy commitów**. Zatrzymuje się przy pierwszym błędzie taska i przekazuje raport oraz pełny log tego taska.

To jest jedyny test, który może potwierdzić rzeczywiste działanie na Windows. Parser/testy sandboxowe tego nie dowodzą.

## Oczekiwana gałąź

```text
feature/windows-cmd-runtime-sdlc-2026-09-26
```

W repozytorium:

```bat
git pull --ff-only origin feature/windows-cmd-runtime-sdlc-2026-09-26
git status --short --branch
git log -1 --oneline
```

Zapisz `git rev-parse HEAD` w raporcie. Oczekiwany jest commit zawierający migrację Windows-native. Jeśli źródła mają niezatwierdzone zmiany, nie nadpisuj ich — zakończ przygotowanie i zgłoś stan.

## Przygotowanie runtime

Przed uruchomieniem `app.cmd start` sprawdź wszystkie procesy `cronova.exe` i zanotuj PID, ścieżkę programu oraz command line. **`app.cmd start` przebudowuje aplikację i sam zatrzymuje procesy komendą `taskkill /F /IM cronova.exe`; nie ogranicza tego do bieżącego checkoutu.** Uruchamiaj go tylko wtedy, gdy nie działa żaden Cronova albo każdy proces o tej nazwie jest znaną instancją testową, którą wolno zatrzymać. Jeśli widzisz obcy lub nierozpoznany proces, nie uruchamiaj `app.cmd start` — zatrzymaj przygotowanie i zgłoś PID/ścieżkę/command line.

Uruchom `app.cmd start` z katalogu repozytorium w lokalnym Windows terminalu. Następnie otwórz `http://127.0.0.1:8090` i zaloguj się istniejącym kontem (`admin` / `admin123`). Nie zmieniaj uwierzytelniania, konfiguracji providera AI ani allowlist środowiska na potrzeby testu.

## Ważne: workspace jest czyszczony

Task `scaffold` przekazuje `-Clean`, co usuwa `workspaces/springboot-startio/app` przed rozpakowaniem nowego projektu. Przed uruchomieniem sprawdź, czy workspace nie zawiera potrzebnych danych. Nie kasuj niczego ręcznie. Jeśli są tam pliki, których nie można odtworzyć, zatrzymaj test i zgłoś to.

## Uruchomienie

W UI wybierz DAG `sdlc_springboot_startio` i uruchom **jeden** ręczny run. Oczekiwana kolejność:

```text
scaffold
-> compile_skeleton
-> ai_add_crud
-> compile_loop
-> tests
```

Nie uruchamiaj kolejnych runów równolegle. Zatrzymaj obserwację na pierwszym błędzie; nie próbuj naprawiać go po stronie Windows.

## Raport

Prześlij status każdego taska, run ID i commit. Przy błędzie dołącz pełny log pierwszego failed taska. Nie przesyłaj tokenów ani haseł; zamaskuj prywatny fragment ścieżki użytkownika, jeśli chcesz.

```text
DAG=sdlc_springboot_startio
BRANCH=
COMMIT=
RUN_ID=
SCAFFOLD=
COMPILE_SKELETON=
AI_ADD_CRUD=
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

Dołącz pełne logi wszystkich tasków, jeśli run zakończył się sukcesem; przy awarii wymagany jest pełny log pierwszego failed taska.

## Kryterium sukcesu

Runtime test jest sukcesem dopiero, gdy run i wszystkie pięć tasków mają status `success`:

```text
SCAFFOLD=success
COMPILE_SKELETON=success
AI_ADD_CRUD=success
COMPILE_LOOP=success
TESTS=success
```

Do czasu otrzymania takiego raportu DAG pozostaje **niezweryfikowany na Windows**.
