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
