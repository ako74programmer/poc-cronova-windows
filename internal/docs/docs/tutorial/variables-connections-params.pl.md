# Zmienne, połączenia i parametry

Wpisywanie nazw hostów, haseł i dat bezpośrednio w YAML DAG-a to prosty sposób, by schedulera z workflow kończył z sekretami w git. Ten rozdział wyjaśnia trzy zarządzane z poziomu UI cronova przestrzenie nazw — `{{ var.KEY }}`, `{{ conn.ID.FIELD }}` i `{{ params.KEY }}` — dzięki czemu pliki DAG pozostają czyste, a sekretów nie ma w YAML.

Z poprzedniego rozdziału znasz już wbudowane zmienne uruchomieniowe, takie jak `{{ logical_date }}`. Te trzy przestrzenie nazw są inne: ich wartości przechowywane są w bazie danych cronova, nie w YAML, i zarządza się nimi z konsoli.

| Namespace | Co przechowuje | Gdzie się zarządza |
|---|---|---|
| `{{ var.KEY }}` | wspólne wartości konfiguracyjne | console → **Variables & Connections** |
| `{{ conn.ID.FIELD }}` | poświadczenia do zewnętrznych systemów | console → **Variables & Connections** |
| `{{ params.KEY }}` | wartości dla pojedynczego uruchomienia przekazywane przy triggerze | `cronova trigger -params` lub konsola |

## Zmienne współdzielone: `{{ var.KEY }}`

Zmienna (variable) to nazwana wartość współdzielona przez wszystkie DAGi — baza API, nazwa bucketu, webhook. Zmień ją raz w konsoli, a każde zadanie, które się na nią odwołuje, pobierze nową wartość przy następnym uruchomieniu.

Otwórz konsolę pod adresem **http://localhost:8090** i przejdź do strony **Variables & Connections**. Dodaj zmienną o kluczu `greeting` i wartości `hello from a shared variable`. Nazwy mogą zawierać litery, cyfry oraz `_ . -`.

Teraz odwołaj się do niej z DAG-a. Utwórz `dags/use_vars.yaml`:

```yaml
dag_id: use_vars
tasks:
  - id: show
    type: powershell
    command: echo "{{ var.greeting }}"
```

Uruchom je i sprawdź wynik:

```powershell
.\cronova.exe trigger use_vars
.\cronova.exe runs use_vars
```

W konsoli kliknij w run i otwórz log zadania `show` — wypisuje `hello from a shared variable`. Miejsce `{{ var.greeting }}` zostało podmienione przy dispatch, pobrane z magazynu w tym momencie.

Edytuj wartość zmiennej w konsoli i uruchom ponownie: nowe uruchomienie wypisze nową wartość. Bez zmiany YAML, bez przeładowania.

## Połączenia: `{{ conn.ID.FIELD }}`

Connection grupuje poświadczenia do jednego zewnętrznego systemu — baz danych, API, magazynu danych — pod pojedynczym identyfikatorem. Na tej samej stronie **Variables & Connections** utwórz connection o id `api` i wypełnij jego pola.

Każde połączenie ma zestaw pól, do których możesz się odwoływać:

| Field | Odwołanie |
|---|---|
| host | `{{ conn.api.host }}` |
| port | `{{ conn.api.port }}` |
| login | `{{ conn.api.login }}` (alias: `{{ conn.api.user }}`) |
| password | `{{ conn.api.password }}` |
| type | `{{ conn.api.type }}` |
| any extra JSON field | `{{ conn.api.extra.KEY }}` |

Użyj ich wszędzie tam, gdzie działają szablony — w poleceniu PowerShell, albo w URL, nagłówkach i treści zadania `http`:

```yaml
dag_id: call_api
tasks:
  - id: fetch
    type: powershell
    command: 'curl.exe -s -u {{ conn.api.login }}:{{ conn.api.password }} "https://{{ conn.api.host }}/status"'
  - id: ingest
    type: http
    deps: [fetch]
    http:
      method: POST
      url: "https://{{ conn.api.host }}/ingest"
      headers: { Authorization: "Bearer {{ var.TOKEN }}" }
      body: '{"date":"{{ logical_date }}"}'
      expected_status: [200, 201]
```

!!! note

    Dla zadań `sql` zazwyczaj w ogóle nie szablonujesz pól. Ustaw pole na poziomie zadania
    `conn: warehouse` — `type` połączenia wybiera sterownik
    (postgres / mysql / sqlite), a cronova buduje DSN za Ciebie. Zobacz
    [DAG Reference](../DAG_REFERENCE.pl.md#typy-zadań).

## Parametry dla pojedynczego uruchomienia: `{{ params.KEY }}`

Zmienne i połączenia to współdzielony stan. Parametry są przeciwieństwem: wartości, które przekazujesz dla jednego konkretnego uruchomienia przy ręcznym triggerze — data do przetworzenia ponownie, identyfikator klienta, flaga dry-run.

Utwórz `dags/daily_report.yaml` (bez `schedule`, więc tylko ręczne):

```yaml
dag_id: daily_report
tasks:
  - id: build
    type: powershell
    command: echo "building report for {{ params.day }} (env says $env:CRONOVA_PARAM_DAY)"
```

Uruchom z parametrami jako obiekt JSON:

```powershell
.\cronova.exe trigger daily_report -params '{\"day\":\"2026-01-01\"}'
```

Sprawdź log zadania `build` w konsoli: obie formy wypisują `2026-01-01`. Każdy parametr jest dostępny na dwa sposoby — jako szablon `{{ params.KEY }}` *oraz* jako zmienna środowiskowa `CRONOVA_PARAM_<KEY>` (klucz zamieniony na wielkie litery), więc skrypty czytające tylko environment też zadziałają.

W konsoli przycisk **⋯** obok Trigger otwiera dialog **Trigger with params** — formularz klucz/wartość, który robi to samo bez JSON-a.

!!! tip

    W edytorze zadań w konsoli nigdy nie wpisujesz nawiasów `{{ }}`. Każde
    odwołanie renderuje się jako kolorowana **pigułka** (pill), a pogrupowana paleta
    (built-in · variables · connections · params) wstawia je na kliknięcie lub
    przeciągnięcie.

## Jak sekrety pozostają odseparowane

cronova rozwiązuje `var.*` i `conn.*` leniwie, po stronie serwera, przy dispatch — i **tylko wtedy, gdy zadanie wyraźnie się do nich odwołuje**. Nigdy nie są one masowo wstrzykiwane do środowiska każdego zadania, więc hasło z connection nie może wyciec do env (ani do zalogowanego outputu `env`) niepowiązanego zadania. Tylko wbudowane zmienne uruchomieniowe i parametry triggera stają się zmiennymi środowiskowymi `CRONOVA_*`.

!!! warning

    Szablon jest podstawiany do polecenia zanim ono zostanie uruchomione, więc zadanie,
    które robi `echo {{ conn.api.password }}` wypisze sekret w swoim własnym logu.
    Odwołuj się do sekretów tam, gdzie są konsumowane (flaga autoryzacji, nagłówek) — nie
    echo-uj ich.

## Czego się nauczyłeś

- `{{ var.KEY }}` i `{{ conn.ID.FIELD }}` pobierają współdzieloną konfigurację i poświadczenia ze strony **Variables & Connections** w konsoli — poza Twoim YAML-em DAG.
- Pola połączeń to `host`, `port`, `login`/`user`, `password`, `type` oraz `extra.KEY`; zadania `sql` przyjmują na poziomie zadania identyfikator `conn:`.
- `cronova trigger <dag_id> -params '{"day":"…"}'` przekazuje wartości dla pojedynczego uruchomienia, dostępne jako `{{ params.KEY }}` lub `CRONOVA_PARAM_<KEY>`.
- Zmienne i połączenia są rozwiązywane tylko wtedy, gdy są referencjonowane — sekrety nigdy nie są wstrzykiwane do środowiska każdego zadania.

**Następnie:** podłącz prawdziwy kod do zadania — wgraj go raz i uruchom jako [projekt](projects.pl.md).
