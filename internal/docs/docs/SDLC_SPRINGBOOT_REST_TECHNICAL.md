# Techniczny opis DAG-ów `sdlc_springboot_rest` i `sdlc_springboot_variant`

## 1. Cel przepływu

`sdlc_springboot_rest` jest deterministycznym przepływem SDLC dla backendu Spring Boot udostępniającego API REST.
`sdlc_springboot_variant` używa tego samego zestawu klocków, ale wybiera wariant aplikacji per-run przez parametr `variant`.

Zadaniem obu przepływów jest:

1. sprawdzić konfigurację Spring Boot i dostępność Javy;
2. sprawdzić minimalną spójność kontraktu OpenAPI;
3. utworzyć projekt Spring Boot z Spring Initializr;
4. skompilować projekt Maven Wrapperem;
5. uruchomić testy jednostkowe;
6. spakować wykonywalny JAR i zapisać manifest.

DAG-i nie używają AI. Jest to analiza statyczna kodu.

## 2. Definicja DAG-u

Pliki: [`dags/sdlc_springboot_rest.yaml`](../dags/sdlc_springboot_rest.yaml), [`dags/sdlc_springboot_variant.yaml`](../dags/sdlc_springboot_variant.yaml).

| Pole | Wartość |
|---|---|
| `schedule` | `""` (tylko ręcznie lub przez trigger) |
| `start_date` | `2026-09-01` |
| `catchup` | `false` |
| `max_active_runs` | `1` |
| `default_retries` | `1` |

`sdlc_springboot_rest` wywołuje skrypty z `-Config configs\sdlc-springboot.yaml -Artifacts artifacts\springboot` (oraz `-Workspace .workspaces\springboot` dla scaffold/compile/test/package).

`sdlc_springboot_variant` w każdym tasku wybiera konfigurację:

```powershell
$variant = if ($env:CRONOVA_PARAM_VARIANT) { $env:CRONOVA_PARAM_VARIANT } else { 'rest' }
$config = & .\internal\scripts\resolve-springboot-variant-config.ps1 -Variant $variant
& .\internal\scripts\springboot-validate-config.ps1 -Config $config
```

[`resolve-springboot-variant-config.ps1`](../internal/scripts/resolve-springboot-variant-config.ps1) mapuje: `rest` → `configs/sdlc-springboot.yaml`, `crud` → `configs/sdlc-springboot-crud.yaml`, `h2` → `configs/sdlc-springboot-h2.yaml`, `security` → `configs/sdlc-springboot-security.yaml`; inna wartość to błąd. W wariancie workspace i katalog artefaktów pochodzą wyłącznie z konfiguracji (np. `.workspaces/springboot-crud`, `artifacts/springboot-crud`).

## 3. Graf zależności

```mermaid
flowchart LR
  A[springboot_validate_config] --> B[springboot_validate_openapi]
  B --> C[springboot_scaffold_from_config]
  C --> D[springboot_maven_compile_from_config]
  D --> E[springboot_maven_test_from_config]
  E --> F[springboot_package_from_config]
```

| Task | Timeout | Skrypt |
|---|---:|---|
| `springboot_validate_config` | 120 s | [`springboot-validate-config.ps1`](../internal/scripts/springboot-validate-config.ps1) |
| `springboot_validate_openapi` | 180 s | [`springboot-validate-openapi.ps1`](../internal/scripts/springboot-validate-openapi.ps1) |
| `springboot_scaffold_from_config` | 600 s | [`springboot-scaffold-from-config.ps1`](../internal/scripts/springboot-scaffold-from-config.ps1) |
| `springboot_maven_compile_from_config` | 900 s | [`springboot-maven-compile-from-config.ps1`](../internal/scripts/springboot-maven-compile-from-config.ps1) |
| `springboot_maven_test_from_config` | 900 s | [`springboot-maven-test-from-config.ps1`](../internal/scripts/springboot-maven-test-from-config.ps1) |
| `springboot_package_from_config` | 600 s | [`springboot-package-from-config.ps1`](../internal/scripts/springboot-package-from-config.ps1) |

## 4. Przebieg krok po kroku

### 4.1. `springboot_validate_config`

1. tworzy `<artifacts>/metadata`;
2. `Set-JavaMavenToolchain`, wymaga `java`;
3. odrzuca konfigurację z `/c/Users/`, `/home/`, `/tmp/`, `/var/`, `systemd`, `launchd`;
4. wymaga `project.id` oraz `project.kind: springboot` (po scaleniu ze standardem);
5. zapisuje `java -version` do `metadata/java-version.txt` i diagnostykę do `metadata/toolchain-runtime.txt`.

### 4.2. `springboot_validate_openapi`

Wymaga pliku `api.openapi_file` i Pythona. Uruchamia krótki skrypt Pythona sprawdzający obecność markerów `openapi:`, `paths:` i `/api/items`. Log: `logs/springboot-openapi-validation.log`. Nie jest to pełna walidacja OpenAPI.

### 4.3. `springboot_scaffold_from_config`

Jeśli `pom.xml` już istnieje w workspace — kończy się sukcesem bez zmian. W przeciwnym razie pobiera przez `Invoke-WebRequest`:

```text
https://start.spring.io/starter.zip?type=maven-project&language=java&bootVersion=<runtime.spring_boot_version>&javaVersion=<runtime.java_version>&groupId=<springboot.group_id>&artifactId=<springboot.artifact_id>&name=<artifact_id>&packageName=<springboot.package_name>&packaging=jar&configFormat=yaml&dependencies=<dependencies.starters>
```

zapisuje ZIP do `metadata/springboot-starter.zip`, rozpakowuje do workspace i wymaga `pom.xml`. Domyślne wartości w skrypcie: Boot `3.5.5`, Java `21`, `com.example`, `item-service`, `com.example.item`, `web,validation,actuator` — używane tylko, gdy konfiguracja ich nie podaje.

### 4.4. `springboot_maven_compile_from_config`

`Set-JavaMavenToolchain`, wymaga `java` i `maven`, a także Maven Wrappera z `runtime.maven_wrapper` (domyślnie `./mvnw.cmd`). Wykonuje `mvnw.cmd -B -DskipTests compile`, log `logs/springboot-compile.log`.

### 4.5. `springboot_maven_test_from_config`

`mvnw.cmd -B test`, log `logs/springboot-unit-tests.log`.

### 4.6. `springboot_package_from_config`

1. `mvnw.cmd -B package -DskipTests`, log `logs/springboot-package.log`;
2. bierze pierwszy `*.jar` z `<workspace>/<project.artifact_directory>` (domyślnie `target`), z pominięciem `*-plain.jar`;
3. kopiuje go do `<artifacts>/package/<project.artifact_name>` (domyślnie `item-service.jar`);
4. zapisuje SHA-256 do `<jar>.sha256`;
5. zapisuje `backend-manifest.json` (`component`, `artifact`, `source_directory`, `result`).

## 5. Wspólny bootstrap i kontrakt klocków

Każdy skrypt ma kontrakt `-Config` (wymagany), `-Workspace` i `-Artifacts` (opcjonalne; walidatory przyjmują tylko `-Config`/`-Artifacts`). Skrypty ładują:

- [`internal/scripts/common/toolchain.ps1`](../internal/scripts/common/toolchain.ps1) — `Set-JavaMavenToolchain` (`CRONOVA_JAVA_HOME`/`JAVA_HOME`, `CRONOVA_MAVEN_HOME`/`MAVEN_HOME`), `Get-ConfiguredCommand`, `Write-ToolchainRuntime`, `ConvertTo-NativeArgumentString`;
- [`scripts/sdlc/common/SpringbootConfig.ps1`](../scripts/sdlc/common/SpringbootConfig.ps1) — `Get-SpringbootSdlcConfig`, który scala wartości z pliku workflow i pliku standardu wskazanego w `standard.file`.

Natywne procesy są uruchamiane przez `Start-Process` z przekierowaniem stdout/stderr do pliku logu.

## 6. Konfiguracja

`configs/sdlc-springboot.yaml` wskazuje standard `configs/standards/springboot-rest-api.yaml` i ustawia m.in. workspace `.workspaces/springboot`, `project.id: item-service`, artefakty `artifacts/springboot`. Standard REST definiuje `project.artifact_name: item-service.jar`, pakiet `com.example.items`, startery `web,validation,actuator`, port `18080` i bazuje na `configs/standards/springboot-base.yaml`, który ustawia m.in.:

```yaml
project:
  kind: springboot
  artifact_directory: target
runtime:
  java_version: "25"
  spring_boot_version: "4.0.0"
  maven_wrapper: ./mvnw.cmd
api:
  openapi_file: contracts/openapi.yaml
```

Warianty `crud`, `h2` i `security` mają własne pliki w `configs/` i standardy w `configs/standards/`.

## 7. Ocena modelu „klocków Lego”

### 7.1. Elementy rzeczywiście reużywalne

- sześć skryptów `springboot-*-from-config.ps1` / `springboot-validate-*.ps1` — każdy wykonuje jedną operację i jest sterowany konfiguracją;
- `resolve-springboot-variant-config.ps1` — wybór konfiguracji bez duplikowania DAG-a;
- `SpringbootConfig.ps1` — scalanie configu workflow ze standardem.

### 7.2. Elementy specyficzne, które nie są w DAG-u

Wartości projektu (pakiet, startery, wersje, nazwa JAR-a) są w konfiguracji i standardach, nie w YAML DAG-a.

### 7.3. Ograniczenia reużywalności

1. Walidacja OpenAPI sprawdza wyłącznie markery tekstowe, w tym zaszyte `/api/items`.
2. Scaffold pomija generowanie przy istniejącym `pom.xml`; DAG nie czyści workspace’u.
3. Scaffold zależy od sieci i dostępności Spring Initializr.
4. W `sdlc_springboot_variant` blok wyboru wariantu jest powtórzony w każdym tasku.
5. Parser konfiguracji obsługuje tylko prosty dwupoziomowy YAML.

## 8. Wniosek audytowy

### Ocena: **spełnia założenie reużywalnych klocków, z ograniczeniami parametryzacji**

Oba DAG-i są deklaratywnymi grafami sześciu tasków PowerShell wywołujących te same skrypty. Wariant różni się wyłącznie wyborem pliku konfiguracji.

## 9. Zakres następnych możliwych usprawnień

- przeniesienie wyboru wariantu do jednego miejsca (np. parametru przekazywanego do skryptów);
- pełniejsza walidacja OpenAPI;
- opcja czyszczenia workspace’u przed scaffoldem.
