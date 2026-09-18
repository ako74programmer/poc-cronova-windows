# Twój pierwszy DAG

W tym rozdziale napiszesz swój pierwszy **DAG** — workflow dwóch zadań shell połączonych zależnością — a następnie uruchomisz go z harmonogramem cronova i obserwować jego sukces, zarówno z CLI, jak i z konsoli webowej.

## Utwórz plik DAG-a

DAG (skierowany graf acykliczny) to zbiór zadań połączonych krawędziami zależności, zdefiniowany jako pojedynczy plik YAML w katalogu `./dags/`. Każde zadanie shell działa jako podproces OS.

Utwórz `dags/hello.yaml`:

```yaml
dag_id: hello
tasks:
  - id: greet
    type: shell
    command: echo "hello from cronova"
  - id: report
    type: shell
    command: echo "run $CRONOVA_RUN_ID finished greeting"
    deps: [greet]
```

To kompletny, uruchamialny workflow. Przejdźmy przez niego linia po linii.

### `dag_id`

```yaml
dag_id: hello
```

Unikalny identyfikator DAG-a. Jest wymagany i to nazwa, której użyjesz wszędzie indziej — `cronova trigger hello`, lista DAG-ów w konsoli, historia uruchomień.

### `tasks`

```yaml
tasks:
  - id: greet
```

Lista zadań — również wymagana. Każdy wpis dostaje `id`, które musi być unikalne w obrębie DAG-a.

### `type`

```yaml
    type: shell
```

Typ zadania. `shell` uruchamia `command` jako podproces OS przez `sh -c`, więc wszystko, co możesz wpisać w terminalu, działa tutaj. Jest jeszcze cztery inne typy — `python`, `sql`, `jar` i `http` — omówione dalej w tutorialu.

!!! tip

    `shell` to domyślny `type`, więc możesz pominąć te dwie linie całkowicie.
    Wypisujemy je tutaj, by plik był jednoznaczny.

### `command`

```yaml
    command: echo "run $CRONOVA_RUN_ID finished greeting"
```

To, co wykonuje zadanie. Zwróć uwagę na `$CRONOVA_RUN_ID`: cronova wstrzykuje informacje o uruchomieniu do środowiska każdego zadania jako zmienne `CRONOVA_*` — id uruchomienia, id DAG-a, id zadania, logiczna data i więcej. Twoje skrypty mogą z nich korzystać bez żadnego okablowania.

### `deps`

```yaml
    deps: [greet]
```

Krawędź zależności — to właśnie czyni to grafem. `report` czeka na `greet` i (domyślnie) działa tylko po **sukcesie** `greet`. Krawędzie są sprawdzane pod kątem cykli przy ładowaniu pliku, więc przypadkowa pętla jest odrzucana zamiast zawieszać workflow.

## Uruchom harmonogram

`cronova serve` uruchamia pętlę harmonogramu, REST API i konsolę webową w jednym procesie:

```bash
cronova serve
```

Ładuje każdy plik `*.yaml` i `*.yml` z `./dags`. Nieprawidłowy plik jest logowany i pomijany — nigdy nie wywala harmonogramu.

**Sprawdź to** — z drugiego terminala:

```bash
cronova dags
```

```
DAG_ID  SCHEDULE  CATCHUP  PAUSED  MAX_ACTIVE
hello   (manual)  false    false   1
```

`hello` jest zarejestrowany. Możesz też otworzyć konsolę pod **http://localhost:8090** — lista DAG-ów pokazuje `hello` z tymi samymi szczegółami.

## Wyzwól uruchomienie

```bash
cronova trigger hello
```

```
created run hello__manual_1783468804512345600 (a running `cronova serve` will execute it)
```

!!! note

    `cronova trigger` tylko **tworzy** uruchomienie — zapisuje wiersz uruchomienia do
    bazy danych i zwraca natychmiast. Działający `cronova serve` podnosi je przy
    następnym ticku harmonogramu (domyślnie co `2s`), więc wykonanie zaczyna się
    prawie natychmiast, tylko nie wewnątrz samej komendy `trigger`.

## Obserwuj wykonanie

```bash
cronova runs hello
```

```
RUN_ID                              LOGICAL_DATE          STATE    TRIGGER  TASKS
hello__manual_1783468804512345600   2026-07-07T08:15:04Z  success  manual   greet=success report=success
```

Uruchomienie poszło najpierw `greet`, potem `report` — dokładnie w kolejności dyktowanej przez `deps`. Jeśli uruchomisz `cronova runs hello` wystarczająco szybko po wyzwalaniu, złapiesz stany w trakcie zmiany: `queued` → `running` → `success`.

### To samo w konsoli

Otwórz **http://localhost:8090** i znajdziesz konsolowe odpowiedniki wszystkiego, co właśnie zrobiłeś:

- **Lista DAG-ów** pokazuje `hello` z jednoklikowym wyzwalaczem ręcznym — bez terminala.
- Kliknij `hello`, by zobaczyć **historię uruchomień** i stany zadań każdego uruchomienia.
- Kliknij instancję zadania, by zobaczyć **podgląd logów na żywo** — w logu `greet` zobaczysz `hello from cronova`, a w logu `report` wydrukowane rzeczywiste id uruchomienia.

## Zaplanowane vs. ręczne

Być może zauważyłeś, że `hello.yaml` nie ma pola `schedule`. To celowe: **pominięcie `schedule` sprawia, że DAG jest tylko ręczny** — działa, gdy go wyzwolisz (z CLI, konsoli lub API) i nigdy sam z siebie. Dlatego `cronova dags` pokazuje `(manual)` w kolumnie SCHEDULE.

Aby cronova uruchamiał go samodzielnie, dodaj jedną linię — wyrażenie cron lub interwał:

```yaml
dag_id: hello
schedule: "@every 1m"    # lub wyrażenie cron jak "0 2 * * *"
tasks:
  # ...bez zmian...
```

Zapisz plik, a `cronova dags` teraz pokazuje `SCHEDULE=@every 1m` — harmonogram tworzy nowe uruchomienie co minutę. Harmonogramy, `start_date` i catchup/backfill mają swój własny rozdział dalej.

!!! warning

    Harmonogram `@every 1m` produkuje uruchomienia tak długo, jak długo działa `serve`.
    Dla eksperymentów albo ponownie usuń linię `schedule`, albo wstrzymaj DAG z konsoli
    (lub `cronova pause hello`), gdy skończysz.

## Czego się nauczyłeś

- DAG to jeden plik YAML w `./dags`: wymagany `dag_id` plus lista `tasks`, z `deps` rysującymi krawędzie zależności.
- `cronova serve` uruchamia harmonogram i konsolę pod http://localhost:8090; `cronova dags` listuje to, co załadował.
- `cronova trigger <dag_id>` tworzy uruchomienie, a `serve` wykonuje je przy następnym ticku; `cronova runs <dag_id>` i historia uruchomień w konsoli pokazują stan każdego zadania.
- Brak pola `schedule` oznacza tylko ręczne; dodanie go przekazuje DAG harmonogramowi.

Pełny schemat pól znajdziesz w [Dokumentacji DAG-ów i zadań](../DAG_REFERENCE.pl.md). **Dalej:** włóż `hello` na prawdziwy harmonogram — wyrażenia cron, interwały, `start_date` i catchup — w [Harmonogramach](scheduling.md).
