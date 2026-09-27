# Reusable SDLC scripts

Katalog zawiera skrypty wspólne dla Windows/Git Bash oraz workflowów Angular, Spring Boot i full-stack.

## Kontrakt wywołania

Każdy skrypt przyjmuje:

```text
--config PATH       wersjonowany plik sdlc YAML
--workspace PATH    katalog projektu (domyślnie CRONOVA_PROJECT_DIR, workspace.directory z configu albo repozytorium)
--artifacts PATH    katalog wyników (domyślnie CRONOVA_ARTIFACTS_DIR, artifacts.directory z configu albo artifacts)
```

DAG opisuje kolejność zadań. Konfiguracja opisuje stack technologiczny i parametry projektu. Skrypt wykonuje operację.

## Windows

Pipeline docelowo działa na Windows i używa Git Bash. Skrypty nie mogą zawierać prywatnych ścieżek autora ani założeń o `/tmp`, `systemd`, `launchd` lub Unix socketach.

## Aktualny zakres

Pierwsza wersja zawiera:

- `configs/sdlc-angular.yaml`;
- `configs/sdlc-springboot.yaml`;
- `configs/sdlc-fullstack.yaml`;
- wspólny kontrakt `contracts/openapi.yaml`;
- podstawowe skrypty walidacji, npm, Angular build/test/lint;
- Spring Boot compile/test/package wrappers;
- instalację i uruchomienie Playwright;
- podstawowe DAG-i `sdlc_angular`, `sdlc_springboot_rest` i `sdlc_fullstack`.

Workspace’y i katalogi artefaktów są wybierane z konfiguracji projektu. Na Windows Cronova sprząta procesy potomne wraz z końcem taska (Job Object), dlatego start usług, readiness, E2E i ich stop muszą być skomponowane w jednym tasku przez `integration/run-stack-e2e.sh`. Skrypty Spring Boot i full-stack nadal wymagają natywnego testu Windows.
