# Zależności i reguły wyzwalania

W tym rozdziale połączysz zadania w prawdziwy graf zależności przy pomocy `deps`, zobaczysz, co się dzieje „w dół” gdy zadanie się nie powiedzie, i przejmiesz kontrolę nad tym zachowaniem za pomocą **trigger rules** — oraz poznasz dwa narzędzia operatorskie do odzyskiwania nieudanego przebiegu: `cronova retry` i `cronova mark`.

## Połącz zadania za pomocą `deps`

Cronova **DAG** to skierowany acykliczny graf: zadania są węzłami, a lista `deps` każdego zadania rysuje krawędzie przychodzące. Zadanie uruchamia się tylko wtedy, gdy jego zadania nadrzędne (te, które wymienia w `deps`) osiągną stany wymagane przez jego regułę wyzwalania — domyślnie, gdy wszystkie **zakończą się powodzeniem**.

Utwórz `dags/daily_etl.yaml`, klasyczny łańcuch extract → transform → load. Pomij `schedule`, żeby uruchamiał się tylko ręcznie:

```yaml
dag_id: daily_etl
tasks:
  - id: extract
    type: powershell
    command: echo "extracting rows"
  - id: transform
    type: powershell
    command: echo "transforming"
    deps: [extract]
  - id: load
    type: powershell
    command: echo "loading"
    deps: [transform]
```

`deps` to lista, więc grafy nie muszą być liniami prostymi: zadanie z `deps: [a, b]` zbiera wejścia i czeka na oba, a dwa zadania, które oba wskazują `deps: [extract]`, rozgałęziają się i uruchamiają równolegle.

Każdy plik DAG jest walidowany i sprawdzany pod kątem cykli przy wczytywaniu. Jeśli przypadkowo stworzysz pętlę (np. `extract` zależne od `load`), plik zostanie odrzucony z błędem `dependency cycle detected` w logu `serve` i pominięty — cykl nigdy nie zablokuje harmonogramu cicho.

**Sprawdź** — wyzwól DAG i obserwuj wykonanie łańcucha w kolejności:

```powershell
cronova trigger daily_etl
cronova runs daily_etl
```

```
RUN_ID                                 LOGICAL_DATE          STATE    TRIGGER  TASKS
daily_etl__manual_1783472901234567000  2026-07-07T09:08:21Z  success  manual   extract=success transform=success load=success
```

W konsoli pod adresem **http://localhost:8090** otwórz `daily_etl` i zobaczysz ten sam graf narysowany jako węzły i krawędzie — wizualne odwzorowanie list `deps`.

## Gdy upstream zawiedzie: `upstream_failed`

Co stanie się z `load`, jeśli `transform` zawiedzie? Wypróbuj to. Zmień polecenie `transform`, żeby celowo zakończyło się niepowodzeniem:

```yaml
  - id: transform
    type: powershell
    command: exit 1
    deps: [extract]
```

Zapisz, wyzwól ponownie i sprawdź:

```powershell
cronova trigger daily_etl
cronova runs daily_etl -n 1
```

```
RUN_ID                                 LOGICAL_DATE          STATE   TRIGGER  TASKS
daily_etl__manual_1783473010987654000  2026-07-07T09:10:10Z  failed  manual   extract=success transform=failed load=upstream_failed
```

`load` nigdy się nie uruchomił. Gdy zadanie nadrzędne zawiedzie, cronova oznacza zadania poniżej niego jako **`upstream_failed`** — stan końcowy oznaczający „zablokowane przez błąd upstream, nie zostało wykonane”. Propagacja podąża krawędziami: zablokowane są tylko potomkowie zadania, które zawiodło, podczas gdy niezwiązane równoległe gałęzie tego samego przebiegu kontynuują wykonanie do końca. Zadanie może zostać złapane w ten stan nawet będąc już w kolejce, jeśli jego upstream zawiedzie zanim wykonawca je pobierze.

Każde zadanie w stanie `failed` lub `upstream_failed` powoduje, że cały przebieg kończy się jako `failed` — co widzisz w kolumnie `STATE`.

## Reguły wyzwalania

Domyślna bramka — „uruchom, gdy **wszystkie** upstreamy się powiodły” — to jedna z sześciu reguł. Ustaw `trigger_rule` zadania, żeby zmienić moment jego uruchomienia względem `deps`:

| Rule | Uruchamia się gdy |
|---|---|
| `all_success` (default) | wszystkie zadania nadrzędne zakończyły się powodzeniem |
| `all_done` | wszystkie zadania nadrzędne zakończyły wykonanie (dowolny stan) |
| `all_failed` | wszystkie zadania nadrzędne nie powiodły się |
| `one_success` | przynajmniej jedno zadanie nadrzędne zakończyło się powodzeniem |
| `one_failed` | przynajmniej jedno zadanie nadrzędne nie powiodło się |
| `none_failed` | żadne zadanie nadrzędne nie zakończyło się niepowodzeniem (sukces lub `skipped`) |

Dwie z tych reguł rozwiązują codzienne problemy. Zadanie **sprzątające** powinno uruchomić się bez względu na to, czy pipeline się powiódł czy nie — to `all_done`. Zadanie **alarmowe** powinno uruchomić się właśnie *dlatego*, że coś się nie powiodło — to `one_failed`. Dodaj oba do `daily_etl` (zostaw `transform` z błędem):

```yaml
  - id: cleanup
    type: powershell
    command: echo "removing temp files"
    deps: [extract, transform, load]
    trigger_rule: all_done
  - id: alert
    type: powershell
    command: echo "ALERT daily_etl failed"   # curl.exe your pager here
    deps: [transform, load]
    trigger_rule: one_failed
```

**Sprawdź** — wyzwól jeszcze raz:

```powershell
cronova trigger daily_etl
cronova runs daily_etl -n 1
```

```
RUN_ID                                 LOGICAL_DATE          STATE   TRIGGER  TASKS
daily_etl__manual_1783473120123456000  2026-07-07T09:12:00Z  failed  manual   extract=success transform=failed load=upstream_failed cleanup=success alert=success
```

`transform` zawiódł i `load` zostało zablokowane tak jak wcześniej — ale `cleanup` uruchomił się mimo to (`all_done`), a `alert` zadziałał, bo jedna z zależności zawiodła (`one_failed`). Otwórz log zadania `alert` w konsoli, aby zobaczyć komunikat.

!!! warning

    Zadanie, którego reguła wyzwalania **nigdy** nie może już zostać spełniona, zostanie oznaczone jako
    `upstream_failed` — i każde zadanie w stanie `upstream_failed` powoduje, że zapisany
    stan przebiegu to `failed`. W w pełni zielonym przebiegu, bezwarunkowe zadanie alarmowe `one_failed`
    nigdy nie zadziała, więc zakończy się jako `upstream_failed` i *poprawny*
    pipeline zostanie zapisany jako nieudany przebieg. Używaj gałęzi `one_failed` / `all_failed`
    do *reagowania* na niepowodzenia wewnątrz przebiegu, który spodziewasz się, że będzie czerwony;
    dla zwykłego „powiadom mnie, gdy przebieg zawiedzie” lepiej użyć poziomowego dla DAG webhooka `notify`
    (zobacz [DAG Reference](../DAG_REFERENCE.md)) i usuń zadanie alertu przed ustawieniem harmonogramu tego DAG.

## Ponowne uruchomienie nieudanego przebiegu: `cronova retry`

Teraz napraw błąd — przywróć `transform` do działającego polecenia:

```yaml
  - id: transform
    type: powershell
    command: echo "transforming"
    deps: [extract]
```

Zapisanie pliku nie zmienia historii: nieudany przebieg pozostaje nieudany. Aby ponownie uruchomić tylko zepsute części, użyj `cronova retry` z id przebiegu z `cronova runs`:

```powershell
cronova retry daily_etl__manual_1783473120123456000 -server http://localhost:8090
```

```
{
  "retried": true
}
```

!!! note

    `retry`, `mark` oraz `cancel` to operacje operatorskie komunikujące się z REST API
    działającego serwera, więc wymagają celu: podaj
    `-server http://localhost:8090` (lub wyeksportuj `CRONOVA_SERVER`). Jeśli
    włączyłeś logowanie z `-auth`, dostarcz także token API przez `-token` /
    `CRONOVA_TOKEN` — wygeneruj go poleceniem `cronova tokens create`. Wszystkie
    szczegóły są w [CLI Reference](../CLI.md).

Retry ponownie wstawia do kolejki każde zadanie w stanie `failed`, `upstream_failed` i `cancelled` — plus wszystko poniżej nich — i reaktywuje przebieg. Zadania, które już zakończyły się sukcesem, zachowują swoje wyniki i nie są uruchamiane ponownie. Ponownie zarejestrowane zadania wykonują się wobec **bieżącej** definicji DAG, więc pętla popraw -> retry jest dokładnie taka: edytuj YAML, zapisz, retry. Jeśli przebieg jest nadal aktywny, albo nic w nim nie zawiodło, API odpowie konfliktem zamiast wykonać retry.

Możesz też wycelować w pojedyncze zadanie; jego zadania potomne zostaną razem z nim wyczyszczone:

```powershell
cronova retry daily_etl__manual_1783473120123456000 transform -server http://localhost:8090
```

**Sprawdź:**

```powershell
cronova runs daily_etl -n 1
```

Przebieg wraca do stanu `running`, `transform` i `load` wykonują się ponownie, a kolumna `STATE` kończy na `success`. W konsoli historia tego samego przebiegu pokaże teraz świeże próby.

!!! tip

    Ręczne `retry` służy do odzyskiwania po fakcie. Dla przewidywalnych błędów —
    niestabilne sieci, przeciążone bazy danych — nadaj zadaniom automatyczne
    `retries` i `retry_delay`, omówione w [Retries, timeouts & pools](retries-timeouts-pools.pl.md).

## Nadpisanie stanu ręcznie: `cronova mark`

Czasami ponowne uruchomienie jest złe — np. dane naprawiłeś ręcznie, albo zadanie utknęło i chcesz, aby pipeline poszedł dalej. `cronova mark` to operatorskie nadpisanie:

```text
cronova mark <run_id> <state>              # run:  success | failed
cronova mark <run_id> <task_id> <state>    # task: success | failed | skipped
```

Powiedzmy, że `transform` zawiódł, ale wykonałeś transformację ręcznie. Oznacz je jako zakończone i pozwól przebiegowi kontynuować:

```powershell
cronova mark daily_etl__manual_1783473120123456000 transform success -server http://localhost:8090
```

```
{
  "marked": true
}
```

Oznaczenie zadania jako `success` lub `skipped` zwalnia zadania potomne, które zostały oznaczone jako `upstream_failed` z jego powodu — scheduler podniesie je przy następnym cyklu i przebieg wznowi się od miejsca blokady. Mark działa także na aktywnym przebiegu: proces uruchomionego zadania zostanie najpierw zabity, a następnie zwycięży wybrany przez ciebie stan.

Jedna subtelność: domyślna reguła `all_success` traktuje `skipped` jako blokujące. Jeśli zadanie powinno tolerować pominięte upstreamy, ustaw mu `trigger_rule: none_failed` — „żaden upstream nie zawiódł; sukces lub `skipped` jest dopuszczalny”.

Mark na poziomie przebiegu koryguje zapisany wynik *zakończonego* przebiegu — na przykład, zadeklarowanie przebiegu jako `success` po tym, jak poradziłeś sobie z jego błędem poza systemem:

```powershell
cronova mark daily_etl__manual_1783473120123456000 success -server http://localhost:8090
```

**Sprawdź** — `cronova runs daily_etl -n 1` od razu odzwierciedli nadpisanie, a każde `trigger`, `cancel`, `retry` i `mark` jest rejestrowane w audytowym logu operacji serwera, więc nadpisania nigdy nie są niewidoczne.

## Czego się nauczyłeś

- `deps` rysuje krawędzie grafu; każdy plik DAG jest sprawdzany pod kątem cykli przy wczytaniu, a zadanie odpala się, gdy jego upstreamy spełnią `trigger_rule` (domyślnie: `all_success`).
- Błąd blokuje tylko jego potomków — kończą one jako `upstream_failed` — podczas gdy równoległe gałęzie kończą wykonanie; każde nieudane lub zablokowane zadanie powoduje, że przebieg jest `failed`.
- Sześć reguł wyzwalania pokrywa pozostałe przypadki: `all_done` do sprzątania, `one_failed` do obsługi błędów w przebiegu, `none_failed` by tolerować pominięte upstreamy, oraz `one_success` i `all_failed`.
- `cronova retry <run_id> [task_id]` ponownie wstawia do kolejki nieudane części zakończonego przebiegu wobec bieżącej definicji DAG; `cronova mark <run_id> [task_id] <state>` to ręczne nadpisanie, które może odblokować lub poprawić przebieg.

**Dalej:** sparametryzuj swoje polecenia przy użyciu logicznej daty przebiegu i pokrewnych zmiennych w [Template variables](template-variables.pl.md).
