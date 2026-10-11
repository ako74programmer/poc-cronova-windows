# Wyzwalanie i powiadomienia między DAG-ami

Jak dotąd wszystkie zależności żyły *wewnątrz* pojedynczego DAG-a. W tym ostatnim rozdziale połączysz całe DAG-i ze sobą za pomocą `trigger_after`, zobaczysz wynik w konsoli w **DAG Graph**, i podłączysz webhook `notify`, żeby nieudane uruchomienie od razu wysłało powiadomienie zamiast czekać, aż ktoś je znajdzie.

## Zależności zadań a zależności między DAG-ami

`deps` łączy zadania w obrębie jednego uruchomienia jednego DAG-a. `trigger_after` działa o poziom wyżej: uruchamia **cały downstream DAG** po sukcesie innego DAG-a. To naturalny kształt, gdy jeden potok danych kończy się tam, gdzie zaczyna się kolejny — np. ingest należący do jednego zespołu, raportowanie do innego — bez scalania ich w jeden olbrzymi workflow.

cronova dostarcza obie połówki tego wzorca jako przykłady do uruchomienia w katalogu repozytorium [`dags/`](https://github.com/ako74programmer/poc-cronova-windows/tree/main/dags): `upstream_ingest.yaml` i `downstream_report.yaml`.

## Nadrzędny DAG

Upstream to całkowicie zwykły DAG — nic w nim nie wie, że istnieje downstream:

```yaml
dag_id: upstream_ingest
# manual/scheduled upstream; downstream_report runs after this succeeds
start_date: 2026-06-01
max_active_runs: 1
tasks:
  - id: ingest
    type: powershell
    command: "Write-Output \"ingesting for $env:CRONOVA_LOGICAL_DATE\"; Start-Sleep 1"
```

Nie ma `schedule`, więc uruchamia się tylko po wyzwoleniu — wygodne dla tego przewodnika, ale harmonogram cron działa dokładnie tak samo.

## Podrzędny DAG: `trigger_after`

Downstream deklaruje zależność po swojej stronie:

```yaml
dag_id: downstream_report
start_date: 2026-06-01
max_active_runs: 1
default_retries: 1
# runs automatically once upstream_ingest succeeds for the same logical_date
trigger_after:
  - dag_id: upstream_ingest
tasks:
  - id: build_report
    type: powershell
    command: "echo building report from $env:CRONOVA_LOGICAL_DATE data"
    pool: reports        # configure size with: cronova pools set reports <n>
    retries: 2
    timeout: 600
```

Dwie rzeczy warte zauważenia:

- **Brak `schedule`.** DAG z pustym harmonogramem uruchamia się tylko ręcznie lub przez `trigger_after` — upstream *jest* jego harmonogramem.
- **`trigger_after` wskazuje upstream.** Kiedykolwiek `upstream_ingest` zakończy uruchomienie w stanie `success`, scheduler tworzy uruchomienie `downstream_report` dla **tej samej daty logicznej**.

Ponieważ data logiczna jest przenoszona, backfillowane uruchomienie upstreama uruchomi raport dla *tego* okresu — nie dla „teraz” zegara ściennego. Catchup i wyzwalanie między DAG-ami współpracują bez dodatkowej konfiguracji.

!!! tip
    `trigger_after` przyjmuje listę, więc downstream może zbierać wejścia z kilku upstreamów. Wystrzeliwuje tylko gdy **każdy** wymieniony upstream ma udane uruchomienie dla danej logical date, i nadal respektuje własne `max_active_runs` downstreamu.

Sygnał sukcesu jest trwały: cronova zapisuje go razem z końcowym stanem uruchomienia upstreama. Jeśli globalny limit uruchomień w kolejce jest pełny, sygnał pozostaje w oczekiwaniu i jest ponawiany przy kolejnych tickach schedulera. Po przyjęciu downstream czeka w stanie `queued` aż dostępne będzie miejsce zgodne z jego `max_active_runs`.

## Wyzwól cały łańcuch

Z uruchomionym `cronova serve`, odpalenie upstreama wygląda tak:

```powershell
.\cronova.exe trigger upstream_ingest
```

Poczekaj kilka sekund (zadanie ingest śpi przez sekundę, a scheduler tickuje co 2s), następnie sprawdź oba DAG-i:

```powershell
.\cronova.exe runs upstream_ingest
.\cronova.exe runs downstream_report
```

Upstream pokaże normalne ręczne uruchomienie:

```
RUN_ID                             LOGICAL_DATE          STATE    TRIGGER  TASKS
upstream_ingest__20260707T091502Z  2026-07-07T09:15:02Z  success  manual   ingest=success
```

A downstream pokaże uruchomienie, **którego nie wyzwoliłeś**:

```
RUN_ID                               LOGICAL_DATE          STATE    TRIGGER     TASKS
downstream_report__20260707T091502Z  2026-07-07T09:15:02Z  success  dependency  build_report=success
```

W kolumnie `TRIGGER` widnieje `dependency`, a `LOGICAL_DATE` dokładnie pasuje do upstreamu — to właśnie działanie cross-DAG triggera.

## Zobacz to na grafie DAG-ów

Otwórz konsolę na **http://localhost:8090** i kliknij **Graph** w nawigacji. Widok **DAG Graph** rysuje zależności triggerów między DAG-ami — zobaczysz krawędź od `upstream_ingest` do `downstream_report`. Gdy twój scheduler workflow rozrośnie się do dziesiątek DAG-ów, ten graf pozwoli ci błyskawicznie odpowiedzieć na pytanie „co uruchamia co?”.

## Powiadomienia webhook za pomocą `notify`

Potok, który zawodzi po cichu, jest gorszy niż brak potoku. `notify` to pole na poziomie DAG-a: URL, który otrzymuje JSON `POST`, gdy uruchomienie zakończy się w stanie, który wymienisz. Dodaj to do dowolnego DAG-a:

```yaml
dag_id: downstream_report
# … tasks as above …
notify:
  url: https://hooks.slack.com/services/T000/B000/XXXX
  on: [failure]
```

`on` akceptuje `failure` i/lub `success` — `failure` obejmuje też anulowane i timeoutowane uruchomienia, więc wszystko co nie jest zielone powoduje alert. URL musi być `http(s)`.

Payload wygląda tak:

```json
{
  "text": "cronova · downstream_report · run downstream_report__20260707T091502Z finished: failed (tasks: [build_report])",
  "dag_id": "downstream_report",
  "run_id": "downstream_report__20260707T091502Z",
  "state": "failed",
  "logical_date": "2026-07-07T09:15:02Z",
  "started_at": "2026-07-07T09:15:04Z",
  "finished_at": "2026-07-07T09:15:07Z",
  "duration_ms": 3000,
  "failed_tasks": ["build_report"]
}
```

Pole `text` to gotowe streszczenie dla ludzi, więc adres webhooka przychodzącego Slacka, Feishu czy Discorda renderuje je bez dodatkowego kodu; pola strukturalne służą twoim własnym endpointom.

Aby zobaczyć działanie, tymczasowo zmień komendę `build_report` na `exit 1`, wyzwól ponownie `upstream_ingest` i obserwuj log `cronova serve`: zobaczysz linię `notify sent` z id uruchomienia (lub `notify non-2xx` / `notify post` jeśli dostawa nie powiodła się). Dostawa jest asynchroniczna i best-effort — nigdy nie blokuje pętli schedulera.

Jeśli ustawisz `sla` lub `dagrun_timeout` w DAG-u, naruszenia również raportowane są przez ten sam webhook — skonfigurowanie progu samo w sobie jest opt-in, niezależnie od `on`.

!!! warning
    Outbound webhooks są zabezpieczone przed SSRF: cronova odrzuca URL-e, które rozwiązują się do prywatnych lub wewnętrznych adresów (localhost, zakresy RFC 1918, link-local, metadane chmury) i nigdy nie podąża za przekierowaniami. Testuj przeciw publicznemu endpointowi — rzeczywisty webhook Slack/Feishu lub hostowana usługa do inspekcji żądań — nie odbiornik na `http://localhost`.

## Czego się nauczyłeś

- `trigger_after` łączy całe DAG-i: downstream uruchamia się automatycznie gdy każdy wymieniony upstream ma **udane uruchomienie dla tej samej logical date**, pokazując `TRIGGER=dependency` w `cronova runs`.
- DAG bez `schedule` uruchamia się tylko ręcznie lub przez `trigger_after`, a widok **Graph** w konsoli wizualizuje wszystkie cross-DAG krawędzie.
- `notify` wysyła POST JSON — z `text` gotowym pod Slacka — przy `failure` i/lub `success`, dostarczane asynchronicznie z wbudowaną ochroną SSRF.

## Co dalej

To koniec tutorialu — przeszedłeś od pojedynczego zadania `echo` do zaplanowanego, świadomego zależności, odpornych na retry, cross-DAG potoku z alertowaniem, wszystko na kompaktowej natywnej instalacji z wbudowanym SQLite. Stąd:

- **[Deployment](../DEPLOY.md)** — zainstaluj cronova jako usługi Windows (`Cronova`, `CronovaExecutor`), przełącz się na gRPC executor z możliwością odzyskiwania po awarii, aby uruchomione zadania przetrwały restart lub upgrade schedulera, i utrzymuj go aktualnym poleceniem `deploy\update.ps1`.
- **[AI Agents (MCP)](../AGENTS.md)** — pozwól agentom AI listować, tworzyć, walidować i wyzwalać DAG-i przez wbudowany serwer MCP i zdalne JSON CLI.
- **[DAG & Task Reference](../DAG_REFERENCE.md)** — wyczerpujące schema: każde pole DAG-a i taska, wszystkie pięć typów zadań, reguły triggerów i pule.
- **[CLI Reference](../CLI.md)** — wszystkie polecenia i flagi, od `serve` po `tokens create`.
