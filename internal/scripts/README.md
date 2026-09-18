# Reużywalne skrypty build/SDLC

Katalog `internal/scripts/` zawiera narzędzia CLI używane przez przepływy Cronova.
Każdy skrypt jest niezależny i można go wywołać ręcznie lub z innego workflow.

## Wymagania

- Git Bash lub inne środowisko bash (np. WSL, MSYS2)
- Java JDK (skrypty ustawiają `JAVA_HOME=/c/Program Files/Java/jdk-25`)
- Apache Maven 3.9.14 w `/c/apache-maven-3.9.14`
- Python 3.13 (dla skryptów AI, domyślnie `/c/Users/Andrzej/AppData/Local/Programs/Python/Python313/python`)

## Konwencja parametrów

| Parametr | Znaczenie | Domyślna wartość |
|---|---|---|
| `-w WORKSPACE` | Katalog workspace (bezwzględny lub względem repo) | `workspaces/springboot-demo` |
| `-p PROJECT` | Podkatalog projektu wewnątrz workspace | `demo` |
| `-h` | Pomoc | — |

## Skrypty

### `fetch-springboot-project`

Pobiera szkielet Spring Boot z `https://start.spring.io/` i rozpakowuje go do wybranego workspace'u.

```bash
# Domyślnie: Maven, Java, Spring Boot wybrany przez start.spring.io, workspaces/springboot-demo/demo
internal/scripts/fetch-springboot-project

# Wybierz konkretną wersję Spring Boot i zależności
internal/scripts/fetch-springboot-project -b 4.0.8 -d web,lombok

# Projekt Gradle + Kotlin
internal/scripts/fetch-springboot-project -t gradle-project-kotlin -l kotlin -b 4.0.8 -d web

# Własna grupa/artifact i inny workspace
internal/scripts/fetch-springboot-project \
  -b 4.0.8 \
  -g com.acme \
  -a store \
  -n com.acme.store \
  -d web,data-jpa \
  -w workspaces/my-app \
  -P app \
  -C
```

Parametry:
- `-t TYPE` — `maven-project`, `gradle-project`, `gradle-project-kotlin` (domyślnie `maven-project`)
- `-l LANG` — `java`, `kotlin`, `groovy` (domyślnie `java`)
- `-b BOOT` — wersja Spring Boot, np. `4.0.8`
- `-g GROUP` — groupId (domyślnie `com.example`)
- `-a ARTIFACT` — artifactId (domyślnie `demo`)
- `-n NAME` — nazwa pakietu (domyślnie `GROUP.ARTIFACT`)
- `-p PACKAGING` — `jar` lub `war` (domyślnie `jar`)
- `-c CONFIG` — `properties` lub `yaml` (domyślnie `properties`)
- `-j JAVA` — wersja Javy: `27`, `25`, `21`, `17` (domyślnie `21`)
- `-d DEPS` — zależności rozdzielone przecinkami, np. `web,lombok`
- `-w WORKSPACE` — workspace docelowy
- `-P PROJECT` — podkatalog projektu w workspace
- `-C` — wyczyść docelowy katalog przed rozpakowaniem
- `-h` — pomoc

---

### `copy-template-to-workspace`

Kopiuje template z `templates/` do wybranego workspace'u.

```bash
# Użycie podstawowe — kopiuje templates/springboot-simple do workspaces/springboot-demo/demo
internal/scripts/copy-template-to-workspace -t springboot-simple

# Wyczyść docelowy katalog przed kopiowaniem
internal/scripts/copy-template-to-workspace -t springboot-simple -c

# Inny workspace i projekt
internal/scripts/copy-template-to-workspace -t springboot-simple -w workspaces/my-app -p app
```

Parametry:
- `-t TEMPLATE` — nazwa katalogu w `templates/` (wymagane)
- `-w WORKSPACE` — docelowy workspace
- `-p PROJECT` — podkatalog projektu
- `-c` — wyczyść docelowy katalog przed kopiowaniem
- `-h` — pomoc

---

### `compile-project`

Kompiluje projekt Maven w wybranym workspace.

```bash
# Domyślnie: workspaces/springboot-demo/demo, cel compile, bez testów
internal/scripts/compile-project

# Kompiluj inny projekt w tym samym workspace
internal/scripts/compile-project -p other-app

# Uruchom testy zamiast kompilacji
internal/scripts/compile-project -g test -t

# Inny workspace
internal/scripts/compile-project -w workspaces/simple_flow -p app -g compile
```

Parametry:
- `-w WORKSPACE` — workspace
- `-p PROJECT` — podkatalog projektu
- `-g GOAL` — cel Mavena (domyślnie `compile`)
- `-t` — nie pomijaj testów
- `-h` — pomoc

---

### `ai-generate-crud`

Generuje prosty CRUD (Item + ItemController) przez lokalne AI proxy.

```bash
# Domyślnie: workspaces/springboot-demo/demo, pakiet com.example.demo
internal/scripts/ai-generate-crud

# Inny pakiet
internal/scripts/ai-generate-crud -k com.example.store

# Inny projekt i interpreter Pythona
internal/scripts/ai-generate-crud -w workspaces/my-app -p app -k com.example.app -y /usr/bin/python3
```

Parametry:
- `-w WORKSPACE` — workspace
- `-p PROJECT` — podkatalog projektu
- `-k PACKAGE` — pakiet Java (domyślnie `com.example.demo`)
- `-y PYTHON` — ścieżka do Pythona
- `-h` — pomoc

---

### `ai-review-fix-loop`

Pętla: kompilacja → w razie błędu wywołanie AI reviewer → ponowna kompilacja.

```bash
# Domyślnie 3 iteracje
internal/scripts/ai-review-fix-loop

# 5 iteracji
internal/scripts/ai-review-fix-loop -i 5

# Inny projekt i pakiet
internal/scripts/ai-review-fix-loop -w workspaces/my-app -p app -k com.example.app -i 5
```

Parametry:
- `-w WORKSPACE` — workspace
- `-p PROJECT` — podkatalog projektu
- `-k PACKAGE` — pakiet Java
- `-i ITERATIONS` — maksymalna liczba iteracji (domyślnie `3`)
- `-y PYTHON` — ścieżka do Pythona
- `-h` — pomoc

---

### `run-tests`

Uruchamia testy Maven w wybranym projekcie.

```bash
# Domyślnie: workspaces/springboot-demo/demo
internal/scripts/run-tests

# Inny projekt
internal/scripts/run-tests -w workspaces/simple_flow -p app
```

Parametry:
- `-w WORKSPACE` — workspace
- `-p PROJECT` — podkatalog projektu
- `-h` — pomoc

---

## Wrappery w workflow

Skrypty w `workflows/sdlc_springboot/` są cienkimi wrapperami:

| Workflow | Wywołanie |
|---|---|
| `scaffold.sh` | `copy-template-to-workspace -t springboot-simple -c` |
| `compile_skeleton.sh` | `compile-project` |
| `ai_add_crud.sh` | `ai-generate-crud` |
| `compile_loop.sh` | `ai-review-fix-loop` |
| `tests.sh` | `run-tests` |

Dzięki temu definicja DAG-a (`dags/sdlc_springboot.yaml`) nie musi znać szczegółów implementacji.

---

## Przykład: workflow z `start.spring.io`

Utwórz `workflows/my_startio_app/scaffold.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec "$REPO_ROOT/internal/scripts/fetch-springboot-project" \
  -b 4.0.8 \
  -d web,lombok \
  -w "$REPO_ROOT/workspaces/my_startio_app" \
  -P app \
  -C
```

Pozostałe wrappery (`compile_skeleton.sh`, `ai_add_crud.sh`, `compile_loop.sh`, `tests.sh`) wyglądają tak samo jak w przykładzie powyżej — tylko zmieniają workspace na `workspaces/my_startio_app` i projekt na `app`.

Definicja DAG-a `dags/my_startio_app.yaml`:

```yaml
dag_id: my_startio_app
schedule: "0 2 * * *"
start_date: "2026-09-01"
catchup: false
max_active_runs: 1

tasks:
  - id: scaffold
    type: shell
    timeout: 300
    command: bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/my_startio_app/scaffold.sh

  - id: compile_skeleton
    type: shell
    timeout: 600
    deps:
      - scaffold
    command: bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/my_startio_app/compile_skeleton.sh

  - id: ai_add_crud
    type: shell
    timeout: 300
    deps:
      - compile_skeleton
    command: bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/my_startio_app/ai_add_crud.sh

  - id: compile_loop
    type: shell
    timeout: 900
    deps:
      - ai_add_crud
    command: bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/my_startio_app/compile_loop.sh

  - id: tests
    type: shell
    timeout: 300
    deps:
      - compile_loop
    command: bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/my_startio_app/tests.sh
```

Gotowy przykład działający w tym repo znajdziesz w:
- `workflows/sdlc_springboot_startio/`
- `dags/sdlc_springboot_startio.yaml`

---

## Przykład: tworzenie nowego workflow

Załóżmy, że chcesz stworzyć workflow `my_springboot_app`, który:
1. Kopiuje szkielet `springboot-simple`.
2. Kompiluje szkielet.
3. Generuje CRUD.
4. Uruchamia testy.

### Krok 1: Utwórz workspace i wrappery

```bash
mkdir -p workspaces/my_springboot_app/app
mkdir -p workflows/my_springboot_app
```

Utwórz `workflows/my_springboot_app/scaffold.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
exec "$REPO_ROOT/internal/scripts/copy-template-to-workspace" \
  -t springboot-simple \
  -w "$REPO_ROOT/workspaces/my_springboot_app" \
  -p app \
  -c
```

Utwórz `workflows/my_springboot_app/compile.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
exec "$REPO_ROOT/internal/scripts/compile-project" \
  -w "$REPO_ROOT/workspaces/my_springboot_app" \
  -p app
```

Utwórz `workflows/my_springboot_app/ai_add_crud.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
exec "$REPO_ROOT/internal/scripts/ai-generate-crud" \
  -w "$REPO_ROOT/workspaces/my_springboot_app" \
  -p app \
  -k com.example.app
```

Utwórz `workflows/my_springboot_app/tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
exec "$REPO_ROOT/internal/scripts/run-tests" \
  -w "$REPO_ROOT/workspaces/my_springboot_app" \
  -p app
```

### Krok 2: Utwórz definicję DAG-a

Utwórz `dags/my_springboot_app.yaml`:

```yaml
dag_id: my_springboot_app
schedule: "0 2 * * *"
start_date: "2026-09-01"
catchup: false
max_active_runs: 1

tasks:
  - id: scaffold
    type: shell
    timeout: 120
    command: bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/my_springboot_app/scaffold.sh

  - id: compile
    type: shell
    timeout: 300
    deps:
      - scaffold
    command: bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/my_springboot_app/compile.sh

  - id: ai_add_crud
    type: shell
    timeout: 300
    deps:
      - compile
    command: bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/my_springboot_app/ai_add_crud.sh

  - id: tests
    type: shell
    timeout: 300
    deps:
      - ai_add_crud
    command: bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/my_springboot_app/tests.sh
```

### Krok 3: Zweryfikuj i uruchom

```bash
# Sprawdź, czy Cronova widzi nowy DAG
.\cronova.exe dags

# Wyzwól ręcznie
.\cronova.exe trigger my_springboot_app
```

Nowy workflow używa tych samych reużywalnych skryptów — różni się tylko parametrami wywołania.
