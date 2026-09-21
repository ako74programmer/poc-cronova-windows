# Reusable SDLC scripts

Katalog zawiera skrypty wspólne dla Windows/Git Bash oraz workflowów Angular, Spring Boot i full-stack.

## Kontrakt wywołania

Każdy skrypt przyjmuje:

```text
--config PATH       wersjonowany plik sdlc YAML
--workspace PATH    katalog projektu (domyślnie CRONOVA_PROJECT_DIR lub repozytorium)
--artifacts PATH    katalog wyników (domyślnie artifacts)
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

Skrypty Spring Boot i full-stack wymagają dalszego spięcia z workspace’ami artefaktów oraz zarządzaniem procesami Windows Job Object.
