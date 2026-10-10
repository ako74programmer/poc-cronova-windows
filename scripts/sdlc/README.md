# Reusable SDLC scripts

Katalog zawiera skrypty PowerShell wspólne dla workflowów Angular, Spring Boot i full-stack.

## Kontrakt wywołania

Każdy skrypt przyjmuje:

```text
.\scripts\sdlc\Invoke-Sdlc.ps1 -Step <krok> -Config <plik sdlc YAML> [-Workspace <katalog projektu>] [-Artifacts <katalog wyników>]
```

`-Workspace` domyślnie: `CRONOVA_PROJECT_DIR`, `workspace.directory` z configu albo repozytorium. `-Artifacts` domyślnie: `CRONOVA_ARTIFACTS_DIR`, `artifacts.directory` z configu albo `artifacts`.

DAG opisuje kolejność zadań. Konfiguracja opisuje stack technologiczny i parametry projektu. Skrypt wykonuje operację.

## Windows

Pipeline działa wyłącznie na Windows i PowerShell. Skrypty nie mogą zawierać prywatnych ścieżek autora ani ścieżek uniksowych.

## Aktualny zakres

Pierwsza wersja zawiera:

- `configs/sdlc-angular.yaml`;
- `configs/sdlc-springboot.yaml`;
- `configs/sdlc-fullstack.yaml`;
- wspólny kontrakt `contracts/openapi.yaml`;
- generator implementacji CRUD Spring Boot oraz klienta i interfejsu Angular dla `sdlc_fullstack`, walidujący zgodność z kontraktem;
- podstawowe skrypty walidacji, npm, Angular build/test/lint;
- Spring Boot compile/test/package wrappers;
- instalację i uruchomienie Playwright;
- podstawowe DAG-i `sdlc_angular`, `sdlc_springboot_rest` i `sdlc_fullstack`.

Workspace’y i katalogi artefaktów są wybierane z konfiguracji projektu. Na Windows Cronova sprząta procesy potomne wraz z końcem taska (Job Object), dlatego start usług, readiness, E2E i ich stop muszą być skomponowane w jednym tasku przez `internal/scripts/fullstack-run-stack-e2e.ps1`.
