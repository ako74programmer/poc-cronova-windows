# Techniczny opis DAG-u `sdlc_springboot_rest`

## 1. Cel przepływu

`sdlc_springboot_rest` jest deterministycznym przepływem SDLC dla backendu Spring Boot udostępniającego API REST. Jego zadaniem jest:

1. sprawdzić konfigurację Spring Boot i dostępność Java/Maven;
2. sprawdzić minimalną spójność kontraktu OpenAPI;
3. utworzyć projekt Spring Boot z Spring Initializr;
4. skompilować projekt;
5. uruchomić testy jednostkowe;
6. zbudować wykonywalny JAR i opublikować go jako artefakt Cronova.

DAG nie zawiera implementacji operacji. Zawiera wyłącznie deklaratywną kolejność i parametry wywołania reużywalnych skryptów.

## 2. Definicja DAG-u

Plik:

```text
dags/sdlc_springboot_rest.yaml
```

Ustawienia:

| Właściwość | Wartość | Znaczenie |
|---|---:|---|
| `dag_id` | `sdlc_springboot_rest` | Identyfikator przepływu |
| `schedule` | pusty | Przepływ uruchamiany ręcznie |
| `catchup` | `false` | Brak uruchamiania zaległych instancji |
| `max_active_runs` | `1` | Tylko jeden aktywny run tego DAG-u |
| `default_retries` | `1` | Jedna domyślna próba ponowienia |

## 3. Graf zależności

```text
validate_config
        │
        ▼
validate_openapi
        │
        ▼
scaffold
        │
        ▼
compile
        │
        ▼
unit_tests
        │
        ▼
package
```

Każdy task ma typ `shell`. Cronova uruchamia go przez Windows/Git Bash zgodnie z konfiguracją runtime. Wszystkie taski korzystają z argumentów `--config`, `--workspace` i `--artifacts` tam, gdzie potrzebują workspace’u lub artefaktów.

## 4. Przebieg krok po kroku

### 4.1. `validate_config`

Wywołanie:

```bash
bash scripts/sdlc/springboot/validate.sh \
  --config configs/sdlc-springboot.yaml
```

Używany skrypt:

```text
scripts/sdlc/springboot/validate.sh
```

Skrypt:

1. ładuje wspólny `bootstrap.sh`;
2. parsuje `--config`;
3. normalizuje ścieżki względem repozytorium;
4. przygotowuje katalogi artefaktów;
5. konfiguruje toolchain Java/Maven;
6. wymaga dostępności `java` i `mvn`;
7. odrzuca prywatne lub unixowe ścieżki środowiska w konfiguracji;
8. sprawdza obecność sekcji `project:`;
9. sprawdza `kind: springboot`;
10. zapisuje wersję Java i runtime toolchainu do artefaktów.

Artefakty diagnostyczne:

```text
artifacts/metadata/java-version.txt
artifacts/metadata/runtime.txt
artifacts/metadata/toolchain-runtime.txt
```

### 4.2. `validate_openapi`

Wywołanie:

```bash
bash scripts/sdlc/integration/validate.sh \
  --config configs/sdlc-fullstack.yaml
```

Używany skrypt:

```text
scripts/sdlc/integration/validate.sh
```

Skrypt:

1. ładuje wspólny bootstrap;
2. wymaga `python`;
3. sprawdza obecność `contracts/openapi.yaml`;
4. sprawdza obecność konfiguracji full-stack;
5. odrzuca prywatne i nieprzenośne ścieżki w konfiguracji;
6. uruchamia krótki program Python przekazany przez stdin;
7. wymaga markerów:
   - `openapi:`;
   - `paths:`;
   - `/api/items`.

Jest to smoke test kontraktu, nie pełna walidacja schematu OpenAPI.

### 4.3. `scaffold`

Wywołanie:

```bash
bash scripts/sdlc/springboot/scaffold.sh \
  --config configs/sdlc-springboot.yaml \
  --workspace .workspaces/springboot \
  --artifacts artifacts/springboot
```

Używane skrypty:

```text
scripts/sdlc/springboot/scaffold.sh
scripts/sdlc/common/config-value.sh
```

Skrypt:

1. ładuje bootstrap i parser wartości konfiguracji;
2. konfiguruje Java/Maven;
3. wymaga `curl` i `unzip`;
4. kończy się bez zmian, jeśli workspace ma już `pom.xml`;
5. odczytuje z YAML:
   - wersję Spring Boot;
   - wersję Java;
   - group ID;
   - artifact ID;
   - nazwę pakietu;
6. buduje URL do Spring Initializr;
7. pobiera ZIP projektu;
8. zapisuje ZIP w `artifacts/springboot/metadata/`;
9. rozpakowuje projekt do workspace’u;
10. wymaga obecności `pom.xml`.

Generator używa zależności:

```text
web, validation, actuator
```

### 4.4. `compile`

Wywołanie:

```bash
bash scripts/sdlc/springboot/compile.sh \
  --config configs/sdlc-springboot.yaml \
  --workspace .workspaces/springboot \
  --artifacts artifacts/springboot
```

Używany skrypt:

```text
scripts/sdlc/springboot/compile.sh
```

Skrypt:

1. ładuje bootstrap;
2. konfiguruje Java/Maven i runtime Windows;
3. wymaga `java` i `mvn`;
4. sprawdza obecność `mvnw.cmd`;
5. zmienia katalog na workspace;
6. uruchamia:

```text
./mvnw.cmd -B -DskipTests compile
```

Log zapisuje do:

```text
artifacts/springboot/logs/springboot-compile.log
```

Maven Wrapper jest generowany przez Spring Initializr. Skrypt wymaga konkretnego pliku `mvnw.cmd`, więc ten klocek jest reużywalny dla projektów Spring Boot generowanych lub dostarczanych z wrapperem Maven.

### 4.5. `unit_tests`

Wywołanie:

```bash
bash scripts/sdlc/springboot/unit-test.sh \
  --config configs/sdlc-springboot.yaml \
  --workspace .workspaces/springboot \
  --artifacts artifacts/springboot
```

Używany skrypt:

```text
scripts/sdlc/springboot/unit-test.sh
```

Skrypt:

1. ładuje bootstrap;
2. konfiguruje Java/Maven;
3. wymaga `java` i `mvn`;
4. sprawdza `mvnw.cmd`;
5. uruchamia:

```text
./mvnw.cmd -B test
```

Log zapisuje do:

```text
artifacts/springboot/logs/springboot-unit-tests.log
```

### 4.6. `package`

Wywołanie:

```bash
bash scripts/sdlc/springboot/package.sh \
  --config configs/sdlc-springboot.yaml \
  --workspace .workspaces/springboot \
  --artifacts artifacts/springboot
```

Używany skrypt:

```text
scripts/sdlc/springboot/package.sh
```

Skrypt:

1. ładuje bootstrap;
2. konfiguruje Java/Maven;
3. wymaga `java` i `mvn`;
4. sprawdza `mvnw.cmd`;
5. uruchamia:

```text
./mvnw.cmd -B package -DskipTests
```

6. wyszukuje JAR przez glob Bash `target/*.jar`;
7. pomija artefakt `*-plain.jar`;
8. kopiuje główny JAR do:

```text
artifacts/springboot/package/item-service.jar
```

9. zapisuje sumę SHA-256;
10. tworzy manifest backendu.

Artefakty:

```text
artifacts/springboot/package/item-service.jar
artifacts/springboot/package/item-service.jar.sha256
artifacts/springboot/backend-manifest.json
```

## 5. Wspólny bootstrap i kontrakt klocków

Plik:

```text
scripts/sdlc/common/bootstrap.sh
```

Jest warstwą wspólną dla wszystkich skryptów SDLC. Odpowiada za:

- wyznaczenie `REPO_ROOT` na podstawie lokalizacji skryptu;
- obsługę `--config`, `--workspace`, `--artifacts`;
- konwersję ścieżek Windows przez `cygpath`;
- zamianę ścieżek względnych na ścieżki względem repozytorium;
- utworzenie katalogów `logs`, `reports`, `metadata`;
- przygotowanie runtime Python/Node/npm i Windows PATH;
- wymaganie poleceń przez `require_command`;
- zapis podstawowych informacji runtime.

Dzięki temu skrypty mogą zmieniać katalog roboczy bez utraty lokalizacji artefaktów.

## 6. Konfiguracja

Główna konfiguracja:

```text
configs/sdlc-springboot.yaml
```

Opisuje:

- typ projektu: `springboot`;
- Java `25`;
- Spring Boot `4.0.0`;
- Maven Wrapper;
- dane Spring Initializr;
- kontrakt API;
- port backendu i endpoint health;
- katalog artefaktów;
- ustawienia jakości i AI.

Konfiguracja full-stack:

```text
configs/sdlc-fullstack.yaml
```

Jest wykorzystywana w tym DAG-u tylko przez `validate_openapi`. Zawiera wspólny identyfikator platformy, lokalizację kontraktu OpenAPI oraz manifesty i adresy usług dla dalszego DAG-u full-stack.

Parser:

```text
scripts/sdlc/common/config-value.sh
```

`config_value` jest celowo prostym parserem dwupoziomowych wartości skalarnych YAML. Nie jest pełnym parserem YAML. W tym DAG-u pobiera tylko wartości o prostym układzie sekcji `runtime` i `springboot`.

## 7. Ocena modelu „klocków Lego”

### 7.1. Elementy rzeczywiście reużywalne

| Klocek | Reużywalność | Uzasadnienie |
|---|---|---|
| `bootstrap.sh` | wysoka | Wspólny kontrakt argumentów, ścieżki, artefakty i runtime |
| `config-value.sh` | średnia | Reużywalny dla prostych sekcji YAML, ale nie zastępuje parsera YAML |
| `common_toolchain.sh` | wysoka w Windows/Git Bash | Wspólna konfiguracja Java/Maven/Python/Node i ścieżek |
| `validate.sh` Spring Boot | średnia/wysoka | Może obsługiwać różne projekty Spring Boot z podobnym manifestem |
| `scaffold.sh` | średnia | Reużywalny dla projektów Spring Initializr, ale zależny od parametrów Spring Boot |
| `compile.sh` | średnia/wysoka | Ogólny compile Maven Wrapper dla workspace’u Spring Boot |
| `unit-test.sh` | średnia/wysoka | Ogólny test Maven Wrapper dla workspace’u Spring Boot |
| `package.sh` | średnia/wysoka | Pakuje główny JAR Spring Boot i tworzy standardowy manifest |
| `integration/validate.sh` | średnia | Wspólny smoke test OpenAPI, ale obecnie zna `/api/items` |

### 7.2. Elementy specyficzne, które nie są w DAG-u

DAG nie korzysta z dedykowanego katalogu typu:

```text
workflows/sdlc_springboot_rest/
```

Nie ma więc osobnych wrapperów dla tego przepływu. Właściwa logika znajduje się w katalogach bibliotek:

```text
scripts/sdlc/common/
scripts/sdlc/springboot/
scripts/sdlc/integration/
internal/scripts/
```

To spełnia główną zasadę architektury klocków: DAG składa przepływ z istniejących komponentów, a nie zawiera skryptów napisanych wyłącznie dla jednego DAG-u.

### 7.3. Ograniczenia reużywalności do późniejszego uporządkowania

Przepływ jest reużywalny, ale nie jest jeszcze w 100% neutralny. Obecne ograniczenia:

1. `integration/validate.sh` wymaga literalnie `/api/items` zamiast odczytywać wymagane ścieżki z konfiguracji OpenAPI.
2. `scaffold.sh` jest związany ze Spring Initializr i stałym zestawem zależności `web, validation, actuator`.
3. `compile.sh`, `unit-test.sh` i `package.sh` wymagają `mvnw.cmd`, więc są przeznaczone dla workspace’ów z Maven Wrapperem.
4. `package.sh` kopiuje artefakt do stałej nazwy `item-service.jar`, choć konfiguracja zawiera `artifact_name`.
5. `package.sh` wyłącza tylko `*-plain.jar`; wybór głównego JAR-a jest oparty na pierwszym dopasowaniu globu.
6. `config-value.sh` obsługuje tylko prosty fragment YAML.
7. `validate.sh` sprawdza konfigurację przez `grep`, a nie przez formalną walidację schematu.
8. `sdlc_springboot_rest` korzysta z konfiguracji full-stack dla walidacji OpenAPI, mimo że sam DAG nie uruchamia usług ani testów E2E.

Są to ograniczenia zakresu uogólnienia, nie dedykowane skrypty DAG-u. Można je poprawić jako osobne kroki, nie zmieniając zasadniczego modelu kompozycji.

## 8. Wniosek audytowy

### Ocena: **spełnia założenie reużywalnych klocków, z ograniczeniami parametryzacji**

DAG jest złożony poprawnie z reużywalnych elementów:

- nie zawiera implementacji skryptów;
- nie ma dedykowanego katalogu wrapperów dla `sdlc_springboot_rest`;
- każdy krok ma jawny kontrakt wejścia i wyjścia;
- wspólny bootstrap izoluje problemy ścieżek i katalogu roboczego;
- skrypty są użyteczne także w innych przepływach Spring Boot/full-stack.

Nie należy jednak nazywać wszystkich klocków w pełni uniwersalnymi. Część z nich jest **uniwersalna w obrębie technologii** — Spring Boot, Maven Wrapper albo OpenAPI — a nie dla dowolnego stosu.

Najważniejsza granica jest prawidłowa:

```text
DAG = kompozycja i zależności
skrypt = jedna reużywalna operacja
config = parametry projektu i środowiska
artifact = wynik przekazywany dalej
```

## 9. Zakres następnych możliwych usprawnień

Po przetestowaniu kolejnych DAG-ów można niezależnie rozważyć:

1. parametr `openapi_required_paths` zamiast literalnego `/api/items`;
2. parametr `dependencies` dla scaffoldingu Spring Initializr;
3. parametr `maven_command` lub tryb `wrapper/system-maven`;
4. parametr `artifact_name` używany przez `package.sh`;
5. formalną walidację YAML i konfiguracji;
6. osobny lokalny plik toolchainu Windows, jeśli potrzebna będzie wygodniejsza konfiguracja wielu komputerów.

Te usprawnienia powinny być wykonywane osobno, ponieważ obecny przepływ został już zweryfikowany end-to-end na Windowsie.
