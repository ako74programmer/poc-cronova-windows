# Pierwsze kroki z cronova

Zainstaluj cronova na Windows, uruchom harmonogram i konsolę webową, napisz i wyzwól swój pierwszy DAG, a następnie podłącz własne skrypty do workflow. To repozytorium jest przeznaczone dla Windows amd64 i używa Git for Windows Bash dla zadań `shell`.

Ten przewodnik jest zorientowany na zadania. Pełną specyfikację pól DAG-a znajdziesz w [Dokumentacji DAG-ów](DAG_REFERENCE.pl.md); wszystkie komendy i flagi w [Dokumentacji CLI](CLI.md); instrukcję produkcyjnej instalacji w [Wdrożeniu](DEPLOY.md). Nowy w cronova? Zacznij od [README](https://github.com/zoyluoblue/cronova#readme).

## 1. Zainstaluj cronova

Zalecaną ścieżką produkcyjną jest ZIP dla Windows. Najpierw zainstaluj Git for Windows, a następnie otwórz podniesiony PowerShell w rozpakowanym katalogu.

### Instalacja ZIP

```powershell
.\deploy\install.ps1
```

Dla niestandardowej instalacji Git użyj `-BashPath 'D:\Tools\Git\bin\bash.exe'`. Instalator tworzy `C:\ProgramData\Cronova`, instaluje scheduler i executor w `C:\Program Files\Cronova` oraz rejestruje obie usługi Windows. Zobacz [Wdrożenie](DEPLOY.md) po szczegóły aktualizacji i odzyskiwania.

### Budowanie ze źródeł

Zbuduj harmonogram, konsolę webową i CLI w jednej statycznej binarce z Go 1.26.5+:

```powershell
git clone https://github.com/zoyluo/cronova
cd cronova
go build -o cronova.exe ./cmd/cronova
go build -o cronova-executor.exe ./cmd/cronova-executor
```

Zwykłe `go build` zgłasza wersję jako `dev`. Binarka jest wolna od CGO (czysto-Go `modernc.org/sqlite`), więc nie jest wymagany łańcuch narzędzi C.

### Wydanie prebuilt

Pobierz `cronova_windows_amd64.zip` ze strony [Releases](https://github.com/ako74programmer/poc-cronova-windows/releases) i uruchom `deploy\install.ps1` z rozpakowanego katalogu:

```powershell
.\cronova.exe version        # wypisuje: cronova <version> windows/amd64
```

## 2. Uruchom harmonogram i otwórz konsolę

`cronova serve` uruchamia pętlę harmonogramu **oraz** konsolę webową + REST API w jednym procesie:

```bash
./cronova serve
```

Następnie otwórz **http://localhost:8090** — lista DAG-ów, historia uruchomień, stany zadań, podgląd logów na żywo i jednoklikowe wyzwalacze ręczne.

Domyślnie `serve` używa względnych ścieżek katalogu roboczego i executoru w procesie:

| Ustawienie | Flaga | Zmienna środowiskowa | Domyślnie |
|---|---|---|---|
| Adres konsoli + API | `-http` | `CRONOVA_HTTP` | `127.0.0.1:8090` (tylko loopback) |
| Katalog z YAML-ami DAG-ów | `-dags` | `CRONOVA_DAGS` | `dags` |
| Baza SQLite | `-db` | `CRONOVA_DB` | `data/cronova.db` |
| Katalog logów zadań | `-logs` | `CRONOVA_LOGS` | `logs` |
| Przesłane projekty | `-projects` | `CRONOVA_PROJECTS` | `~/.cronova/projects` |
| Katalogi workspace'ów prób | `-workspaces` | `CRONOVA_WORKSPACES` | katalog tymczasowy systemu |
| Tick harmonogramu | `-tick` | `CRONOVA_TICK` | `2s` |
| Cel executor gRPC | `-executor` | `CRONOVA_EXECUTOR` | *(pusty = w procesie)* |
| Wymagaj logowania | `-auth` | `CRONOVA_AUTH` | *(wyłączone dla lokalnego `serve`; `init` domyślnie włącza)* |
| Zezwól na nieuwierzytelniony zdalny bind | `-allow-unauthenticated-remote` | `CRONOVA_ALLOW_UNAUTHENTICATED_REMOTE` | `false` |

Ustawienia rozwiązywane są w kolejności ważności, od najwyższej: **jawna flaga → zmienna `CRONOVA_*` → plik konfiguracyjny `cronova.yaml` → wbudowana wartość domyślna**. Plik konfiguracyjny jest opcjonalny; `serve` zgłasza błąd brakującej konfiguracji tylko wtedy, gdy jawnie podasz `-config`.

> Domyślny executor w procesie uruchamia zadania wewnątrz ręcznego procesu `serve`, więc restart kończy działające zadania. Zarządzane instalacje domyślnie używają rozdzielonego executor gRPC. Dla ręcznej pary użyj absolutnego gniazda `unix:///...` w prywatnym (`0700`) katalogu i jawnej współdzielonej ścieżki workspace. Cele executor TCP są odrzucane. Zobacz [Wdrożenie](DEPLOY.md).

Steruj tym samym serwerem z innego terminala za pomocą CLI:

```bash
./cronova dags                  # listuj DAG-i załadowane z ./dags
./cronova trigger example_etl   # utwórz ręczne uruchomienie
./cronova runs example_etl      # historia uruchomień + stany zadań
```

### Włączanie logowania

Uwierzytelnianie jest wyłączone dla zwykłego deweloperskiego `serve`, ale listener jest tylko na loopback. Cronova odmawia nieuwierzytelnionego bindu nie-loopback, chyba że ustawiono jawną niebezpieczną opcję nadpisania. Włącz logowanie i zasiej admina przed wystawieniem konsoli:

```bash
./cronova init                 # zapisuje hash admina bezpośrednio w SQLite
./cronova serve -auth
```

Kontami zarządzasz też za pomocą `cronova users add|list|passwd|delete`.
`cronova init` zapisuje `cronova.yaml` plus szablon nadpisania środowiska `0600` bez poświadczeń; nigdy nie zostawia hasła admina w długotrwałym pliku.
Szczegóły w [Dokumentacji CLI](CLI.md).

## 3. Napisz swój pierwszy DAG i wyzwól go

**DAG** (skierowany graf acykliczny) to zbiór zadań połączonych krawędziami zależności, zdefiniowany jako plik YAML w katalogu `./dags/`. Każde zadanie działa jako podproces OS. Utwórz `dags/hello.yaml`:

```yaml
dag_id: hello
schedule: "@every 1m"        # cron ("0 2 * * *") lub interwał ("@every 30s"); pomiń dla ręcznego
start_date: 2026-06-01
catchup: false               # true = uzupełnij przegapione okresy od start_date
max_active_runs: 1
default_retries: 0
tasks:
  - id: greet
    type: shell
    command: echo "hello from cronova at $CRONOVA_LOGICAL_DATETIME"
  - id: report
    type: shell
    command: echo "run $CRONOVA_RUN_ID finished greeting"
    deps: [greet]            # działa po sukcesie greet
```

Harmonogram ładuje pliki `*.yaml` i `*.yml` z katalogu DAG-ów. Nieprawidłowy plik jest logowany i pomijany, a nie fatalny. Zobacz uruchamialne przykłady w [`dags/`](https://github.com/zoyluoblue/cronova/tree/main/dags) — `example_etl.yaml`, `ticker.yaml`, `upstream_ingest.yaml` i `downstream_report.yaml`.

Teraz uruchom to. Przy działającym `serve` wylistuj i wyzwól DAG:

```bash
./cronova dags                # hello pojawia się z SCHEDULE=@every 1m
./cronova trigger hello       # utwórz ręczne uruchomienie — serve wykona je przy następnym ticku
./cronova runs hello          # obserwuj stany zadań: greet, potem report
```

`cronova trigger` tworzy tylko wiersz uruchomienia; działający `cronova serve` wykonuje je przy następnym ticku (domyślnie co `2s`). Możesz też wyzwolić z konsoli jednym kliknięciem lub przekazać parametry wyzwalania jako JSON:

```bash
./cronova trigger hello -params '{"day":"2026-01-01"}'
```

Typowe pola zadań — `type` (`shell`, `python`, `sql`, `jar`, `http`), `command`, `deps`, `pool`, `retries`, `retry_delay`, `timeout`, `trigger_rule`, `project` — oraz pola na poziomie DAG-a, takie jak `schedule`, `catchup`, `max_active_runs`, `default_retries`, `trigger_after` i `dagrun_timeout`, są w pełni udokumentowane w [Dokumentacji DAG-ów](DAG_REFERENCE.pl.md).

## 4. Zmienne szablonowe

Każde `command` zadania (oraz URL, nagłówki i ciało zadania `http`) może odwoływać się do zmiennych szablonowych za pomocą `{{ … }}`. Harmonogram podstawia je dla każdej instancji zadania; nieznane placeholdery pozostawia nietknięte, więc zwykłe nawiasy shella nie są niszczone.

### Wbudowane zmienne uruchomienia

Są zawsze dostępne, a te same wartości są również wstrzykiwane jako zmienne środowiskowe `CRONOVA_*`:

| Szablon | Zmienna środowiskowa | Wartość |
|---|---|---|
| `{{ run_id }}` | `CRONOVA_RUN_ID` | Unikalne id tego uruchomienia |
| `{{ dag_id }}` | `CRONOVA_DAG_ID` | Id DAG-a |
| `{{ task_id }}` | `CRONOVA_TASK_ID` | Id zadania |
| `{{ try_number }}` | `CRONOVA_TRY_NUMBER` | Numer próby (rośnie przy retry) |
| `{{ logical_date }}` | `CRONOVA_LOGICAL_DATE` | Logiczna data uruchomienia, `YYYY-MM-DD` |
| `{{ logical_datetime }}` | `CRONOVA_LOGICAL_DATETIME` | Logiczna data jako RFC 3339 |

**Logiczna data** to to, co czyni catchup sensownym: uruchomienie backfill przetwarza dane dla okresu, który reprezentuje, a nie zegarowej „teraz". Użyj dowolnej formy:

```yaml
tasks:
  - id: extract
    type: shell
    command: python extract.py --date {{ logical_date }}     # przez szablon
  - id: load
    type: shell
    command: echo "loading for $CRONOVA_LOGICAL_DATE"        # przez zmienną środowiskową
    deps: [extract]
```

### Parametry wyzwalania, zmienne i połączenia

Trzy dodatkowe przestrzenie nazw rozwiązują się leniwie ze stanu zarządzanego w konsoli (lub przez API):

- `{{ params.KEY }}` — parametr wyzwalania per uruchomienie (z `cronova trigger -params '{...}'` lub konsoli). Każdy parametr jest również eksportowany jako `CRONOVA_PARAM_<KEY>` (wielkimi literami).
- `{{ var.KEY }}` — zarządzana w UI **zmienna**. Pobierana ze store tylko gdy jest referencjonowana.
- `{{ conn.ID.field }}` — pole zarządzanego w UI **połączenia**. Prawidłowe pola to `host`, `port`, `login` (alias `user`), `password`, `type` i dowolne dodatkowe pole JSON jako `extra.KEY`.

```yaml
tasks:
  - id: notify
    type: shell
    command: curl -u {{ conn.api.login }}:{{ conn.api.password }} {{ var.webhook_url }}?day={{ params.day }}
```

> Zmienne i połączenia **nie są** masowo wstrzykiwane do środowiska każdego zadania — trafiają do niego tylko przez jawne referencje `{{ var.X }}` / `{{ conn.Y.Z }}`, więc sekrety nie wyciekają do env niepowiązanych zadań. Tylko zmienne `run` i `params` stają się zmiennymi `CRONOVA_*`.

W konsoli nie wpisujesz nawiasów `{{ }}`: wizualny edytor zadań renderuje każdą zmienną jako kolorową pigułkę, a pogrupowana paleta (wbudowane, zmienne, połączenia, parametry) wstawia je kliknięciem lub przeciągnięciem.

## 5. Uruchamiaj własne skrypty i projekty

Aby uruchomić prawdziwy skrypt lub całą bazę kodu, prześlij go jako **projekt** i wskaż w zadaniu shell. cronova przygotowuje świeżą, izolowaną kopię projektu jako katalog roboczy każdej próby.

Prześlij z konsoli (edytor zadań → **Project**). Możesz przesłać pojedynczy skrypt, cały folder lub `.zip` (automatycznie rozpakowywany). Następnie odwołaj się do projektu po nazwie:

```yaml
tasks:
  - id: run_main
    type: shell
    command: python3 main.py     # cwd to czysta kopia projektu, więc to się rozwiązuje
    project: my_app
```

Jak działa podpięcie projektu:

- Pole `project` jest honorowane tylko dla zadań **shell** (typy `python`/`sql`/`http` działają w procesie, gdzie katalog roboczy nie ma znaczenia).
- Każda próba otrzymuje **świeżą izolowaną kopię** przesłanego projektu jako swój `cwd`. Próby nigdy nie zakłócają się nawzajem, a ponowne przesłanie zaczyna obowiązywać przy następnym uruchomieniu.
- Ścieżka kopii jest eksportowana jako **`CRONOVA_PROJECT_DIR`**, więc skrypt może zlokalizować własne dołączone pliki danych.
- Nazwy projektów mogą zawierać litery, cyfry oraz `. _ -`. Przesyłane pliki są ograniczone rozmiarem (na plik i na projekt) i chronione przed path traversal / zip-slip.
- Zmiany wielu plików są przygotowywane i zamieniane atomowo; odrzucony upload pozostawia poprzednie drzewo projektu nietknięte.
- Katalog projektów domyślnie to `~/.cronova/projects`; nadpisz go za pomocą `-projects` / `CRONOVA_PROJECTS`. Jeśli katalog projektów nie jest skonfigurowany, przesyłanie jest wyłączone, a zadanie odwołujące się do projektu zakończy się niepowodzeniem w runtime — `cronova api POST /api/dags/validate` zwraca ostrzeżenie dla projektu, który nie został jeszcze przesłany.

### Częste pytania

**Skąd uruchamia się `python3 main.py`?**
Z czystej per-attempt kopii przesłanego projektu, więc ścieżka względna jak `main.py` lub `./main.py` się rozwiązuje. Absolutna ścieżka do tej kopii jest również w `CRONOVA_PROJECT_DIR`.

**Czy muszę ponownie przesyłać po edycji skryptu?**
Prześlij zmieniony plik ponownie (przesyłanie jest addytywne/upsert). Ponieważ każda próba kopiuje aktualny projekt, następne uruchomienie zobaczy zmianę — działające próby zachowują kopię, z którą zaczęły.

**Jakich języków może używać zadanie?**
Dowolnych na hoście. Zadanie `shell` może wywoływać Python, Node, binaria Go/Rust, `psql`, JAR — cokolwiek jest zainstalowane. Harmonogram jest w pełni rozdzielony od języka zadania.

**Dlaczego moje zadanie z projektem zakończyło się natychmiastowym niepowodzeniem?**
Najczęściej projekt nie został przesłany lub serwer nie ma skonfigurowanego katalogu projektów. Najpierw zwaliduj DAG; odpowiedź zaznacza `project`, który odwołuje się do czegoś brakującego.

## 6. Następne kroki

Masz teraz działający harmonogram, pierwszy DAG, zmienne szablonowe i zadanie oparte na projekcie. Dokąd dalej:

- [Dokumentacja DAG-ów](DAG_REFERENCE.pl.md) — każde pole DAG-a i zadania, wszystkie typy zadań (`shell`, `python`, `sql`, `jar`, `http`), reguły wyzwalania, `trigger_after` między DAG-ami, retries, timeouty i pule zasobów.
- [Dokumentacja CLI](CLI.md) — każda komenda i flaga `cronova`: `serve`, `trigger`, `dags`, `runs`, `pools`, `users`, `init` oraz czasowniki remote/agent.
- [Wdrożenie](DEPLOY.md) — instalacja jako usługa systemd/launchd, odporny na awarie executor gRPC, aktualizacje i pułapka service-`PATH`.
- [Agenci AI (MCP)](AGENTS.md) — pozwól agentom AI listować, tworzyć, walidować i wyzwalać DAG-i przez wbudowany serwer MCP i zdalne JSON CLI.
- [Architektura](ARCHITECTURE.md) — model wykonawczy i uzasadnienie projektowe.
- [FAQ](FAQ.pl.md) — częste pytania, odpowiedzi.
