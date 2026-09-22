# cronova FAQ — Najczęściej zadawane pytania

> **Windows-only:** To repozytorium jest przeznaczone dla Windows amd64. Używaj `deploy\install.ps1`, Windows Services, Git for Windows Bash oraz `deploy\update.ps1`. Starsze przykłady wdrożeń Unix w historycznych sekcjach nie dotyczą tego repozytorium; nadrzędną instrukcją jest [Wdrożenie](DEPLOY.md).

Odpowiedzi na najczęstsze pytania o cronova, lekki, samodzielnie hostowany **harmonogram workflow** i otwartoźródłową alternatywę dla Airflow / Azkabana — czym jest, jak się instaluje, gdzie przechowuje dane i jak uruchomić go w produkcji.

Ta strona rozszerza krótkie FAQ z [README](https://github.com/zoyluoblue/cronova#readme). Przewodniki krok po kroku znajdziesz w [Pierwsze kroki](GETTING_STARTED.pl.md), [Dokumentacji DAG-ów](DAG_REFERENCE.pl.md), [Dokumentacji CLI](CLI.md), [Agentach AI (MCP)](AGENTS.md), [Wdrożeniu](DEPLOY.md) i [Architekturze](ARCHITECTURE.md).

## Czym jest cronova?

cronova to otwartoźródłowy, samodzielnie hostowany **harmonogram workflow** (inaczej scheduler zadań / orkiestrator DAG-ów) napisany w Go. Harmonogramuje **DAG-i** — skierowane grafy acykliczne zadań — na wyzwalaczach cron lub interwałowych, uruchamia każde zadanie jako podproces OS przy użyciu własnych interpreterów hosta i dostarcza konsolę webową, REST API, CLI oraz endpoint MCP dla agentów AI. Zarządzane instalacje używają statycznego harmonogramu plus statycznego, samodzielnego executor i wbudowanej SQLite.

## Czy cronova jest alternatywą dla Apache Airflow?

Tak. cronova to lekka alternatywa dla [Apache Airflow](https://airflow.apache.org/) i Azkabana dla zespołów, które chcą harmonogramowania DAG-ów — zależności, retries, catchup / backfill, pule zasobów, interfejs webowy i REST API — **bez** uruchamiania stosu Python, osobnej bazy danych i brokera wiadomości. To kompaktowa para natywnych usług z wbudowaną bazą danych. Dla bardzo dużych, silnie opartych na wtyczkach platform danych Airflow pozostaje bogatszym ekosystemem. Zobacz [cronova vs Airflow](COMPARISON.md) dla porównania funkcja po funkcji.

## Czy cronova wymaga osobnej bazy danych, JVM-a lub Pythona?

Nie. Harmonogram i konsola webowa używają **wbudowanej SQLite** (czysto-Go `modernc.org/sqlite`, bez CGO), więc nie ma zewnętrznego Postgres/MySQL, ani Redis czy brokera Celery, ani JVM-a, ani runtime Python do zainstalowania. Zarządzane wdrożenia dodają tylko samodzielną binarkę executor. Python, Java, `psql` i inne interpretery są potrzebne na hoście tylko wtedy, gdy *twoje zadania* je wywołują.

## W jakich językach można pisać zadania?

W dowolnym języku na hoście. Zadania mają `type` równy `shell`, `python`, `sql`, `jar` lub `http`, a zadanie `shell` może wywołać cokolwiek na maszynie — Node, binaria Go, Rust, CLI i więcej. Harmonogram (Go) jest w pełni rozdzielony od języka zadania: każde zadanie działa jako podproces OS z własnymi interpreterami hosta. Typy zadań `sql` i `http` działają w procesie (sterowniki/klient HTTP wbudowane w binarkę) i nie wymagają niczego dodatkowego. Zobacz [Dokumentację DAG-ów](DAG_REFERENCE.pl.md) dla każdego typu zadania.

## Czym cronova różni się od cron?

Zwykły `cron` uruchamia izolowane komendy zgodnie z zegarem. cronova uruchamia **DAG-i**: zadania z zależnościami, retries, timeoutami, catchup / backfill, pulami współbieżności, wyzwalaczami między DAG-ami, konsolą webową z podglądem logów na żywo i REST API — orkiestracja, którą zwykle ręcznie buduje się wokół `crontab`. cronova nadal używa składni cron (`schedule: "0 2 * * *"`) i obsługuje również interwały `@every 30s` oraz ręczne DAG-i.

## Czy agenci AI mogą sterować cronova (MCP)?

Tak. cronova dostarcza wbudowany **serwer Model Context Protocol (MCP)** (`cronova mcp`), który udostępnia około 30 narzędzi (`list_dags`, `create_dag`, `validate_dag`, `trigger_dag`, `get_task_log`, `retry_task`, …), plus zdalne JSON CLI. Agenci sterują cronova przez **to samo tokenowo uwierzytelnione, rolami ograniczone API**, którego używają ludzie — zasięg agenta to dokładnie rola jego tokenu (`admin` = pełny CRUD + operacje, `viewer` = tylko do odczytu), a `cronova mcp -read-only` udostępnia tylko narzędzia do odczytu. Tokeny są generowane lokalnie za pomocą `cronova tokens create`, nigdy przez API. Pełna konfiguracja: [Agenci AI (MCP)](AGENTS.md).

## Jakie platformy są obsługiwane i jak zainstalować cronova?

cronova działa na **Linux i macOS**, zarówno na **amd64, jak i arm64**. Najszybsza ścieżka to instalator jednoliniowy, który pobiera pasujące wydanie prebuilt, weryfikuje jego SHA256, instaluje natywną usługę (systemd na Linux, launchd na macOS) i uruchamia interaktywny kreator konfiguracji:

```bash
curl -fsSL https://raw.githubusercontent.com/zoyluoblue/cronova/main/deploy/bootstrap.sh | sudo bash
```

Wolisz budować ze źródeł? Z Go 1.26.5+:

```bash
go build -o cronova ./cmd/cronova
./cronova serve                 # konsola pod http://localhost:8090
```

Prebuilt binarki są na stronie [Releases](https://github.com/ako74programmer/poc-cronova-windows/releases). Pełny przewodnik wdrożeniowy: [Wdrożenie](DEPLOY.md).

## Jakiego portu używa konsola?

Konsola webowa i REST API domyślnie działają na **`127.0.0.1:8090`** (tylko loopback). Otwórz `http://localhost:8090` po `cronova serve`. Zmień to za pomocą `-http`, `CRONOVA_HTTP` lub klucza `http:` w `cronova.yaml`. Bind nie-loopback przy wyłączonym auth jest odrzucany, chyba że ustawiono jawną niebezpieczną opcję nadpisania.

## Jak aktualizować cronova?

Uruchom `cronova update`. Pobiera najnowsze wydanie prebuilt dla twojego OS/arch z GitHub, weryfikuje je względem `SHA256SUMS`, atomowo zamienia obie binarki, zachowuje dostosowane definicje usług i restartuje harmonogram bez przerywania executor, który posiada trwające zadania:

```bash
cronova update                               # najnowsze wydanie, potem restart
cronova update v0.2.1                         # przypnij lub zdegraduj do konkretnego tagu
cronova update -proxy http://127.0.0.1:7890   # pobierz przez proxy
```

Nieprzypięta aktualizacja, która jest już aktualna, to no-op. Wersja przypięta zawsze się aplikuje, więc zarówno ponowna instalacja, jak i downgrade działają. `update` wymaga roota i **automatycznie eskaluje przez `sudo`** — ustaw `CRONOVA_NO_SUDO=1`, by samodzielnie zarządzać uprawnieniami. **Nie dotyka** konfiguracji, bazy danych ani DAG-ów. Za ograniczoną siecią `-proxy` honoruje również `CRONOVA_UPDATE_PROXY`, `HTTPS_PROXY` i `ALL_PROXY`. Zobacz [Wdrożenie](DEPLOY.md).

## Czy aktualizacja jest bezpieczna, jeśli przerwie się w połowie?

Tak. `update` tworzy kopię zapasową starych binarek i zarządzanych definicji usług przed zamianą, następnie restartuje i **potwierdza, że harmonogram faktycznie pozostaje uruchomiony** (nie tylko że się załadował). Jeśli restart się nie powiedzie, automatycznie wycofuje zmiany i przywraca poprzednią wersję. Brakujące/niekompletne `SHA256SUMS`, niezgodność sumy kontrolnej, zbyt duży payload lub downgrade do redirectu cleartext są krytyczne. Dostosowany unit/plist nigdy nie jest cicho nadpisywany; nowy kandydat jest zapisywany jako `*.dist`.

## Czy cronova jest odporny na awarie / gotowy do produkcji?

cronova jest zaprojektowany do niezawodnej pracy. Zarządzane instalacje domyślnie używają rozdzielonego **executor gRPC**, więc harmonogram może się restartować lub aktualizować **bez zabijania działających zadań** — po odzyskaniu ponownie podłącza się do trwających zadań bez podwójnego wykonania. Ręczny `serve` bez celu executor pozostaje w procesie i kończy aktywne zadania przy wyjściu. Zarządzane usługi udostępniają również gotowość świadomą executor, atomowe samoaktualizacje z rollbackiem oraz ścieżkę audytu. Zobacz [Wdrożenie](DEPLOY.md) i [Architekturę](ARCHITECTURE.md) dla modelu wykonawczego.

## Gdzie cronova przechowuje swoje dane?

Stan żyje w **wbudowanej bazie SQLite** plus na dysku: YAML-e DAG-ów, logi zadań i przesłane projekty. Dla `cronova serve` uruchomionego z katalogu roboczego domyślne ścieżki są względne: `data/cronova.db` (DB), `dags/` (DAG-i) i `logs/` (logi zadań). Przesłane projekty domyślnie trafiają do `~/.cronova/projects`. Po zainstalowaniu jako natywna usługa ścieżki są absolutne:

| Cel | Linux (systemd) | macOS (launchd) |
|---|---|---|
| SQLite DB | `/var/lib/cronova/cronova.db` | `/usr/local/var/cronova/cronova.db` |
| YAML DAG-ów | `/var/lib/cronova/dags/` | `/usr/local/var/cronova/dags/` |
| logi zadań | `/var/log/cronova/` | `/usr/local/var/log/cronova/` |
| konfiguracja | `/etc/cronova/cronova.yaml` | `/usr/local/etc/cronova/cronova.yaml` |
| przesłane projekty | `/var/lib/cronova/projects/` | `/usr/local/var/cronova/projects/` |
| katalogi workspace'ów prób | `/var/lib/cronova/workspaces/` | `/usr/local/var/cronova/workspaces/` |

Nadpisz je za pomocą odpowiednich flag `-db` / `-dags` / `-logs` / `-projects` /
`-workspaces`, zmiennych środowiskowych `CRONOVA_*` lub `cronova.yaml`.
Pełna tabela układu: [Wdrożenie](DEPLOY.md).

## Jak długo cronova przechowuje historię uruchomień?

**Domyślnie 90 dni.** Serwer automatycznie usuwa zakończone uruchomienia — ich wiersze w bazie i katalogi logów — gdy są starsze niż okno retencji (domyślnie `2160h`, czyli 90 dni). Zmień to za pomocą klucza `retention:` w `cronova.yaml`, flagi `-retention` w `cronova serve` lub zmiennej środowiskowej `CRONOVA_RETENTION`; ustaw `0`, by zachować wszystko na zawsze. Tylko zakończone uruchomienia wygasają — trwające nigdy nie są dotykane.

Rekordy audytu mają niezależne domyślne okno jednego roku (`audit_retention: 8760h` /
`CRONOVA_AUDIT_RETENTION` / `-audit-retention`), więc skrócenie retencji historii uruchomień nie usuwa jednocześnie śladu operacji.

Dla jednorazowego czyszczenia (lub wdrożenia działającego z wyłączoną retencją) użyj `cronova prune`:

```bash
cronova prune                    # usuń zakończone uruchomienia starsze niż 90 dni (pyta najpierw)
cronova prune -older-than 720h   # niestandardowe okno
cronova prune -yes               # pomiń potwierdzenie (skrypty / cron)
```

## Czy hasła połączeń są szyfrowane?

Tak. Hasła połączeń są szyfrowane **w spoczynku za pomocą AES-256-GCM**. Przy pierwszym starcie `cronova serve` automatycznie generuje plik klucza szyfrowania — `cronova.key`, uprawnienia `0600` — w swoim katalogu roboczym (dla instalacji usługowych jest obok DB, zobacz [Wdrożenie](DEPLOY.md)); wskaż inne miejsce za pomocą klucza `key_file:` w `cronova.yaml` lub zmiennej `CRONOVA_KEY_FILE`. **Wykonuj kopię zapasową tego pliku razem z bazą danych** — bez niego zapisane hasła połączeń są nieczytelne i trzeba je wprowadzić ponownie. Połączenia zapisane przed istnieniem szyfrowania (legacy plaintext) są automatycznie uaktualniane przy następnym starcie serwera. Aby zrezygnować, ustaw `key_file: none` — hasła są wtedy przechowywane jako plaintext, a serwer loguje ostrzeżenie przy starcie.

## Jak uruchomić cronova za reverse proxy?

Przypnij cronova do localhost i zakończ TLS na swoim proxy (nginx, Caddy, Traefik, …). Kreator jednoklikowy oferuje opcję bindu **„tylko ta maszyna (127.0.0.1)"** dokładnie w tym celu, lub ustaw `CRONOVA_HTTP=127.0.0.1:8090` (lub `-http 127.0.0.1:8090`). Przy serwowaniu przez HTTPS ustaw `CRONOVA_SECURE_COOKIE=true`. Wypisz nie-loopbackowe peery proxy w `auth.trusted_proxies` lub `CRONOVA_TRUSTED_PROXIES`; `X-Forwarded-*` z każdego innego źródła jest ignorowany. Konsola, REST API i strumień SSE live-log dzielą jeden listener HTTP. Zobacz [Wdrożenie](DEPLOY.md).

## Czy potrzebuję Docker lub Kubernetes?

Nie. cronova to scheduler podprocesów, który uruchamia zadania za pomocą **własnych interpreterów hosta**, więc wdraża się jako dwie małe statyczne binarki pod systemd (Linux) lub launchd (macOS) — bez obrazu kontenera do zbudowania, bez runtime do spakowania. Skonteneryzowanie wielojęzycznego schedulera zmusiłoby cię do wbudowania każdego runtime zadania w obraz; natywne usługi tego unikają. Jeśli mimo wszystko skonteneryzujesz harmonogram, zostaw samodzielnego executor na hoście i wskaż harmonogramowi na niego przez prywatne gniazdo Unix. Zobacz [Wdrożenie](DEPLOY.md).

## Jak odinstalować cronova?

Uruchom `cronova uninstall`. Zatrzymuje i usuwa natywną usługę oraz binarkę, ale **zachowuje twoje dane** (konfiguracja, DB, DAG-i, logi), więc zwykła deinstalacja jest odwracalna przez ponowną instalację. Dodaj `--purge`, by również usunąć dane:

```bash
cronova uninstall            # usuń usługę + binarkę, ZACHOWAJ dane
cronova uninstall --purge    # usuń również konfigurację, DB, DAG-i, logi
cronova uninstall -yes       # pomiń potwierdzenie (dla skryptów)
```

Podobnie jak inne mutujące komendy, `uninstall` wymaga roota i automatycznie eskaluje przez `sudo`. Zobacz [Wdrożenie](DEPLOY.md).

## Na jakiej licencji jest wydany cronova?

cronova jest wydany na **[Licencji MIT](https://github.com/zoyluoblue/cronova/blob/main/LICENSE)** — licencji permisywnej, która zezwala na użycie komercyjne i prywatne, modyfikację i redystrybucję.

## Zobacz też

- [README](https://github.com/zoyluoblue/cronova#readme) — ogólny opis projektu i szybki start
- [Pierwsze kroki](GETTING_STARTED.pl.md) — instalacja, pierwszy DAG, projekty, zmienne szablonowe
- [Dokumentacja DAG-ów](DAG_REFERENCE.pl.md) — każde pole DAG-a/zadania, typy zadań, wyzwalacze, pule
- [Dokumentacja CLI](CLI.md) — każda komenda i flaga `cronova`
- [Agenci AI (MCP)](AGENTS.md) — serwer MCP, zdalne CLI, tokeny, bezpieczeństwo
- [Wdrożenie](DEPLOY.md) — systemd/launchd, aktualizacje, odporny na awarie executor
- [Architektura](ARCHITECTURE.md) — uzasadnienie projektowe, model wykonawczy, diagramy
- [cronova vs Airflow](COMPARISON.md) — kiedy wybrać cronova, porównanie funkcja po funkcji
