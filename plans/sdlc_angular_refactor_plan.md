# Plan dalszego rozwoju `sdlc_angular`

## Cel

Dalszy krok dla `sdlc_angular` nie dotyczy już migracji shell → PowerShell, bo ta część została wykonana. Aktualny cel to:

1. utrzymać działający, PowerShellowy DAG komponentowy Angular,
2. oprzeć frontend na tym samym kontrakcie OpenAPI co backend,
3. zachować config-driven model workflow,
4. nie mieszać komponentowego DAG-a Angular z integracyjnym DAG-iem fullstack,
5. wrócić do rozwoju funkcjonalnego dopiero wtedy, gdy będziemy gotowi przejść na model kontraktowy frontendu.

## Stan obecny

- DAG: [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml)
- config: [configs/sdlc-angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/configs/sdlc-angular.yaml)
- wykonanie: `internal/scripts/angular-*.ps1`
- opis techniczny: [docs/SDLC_ANGULAR_TECHNICAL.md](c:/Users/Andrzej/Downloads/sdlc/cronova/docs/SDLC_ANGULAR_TECHNICAL.md)

## Co jest już zrobione

- [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml) działa na `type: powershell`,
- istnieje rodzina klocków `internal/scripts/angular-*.ps1`,
- task IDs są samoopisujące się i odpowiadają uruchamianym klockom,
- pełny run DAG-a zakończył się sukcesem,
- główna ścieżka nie rozwija już modelu shell/bash dla Angulara.

## Co nadal jest otwarte

- frontend nadal jest głównie pipeline'em scaffold + jakość techniczna,
- workflow nie jest jeszcze przestawiony na model „frontend z kontraktu OpenAPI”,
- nie ma jeszcze opisanego i wdrożonego docelowego sposobu generowania klienta API z [contracts/openapi.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/contracts/openapi.yaml),
- nie ma jeszcze decyzji, jak głęboko `sdlc_angular` ma wejść w generowanie CRUD/UI z kontraktu bez mieszania odpowiedzialności z DAG-iem fullstack.

## Zasady dalszych prac

1. Reużywalność: nowe kroki Angular nadal budujemy z małych klocków `.ps1`.
2. Minimalizm: nie ruszamy działającej ścieżki tylko po to, żeby ją przepisać ponownie.
3. Samoopisujące się nazwy: jeśli dojdą nowe taski, ich ID nadal mają odpowiadać nazwom klocków.
4. Config-driven: workspace, artifacts i kluczowe ustawienia mają dalej pochodzić z `configs/sdlc-angular.yaml`.
5. Windows-only: nie wracamy do wrapperów shellowych.
6. Modułowość: frontend pozostaje osobnym DAG-iem względem backendu; wspólnym źródłem prawdy jest kontrakt OpenAPI, a nie wspólny DAG komponentowy.

## Kolejność dalszych prac

### Etap 1. Potwierdzenie docelowego kontraktu frontendowego

- ustalić, które zasoby z [contracts/openapi.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/contracts/openapi.yaml) mają być podstawą dla Angulara,
- zdecydować, czy klient API ma być generowany automatycznie, czy tylko częściowo wspierany generacją,
- opisać granicę między odpowiedzialnością DAG-a Angular a DAG-a fullstack.

### Etap 2. Przejście na model kontraktowy

- oprzeć frontend na tym samym kontrakcie OpenAPI co backend,
- wygenerować klienta API i warstwę komunikacji z kontraktu,
- przygotować frontendowy CRUD oparty o kontrakt, ale bez integracji runtime z backendem w tym DAG-u,
- unikać hardkodowanych mocków; jeśli potrzebne będą mocki frontendowe, mają wynikać z kontraktu i być traktowane jako etap przejściowy przed integracją.

### Etap 3. Walidacja wykonania po zmianie zakresu

- uruchomić lokalną walidację krok po kroku dla zmienionych klocków,
- wykonać pełny run [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml) przez Cronova,
- potwierdzić, że wynik dalej jest zgodny z rolą DAG-a komponentowego.

### Etap 4. Dokumentacja końcowa

- zaktualizować [docs/SDLC_ANGULAR_TECHNICAL.md](c:/Users/Andrzej/Downloads/sdlc/cronova/docs/SDLC_ANGULAR_TECHNICAL.md),
- zaktualizować [dags/sdlc_angular.yaml.md](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml.md), jeśli zajdzie potrzeba,
- uzupełnić README i indeksy dopiero po potwierdzeniu docelowego kontraktu frontendowego.

## Hipoteza lokalna

Najtańsza dalsza ścieżka nie wymaga przebudowy samego DAG-a od zera, bo [configs/sdlc-angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/configs/sdlc-angular.yaml) i PowerShellowa warstwa wykonawcza już działają. Główny brak to nie runtime, tylko docelowy model kontraktowy frontendu oparty o OpenAPI.

## Stan po iteracji udrożnienia

Zrealizowane:

- helper configu Angular: [scripts/sdlc/common/AngularConfig.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/scripts/sdlc/common/AngularConfig.ps1),
- klocki PowerShell:
	- `angular-validate-config.ps1`
	- `angular-scaffold-from-config.ps1`
	- `angular-npm-install-from-config.ps1`
	- `angular-lint-from-config.ps1`
	- `angular-test-from-config.ps1`
	- `angular-build-from-config.ps1`
	- `angular-smoke-test-from-config.ps1`,
- przepięcie [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml) na `type: powershell` i samoopisujące się task IDs,
- pełny run DAG-a przez Cronova zakończony sukcesem:
	- run id: `sdlc_angular__manual_1791137650769022600`
	- wynik: `success`
	- task IDs nowej definicji:
		- `angular_validate_config`
		- `angular_scaffold_from_config`
		- `angular_npm_install_from_config`
		- `angular_lint_from_config`
		- `angular_test_from_config`
		- `angular_build_from_config`
		- `angular_smoke_test_from_config`

Wniosek po udrożnieniu:

- obecny DAG jest technicznie sprawny, ale nadal buduje głównie szkielet Angulara i jego jakość techniczną,
- docelowy sens biznesowy tego przepływu to frontend oparty o wspólny kontrakt OpenAPI, a nie sam scaffold.

## Następny krok

Przestawić zakres `sdlc_angular` z „scaffold quality pipeline” na „frontend z kontraktu OpenAPI”, zachowując osobność względem backendu i odkładając integrację runtime do osobnego przepływu fullstack.