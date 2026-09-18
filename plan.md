# Plan refaktoryzacji przepływu `sdlc_springboot`

## Cel
Przejście z modelu „jeden krok = jeden dedykowany skrypt” w `workflows/sdlc_springboot/` na model **reużywalnych narzędzi build/SDLC** przechowywanych w `internal/scripts/`.

## Zakres prac
1. Utworzenie katalogu `internal/scripts/` z rodziną reużywalnych skryptów CLI.
2. Utworzenie katalogu `templates/springboot-simple/` zawierającego pliki źródłowe szkieletu Spring Boot.
3. Zastąpienie obecnych skryptów w `workflows/sdlc_springboot/` cienkimi wrapperami wywołującymi nowe narzędzia.
4. Aktualizacja definicji DAG-a `dags/sdlc_springboot.yaml` do nowych poleceń.
5. Weryfikacja lokalna (testy w terminalu) oraz weryfikacja w przeglądarce (uruchomienie DAG-a w Cronova Console).

## Struktura docelowa

```
internal/scripts/
  copy-template-to-workspace   # kopiuje template do workspace'u projektu
  compile-project              # kompiluje projekt Maven
  ai-generate-crud             # generuje CRUD przez AI proxy
  ai-review-fix-loop           # pętla kompilacji + napraw AI
  run-tests                    # uruchamia testy Maven

templates/
  springboot-simple/
    pom.xml
    src/main/java/com/example/demo/DemoApplication.java
    src/test/java/com/example/demo/DemoApplicationTests.java

workflows/sdlc_springboot/
  scaffold.sh                  # wrapper: copy-template-to-workspace -t springboot-simple
  compile_skeleton.sh          # wrapper: compile-project
  ai_add_crud.sh               # wrapper: ai-generate-crud
  compile_loop.sh              # wrapper: ai-review-fix-loop
  tests.sh                     # wrapper: run-tests
```

## Zadania

### Zadanie 1: Utworzenie `internal/scripts/copy-template-to-workspace`
- Skrypt bash z obsługą parametrów (`-t TEMPLATE`, opcjonalnie `-w WORKSPACE`, `-p PROJECT`, `-h`).
- Domyślnie szuka template'ów w `templates/` względem katalogu repo.
- Domyślnie kopiuje do `workspaces/springboot-demo/demo` (zgodnie z obecnym przepływem).
- Czyści docelowy katalog przed kopiowaniem.
- Test: uruchomienie skryptu z parametrem `-t springboot-simple` i sprawdzenie, czy pliki pojawiły się w workspace.

### Zadanie 2: Utworzenie `templates/springboot-simple/`
- Przeniesienie zawartości generowanej obecnie przez `scaffold.sh` do plików:
  - `templates/springboot-simple/pom.xml`
  - `templates/springboot-simple/src/main/java/com/example/demo/DemoApplication.java`
  - `templates/springboot-simple/src/test/java/com/example/demo/DemoApplicationTests.java`
- Test: struktura katalogów i plików zgodna z oczekiwaniami.

### Zadanie 3: Utworzenie `internal/scripts/compile-project`
- Skrypt bash z obsługą parametrów (`-w WORKSPACE`, opcjonalnie `-h`).
- Ustawia `JAVA_HOME` i `PATH` do Mavena.
- Wywołuje `mvn -B -Dmaven.repo.local=... -DskipTests compile`.
- Test: uruchomienie po Zadaniu 1 — projekt kompiluje się.

### Zadanie 4: Utworzenie `internal/scripts/ai-generate-crud`
- Skrypt bash z obsługą parametrów (`-w WORKSPACE`, `-p PACKAGE`, opcjonalnie `-h`).
- Przygotowuje prompt, wywołuje istniejący `ai_add_crud.py` (lub jego przeniesioną wersję).
- Zapisuje wygenerowane pliki w workspace.
- Test: po Zadaniu 3 — CRUD zostaje dodany.

### Zadanie 5: Utworzenie `internal/scripts/ai-review-fix-loop`
- Skrypt bash z obsługą parametrów (`-w WORKSPACE`, `-p PACKAGE`, `-i ITERATIONS`, opcjonalnie `-h`).
- Pętla: kompilacja → w razie błędu wywołanie AI reviewer → ponowna kompilacja (max 3 iteracje).
- Test: po Zadaniu 4 — pętla kończy się sukcesem.

### Zadanie 6: Utworzenie `internal/scripts/run-tests`
- Skrypt bash z obsługą parametrów (`-w WORKSPACE`, opcjonalnie `-h`).
- Wywołuje `mvn -B -Dmaven.repo.local=... test`.
- Test: po Zadaniu 5 — testy przechodzą.

### Zadanie 7: Zastąpienie skryptów w `workflows/sdlc_springboot/`
- Każdy skrypt staje się cienkim wrapperem wywołującym odpowiednie narzędzie z `internal/scripts/`.
- `scaffold.sh` → `copy-template-to-workspace -t springboot-simple`
- `compile_skeleton.sh` → `compile-project`
- `ai_add_crud.sh` → `ai-generate-crud`
- `compile_loop.sh` → `ai-review-fix-loop`
- `tests.sh` → `run-tests`
- Test: każdy wrapper uruchamia się bez błędów.

### Zadanie 8: Aktualizacja `dags/sdlc_springboot.yaml`
- Opcjonalnie: zamiana bezwzględnych ścieżek w `command` na wywołania wrapperów (ścieżki pozostają bezwzględne, ale wskazują na nowe skrypty).
- Test: walidacja YAML (np. przez `cronova` lub ręczna).

### Zadanie 9: Test końcowy w przeglądarce
- Wyzwolenie DAG-a `sdlc_springboot` z poziomu Cronova Console.
- Potwierdzenie, że wszystkie 5 kroków zakończyło się sukcesem.

## Kryteria ukończenia
- Każde zadanie jest ukończone, gdy:
  1. Test w terminalu/chat przeszedł pozytywnie.
  2. Test w zadaniu w przeglądarce (jeśli dotyczy) przeszedł pozytywnie.
- Cały plan jest ukończony, gdy DAG `sdlc_springboot` uruchamia się w Cronova Console z sukcesem.

## Decyzje projektowe
- Skrypty reużywalne umieszczamy w `internal/scripts/`.
- Template'y umieszczamy w `templates/`.
- Ścieżka do workspace'u domyślnie: `workspaces/springboot-demo/demo`.
- Ścieżka do lokalnego repo Mavena: `.m2/repository` w katalogu repo.
- Skrypty w `workflows/sdlc_springboot/` pozostają wrapperami, aby nie zmieniać bezpośrednio definicji DAG-a.
- Skrypty CLI obsługują `-h` / `--help` oraz zwracają kod błędu przy braku wymaganych parametrów.
