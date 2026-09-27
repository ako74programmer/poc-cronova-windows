# DAG-i SDLC — indeks techniczny

Ten indeks zbiera **wszystkie sześć DAG-ów** z katalogu `dags/`, ich przeznaczenie, główną rodzinę skryptów oraz link do szczegółowego opisu technicznego. Opisy są weryfikowane względem YAML-i i implementacji skryptów. Szczegółowy opis `sdlc_fullstack` uwzględnia udany run Windows na commicie `40b660a94d3788a0c10c1d029d5fa1a9152e8689`.

## Mapa DAG-ów

| DAG | Cel i główne etapy | Harmonogram w YAML | Rodzina skryptów | Szczegółowy opis |
|---|---|---|---|---|
| [`sdlc_angular`](../dags/sdlc_angular.yaml) | Walidacja → Angular scaffold → npm install → lint → testy → production build → smoke test | Ręczny | `scripts/sdlc/angular/`, `scripts/sdlc/common/` | [Opis Angular](SDLC_ANGULAR_TECHNICAL.md) |
| [`sdlc_fullstack`](../dags/sdlc_fullstack.yaml) | Walidacja → równoległe przygotowanie Angular/Spring Boot → build/test komponentów → jeden task integracyjny z backendem, frontendem i Playwright → logi/manifest | Ręczny | `scripts/sdlc/angular/`, `springboot/`, `integration/`, `playwright/`, `common/` | [Opis Fullstack](SDLC_FULLSTACK_TECHNICAL.md) |
| [`sdlc_springboot_rest`](../dags/sdlc_springboot_rest.yaml) | Walidacja konfiguracji i OpenAPI → Spring Initializr scaffold → compile → unit tests → JAR package | Ręczny | `scripts/sdlc/springboot/`, `integration/`, `common/` | [Opis Spring Boot REST](SDLC_SPRINGBOOT_REST_TECHNICAL.md) |
| [`sdlc_maven_luhn`](../dags/sdlc_maven_luhn.yaml) | Maven archetype → compile skeleton → AI feature Luhn → AI review/fix loop → Maven tests | Codziennie, `0 2 * * *` | `internal/scripts/` i prompt `prompts/luhn.txt` | [Opis Maven Luhn](SDLC_MAVEN_LUHN_TECHNICAL.md) |
| [`sdlc_springboot`](../dags/sdlc_springboot.yaml) | Lokalny template Spring Boot → compile → AI CRUD → AI review/fix loop → Maven tests | Codziennie, `0 2 * * *` | `internal/scripts/`, `templates/springboot-simple` | [Opis Spring Boot](SDLC_SPRINGBOOT_TECHNICAL.md) |
| [`sdlc_springboot_startio`](../dags/sdlc_springboot_startio.yaml) | Spring Initializr → compile → AI CRUD → AI review/fix loop → Maven tests | Codziennie, `0 2 * * *` | `internal/scripts/`, Spring Initializr | [Opis Spring Boot Start.io](SDLC_SPRINGBOOT_STARTIO.md) |

Harmonogram `0 2 * * *` jest interpretowany przez Cronova w UTC, jeśli DAG nie określa innej strefy. Wartości harmonogramu są deklaracją DAG-a — przed włączeniem automatycznego uruchamiania na danym środowisku należy sprawdzić konfigurację scheduler/executor i dostępność wymaganych sekretów/runtime.

## Gdzie jest szczegółowy opis?

Pięć przepływów miało już dokumenty techniczne. Dodano brakujący opis Fullstack, więc teraz każdy YAML w `dags/` ma odpowiadający mu opis:

| DAG | Dokument techniczny |
|---|---|
| `sdlc_angular` | [`SDLC_ANGULAR_TECHNICAL.md`](SDLC_ANGULAR_TECHNICAL.md) |
| `sdlc_fullstack` | [`SDLC_FULLSTACK_TECHNICAL.md`](SDLC_FULLSTACK_TECHNICAL.md) |
| `sdlc_maven_luhn` | [`SDLC_MAVEN_LUHN_TECHNICAL.md`](SDLC_MAVEN_LUHN_TECHNICAL.md) |
| `sdlc_springboot` | [`SDLC_SPRINGBOOT_TECHNICAL.md`](SDLC_SPRINGBOOT_TECHNICAL.md) |
| `sdlc_springboot_rest` | [`SDLC_SPRINGBOOT_REST_TECHNICAL.md`](SDLC_SPRINGBOOT_REST_TECHNICAL.md) |
| `sdlc_springboot_startio` | [`SDLC_SPRINGBOOT_STARTIO.md`](SDLC_SPRINGBOOT_STARTIO.md) |

## Rodziny implementacyjne i stopień reużywalności

W repozytorium istnieją dwie główne rodziny skryptów SDLC:

1. **`scripts/sdlc/` — deterministyczne skrypty komponentowe.** Angular, Spring Boot REST i Fullstack używają wspólnego bootstrapu, konfiguracji YAML, argumentów workspace/artifacts, logów i manifestów. Skrypty są reużywalne przede wszystkim w ramach technologii lub kontraktu (Angular, Spring Boot/Maven Wrapper, usługi HTTP, Playwright).
2. **`internal/scripts/` — istniejące klocki Maven/AI.** `sdlc_springboot`, `sdlc_springboot_startio` i `sdlc_maven_luhn` używają wspólnych narzędzi do scaffoldingu, Maven compile/test, generowania kodu AI i pętli review/fix. Różnią się źródłem projektu, domenowym promptem, pakietem i ścieżkami.

**Ocena ogólna:** DAG-i są składane z osobnych skryptów zamiast zawierać implementację bezpośrednio w YAML. „Reużywalny” nie oznacza „dowolny dla każdej technologii”: część klocków ma jawny kontrakt, np. Maven Wrapper, Spring Initializr, model CRUD `Item`, prosty format odpowiedzi AI lub konkretne wymagania Angulara. Szczegóły ograniczeń są opisane w poszczególnych przewodnikach.

W Fullstack task `playwright_e2e` celowo jest kompozytowym klockiem, który wywołuje istniejące skrypty backend/frontend/readiness/Playwright/cleanup w jednym procesie taska. Cronova na Windows sprząta potomne procesy przy zamknięciu Job Object taska, więc dzielenie długowiecznych serwisów na osobne taski nie zapewnia im życia do następnego etapu. Szczegóły znajdują się w [opisie Fullstack](SDLC_FULLSTACK_TECHNICAL.md#cykl-życia-w-windows-job-object).

## Procedura aktualizacji dokumentacji

Przy dodaniu lub zmianie DAG-a:

1. zaktualizuj odpowiadający mu szczegółowy opis, w tym taski, dependencies, timeouty, skrypty, config i artefakty;
2. zaktualizuj tabelę „Mapa DAG-ów” oraz listę dokumentów w tym pliku;
3. sprawdź wszystkie linki względne i potwierdź, że każdy `dags/*.yaml` ma wpis oraz opis;
4. odróżnij analizę statyczną od wyniku rzeczywistego testu środowiska — nie deklaruj testu, który nie został uruchomiony.
