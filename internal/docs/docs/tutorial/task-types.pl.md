# Typy zadań: powershell, python, sql, jar, http

Każde zadanie w grafie zależności (DAG) cronova ma `type`, który mówi harmonogramowi, *jak* je wykonać. Ten rozdział przechodzi przez wszystkie pięć typów — `powershell`, `python`, `sql`, `jar` i `http` — z minimalnym, wykonalnym przykładem każdego z nich i pokazuje, które wymagają narzędzi zainstalowanych na hoście, a które są samowystarczalne w binarce.

## `powershell` — uruchom dowolne polecenie

Zadanie `powershell` uruchamia polecenie z pola `command` jako podproces systemowy za pomocą `powershell.exe -Command`, więc potoki, przekierowania, podwyrażenia `$(...)` i zmienne środowiskowe (`$env:NAME`) działają dokładnie tak, jak w konsoli PowerShell. Cronova działa tylko na Windows; `type: shell` nie jest obsługiwany i zostanie odrzucony podczas ładowania DAG-a.

Utwórz `dags/type_powershell.yaml` (bez `schedule`, więc uruchomi się tylko po wyzwoleniu):

```yaml
dag_id: type_powershell
tasks:
  - id: hello
    type: powershell
    command: Write-Output "hello from $env:COMPUTERNAME at $env:CRONOVA_LOGICAL_DATETIME"
```

Wyzwól i sprawdź wynik:

```powershell
cronova trigger type_powershell
cronova runs type_powershell
```

Zadanie `hello` przejdzie do **success**. Otwórz przebieg w konsoli na [http://localhost:8090](http://localhost:8090) i kliknij zadanie — w logu zobaczysz coś w rodzaju `hello from MYHOST at 2026-07-07T09:00:00Z`.

!!! note
    `powershell` jest domyślnym (`**default**`) typem — każde zadanie, które pisałeś w poprzednich rozdziałach, było zadaniem PowerShell. Możesz pominąć `type: powershell` całkowicie.

Zadanie PowerShell może wywołać cokolwiek, co jest zainstalowane na hoście: skrypt Pythona, narzędzie Node, `psql`, skompilowany binarny. Jest to też jedyny typ, który akceptuje pole `project` z [poprzedniego rozdziału](projects.pl.md).

## `python` — kod Pythona w linii

Zadanie `python` umieszcza kod Pythona w `command` i uruchamia go przez `python -c` używając interpretera `python` z `PATH` serwisu (lub `CRONOVA_PYTHON`). Dla wielu linii użyj skalara bloku YAML (`|`). Kod jest przekazywany do interpretera jako argument — nie przez powłokę — więc nigdy nie musisz uciekać cudzysłowów.

Utwórz `dags/type_python.yaml`:

```yaml
dag_id: type_python
tasks:
  - id: crunch
    type: python
    command: |
      import os, platform
      print("python", platform.python_version())
      print("processing", os.environ["CRONOVA_LOGICAL_DATE"])
```

Zmienne uruchomieniowe `CRONOVA_*` znajdują się w środowisku, tak jak w zadaniu PowerShell.

Wyzwól i sprawdź:

```powershell
cronova trigger type_python
cronova runs type_python
```

W logu zadania zobaczysz wersję interpretera i logiczną datę. Wynik zadania to kod wyjścia interpretera, więc nieobsłużony wyjątek kończy zadanie niepowodzeniem — i wywołuje ponowienia, jeśli je skonfigurujesz. Jeśli interpreter nie zostanie znaleziony, w logu pojawi się komunikat `python: no Python interpreter found (set CRONOVA_PYTHON or put python.exe on PATH)` i zadanie zakończy się niepowodzeniem.

## `sql` — zapytanie do bazy, bez narzędzi klienckich

Zadanie `sql` przechowuje zapytanie w `command` i wskazuje [połączenie](variables-connections-params.pl.md) przez `conn`. cronova otwiera bazę danych samodzielnie przy użyciu natywnego sterownika skompilowanego do binarki — typ połączenia wybiera PostgreSQL, MySQL/MariaDB lub SQLite — więc nie trzeba instalować klienta `psql` ani `mysql`.

```yaml
dag_id: type_sql
tasks:
  - id: count_events
    type: sql
    conn: warehouse
    command: "SELECT count(*) FROM events WHERE day = '{{ logical_date }}'"
```

Tu `warehouse` to id połączenia, które utworzyłeś w konsoli, a zapytanie jest szablonowane per uruchomienie, jak każde inne `command`.

W logu zadania widać wynik: instrukcja zwracająca wiersze (`SELECT`, `WITH`, `SHOW`, …) loguje kolumny i wiersze oddzielone tabulatorami (pierwsze 100) a następnie liczbę wierszy; każda inna instrukcja loguje `(N rows affected)`.

!!! tip
    Możesz wypróbować zadania `sql` bez żadnej infrastruktury: utwórz połączenie o typie `sqlite` i ustaw jego **host** na ścieżkę do pliku (dla SQLite host trzyma plik bazy danych). Wskaż `conn` na to połączenie z `command: "SELECT 1 AS ok"` i wyzwól — w logu zobaczysz:

    ```
    ok
    1
    (1 rows)
    ```

## `jar` — uruchom program Java

Zadanie `jar` uruchamia polecenie `java -jar …`. Wykonuje się z tymi samymi semantykami PowerShell co zadanie `powershell` — flagi, cytowania, zmienne środowiskowe i szablony `{{ }}` działają identycznie — typ dokumentuje, że jest to zadanie Java. Wymaga JRE/JDK na `PATH` serwisu.

```yaml
dag_id: type_jar
tasks:
  - id: report
    type: jar
    command: "java -jar /opt/jobs/report.jar --date {{ logical_date }}"
```

Sprawdź to w ten sam sposób: wyzwól, a następnie odczytaj stdout programu w logu zadania. Niezerowy kod wyjścia JVM powoduje niepowodzenie zadania. Jeśli zadanie nie powiedzie się natychmiast z logiem w stylu "command not found", `java` nie znajduje się na `PATH`, które widzi *serwis* — zweryfikuj przez `java -version` w tym środowisku.

## `http` — wywołaj API, bez curl

Zadanie `http` w ogóle nie używa `command`. Zamiast tego opisujesz żądanie pod kluczem `http:`, a cronova wykonuje je w procesie przy użyciu wbudowanego klienta HTTP — nic nie trzeba instalować, a przekierowania są obsługiwane.

| Field | Default | Meaning |
|---|---|---|
| `method` | `GET` | HTTP method |
| `url` | — (required) | Request URL; supports `{{ }}` templates |
| `headers` | — | Header map; values support templates |
| `body` | — | Request body; supports templates |
| `expected_status` | any 2xx | Status codes counted as success, e.g. `[200, 201]` |

Najmniejszy możliwy przykład — utwórz `dags/type_http.yaml`:

```yaml
dag_id: type_http
tasks:
  - id: ping
    type: http
    http:
      url: https://example.com
```

Wyzwól je, a potem otwórz log zadania w konsoli. Zobaczysz transkrypt żądania/odpowiedzi:

```
> GET https://example.com
< 200 OK (142ms)
<!doctype html>
…
```

Jeżeli status nie zostanie zaakceptowany, log kończy się komunikatem `http: unexpected status 503 (want 2xx)` i zadanie kończy się niepowodzeniem — co, ponownie, uruchamia ponowienia.

Realistyczne wywołanie łączy szablony w URL, nagłówkach i treści:

```yaml
  - id: ingest
    type: http
    http:
      method: POST
      url: "https://{{ conn.api.host }}/ingest"
      headers:
        Authorization: "Bearer {{ var.TOKEN }}"
      body: '{"date": "{{ logical_date }}"}'
      expected_status: [200, 201]
```

Host pochodzi z połączenia, token z zarządzanej zmiennej — więc żaden sekret nigdy nie znajduje się w pliku YAML.

## Samowystarczalne vs. narzędzia na hoście

Pięć typów dzieli się wyraźnie na dwie grupy:

| Type | Runs as | `command` holds | Needs on the host |
|---|---|---|---|
| `powershell` | OS subprocess (`powershell.exe -Command`) | any PowerShell command | the tools the command invokes |
| `python` | OS subprocess (`python -c`) | Python code | `python` on the service `PATH` |
| `sql` | in-process (native driver) | the SQL query; `conn` selects the connection | nothing extra |
| `jar` | OS subprocess (`java`) | a `java -jar …` command | a JRE/JDK on the `PATH` |
| `http` | in-process HTTP client | — (use the `http:` spec) | nothing extra |

`sql` i `http` są wbudowane w binarkę cronova i działają na czystym hoście. `powershell`, `python` i `jar` — oraz cokolwiek, co wywołuje zadanie PowerShell — wymagają, aby to narzędzie było zainstalowane tam, gdzie działa scheduler.

!!! warning
    Gdy cronova działa jako usługa Windows, zadania dziedziczą `PATH` **serwisu**, który zwykle jest znacznie krótszy niż `PATH` twojej interaktywnej powłoki. Polecenie, które działa w twoim terminalu, może nadal nie działać jako `command not found` pod serwisem — zobacz [Deployment](../DEPLOY.md) po rozwiązanie.

Pełne, pole field-po-polu, schema dla każdego typu znajduje się w [DAG Reference](../DAG_REFERENCE.md).

## Czego się nauczyłeś

- Każde zadanie ma `type`; `powershell` jest domyślny i uruchamia `command` przez `powershell.exe -Command`.
- `python` uruchamia kod inline przez `python -c`, a `jar` uruchamia polecenie `java -jar` z semantyką PowerShell — oba wymagają, aby ich runtime znajdował się na `PATH` serwisu.
- `sql` (id `conn` plus zapytanie) oraz `http` (spec `http:` z `method`, `url`, `headers`, `body`, `expected_status`) są samowystarczalne w binarce, z obsługą szablonów w zapytaniach, URL-ach, nagłówkach i treściach.

Następny rozdział: ucz zadania odporności z [Retries, timeouts & pools](retries-timeouts-pools.pl.md).
