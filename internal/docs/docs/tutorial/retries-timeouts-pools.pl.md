# Ponowienia, limity czasu i pule

Prawdziwe pipeline'y zawodzą: API zrywa połączenie, zapytanie się wiesza, dziesięć ciężkich zadań trafia na tę samą maszynę jednocześnie. Ten rozdział czyni twój workflow odpornym dzięki automatycznym **ponowieniom (retries)**, limitom czasu na pojedynczą próbę (**timeouts**), miękkim **SLA**, twardemu deadline'owi wykonania oraz globalnym limitom współbieżności — funkcjom, które odróżniają scheduler workflow od zwykłego crona.

## Zawodne zadanie

Zbudujmy zadanie, które celowo zawodzi. Każda próba otrzymuje numer próby — `{{ try_number }}` w szablonach, `CRONOVA_TRY_NUMBER` w środowisku — zaczynając od `1` i zwiększając się przy każdym ponowieniu. Użyjemy go do zasymulowania pobrania, które powiedzie się dopiero przy trzeciej próbie.

Utwórz `dags/flaky_pipeline.yaml`:

```yaml
dag_id: flaky_pipeline
tasks:
  - id: fetch
    type: powershell
    command: |
      if ([int]$env:CRONOVA_TRY_NUMBER -lt 3) {
        [Console]::Error.WriteLine("attempt $env:CRONOVA_TRY_NUMBER: connection reset by peer")
        exit 1
      }
      echo "attempt $env:CRONOVA_TRY_NUMBER: fetched 1200 rows"
    retries: 3
    retry_delay: 5
```

Dwa nowe pola zadania:

- `retries: 3` — ponów do 3 razy przy błędzie. Zadanie ma łącznie **`retries` + 1 prób** (tutaj: 4).
- `retry_delay: 5` — odczekaj 5 sekund między próbami. Domyślnie oba są `0`.

Brak pola `schedule` oznacza, że DAG uruchamia się tylko po ręcznym wyzwoleniu. Zrób to teraz:

```powershell
cronova trigger flaky_pipeline
```

Następnie obserwuj przebieg:

```powershell
cronova runs flaky_pipeline
```

Przez pierwsze dwie próby zobaczysz, że zadanie przechodzi między `running` i `up_for_retry` — stan, w którym ląduje nieudana próba, czekając na zakończenie `retry_delay`:

```
RUN_ID                                  LOGICAL_DATE          STATE    TRIGGER  TASKS
flaky_pipeline__manual_1751871234...    2026-07-07T00:00:00Z  running  manual   fetch=up_for_retry
```

Po około dziesięciu sekundach (dwie porażki × 5s opóźnienia) uruchom ponownie — trzecia próba powiedzie się i przebieg zakończy się:

```
RUN_ID                                  LOGICAL_DATE          STATE    TRIGGER  TASKS
flaky_pipeline__manual_1751871234...    2026-07-07T00:00:00Z  success  manual   fetch=success
```

Otwórz przebieg w konsoli pod adresem [http://localhost:8090](http://localhost:8090) i kliknij zadanie `fetch`: log pokazuje każdą próbę — `attempt 1: connection reset by peer`, `attempt 2: …`, i wreszcie `attempt 3: fetched 1200 rows`. Numer próby zadania jest zapisywany dla każdej próby, więc zawsze możesz sprawdzić, jak bardzo zadanie musiało się natrudzić.

!!! tip
    Automatyczne ponowienia radzą sobie z przejściowymi błędami. Dla przebiegu, który już się zakończył jako nieudany, użyj polecenia operatora `cronova retry <run_id> [task_id]`, aby ponownie uruchomić tylko nieudane zadania — zobacz [CLI Reference](../CLI.md).

## Domyślne wartości na poziomie DAG

Ustawianie `retries` w każdym zadaniu jest powtarzalne. Ustal wartość domyślną raz na poziomie DAG:

```yaml
dag_id: flaky_pipeline
default_retries: 2
default_retry_delay: 30
tasks:
  - id: fetch
    ...            # inherits: 2 retries, 30s apart
  - id: load
    retries: 5     # tasks can still override the default
    ...
```

`default_retries` i `default_retry_delay` mają zastosowanie do każdego zadania, które nie ustawi własnych `retries` / `retry_delay`. Obie domyślnie równe `0`.

## Limity czasu: zabij zablokowaną próbę

Ponowienie pomaga tylko wtedy, gdy próba faktycznie *kończy się błędem*. Zawieszony proces — zablokowane połączenie, blokada, która nigdy się nie zwalnia — mógłby inaczej działać wiecznie. `timeout` nakłada limit czasu na pojedynczą próbę. Dodaj drugie zadanie:

```yaml
  - id: transform
    type: powershell
    command: "Start-Sleep 120"
    deps: [fetch]
    timeout: 5
```

`timeout: 5` daje każdej próbie 5 sekund. Po przekroczeniu cronova zabija **całą grupę procesów** — nie tylko powłokę najwyższego poziomu, ale też wszystkie procesy potomne, które ona uruchomiła — więc nic nie będzie dalej działać w tle. Domyślnie jest `0` (brak limitu).

Wyzwól DAG ponownie i po kilku sekundach sprawdź log `transform` w konsoli. `sleep` nigdy się nie zakończy; zamiast tego log kończy się:

```
=== killed: timeout after 5s ===
```

Zabita próba kończy się kodem `124` i liczy się jako zwykła porażka — więc jeśli zadanie ma pozostałe `retries`, przejdzie do `up_for_retry` i dostanie kolejną próbę z nowym zegarem. Jeśli nie ma już ponowień, finalizuje się jako `failed`, a jego zadania zależne stają się `upstream_failed`.

## SLA: miękki deadline, który alarmuje

Czasami nie chcesz niczego zabijać — chcesz po prostu *wiedzieć*, kiedy rzeczy się opóźniają. To robi `sla`, dostępne na obu poziomach i zawsze mierzone **od rozpoczęcia uruchomienia**:

```yaml
dag_id: flaky_pipeline
sla: 600                 # alert if the whole run exceeds 10 minutes
notify:
  - url: https://hooks.example.com/cronova
    on: [failure]
tasks:
  - id: transform
    sla: 300             # alert if this task hasn't finished 5 minutes into the run
    ...
```

Gdy uruchomienie (lub wciąż nierozpoczęte zadanie) przekroczy swoje `sla`, cronova zapisuje ostrzeżenie i wywołuje webhook `notify:` DAG-a z payloadem `sla_miss` (lub `task_sla_miss`). Uruchomienie **kontynuuje** — SLA to czysto alert, wysyłany co najwyżej raz na uruchomienie lub zadanie. Samo ustawienie progu jest formą opt-in: alerty SLA wywołują się na dowolnym skonfigurowanym webhooku niezależnie od listy `on:` (która jedynie kontroluje alerty sukcesu/porażki na końcu uruchomienia).

!!! note
    `sla` zadania to deadline liczony od **rozpoczęcia uruchomienia**, a nie od momentu startu zadania. Jeśli zadania nadrzędne zużyją cały budżet, zadanie podrzędne może przegapić swoje SLA zanim wykona choćby jedną linijkę — i właśnie o tym chcesz być informowany.

## dagrun_timeout: twarde zatrzymanie

`sla` ostrzega; `dagrun_timeout` działa. To twardy deadline na poziomie uruchomienia, również w sekundach od startu:

```yaml
dag_id: flaky_pipeline
sla: 600
dagrun_timeout: 1800     # kill the whole run after 30 minutes
```

Po przekroczeniu cronova zabija każde uruchomione zadanie, oznacza wszystkie niedokończone zadania jako `timed_out`, finalizuje uruchomienie jako `timed_out` i — jeśli skonfigurowano webhook `notify:` — wysyła alert o porażce (również niepodlegający `on:`). Domyślnie `0` oznacza brak limitu.

Dobrym wzorcem jest ich sparowanie: `sla` ustaw na czas, którego się *oczekujesz*, `dagrun_timeout` na czas, którego nie możesz *tolerować*.

## Pule zasobów: globalne limity współbieżności

Ponowienia i limity czasu chronią pojedyncze zadanie. **Pule** chronią współdzielone zasoby — bazę danych, która obsłuży 4 równoczesne zapytania raportowe, API z rygorystycznym limitem — w skali *wszystkich* DAG-ów. Pula to nazwana pula globalnych slotów; zadanie zajmuje jeden slot puli podczas wykonywania.

Utwórz pulę z CLI:

```powershell
cronova pools set reports 4
```

```
pool "reports" set to 4 slots
```

Następnie wskaż zadania na nią przez `pool:`, i ustaw im kolejność przez `priority:`:

```yaml
  - id: build_report
    type: powershell
    command: "python report.py --date {{ logical_date }}"
    deps: [transform]
    pool: reports
    priority: 10
```

Bez względu na to, ile uruchomień DAG-ów jest aktywnych, maksymalnie 4 zadania z puli `reports` wykonują się jednocześnie. Gdy więcej zadań czeka niż jest wolnych slotów, wygrywa wyższe `priority` (domyślnie `0`).

Każde zadanie, które nie ustawi `pool:`, korzysta z wbudowanej puli `default`, utworzonej z 16 slotami. Sprawdź, co istnieje, i zmień rozmiar puli w dowolnym momencie:

```powershell
cronova pools
```

```
NAME     SLOTS
default  16
reports  4
```

!!! warning
    Jeśli zadanie odwołuje się do puli, która jeszcze nie istnieje, cronova automatycznie ją tworzy z domyślnie 16 slotami, żeby nic nie zablokować — prawdopodobnie nie jest to jednak limit, który miałeś na myśli. Utwórz pulę za pomocą `cronova pools set` *zanim* wdrożysz DAG.

## Czego się nauczyłeś

- `retries` / `retry_delay` (i domyślne DAG-owe `default_retries` / `default_retry_delay`) dają zadaniu `retries + 1` prób, z rosnącym `try_number` i stanem `up_for_retry` w czasie oczekiwania.
- `timeout` zabija całą grupę procesów zawieszonej próby; `sla` (zadania lub DAG-a) to miękki deadline generujący tylko alerty liczony od początku uruchomienia; `dagrun_timeout` to twarde zatrzymanie całego uruchomienia.
- Pule ograniczają współbieżność globalnie: `cronova pools set reports 4`, potem `pool:` + `priority:` na zadaniach; wszystkie pozostałe korzystają z 16-slotowej puli `default`.

Następny rozdział: łączenie całych workflowów przy użyciu `trigger_after` i powiadomień webhook w [Cross-DAG dependencies](cross-dag.pl.md).
