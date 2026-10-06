# AGENT.md

## Cel repo

Repozytorium jest migrowane do modelu Windows-only.
Docelowo aplikacja, workflowy, instalacja, pakowanie i dokumentacja mają wspierać tylko Windows.
Nie utrzymujemy równolegle starej ścieżki bash/unix, jeśli nie jest już potrzebna.

## Główne założenia architektoniczne

1. PowerShell-first.
Wszystkie aktywne workflowy i skrypty operacyjne w repo mają docelowo działać przez PowerShell `.ps1`.

2. Windows-native.
Nie dokładamy nowych zależności od Bash, `systemd`, `launchd`, unix socketów ani skryptów `.sh`.

3. Clean code.
Zmiany mają iść w stronę prostoty, czytelności i małych odpowiedzialności.

4. DRY.
Nie duplikujemy logiki między DAG-ami, skryptami i wariantami workflowów.
Wspólne zachowania wynosimy do reużywalnych klocków.

5. Single responsibility.
Każdy skrypt powinien robić jedną rzecz dobrze.
DAG ma orkiestrwać kroki, a nie ukrywać dużą logikę w jednym tasku.

6. Modułowość.
Komponenty Angular, Spring Boot i Fullstack mają być rozdzielone odpowiedzialnościami.
Komponentowe DAG-i budują swoje artefakty, a DAG integracyjny konsumuje gotowe wyniki.

7. Reużywalność.
Logika wykonawcza ma być budowana z małych klocków `internal/scripts/*.ps1`, które można składać w różnych DAG-ach.

8. Bezpieczne porządki.
Usuwamy tylko to, co zostało zweryfikowane jako nieaktywne, historyczne albo zastąpione przez ścieżkę PowerShell.
Jeżeli coś nie zostało jeszcze zmigrowane, nie usuwamy tego w ciemno.

## Ustalenia SDLC / DAG

1. `sdlc_angular` zostaje DAG-iem komponentowym.
2. `sdlc_springboot_rest` zostaje DAG-iem komponentowym backendu.
3. `sdlc_fullstack` ma być DAG-iem integracyjnym, a nie komponentowym.
4. `sdlc_fullstack` ma konsumować artefakty i kontrakt zamiast budować frontend/backend od zera.
5. Cross-DAG zależności mają odzwierciedlać realną orkiestrację, tak aby `#/graph` pokazywał prawdziwe relacje DAG -> DAG.

## Stan aktywnej ścieżki runtime

Aktywne DAG-i zostały już przepięte na PowerShell:

- `dags/sdlc_angular.yaml`
- `dags/sdlc_springboot_rest.yaml`
- `dags/sdlc_fullstack.yaml`

Aktywne klocki wykonawcze są w:

- `internal/scripts/angular-*.ps1`
- `internal/scripts/springboot-*.ps1`
- `internal/scripts/fullstack-*.ps1`
- `internal/scripts/maven-*.ps1`
- `internal/scripts/ai-*.ps1`

## Najważniejsze ustalenia operacyjne

1. Do realnego runtime używamy `scripts/windows/app.ps1 start`.
Nie używać `scripts/windows/app.ps1 start-dev` do walidacji docelowego przepływu, bo rozjeżdża runtime, DB i auth względem właściwej ścieżki.

2. Najpierw udrożnienie i test jak użytkownik, potem dokumentacja.
Dokumentacja nie może wyprzedzać działającej ścieżki runtime.

3. Nie wracamy do architektury eksperymentalnej.
Najpierw działający przepływ, potem porządki opisowe.

4. Po pierwszym działającym cięciu walidujemy lokalnie najwęższym możliwym testem.

## Stan techniczny po tej sesji

### Zrobione

- `sdlc_angular` działa jako DAG komponentowy na PowerShell.
- `sdlc_springboot_rest` działa jako DAG komponentowy na PowerShell.
- `sdlc_fullstack` został zredukowany do integracji-only i działa na PowerShell.
- dodano cross-DAG `trigger_after` dla realnej orkiestracji.
- usunięto stare bashowe skrypty SDLC z głównej ścieżki repo.
- usunięto bashowe entrypointy z `internal/scripts` w głównym repo.
- usunięto historyczną kopię `sdlc-verify/cronova-verify`.
- usunięto unixowe skrypty instalacji/pakowania niepasujące do modelu Windows-only.
- wyczyszczono lokalną bazę testową i dane runów.
- wyczyszczono wygenerowane workspace'y, artefakty, `.tmp` i lokalny `.m2` cache.

### Nadal otwarte

1. `deploy/install.ps1` nadal wymaga Git Bash i zapisuje `bash_path` do konfiguracji.
To jest osobny, realny blocker pełnego domknięcia Windows-only.

2. Runtime fullstack wymaga dalszej walidacji.
Wcześniej aktywny problem dotyczył finalizacji `playwright_e2e` w live runtime.
Przed kolejną serią zmian trzeba to jutro przetestować na czystym stanie.

## Najważniejsze poprawki runtime już wprowadzone

- `internal/scheduler/scheduler.go`
  - wsparcie `dependency_sync_key`
  - recovery z persisted exit code
  - recovery z completed log output w ścieżce await completion

- `internal/executor/state.go`
  - `ReadExitCode(stateDir, ref string)`

- `internal/executor/state_windows.go`
  - poprawione sprawdzanie żywotności procesu przez realny Windows exit code (`259` jako still active)

- testy
  - `internal/scheduler/dependency_event_test.go`
  - `internal/executor/runner_test.go`

## Zasady dalszej migracji

1. Każdy nowy workflow lub refaktor ma zaczynać się od pytania:
czy to jest potrzebne w aktywnej ścieżce Windows-only?

2. Jeśli istnieje odpowiednik `.ps1`, stary `.sh` powinien zostać usunięty po weryfikacji użyć.

3. Jeśli coś jest historyczne, zduplikowane albo testowe, preferowane jest usunięcie całego drzewa zamiast utrzymywania martwej kopii.

4. Jeśli coś nadal jest potrzebne, ale ma złą odpowiedzialność, najpierw rozdzielić logikę na mniejsze klocki, potem przepinać DAG.

5. Nie budować nowych wrapperów bashowych.

6. Nie mieszać odpowiedzialności komponentowych i integracyjnych.

7. Nie duplikować konfiguracji i logiki między Angular, Spring Boot i Fullstack, jeśli można użyć wspólnego helpera PowerShell.

## Podejście do kodu

### Clean code

- małe funkcje i małe skrypty
- czytelne nazwy tasków i plików
- brak ukrytej magii w wrapperach
- jawne wejścia i wyjścia
- minimum efektów ubocznych

### DRY

- wspólne helpery w `internal/scripts/common/*.ps1` lub podobnych modułach
- brak kopiowania tej samej logiki walidacji, toolchainu i ścieżek między skryptami

### Single responsibility

- walidacja configu osobno
- scaffold osobno
- compile/test/package osobno
- integracja runtime osobno
- collect/archive osobno

### Modułowość

- DAG opisuje orkiestrację
- skrypt `.ps1` opisuje pojedynczy krok
- helper opisuje wspólną logikę techniczną

### Reużywalność

- skrypty mają być parametryzowane i możliwe do użycia w więcej niż jednym DAG-u
- unikać logiki zaszytej pod jeden konkretny workflow, jeśli można ją wynieść poziom niżej

## Priorytet na jutro

1. Testować na czystym stanie po porządkach.
2. Uruchamiać przez `scripts/windows/app.ps1 start`.
3. Zweryfikować end-to-end `sdlc_fullstack` jak użytkownik.
4. Jeśli problem z `playwright_e2e` wróci, wejść bezpośrednio w ścieżkę finalizacji runtime, a nie wracać do szerokiej architektury.
5. Po stabilizacji runtime wrócić do migracji `deploy/install.ps1` z zależności od Git Bash.

## Krótkie podsumowanie intencji

To repo nie ma już być hybrydą Windows + Bash + Unix.
Ma zostać uporządkowane do jednej wspieranej ścieżki:

- Windows-only
- PowerShell-first
- małe reużywalne klocki
- komponentowe DAG-i + integracyjny fullstack
- porządki robione bezpiecznie, ale konsekwentnie
