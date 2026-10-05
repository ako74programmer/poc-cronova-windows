# Plan refaktoryzacji `sdlc_fullstack`

## Cel docelowy

Ustalone rozwiązanie docelowe jest następujące:

1. zostawić [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml) jako DAG komponentowy,
2. zostawić DAG Spring Boot jako DAG komponentowy,
3. odchudzić [dags/sdlc_fullstack.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_fullstack.yaml), żeby konsumował artefakty i kontrakt zamiast budować komponenty od zera,
4. dodać cross-DAG zależności, żeby `#/graph` pokazywał realną orkiestrację DAG -> DAG.

## Stan obecny

- [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml) jest działającym DAG-iem komponentowym Angular.
- komponent Spring Boot jest nadal wykonywany przez osobny DAG komponentowy, ale trzeba potwierdzić właściwy aktywny plik DAG dla tego przepływu.
- [dags/sdlc_fullstack.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_fullstack.yaml) został już technicznie udrożniony na PowerShell, ale nadal zawiera taski komponentowe frontend/backend.
- globalny graph DAG-ów jest pusty, bo nie ma jeszcze relacji cross-DAG (`trigger_after`).

## Problem do rozwiązania

- `sdlc_fullstack` nadal buduje frontend i backend zamiast konsumować ich artefakty.
- przez to `sdlc_fullstack` nie jest jeszcze prawdziwym DAG-iem integracyjnym.
- `#/graph` nie pokazuje orkiestracji, bo nie ma zależności DAG -> DAG.

## Zasady realizacji

1. Nie cofamy działających klocków PowerShell.
2. Redukujemy odpowiedzialność `sdlc_fullstack`, zamiast rozbudowywać ją dalej.
3. Artefakty komponentowe pozostają kontraktem wejściowym dla integracji.
4. Cross-DAG graph ma odzwierciedlać realną architekturę, nie tylko wizualizację.

## Plan wykonania

### Etap 1. Ustalenie aktywnego DAG-a komponentowego Spring Boot

- aktywnym DAG-iem komponentowym backendu dla bieżącego modelu jest [dags/sdlc_springboot_rest.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_rest.yaml),
- używa on [configs/sdlc-springboot.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/configs/sdlc-springboot.yaml) i publikuje artefakty do `artifacts/springboot`,
- nie zmieniać Angular DAG-a poza ewentualnym doprecyzowaniem artefaktów wejścia/wyjścia.

### Etap 2. Redukcja `sdlc_fullstack` do integracji-only

Usunąć z `sdlc_fullstack` taski komponentowe:

- `validate_frontend_config`
- `validate_backend_config`
- `scaffold_frontend`
- `scaffold_backend`
- `generate_contract_app`
- `install_frontend_dependencies`
- `lint_frontend`
- `test_frontend`
- `build_frontend`
- `smoke_test_frontend`
- `compile_backend`
- `test_backend`
- `package_backend`

Zostawić tylko taski integracyjne:

- `validate_stack`
- `install_playwright`
- `playwright_e2e`
- `collect_logs`
- `archive_results`

oraz ewentualnie jawne walidacje obecności artefaktów, jeśli będą potrzebne jako osobne taski integracyjne.

### Etap 3. Konsumpcja artefaktów komponentowych

- `sdlc_fullstack` ma używać artefaktów z DAG-a Angular i DAG-a Spring Boot,
- nie ma już generować ani budować komponentów samodzielnie,
- kontrakt wejściowy pozostaje oparty o [contracts/openapi.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/contracts/openapi.yaml) oraz manifesty/artefakty komponentowe.

### Etap 4. Cross-DAG zależności

- dodać zależności DAG -> DAG tak, aby `sdlc_fullstack` uruchamiał się po sukcesie DAG-a Angular i DAG-a Spring Boot,
- zwalidować wynik przez MCP `get_dag_graph`,
- zwalidować wynik w `#/graph`.

### Etap 5. Walidacja końcowa

- uruchomić DAG-i komponentowe,
- potwierdzić, że `sdlc_fullstack` konsumuje gotowe artefakty,
- potwierdzić, że graph pokazuje realne krawędzie między DAG-ami,
- dopiero potem wrócić do dokumentacji.

## Hipoteza lokalna

Najbliższy mały krok, który realnie przybliża architekturę docelową, to usunięcie z [dags/sdlc_fullstack.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_fullstack.yaml) tasków komponentowych i pozostawienie tylko integracji runtime + E2E. To powinno być wykonane przed dodaniem `trigger_after`, bo dopiero wtedy graph będzie odzwierciedlał prawdziwy podział odpowiedzialności.

## Następny krok

Zredukować `sdlc_fullstack` do integracji-only przy założeniu, że backendowym DAG-iem komponentowym jest `sdlc_springboot_rest`.

## Stan po udrożnieniu Windows-only

Zrealizowane w aktywnej ścieżce runtime:

- [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml) działa już na `type: powershell` i klockach `internal/scripts/angular-*.ps1`,
- [dags/sdlc_springboot_rest.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_rest.yaml) działa już na `type: powershell` i klockach `internal/scripts/springboot-*.ps1`,
- [dags/sdlc_fullstack.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_fullstack.yaml) działa już na `type: powershell` i klockach `internal/scripts/fullstack-*.ps1`.

Wniosek porządkowy:

- stare skrypty `scripts/sdlc/**/*.sh` nie są już częścią aktywnej ścieżki wykonania DAG-ów SDLC,
- mogą być usuwane etapami z głównego repo, razem z późniejszym czyszczeniem dokumentacji opisującej model Git Bash.

## Ograniczenie porządków

- katalog [sdlc-verify/cronova-verify](c:/Users/Andrzej/Downloads/sdlc/cronova/sdlc-verify/cronova-verify) pozostaje historyczną kopią niemigrowaną do PowerShell,
- jego DAG-i i `internal/scripts/` nadal są bashowe, więc nie należy usuwać tam skryptów w ciemno w ramach porządków głównego repo,
- bezpieczny zakres usuwania bashowych pozostałości obejmuje najpierw aktywną ścieżkę głównego repo i dokumentację tej ścieżki.

## Stan porządków Windows-only

- usunięto historyczną kopię `sdlc-verify/cronova-verify`,
- usunięto bashowe entrypointy SDLC i `internal/scripts/*` z głównej ścieżki repo,
- usunięto unixowe skrypty pakowania i instalacji, które nie należą do modelu Windows-only,
- nadal otwarty pozostaje osobny temat migracji [deploy/install.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/deploy/install.ps1), bo ten instalator wciąż wymaga Git Bash i zapisuje `bash_path` do konfiguracji.