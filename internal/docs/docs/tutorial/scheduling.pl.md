# Harmonogram i catchup

Do tej pory wywoływałeś swój DAG ręcznie. W tym rozdziale przypiszesz mu **harmonogram**, poznasz *datę logiczną* — model myślowy stojący za backfillami — oraz nauczysz się kontrolować kumulowanie się uruchomień za pomocą `catchup`, `max_active_runs` i wstrzymywania.

## Pole `schedule`

Pole `schedule` w DAG przyjmuje dwie formy: **wyrażenie cron** lub **interwał**.

### Wyrażenia cron

Standardowa składnia cron z 5 pól, dokładnie to, co wpiszesz w `crontab`. Utwórz `dags/daily_report.yaml`:

```yaml
dag_id: daily_report
schedule: "0 2 * * *"        # every day at 02:00
start_date: 2026-07-01
tasks:
  - id: build
    type: powershell
    command: echo "reporting for {{ logical_date }}"
```

Scheduler ocenia harmonogram każdego DAG-a przy każdym ticku (domyślnie co `2s`, konfigurowalne przez `serve -tick`) i tworzy uruchomienie zawsze, gdy granica harmonogramu została przekroczona.

Sprawdź to — wypisz swoje DAGi:

```powershell
.\cronova.exe dags
```

```text
DAG_ID        SCHEDULE   CATCHUP  PAUSED  MAX_ACTIVE
daily_report  0 2 * * *  false    false   1
```

Ten sam harmonogram pojawia się obok DAG-a w konsoli pod adresem [http://localhost:8090](http://localhost:8090).

!!! note

    Scheduler działa w **UTC**: granice cron odpala się według czasu UTC, a data
    logiczna każdego uruchomienia jest zapisywana w UTC. `"0 2 * * *"` oznacza
    02:00 UTC, a nie 02:00 czasu lokalnego.

### Interwały z `@every`

Dla „po prostu uruchamiaj co N sekund/minut/godzin” pomiń rachunki cron i użyj interwału:

```yaml
dag_id: ticker
schedule: "@every 30s"
start_date: 2026-06-01
tasks:
  - id: heartbeat
    type: powershell
    command: echo "tick at $env:CRONOVA_LOGICAL_DATETIME"
```

Poczekaj chwilę, potem sprawdź:

```powershell
.\cronova.exe runs ticker -n 3
```

```text
RUN_ID                     LOGICAL_DATE          STATE    TRIGGER   TASKS
ticker__20260707T091530Z   2026-07-07T09:15:30Z  success  schedule  heartbeat=success
ticker__20260707T091500Z   2026-07-07T09:15:00Z  success  schedule  heartbeat=success
ticker__20260707T091430Z   2026-07-07T09:14:30Z  success  schedule  heartbeat=success
```

Nowe uruchomienia pojawiają się co 30 sekund, każde z `TRIGGER` = `schedule`. Wykonalna wersja tego DAG-a jest dołączona do repozytorium: [`dags/ticker.yaml`](https://github.com/ako74programmer/poc-cronova-windows/blob/main/dags/ticker.yaml).

### Brak harmonogramu = tylko ręczne uruchomienia

Pomiń `schedule` (lub ustaw je na `""`) i DAG nigdy nie będzie uruchamiany automatycznie — w `cronova dags` pojawi się jako `(manual)` i będzie uruchamiany tylko wtedy, gdy wywołasz go z konsoli, uruchomisz `cronova trigger <dag_id>`, albo połączysz go z innym DAG-iem przez `trigger_after` (omówione w późniejszym rozdziale).

## `start_date`: skąd liczyć czas

`start_date` to najwcześniejsza data logiczna, dla której DAG może być zaplanowany. Samo w sobie robi niewiele — ale to od niego zaczyna się zliczanie w catchupie, więc przypisz każdemu harmonogramowanemu DAG-owi `start_date`.

```yaml
start_date: 2026-07-01
```

## Data logiczna

Oto podstawowy model myślowy każdego scheduler-a opartego na DAG-ach, w tym cronova:

**Każde uruchomienie niesie ze sobą `logical_date` — okres, który to uruchomienie *reprezentuje*, a nie moment zegarowy, w którym się wykonuje.**

Uruchomienie o 02:00 dla 6 lipca ma `logical_date = 2026-07-06`, nawet jeśli scheduler był wtedy niedostępny i uruchomienie zostało wykonane dopiero 7 lipca. Twoje zadanie odczytuje datę logiczną zamiast pytać zegar systemowy:

```yaml
tasks:
  - id: build
    type: powershell
    command: python report.py --date {{ logical_date }}      # via template
  - id: notify
    type: powershell
    command: echo "built report for $env:CRONOVA_LOGICAL_DATE"   # via env var
    deps: [build]
```

`{{ logical_date }}` renderuje się jako `YYYY-MM-DD`; `{{ logical_datetime }}` daje pełny znacznik czasu RFC 3339. Obie wartości są także wstrzykiwane do środowiska zadania jako `CRONOVA_LOGICAL_DATE` i `CRONOVA_LOGICAL_DATETIME`. Nawet identyfikator uruchomienia to zawiera: `daily_report__20260706T020000Z`.

Zadanie, które zna tylko „teraz”, czyni backfill bezsensownym — każde powtórzone uruchomienie przetwarzałoby dane *dzisiejsze*. Zadanie oparte na `{{ logical_date }}` przetwarza właściwy okres bez względu na to, kiedy się wykona. To sprawia, że następna sekcja ma sens.

## `catchup`: uzupełnianie zaległych okresów

`catchup` decyduje, co się dzieje z granicami harmonogramu, które minęły, gdy DAG nie był uruchamiany — bo scheduler był wyłączony, DAG dopiero utworzono lub jego `start_date` jest w przeszłości:

- `catchup: false` (domyślnie) — minione okresy są pomijane; tylko przyszłe granice tworzą uruchomienia.
- `catchup: true` — scheduler przechodzi przez każdą granicę od `start_date` do teraz i tworzy jedno uruchomienie na każdy pominięty okres, każde z własną datą logiczną.

Wypróbuj to. Dziś jest 2026-07-07; ustaw datę DAG-a na tydzień wstecz i włącz catchup:

```yaml
dag_id: daily_report
schedule: "0 2 * * *"
start_date: 2026-07-01
catchup: true
tasks:
  - id: build
    type: powershell
    command: echo "reporting for {{ logical_date }}"
```

Sprawdź — w ciągu kilku sekund od zapisania pliku:

```powershell
.\cronova.exe runs daily_report -n 10
```

```text
RUN_ID                           LOGICAL_DATE          STATE    TRIGGER   TASKS
daily_report__20260707T020000Z   2026-07-07T02:00:00Z  running  schedule  build=running
daily_report__20260706T020000Z   2026-07-06T02:00:00Z  success  schedule  build=success
daily_report__20260705T020000Z   2026-07-05T02:00:00Z  success  schedule  build=success
daily_report__20260704T020000Z   2026-07-04T02:00:00Z  success  schedule  build=success
...
```

Jedno uruchomienie na każdy pominięty dzień, od najstarszego do najnowszego, każde przetwarzające „swoją” datę. Otwórz DAG w konsoli i obserwuj, jak historia uruchomień się wypełnia; log każdego uruchomienia wypisuje inną wartość `{{ logical_date }}`.

Backfille są celowo ograniczone: scheduler tworzy co najwyżej jedno nowe uruchomienie na tick i nigdy nie przekracza `max_active_runs`, więc włączenie catchup dla `start_date` sprzed roku spowoduje stopniowe opróżnianie zaległości, a nie zalanie systemu.

!!! warning

    Catchup (i retry) zakładają, że Twoje zadania są **idempotentne**: uruchomienie tej
    samej daty logicznej dwa razy musi dawać ten sam wynik. Jeśli zadanie dopisuje
    zamiast nadpisywać, backfill zdubluje dane.

## `max_active_runs`

`max_active_runs` ogranicza liczbę uruchomień *tego DAG-a*, które mogą być jednocześnie w toku. Domyślnie jest to `1` (wartość `0` traktowana jest jako `1`), co oznacza, że backfill wykonuje się surowo po jednym okresie naraz, w kolejności — zazwyczaj to oczekiwane zachowanie, gdy dzień N+1 zależy od wyników dnia N.

Jeśli Twoje okresy są niezależne i chcesz szybszego backfilla, podnieś tę wartość:

```yaml
max_active_runs: 3
```

Sprawdź to: podczas backfilla `.\cronova.exe runs daily_report` pokaże teraz do trzech uruchomień w stanie `running` jednocześnie.

## Wstrzymywanie (pauzowanie) DAG-a

Pauzowanie zapobiega tworzeniu nowych uruchomień przez scheduler bez zmiany pliku YAML. Przełącz przełącznik pauzy dla DAG-a w konsoli albo użyj CLI — `pause` rozmawia z działającym serwerem przez REST API, więc najpierw skieruj CLI na serwer:

```powershell
$env:CRONOVA_SERVER = 'http://localhost:8090'
.\cronova.exe pause daily_report
```

Sprawdź to:

```powershell
.\cronova.exe dags
```

```text
DAG_ID        SCHEDULE   CATCHUP  PAUSED  MAX_ACTIVE
daily_report  0 2 * * *  true     true    1
```

`PAUSED` jest teraz `true` i nie pojawiają się nowe zaplanowane uruchomienia. Wznów działanie poleceniem:

```powershell
.\cronova.exe pause daily_report -off
```

Jeśli włączyłeś uwierzytelnianie, ustaw także `CRONOVA_TOKEN` (wygeneruj go poleceniem `cronova tokens create` — zobacz [CLI Reference](../CLI.md)).

!!! tip

    `paused` *nie* jest polem w YAML — to stan operacyjny zarządzany z poziomu
    konsoli, CLI lub API i przetrwa przeładowania pliku DAG. Definicja DAG-a
    pozostaje czystym opisem workflow; pauzowanie jest działaniem operacyjnym.

## Czego się nauczyłeś

- `schedule` przyjmuje wyrażenie cron (`"0 2 * * *"`) lub interwał (`"@every 30s"`); pomiń je, aby DAG był uruchamiany tylko ręcznie. Czas odnosi się do UTC.
- Każde uruchomienie ma **datę logiczną** — okres, który reprezentuje — dostępną jako `{{ logical_date }}` / `CRONOVA_LOGICAL_DATE`.
- `catchup: true` wykonuje backfill, tworząc jedno uruchomienie na każdy pominięty okres od `start_date`, ograniczane przez `max_active_runs` (domyślnie `1`).
- Wstrzymuj i wznawiaj harmonogramowanie z poziomu konsoli lub poleceniem `cronova pause <dag_id> [-off]` — to stan operacyjny, a nie pole YAML.

Następnie: rozgałęź workflow na wiele zadań i precyzyjnie kontroluj, kiedy każde z nich odpala w [Dependencies & trigger rules](dependencies.pl.md).
