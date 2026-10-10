# Cronova — przewodnik użytkownika (Windows)

Przewodnik odnosi się do branchu `feature/windows-cmd-runtime-sdlc-2026-09-26`, commit `ec62092aaed0e855989c51e1e7da41c0cbe63de0` (HEAD sprawdzony 2026-10-10). Nazwy komend, parametrów, typów i kluczy pozostają w oryginalnej pisowni. Szczegółowe informacje o architekturze, konfiguracji, bezpieczeństwie i ograniczeniach: [Dokumentacja techniczna](WINDOWS_TECHNICAL.pl.md).

## 1. Co robi Cronova?

Cronova wykonuje workflowy DAG (grafy zadań i zależności) zgodnie z harmonogramem lub na żądanie. Zawiera scheduler, web console, REST API, CLI i opcjonalny samodzielny executor. Zadanie może wywoływać PowerShell, Python, SQL, JAR, HTTP albo inny DAG jako sub-workflow. W tym repo runtime Windows jest PowerShell-first; `type: shell`/Bash nie są obsługiwane.

Cronova uruchamia kod z uprawnieniami swojego procesu. Nie jest systemem sandboxującym niezaufane skrypty.

## 2. Wymagania

### Użytkownik pakietu Windows

- Windows 10/11 lub Windows Server, architektura amd64 (target tego repo).
- Rozpakowany release ZIP. Instalacja usług wymaga Administrator/UAC; instalacja per-user działa bez admina, po zalogowaniu.
- Interpretery i narzędzia są wymagane tylko wtedy, gdy korzystają z nich Twoje taski: np. Python, JDK/Java, Maven, Node.js/npm, Git/klient DB.
- Połączenie sieciowe jest potrzebne dla aktualizacji, webhooków/SMTP, pobierania scaffoldów i usług AI, jeśli używasz tych integracji.

### Deweloper

Do lokalnego builda/testów potrzebujesz Go `1.26.5` lub nowszego oraz Windows PowerShell dla skryptów repo. Skrypty mogą dodatkowo wymagać Python/Node/Java/Maven/Playwright w zależności od testu.

## 3. Instalacja i pierwsze uruchomienie

### Instalacja z pakietu

1. Pobierz i rozpakuj `cronova_windows_amd64.zip` do katalogu, do którego masz prawa.
2. Uruchom `setup.cmd` (dwuklik) albo użyj PowerShell:

   ```powershell
   .\setup.ps1 -Mode auto
   ```

3. W trybie Administrator/UAC wybierz instalację usług Windows; standardowo instalowane są `CronovaExecutor` i `Cronova`. Bez admina lub po odmowie UAC wybierany jest tryb per-user, który startuje po zalogowaniu.
4. Zapisz jednorazowe hasło admina wyświetlone przez setup, jeśli nie podano własnego. Nie umieszczaj go w repo ani w logach.
5. Otwórz domyślny adres `http://127.0.0.1:8090/` i zaloguj się.

Port można zmienić, przekazując `-Port`:

```powershell
.\setup.ps1 -Mode user -Port 8091
```

Dostępne są także `-AdminUser`, `-AdminPassword`, `-AiBaseUrl`, `-AiModel`; szczegóły zobacz w `deploy/setup.ps1` i [README instalatora](../deploy/README-INSTALL.md). Nie przekazuj hasła w publicznym poleceniu/terminalu współdzielonym: argumenty procesu mogą być widoczne dla lokalnych administratorów.

### Uruchomienie bez instalatora

Z checkoutu źródłowego na Windows, w PowerShell:

```powershell
.\scripts\windows\app.ps1 start
```

To buduje `cronova.exe` z checkoutu, wykrywa runtime tools, startuje serwer na loopback i wymusza auth. Konsola jest domyślnie pod `http://127.0.0.1:8090`. Zatrzymanie/status:

```powershell
.\scripts\windows\app.ps1 status
.\scripts\windows\app.ps1 stop
```

`start-dev` jest osobnym trybem developerskim: czyści tymczasową `.tmp\dev-cronova.db` i uruchamia z auth wyłączonym. Nie wystawiaj go do sieci. Do walidacji rzeczywistego runtime AGENT.md repo poleca `start`, nie `start-dev`.

### Zarządzanie usługą

Z konsoli administratora (tam, gdzie wymagane są uprawnienia SCM):

```powershell
cronova status
cronova stop
cronova start
cronova restart
```

`cronova restart` restartuje scheduler, pozostawiając executor uruchomiony; nie jest równoznaczne z zatrzymaniem całej pary. Wrappery instalacji i utrzymania: `deploy/install.ps1`, `deploy/update.ps1`, `deploy/uninstall.ps1`. Tryb user ma skrypt `internal\scripts\cronova-user.ps1` w katalogu instalacji.

## 4. Pierwsze wejście do konsoli

1. Zaloguj się kontem utworzonym przez `setup`/`cronova init`.
2. **DAGs** pokazuje workflowy, ich status, ostatnie runy i skrócone metryki.
3. Kliknij DAG, aby obejrzeć jego runy, graf tasków i ustawienia.
4. **Graph** pokazuje zależności pomiędzy DAG-ami, np. `trigger_after`.
5. **Pools** służy do ograniczania równoległości tasków.
6. **Variables & Connections** przechowuje wartości wykorzystywane w szablonach i połączeniach. Connection passwords są maskowane w UI; szyfrowanie w spoczynku zależy od key file serwera.
7. **Workers** pokazuje zdalne workery, tokeny dołączania i ich stan (gdy worker hub jest skonfigurowany).
8. **Audit** pokazuje zapisywane operacje administracyjne.
9. **API** pozwala zarządzać API tokens i otworzyć dokumentację OpenAPI aktualnego serwera.

Wyszukiwarka w topbarze filtruje listę albo przenosi bezpośrednio do DAG. Konsola ma EN/PL, jasny/ciemny motyw i zapamiętuje preferencje. Zmiany DAG/task zapisują się automatycznie po krótkim opóźnieniu — nie ma przycisku Save. Sprawdzaj badge `Saved`, `Saving…`, `Fix errors to save` lub `Save failed`. Zmiana harmonogramu aktywnego DAG może zacząć obowiązywać przy kolejnym ticku; wstrzymaj DAG przed większą edycją.

Widoczność akcji zależy od roli: `viewer` jest tylko do odczytu; admin może zarządzać. Nie traktuj UI jako osobnej warstwy uprawnień — operacje przechodzą przez API.

## 5. Utworzenie i uruchomienie DAG-a

### Przez konsolę

1. Kliknij `+ New DAG`, wybierz pusty DAG lub starter.
2. Nadaj unikalne `dag_id` i dodaj taski. Ustaw `schedule` albo pozostaw pusty harmonogram, jeśli DAG ma być ręczny.
3. Ustaw `deps` dla zależności. Upewnij się, że graf nie ma cyklu.
4. W edytorze komendy wybierz typ taska i, jeśli przydatne, wstaw variables, connections lub params z palety.
5. Obserwuj komunikaty walidacji i badge zapisu. Niepoprawny DAG nie jest zapisywany.
6. Uruchom ręcznie przyciskiem trigger lub z terminala, a wynik obserwuj w Runs & logs.

### Przez plik YAML

Zapisz plik `dags/daily_etl.yaml`:

```yaml
dag_id: daily_etl
schedule: "0 2 * * *"
timezone: "Europe/Warsaw"
start_date: 2026-10-01
catchup: false
max_active_runs: 1
default_retries: 2
tasks:
  - id: hello
    type: powershell
    command: "Write-Output 'Start {{ logical_date }}'"
  - id: python_step
    type: powershell
    command: "python .\scripts\daily.py --date '{{ logical_date }}'"
    deps: [hello]
```

Aby odpalić jednorazowo, pomiń `schedule`/ustaw `schedule: ""`. Przykłady w `dags/` są wersjozależne i część z nich wymaga toolchainu, parametrów lub AI provider. Zweryfikuj najpierw DAG oraz jego skrypty.

W lokalnym CLI (katalog roboczy i `-db` muszą wskazywać tę samą instancję co scheduler):

```powershell
cronova dags
cronova trigger daily_etl
cronova runs daily_etl -n 5
```

Scheduler musi działać, aby wykonać zakolejkowany run. `cronova dags` w lokalnym trybie czyta YAML z katalogu, ale nie wykonuje zadań samodzielnie.

### Harmonogramy i catchup

- `schedule: "0 2 * * *"` — standardowe 5 pol cron; domyślnie UTC, o ile jawnie nie ustawisz strefy.
- `schedule: "@every 30s"` — interwał.
- Puste `schedule` — ręczny, eventowy lub zależny od innego DAG-a workflow.
- `start_date` ogranicza najwcześniejszy okres; `catchup: true` pozwala uzupełniać pominięte okresy. Wielkość backlogu nadal podlega limitom.
- `cronova backfill <dag_id> -from YYYY-MM-DD -to YYYY-MM-DD` tworzy runy brakujących okresów (maks. 500 okresów na żądanie; istniejące okresy są pomijane; `to` nie wybiega poza teraz).

## 6. Typy zadań i przykłady

| `type` | Zastosowanie | Wymagania / uwagi |
|---|---|---|
| `powershell` | Domyślny typ. Komenda/skrypt PowerShell, w tym uruchamianie Python/Node/Maven/klientów CLI. | `powershell.exe`; narzędzia wywoływane muszą być dostępne dla konta wykonującego. |
| `python` | Kod Python przez operator Cronova. | Python hosta lub ustawienie `CRONOVA_PYTHON`. |
| `sql` | Zapytanie/statement do połączenia `conn`. | Konfiguracja connection i wspierany sterownik. SQL wykonuje się z prawami podanego konta DB. |
| `jar` | Komenda Java/JAR. | Java/JRE/JDK dostępne dla procesu. |
| `http` | Żądanie HTTP skonfigurowane w YAML, bez ręcznego skryptu. | Osiągalny endpoint; świadomie traktuj URL i dane odpowiedzi. |
| `subdag` | Uruchomienie innego DAG-a jako zadania potomnego. | `subdag: <dag_id>`; zagnieżdżenie ograniczone (zob. DAG reference). |

**Nie ustawiaj `type: shell` ani `type: bash`** — na tym branchu są odrzucane. Komenda wykonywana jako PowerShell, a nie `cmd.exe` ani Bash. W `python`/`sql` operator jest uruchamiany wewnątrz pomocniczego procesu Cronova; w `http` używa wbudowanego operatora. `jar` wymaga polecenia Java w środowisku.

Przykład HTTP:

```yaml
tasks:
  - id: send_event
    type: http
    http:
      method: POST
      url: "https://api.example.invalid/events"
      headers:
        Content-Type: application/json
      body: '{"run":"{{ run_id }}","date":"{{ logical_date }}"}'
      expected_status: [200, 202]
```

Przykład SQL:

```yaml
tasks:
  - id: count_rows
    type: sql
    conn: analytics
    command: "SELECT count(*) FROM events WHERE day = '{{ params.day }}'"
```

## 7. Retry, timeout, pule i kontrola runów

- `retries`, `retry_delay`, `retry_backoff: fixed|exponential` sterują ponawianiem taska. Ustaw timeout realistycznie; anulowanie procesu nie cofa już wykonanych zapisów w systemach zewnętrznych.
- `timeout` jest limitem pojedynczej próby; `dagrun_timeout` limitem runu. `sla` generuje alert po deadline, nie zatrzymuje taska/runu.
- `pool` przypisuje slot z puli; w konsoli **Pools** lub `cronova pools` zobaczysz nazwę i liczbę slotów. `cronova pools set <name> <slots>` ustawia limit (liczba dodatnia).
- `max_active_runs`, `max_active_tasks` i globalne limity ograniczają równoległość. `execution_policy` może być `parallel`, `serial_wait`, `serial_discard` lub `serial_priority`.
- `trigger_rule` definiuje, kiedy task może ruszyć względem upstream; sprawdź [DAG reference](DAG_REFERENCE.pl.md) po szczegóły.
- Wstrzymanie DAG-a (`cronova pause <dag_id>`) blokuje harmonogramowanie; nie oznacza automatycznego zatrzymania już działających zadań. `cronova pause <dag_id> -off` wznawia.
- Run detail pokazuje stany i logi. Dostępne działania obejmują cancel, retry oraz operator override stanu (zależne od roli/stanu). Retry uruchamia nową próbę; nie zakładaj, że poprzednia operacja zewnętrzna nie doszła do skutku.

## 8. Zmienne, połączenia, projekty i logi

### Template variables

Dostępne placeholdery w `command`, `http.url`, nagłówkach, body i SQL obejmują `{{ logical_date }}`, `{{ logical_datetime }}`, `{{ run_id }}`, `{{ dag_id }}`, `{{ task_id }}`, `{{ try_number }}`, `{{ var.KEY }}`, `{{ conn.ID.host }}` i `{{ params.KEY }}`. Wbudowane zmienne runu są również przekazywane jako środowiskowe `CRONOVA_*`. Parametry runu podaj w `cronova trigger ... -params '{"day":"2026-10-10"}'` albo w UI/API.

### Variables / Connections

Zarządzaj wartościami w **Variables & Connections**. Nie wkładaj poufnych danych do literalnych poleceń/YAML. Connection password jest zwracany maskowany; klucz `key_file` zabezpiecz w kopii DB i poza nią. Szyfrowanie nie obejmuje automatycznie arbitrary task output/logs.

### Project upload

Edytor taska udostępnia sekcję **Project** do przesłania katalogu lub ZIP. Task może wskazać `project: nazwa` i polecenie uruchamia się w świeżej kopii roboczej projektu dla próby, z `CRONOVA_PROJECT_DIR`. Ta funkcja dotyczy zadań `powershell`; nie łącz jej z `worker_group`. Osobne scheduler/executor muszą mieć zgodny współdzielony filesystem i uprawnienia.

### Runy i logi

Otwórz DAG → wybrany run → task, aby zobaczyć stan, próbę i log. UI udostępnia strumieniowanie logów na żywo; CLI zdalne ma `cronova logs <task_instance_id>`. stdout/stderr są logowane do plików. Logi podlegają limitom/retencji; nie wpisuj do nich haseł, tokenów ani danych wrażliwych.

## 9. Powiadomienia, zależności, worker i AI

- `trigger_after` uruchamia downstream po sukcesie DAG-a upstream. `depends_on_dag` pozwala taskowi czekać na pasujące uruchomienie innego DAG-a. `trigger_on_event` przyjmuje zdarzenia z API. Własność działania zależy od poprawnych identyfikatorów i konfiguracji serwera.
- `notify` konfiguruje webhook, e-mail SMTP lub grupę alertów. Testuj kanał i nie zapisuj tokenów webhooka w publicznym YAML.
- Workerzy są funkcją opcjonalną: admin tworzy jednorazowy join token, worker łączy się wychodząco przez mTLS, ma pasującą etykietę `group`, a DAG/task ustawia `worker_group`. Wymaga listenera hubu, routowalnego adresu `worker_advertise` i certyfikatów.
- AI w przykładowych DAG-ach SDLC wymaga skonfigurowanego providera/modelu; sama instalacja Cronova nie daje klucza ani dostępu do modelu. Konfiguracja `.vscode/mcp.json` jest przykładem integracji MCP klienta z lokalnym repo.
- `cronova mcp` obsługuje AI klienta przez stdio; ustaw `CRONOVA_SERVER` i `CRONOVA_TOKEN`, a do operacji odczytu stosuj `-read-only` i token minimalnej roli.

## 10. Przydatne komendy CLI

```powershell
cronova version
cronova healthcheck -http 127.0.0.1:8090
cronova dags
cronova trigger daily_etl -params '{"day":"2026-10-10"}' -priority 10
cronova runs daily_etl -n 10
cronova pools
cronova pause daily_etl
cronova pause daily_etl -off
cronova backfill daily_etl -from 2026-10-01 -to 2026-10-05
cronova prune -older-than 2160h
```

Zdalny CLI/API wymaga serwera i tokena; zwykłe polecenia lokalne używają lokalnej DB. Flagi globalne `-server`, `-token`, `-o json` zależą od komendy (sprawdź `cronova <command> -h` i [CLI reference](CLI.md)). Komendy administracyjne kont/tokenów dostępne są w `cronova users ...` i `cronova tokens ...`. Nie wstawiaj tokena dosłownie do skryptu przechowywanego w repo.

## 11. Aktualizacja, backup i odinstalowanie

- Aktualizacja binarek: `cronova update` pobiera pakiet i weryfikuje SHA-256, następnie może restartować usługi; używaj w oknie serwisowym. W razie błędu kod próbuje rollback.
- Backup online: `cronova backup <dest-dir>` tworzy spójny snapshot DB oraz plików konfiguracyjnych, key i katalogów DAG/projects (zakres komendy opisany w CLI). Kopia zawierająca bazę bez klucza szyfrowania może być bezużyteczna dla zapisanych connection passwords. Chronić backup jak dane produkcyjne.
- `deploy/uninstall.ps1` zachowuje dane domyślnie. `-Purge` usuwa dane — użyj dopiero po sprawdzeniu backupu i ścieżki.

## 12. Błędy i rozwiązania

| Błąd/objaw | Co sprawdzić |
|---|---|
| Konsola nie odpowiada | Czy scheduler działa? `cronova status`; czy port jest prawidłowy i wolny; czy bind to loopback/host; `cronova healthcheck`. |
| Pojawia się login, ale brak danych | Rola konta, wybór właściwej instancji/DB, czy scheduler załadował DAG YAML. |
| DAG nie przechodzi walidacji | Błędna składnia/nieznane pole, brak wymaganych `dag_id`/`tasks`, duplicate IDs, cykl, nieobsługiwany task `shell`. Porównaj z [DAG reference](DAG_REFERENCE.pl.md). |
| Run pozostaje queued | Czy `serve` działa, czy DAG nie jest held/paused, czy globalny limit/pool nie jest pełny i czy executor/worker jest dostępny. |
| Task failuje `command not found` | Brak narzędzia w PATH konta usługi. Sprawdź log, toolchain env oraz konto procesu. |
| Python/Java działa interaktywnie, a nie w usłudze | Usługi nie dziedziczą PATH zalogowanego użytkownika; skonfiguruj ścieżki/uruchom ponownie instalator. |
| Task retry powtarza zapis | Retry może ponowić działanie zewnętrzne; zastosuj klucz idempotencji/bezpieczny upsert po stronie docelowej. |
| Nie działa HTTPS/proxy | Sprawdź TLS termination, `secure_cookie`, `trusted_proxies` oraz bind/firewall. Nigdy nie ufaj forwarding headers od nieznanych proxy. |
| Hasła connections nieczytelne po odtworzeniu backupu | Zweryfikuj, czy odtworzono ten sam key file i ścieżkę. Nie kasuj ani nie regeneruj klucza przed odzyskiwaniem. |
| Update przerwany | Zachowaj log i sprawdź wersję/status usług; weryfikacja checksum jest obowiązkowa. Nie omijaj jej. |
| Playwright / SDLC failed | Sprawdź log taska, Node/npm/JDK/Maven, właściwe YAML `configs/`, provider credentials i lokalne porty. Wykonanie realnego SDLC nie jest zagwarantowane przez sam scheduler. |

## 13. FAQ

**Czy muszę instalować bazę danych?** Nie dla domyślnej instalacji — SQLite jest wbudowane. PostgreSQL jest opcją widoczną w implementacji, wymagającą osobnego serwera/DSN i migracji. Nie kopiuj aktywnego pliku SQLite jako backupu bez mechanizmu spójnego snapshotu.

**Czy Cronova uruchamia Python/Java/Node automatycznie?** Nie instaluje interpreterów. Zainstaluj zależność, jeśli wymaga jej Twój task, i sprawdź PATH konta usługi.

**Czy `type: shell` oznacza PowerShell?** Nie. Na tym branchu typ `shell` jest odrzucany. Użyj jawnego `type: powershell` albo właściwego typu operatora.

**Czy retry gwarantuje pojedynczy efekt?** Nie. Może powtórzyć task po błędzie/utracie executora. Zapewnij idempotencję po stronie usług docelowych.

**Czy mogę otworzyć konsolę w sieci?** Tylko po świadomym ustawieniu auth, binda, firewalla i TLS/reverse proxy. Default loopback jest bezpieczniejszy; nie włączaj `allow_unauthenticated_remote`.

**Czy po zatrzymaniu scheduler taski zawsze trwają?** Zależy od trybu executor i rodzaju restartu. Oddzielny executor jest projektowany do rozdzielenia cyklu życia; restart całej usługi/update i hard-kill mają inne skutki. Sprawdź status runu i log po operacji.

**Czy dokumentacja API jest w `contracts/openapi.yaml`?** Nie w tym branchu: plik zawiera przykładowe `Item API`. Użyj `/openapi.json` albo `/docs` na działającym serwerze.

**Czy istnieje build testowany w tym przewodniku?** Nie. Ten dokument został zweryfikowany statycznie względem wskazanego commita. Go/PowerShell/Windows nie były dostępne w środowisku autora; testy Windows trzeba uruchomić natywnie.

## 14. Dalsza lektura

- [Dokumentacja techniczna Windows](WINDOWS_TECHNICAL.pl.md)
- [Pierwsze kroki](GETTING_STARTED.pl.md) i [tutorial](tutorial/first-dag.pl.md)
- [Referencja DAG-ów](DAG_REFERENCE.pl.md), [CLI](CLI.md), [Deployment](DEPLOY.md)
- [Przewodnik konsoli](console/index.md), [agenci AI/MCP](AGENTS.md)
- [Indeks SDLC DAG](SDLC_DAGS.md)
