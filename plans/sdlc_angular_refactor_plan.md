# Plan refaktoryzacji `sdlc_angular`

## Cel

Przepisać `sdlc_angular` z modelu shell + `scripts/sdlc/angular/*.sh` do modelu:

1. wykonanie jest złożone z małych klocków `.ps1`,
2. task IDs są samoopisujące się,
3. frontend jest budowany z tego samego kontraktu OpenAPI co backend, ale w osobnym przepływie,
4. config workflow pozostaje wersjonowanym wejściem do klocków,
5. główna ścieżka jest Windows-only i nie rozwija dalej shell/bash,
6. dokumentacja zostaje domknięta dopiero po potwierdzeniu pełnego runa DAG-a i po ustaleniu docelowego kontraktu frontendowego.

## Stan obecny

- DAG: [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml)
- config: [configs/sdlc-angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/configs/sdlc-angular.yaml)
- wykonanie: `scripts/sdlc/angular/*.sh`
- opis techniczny: [docs/SDLC_ANGULAR_TECHNICAL.md](c:/Users/Andrzej/Downloads/sdlc/cronova/docs/SDLC_ANGULAR_TECHNICAL.md)

Problem:

- DAG nadal używa `type: shell` i komend `bash ...`;
- task IDs opisują etapy biznesowo, ale nie są nazwami docelowych klocków `.ps1`;
- repo nie ma jeszcze rodziny `internal/scripts/angular-*.ps1`;
- config Angular jest już sensownie wydzielony, ale nie opisuje jeszcze frontendu generowanego z kontraktu OpenAPI;
- dokumentacja nadal opisuje stan shellowy i zostaje zaktualizowana dopiero po domknięciu udrożnienia.

## Zasady refaktoru

1. Reużywalność: każdy krok Angular ma być osobnym klockiem `.ps1`.
2. Minimalizm: najpierw odtworzyć istniejący kontrakt DAG-a, bez rozszerzania zakresu o nowe funkcje.
3. Samoopisujące się nazwy: task ID ma odpowiadać nazwie uruchamianego klocka.
4. Config-driven: workspace, artifacts i kluczowe ustawienia mają dalej pochodzić z `configs/sdlc-angular.yaml`.
5. Windows-only: nie budujemy nowych wrapperów shellowych.
6. Modułowość: frontend pozostaje osobnym DAG-iem względem backendu; wspólnym źródłem prawdy jest kontrakt OpenAPI, a nie wspólny DAG komponentowy.

## Kolejność prac

### Etap 1. Wspólny odczyt configu Angular

- sprawdzić, czy wystarczy prosty helper Angular analogiczny do Spring Boot,
- helper ma zwracać ustandaryzowane wartości dla workspace, artifactów, runtime Node/npm i sekcji `angular`.

### Etap 2. Backend klocków Angular `.ps1`

- `angular-validate-config.ps1`
- `angular-scaffold-from-config.ps1`
- `angular-npm-install-from-config.ps1`
- `angular-lint-from-config.ps1`
- `angular-test-from-config.ps1`
- `angular-build-from-config.ps1`
- `angular-smoke-test-from-config.ps1`

### Etap 3. Udrożnienie DAG-a Angular

- przepisać [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml) na `type: powershell`,
- zastąpić shellowe komendy wywołaniami nowych klocków,
- zmienić task IDs na samoopisujące się nazwy klocków.

### Etap 4. Walidacja wykonania

- uruchomić lokalną walidację krok po kroku dla każdego nowego klocka,
- przepiąć [dags/sdlc_angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml) na nowe klocki,
- wykonać pełny run DAG-a przez Cronova i potwierdzić sukces na nowych task IDs.

### Etap 5. Dokumentacja

- dodać `.ps1.md` dla nowych klocków Angular,
- dodać [dags/sdlc_angular.yaml.md](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_angular.yaml.md), jeśli go jeszcze nie ma,
- zaktualizować [docs/SDLC_ANGULAR_TECHNICAL.md](c:/Users/Andrzej/Downloads/sdlc/cronova/docs/SDLC_ANGULAR_TECHNICAL.md),
- zaktualizować indeksy i README po potwierdzeniu finalnego kontraktu.

### Etap 6. Przejście na model kontraktowy

- oprzeć frontend na tym samym [contracts/openapi.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/contracts/openapi.yaml), z którego korzysta backend,
- wygenerować klienta API i warstwę komunikacji z kontraktu,
- przygotować frontendowy CRUD oparty o kontrakt, ale bez integracji runtime z backendem w tym DAG-u,
- unikać hardkodowanych mocków; jeśli potrzebne będą mocki frontendowe, mają wynikać z kontraktu i być traktowane jako etap przejściowy przed integracją.

## Hipoteza lokalna

Najtańsza ścieżka refaktoru nie wymaga nowego modelu konfiguracji, bo [configs/sdlc-angular.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/configs/sdlc-angular.yaml) jest już rozdzielony sensownie. Główny brak to warstwa wykonawcza: shellowe skrypty Angular trzeba zastąpić rodziną klocków `.ps1`, zachowując obecny kontrakt DAG-a.

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