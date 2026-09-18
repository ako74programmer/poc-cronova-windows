# Retries, timeout-y i pule

W tym rozdziale nauczysz się, jak cronova radzi sobie z **awariami zadań** (retries), chroni przed **zawieszonymi zadaniami** (timeout-y) i ogranicza **współbieżność** (pule). Wszystkie trzy są konfigurowane w YAML-u DAG-a i działają bez dodatkowej infrastruktury.

## Retries — kiedy zadanie powinno spróbować ponownie

Zadania czasami zawodzą z przejściowych powodów: krótkotrwały błąd sieci, zablokowany zasób, race condition. Zamiast natychmiast oznaczać całe uruchomienie jako nieudane, możesz poprosić cronova, by spróbował ponownie.

Edytuj `dags/hello.yaml`:

```yaml
dag_id: hello
schedule: "@every 5m"
tasks:
  - id: greet
    type: shell
    command: echo "hello from cronova"
  - id: flaky
    type: shell
    command: |
      if [ "$CRONOVA_ATTEMPT" -lt 2 ]; then
        echo "attempt $CRONOVA_ATTEMPT failed" >&2
        exit 1
      fi
      echo "attempt $CRONOVA_ATTEMPT succeeded"
    deps: [greet]
    retry:
      count: 3
      interval: 10s
```

### `retry.count`

Maksymalna liczba **dodatkowych** prób po pierwszej nieudanej. `count: 3` oznacza do czterech prób łącznie.

### `retry.interval`

Opóźnienie między kolejnymi próbami. Wartość to ciąg czasu parsowany przez Go (`10s`, `1m`, `2m30s`).

### `CRONOVA_ATTEMPT`

Każde zadanie otrzymuje zmienną środowiskową `CRONOVA_ATTEMPT` zaczynającą się od `1`. Powyższy skrypt celowo zawodzi na pierwszej próbie, a udaje się na drugiej. Dzięki `retry.count: 3` druga próba kończy się sukcesem i uruchomienie kontynuuje.

Uruchom i obserwuj:

```bash
cronova trigger hello
cronova runs hello
```

Widzisz `flaky=success`, ale w logach zadania `flaky` znajdziesz dwa wiersze — jeden z `attempt 1 failed` i jeden z `attempt 2 succeeded`. Konsola webowa pokazuje każdą próbę jako osobny wiersz w panelu zadania.

!!! tip

    Domyślnie `retry.count` to `0`, więc bez tej sekcji pierwsza porażka zadania
    natychmiast oznacza uruchomienie jako nieudane (chyba że inne zadania mają
    `depends: any_success` lub podobne).

## Timeout-y — zabijanie zawieszonych zadań

Zadanie, które utknie w nieskończonej pętli lub czeka na zewnętrzny zasób, może zablokować pulę i opóźnić inne workflow. Dodaj `timeout`, by cronova wymusiła limit czasu.

```yaml
  - id: slow
    type: shell
    command: sleep 300
    deps: [greet]
    timeout: 5s
```

Po 5 sekundach cronova zabija proces `sleep` i oznacza zadanie jako `failed`. Jeśli zdefiniowałeś `retry`, zadanie zostanie ponowione; w przeciwnym razie uruchomienie kończy się niepowodzeniem.

!!! warning

    Timeout jest egzekwowany przez scheduler, więc działa nawet wtedy, gdy zadanie
    jest wykonywane przez zdalny executor. Nie polega na samym OS-ie.

## Pule — ograniczanie współbieżności

Pule pozwalają ograniczyć, ile zadań lub uruchomień może działać jednocześnie. Są przydatne, gdy zadania dzielą ograniczony zasób: baza danych, API z rate limit, licencja, pamięć.

### Pula zadań

Utwórz pulę w `cronova.yaml` (lub w sekcji `pools:` DAG-a) i przypisz zadania:

```yaml
# dags/hello.yaml
dag_id: hello
schedule: "@every 1m"
pools:
  - name: db_pool
    size: 2
tasks:
  - id: query_1
    type: shell
    command: sleep 10 && echo "query 1 done"
    pool: db_pool
  - id: query_2
    type: shell
    command: sleep 10 && echo "query 2 done"
    pool: db_pool
  - id: query_3
    type: shell
    command: sleep 10 && echo "query 3 done"
    pool: db_pool
```

Tylko dwa z trzech zadań `query_*` mogą działać jednocześnie. Trzecie czeka w kolejce, aż jedno z puli się zwolni. Pule są globalne — jeśli dwa DAG-i używają tej samej nazwy puli, współdzielą ten sam licznik.

### Pula uruchomień DAG-a

Możesz również ograniczyć liczbę równoczesnych uruchomień tego samego DAG-a:

```yaml
dag_id: hello
schedule: "@every 10s"
max_active_runs: 1
tasks:
  # ...
```

Jeśli jedno uruchomienie `hello` nadal trwa, a nadejdzie kolejny tick harmonogramu, nowe uruchomienie zostanie **zaplanowane** (utworzone w stanie `queued`), ale nie rozpocznie się, dopóki poprzednie się nie zakończy. `max_active_runs` jest często używany z długimi zadaniami lub zadaniami, które nie mogą nakładać się na siebie.

## Łączenie retries, timeout-ów i puli

Typowa konfiguracja produkcyjna wygląda tak:

```yaml
dag_id: etl
tasks:
  - id: extract
    type: shell
    command: python extract.py
    retry:
      count: 2
      interval: 30s
    timeout: 5m
    pool: api_pool
  - id: transform
    type: shell
    command: python transform.py
    deps: [extract]
    retry:
      count: 1
      interval: 10s
    timeout: 10m
  - id: load
    type: shell
    command: python load.py
    deps: [transform]
    timeout: 5m
    pool: db_pool
```

- `extract` może ponowić do 2 razy, ma 5 minut na wykonanie i jest ograniczona przez `api_pool`.
- `transform` czeka na `extract`, ponawia raz i ma 10 minut.
- `load` czeka na `transform`, ma 5 minut i jest ograniczona przez `db_pool`.

## Czego się nauczyłeś

- `retry.count` i `retry.interval` pozwalają zadaniom ponawiać po przejściowych awariach; `CRONOVA_ATTEMPT` mówi zadaniu, która próba jest wykonywana.
- `timeout` zabija zawieszone zadania po określonym czasie.
- `pool` ogranicza współbieżność zadań współdzielących zasób; `max_active_runs` ogranicza współbieżność uruchomień jednego DAG-a.
- Wszystkie trzy są czysto deklaratywne w YAML-u — nie ma potrzeby pisania kodu obsługi błędów.

**Dalej:** zobacz, jak dzielić workflow na projekty i używać zmiennych szablonowych w [Projektach i zmiennych](projects.md).
