# Versioned SDLC configuration

Pliki w tym katalogu są częścią kontraktu pipeline’u i powinny być wersjonowane razem z DAG-ami oraz kontraktem OpenAPI.

- `sdlc-angular.yaml` — Node, Angular, npm, katalog frontendu, build i quality gate.
- `sdlc-springboot.yaml` — Java, Spring Boot, Maven Wrapper, backend i quality gate.
- `sdlc-fullstack.yaml` — artefakty i porty obu komponentów oraz ustawienia Playwright.

DAG nie powinien zawierać wersji technologii ani prywatnych ścieżek użytkownika. Zmiana wersji stacku powinna być zmianą konfiguracji poddaną przeglądowi i testom.

Konfiguracja nie może zawierać sekretów. Tokeny AI, hasła i dane dostawców muszą być dostarczane przez bezpieczne zmienne środowiskowe lub konfigurację cronova.
