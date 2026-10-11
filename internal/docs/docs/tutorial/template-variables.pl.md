# Zmienne szablonowe

Do tej pory każde polecenie w Twoim pipeline było statycznym tekstem. Ten rozdział pokazuje, jak wstrzykiwać wartości zależne od uruchomienia — logiczną datę, identyfikator runu, numer próby — do dowolnego zadania, albo jako szablony `{{ ... }}` w poleceniu, albo jako zmienne środowiskowe `CRONOVA_*` w Twoim skrypcie.

## Sześć wbudowanych zmiennych

Każda próba zadania otrzymuje sześć wbudowanych zmiennych runu. Każda z nich jest dostępna **na dwa sposoby**: jako zastępnik `{{ name }}` podstawiany do `command` przy dispatchu oraz jako zmienna środowiskowa wstrzykiwana do procesu zadania:

| Szablon | Zmienna środowiskowa | Wartość |
|---|---|---|
| `{{ logical_date }}` | `CRONOVA_LOGICAL_DATE` | Logiczna data uruchomienia, `YYYY-MM-DD` |
| `{{ logical_datetime }}` | `CRONOVA_LOGICAL_DATETIME` | Logiczna data-czas, RFC 3339 |
| `{{ run_id }}` | `CRONOVA_RUN_ID` | Unikalny identyfikator tego uruchomienia |
| `{{ dag_id }}` | `CRONOVA_DAG_ID` | Identyfikator DAG |
| `{{ task_id }}` | `CRONOVA_TASK_ID` | Identyfikator tego zadania |
| `{{ try_number }}` | `CRONOVA_TRY_NUMBER` | Numer próby (zwiększa się przy ponownych próbach) |

!!! tip
    **Logiczna data** to okres, który run *reprezentuje*, a nie „teraz” według zegara ściennego. Ta różnica sprawia, że backfille przy włączonym `catchup` mają sens: backfill dla 3 czerwca zobaczy `{{ logical_date }}` jako `2026-06-03`, nawet jeśli wykonuje się dzisiaj. Zobacz [Scheduling](scheduling.pl.md) aby dowiedzieć się, jak przypisywane są logiczne daty.

## Użycie szablonu w poleceniu

Zaktualizuj `dags/daily_etl.yaml`, aby pipeline wiedział, który dzień przetwarza:

```yaml
dag_id: daily_etl
schedule: "0 2 * * *"
start_date: 2026-06-01
catchup: false
tasks:
  - id: extract
    type: powershell
    command: echo "extracting data for {{ logical_date }}"
  - id: transform
    type: powershell
    command: echo "transforming for $env:CRONOVA_LOGICAL_DATE (run $env:CRONOVA_RUN_ID, attempt $env:CRONOVA_TRY_NUMBER)"
    deps: [extract]
```

Zadanie `extract` używa **formy szablonowej**: scheduler workflow zastępuje `{{ logical_date }}` w ciągu polecenia w momencie dispatchu, więc PowerShell otrzymuje coś w rodzaju `echo "extracting data for 2026-07-07"`. Spacje wewnątrz nawiasów klamrowych są opcjonalne — `{{logical_date}}` też zadziała.

Wyzwól uruchomienie i obserwuj je:

```powershell
.\cronova.exe trigger daily_etl
.\cronova.exe runs daily_etl
```

**Sprawdź:** `cronova runs` pokazuje nowy run, w którym `extract`, a potem `transform` osiągają `success`. Teraz otwórz konsolę pod adresem **http://localhost:8090**, kliknij **daily_etl** → najnowszy run → zadanie **extract**. Jego log pokazuje:

```
extracting data for 2026-07-07
```

z dzisiejszą datą — logiczna data uruchomienia dla ręcznego uruchomienia to moment, w którym je wyzwoliłeś (w UTC).

## Lub odczytaj zmienną środowiskową

Zadanie `transform` powyżej używa zamiast tego **formy zmiennej środowiskowej**: `$env:CRONOVA_LOGICAL_DATE` to zwykła składnia PowerShell, rozwinięta przez PowerShell w czasie wykonania z wstrzykniętej zmiennej środowiskowej. Jego log pokazuje wszystkie trzy wartości:

```
transforming for 2026-07-07 (run daily_etl__manual_..., attempt 1)
```

Obie formy przekazują te same wartości, więc wybierz tę, która bardziej pasuje:

- **Szablon** (`{{ logical_date }}`) — gdy wartość należy znaleźć się bezpośrednio w linii polecenia: `python extract.py --date {{ logical_date }}`.
- **Zmienna środowiskowa** (`CRONOVA_LOGICAL_DATE`) — gdy wartość jest konsumowana *wewnątrz* skryptu lub programu. Twój kod Pythona po prostu odczytuje `os.environ["CRONOVA_LOGICAL_DATE"]`; nic w pliku nie musi być szablonowane.

`{{ try_number }}` / `CRONOVA_TRY_NUMBER` zaczyna się od 1 i zwiększa się przy każdej ponownej próbie — przydatne do oznaczania linii logów lub plików wyjściowych na próbę, gdy później dodasz retry w [Retries, timeouts & pools](retries-timeouts-pools.pl.md).

## Nieznane zastępniki pozostają nietknięte

Podmiana dotyczy tylko rozpoznanych zastępczych wyrażeń. Nieznane `{{ ... }}` pozostaje dokładnie takim, jak napisane, więc zwykłe nawiasy klamrowe w shellu nigdy nie są zmieniane:

```yaml
  - id: braces_demo
    type: powershell
    command: echo "{{ logical_date }} is replaced, {{ not_a_variable }} is not"
```

**Sprawdź:** wyzwól DAG ponownie i otwórz log zadania w konsoli:

```
2026-07-07 is replaced, {{ not_a_variable }} is not
```

Pojedyncze nawiasy nie są nawet brane pod uwagę — `awk '{ print $1 }'`, `${HOME}` i rozwijanie nawiasów jak `{a,b}` przechodzą bez zmian. Tylko `{{ name }}` złożone ze znaków słowa i kropek jest w ogóle brane pod uwagę.

## Pigułki w konsoli

Nie musisz wpisywać `{{ }}` ręcznie. W edytorze zadań w konsoli każda zmienna renderuje się jako **kolorowa pigułka** w treści polecenia, a pogrupowana paleta (built-in, variables, connections, params) wstawia taką pigułkę jednym **kliknięciem lub przeciągnięciem**. Pigułki są atomowe — przeciągnij jedną, by ją przesunąć, kliknij jej **×**, by usunąć — więc szablon nigdy nie zostanie w połowie skasowany.

**Sprawdź:** otwórz **http://localhost:8090**, kliknij **daily_etl** i edytuj zadanie `extract` — `{{ logical_date }}`, które wpisałeś w YAML, pojawi się jako pigułka, a paleta obok edytora zaoferuje pozostałe pięć.

!!! note
    Tylko wbudowane zmienne runu (i parametry triggera zależne od uruchomienia) stają się zmiennymi środowiskowymi `CRONOVA_*`. Zmienne zarządzane przez UI i connections są rozwiązywane po stronie serwera i trafiają do polecenia **tylko** poprzez jawne odwołania — to następny rozdział.

## Czego się nauczyłeś

- Sześć wbudowanych zmiennych runu — `logical_date`, `logical_datetime`, `run_id`, `dag_id`, `task_id`, `try_number` — jest dostępnych zarówno jako szablony `{{ ... }}`, jak i jako zmienne środowiskowe `CRONOVA_*`.
- Szablony są renderowane do polecenia przy dispatchie; zmienne środowiskowe są odczytywane przez Twój skrypt w czasie wykonywania — te same wartości, wybierz zgodnie z potrzebą.
- Nieznane zastępniki przechodzą bez zmian, więc nawiasy w shellu są bezpieczne.
- Edytor pigułek w konsoli wstawia zmienne jednym kliknięciem lub przeciągnięciem — nie trzeba wpisywać `{{ }}` ręcznie.

Następny rozdział: trzymaj sekrety i ustawienia poza YAML korzystając z [Variables, connections & params](variables-connections-params.pl.md).
