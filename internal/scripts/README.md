# Reużywalne skrypty build/SDLC

Katalog `internal/scripts/` zawiera narzędzia CLI używane przez przepływy Cronova.
Każdy skrypt jest niezależny i można go wywołać ręcznie lub z innego workflow.

## Wymagania

- Git Bash lub inne środowisko bash (np. WSL, MSYS2)
- Java JDK dostępny w `PATH` lub przez `JAVA_HOME`/`CRONOVA_JAVA_HOME`
- Apache Maven dostępny w `PATH` lub przez `MAVEN_HOME`/`CRONOVA_MAVEN_HOME`
- Python dostępny jako `python3`, `python` lub przez `CRONOVA_PYTHON`

Klocki nie zakładają konkretnego użytkownika, katalogu instalacyjnego ani systemu plików. Helper `internal/scripts/common_toolchain.sh` wykrywa narzędzia i zwraca czytelny błąd, jeśli wymagane narzędzie nie jest dostępne.

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

# Wymuś model (zamiast domyślnego z konfiguracji cronova)
internal/scripts/ai-generate-crud -m "kimi-k2.7-code"
```

Parametry:
- `-w WORKSPACE` — workspace
- `-p PROJECT` — podkatalog projektu
- `-k PACKAGE` — pakiet Java (domyślnie `com.example.demo`)
- `-r PROVIDER_ID` — id dostawcy AI z konfiguracji cronova (domyślnie dostawca oznaczony jako default)
- `-m MODEL` — model AI (domyślnie model z domyślnego dostawcy lub zmienna `CRONOVA_AI_MODEL`)
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

# Wymuż model
internal/scripts/ai-review-fix-loop -m "kimi-k2.7-code"
```

Parametry:
- `-w WORKSPACE` — workspace
- `-p PROJECT` — podkatalog projektu
- `-k PACKAGE` — pakiet Java
- `-i ITERATIONS` — maksymalna liczba iteracji (domyślnie `3`)
- `-r PROVIDER_ID` — id dostawcy AI z konfiguracji cronova (domyślnie dostawca oznaczony jako default)
- `-m MODEL` — model AI (domyślnie model z domyślnego dostawcy lub zmienna `CRONOVA_AI_MODEL`)
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

### `generate-maven-archetype`

Generuje szkielet Java + Maven przez `mvn archetype:generate`.

```bash
# Domyślnie: maven-archetype-quickstart, com.example, artifact demo, Java 21
internal/scripts/generate-maven-archetype

# Własny archetyp i parametry
internal/scripts/generate-maven-archetype \
  -a maven-archetype-archetype \
  -v 1.5 \
  -g com.acme \
  -r luhn \
  -k com.acme.luhn \
  -j 21 \
  -w workspaces/sdlc_maven_luhn \
  -p app \
  -C
```

Parametry:
- `-a ARCHETYPE` — artifactId archetypu (domyślnie `maven-archetype-quickstart`)
- `-v VERSION` — wersja archetypu (opcjonalnie)
- `-g GROUP` — groupId projektu (domyślnie `com.example`)
- `-r ARTIFACT` — artifactId projektu (domyślnie `demo`)
- `-k PACKAGE` — pakiet Java (domyślnie `com.example.demo`)
- `-j JAVA` — wersja Javy (domyślnie `21`)
- `-w WORKSPACE` — workspace docelowy
- `-p PROJECT` — podkatalog projektu w workspace
- `-C` — wyczyść docelowy katalog przed generowaniem
- `-h` — pomoc

---

### `ai-generate-feature`

Generuje dowolną funkcję biznesową na podstawie pliku promptu. Jest to generyczna wersja `ai-generate-crud`.

```bash
# Użyj promptu z prompts/luhn.txt
internal/scripts/ai-generate-feature -f prompts/luhn.txt

# Inny projekt i pakiet
internal/scripts/ai-generate-feature \
  -f prompts/my-feature.txt \
  -w workspaces/sdlc_maven_luhn \
  -p app \
  -k com.example.luhn

# Wymuś model
internal/scripts/ai-generate-feature -f prompts/luhn.txt -m "kimi-k2.7-code"
```

Parametry:
- `-f PROMPT_FILE` — ścieżka do pliku promptu (wymagane)
- `-w WORKSPACE` — workspace
- `-p PROJECT` — podkatalog projektu
- `-k PACKAGE` — pakiet Java
- `-r PROVIDER_ID` — id dostawcy AI z konfiguracji cronova (domyślnie dostawca oznaczony jako default)
- `-m MODEL` — model AI (domyślnie model z domyślnego dostawcy lub zmienna `CRONOVA_AI_MODEL`)
- `-y PYTHON` — ścieżka do Pythona
- `-h` — pomoc

Plik promptu powinien zawierać instrukcje dla modelu AI, w tym:
- opis generowanej funkcji,
- wymagane klasy i testy,
- zasady dotyczące zależności (np. brak hardkodowanych wersji dla zarządzanych zależności),
- unikanie problematycznych konstrukcji (np. regex z niedozwolonymi escape'ami w zwykłym Java).

Przykład promptu: [prompts/luhn.txt](prompts/luhn.txt).

---


## Kompozycja DAG-ów z klocków

DAG jest deklaratywnym opisem przepływu, a `internal/scripts/` jest biblioteką reużywalnych klocków. Definicje w `dags/` wywołują klocki bezpośrednio i przekazują im parametry workspace, projektu, pakietu oraz promptu. Nie tworzymy dedykowanych wrapperów w `workflows/<nazwa_dag>/`.

Różne przepływy powstają przez inną kompozycję tych samych klocków:

| Cel przepływu | Klocki |
|---|---|
| Spring Boot z szablonu | `copy-template-to-workspace` → `compile-project` → `ai-generate-crud` → `ai-review-fix-loop` → `run-tests` |
| Spring Boot ze Spring Initializr | `fetch-springboot-project` → `compile-project` → `ai-generate-crud` → `ai-review-fix-loop` → `run-tests` |
| Maven + funkcja biznesowa | `generate-maven-archetype` → `compile-project` → `ai-generate-feature` → `ai-review-fix-loop` → `run-tests` |

Przykład zadania w DAG-u:

```yaml
- id: ai_add_crud
  type: shell
  timeout: 300
  deps: [compile_skeleton]
  command: bash internal/scripts/ai-generate-crud -w workspaces/my-app -p app -k com.example.app -r default -y python
```

Klocki AI korzystają z pomocniczych implementacji w `internal/scripts/ai/`. Ten katalog jest częścią biblioteki narzędzi i nie jest związany z żadnym konkretnym DAG-iem.

Jeżeli autodetekcja nie wystarcza, środowisko może jawnie ustawić `CRONOVA_PYTHON`, `CRONOVA_JAVA_HOME` albo `CRONOVA_MAVEN_HOME`. Są to opcjonalne parametry środowiska, a nie ścieżki zapisane w DAG-ach.

### Dodawanie nowego przepływu

Nowy przepływ powinien wymagać wyłącznie nowego pliku YAML w `dags/`. Nie należy dodawać skryptów do `dags/` ani tworzyć katalogu `workflows/<nazwa_dag>/`. Jeżeli istniejące klocki nie mają potrzebnego parametru, należy rozszerzyć klocek uniwersalnie, tak aby był użyteczny również dla innych przepływów.
