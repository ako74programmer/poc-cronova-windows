# Dokumentacja DAG-ów i zadań

Pełny schemat YAML dla **DAG-a** (skierowanego grafu acyklicznego zadań) w cronova — wszystkie pola na poziomie DAG-a i zadania, pięć typów zadań, reguły wyzwalania i pule zasobów. Praktyczne wprowadzenie znajdziesz w [Pierwsze kroki](GETTING_STARTED.pl.md); ogólny opis projektu w [README](https://github.com/zoyluoblue/cronova#readme).

DAG to pojedynczy plik YAML w katalogu `dags/` (domyślnie `./dags` lub katalog danych usługi). cronova waliduje i sprawdza cykle każdego DAG-a przy ładowaniu; uruchamialne przykłady znajdują się w [`dags/`](https://github.com/zoyluoblue/cronova/tree/main/dags). Parsowanie jest rygorystyczne: nieznane pola, nieobsługiwane typy zadań, kończące się dokumenty YAML, nieprawidłowe wartości ujemne i ustawienia spoza zakresu są odrzucane, a nie ignorowane.

Limity bezpieczeństwa są egzekwowane zanim definicja trafi do harmonogramu: 1 MiB
na dokument YAML, 1000 zadań, 10 000 krawędzi zależności, 256 zależności na
zadanie, identyfikatory 128-bajtowe, komendy 256 KiB, 100 ponownych prób i jeden rok dla dowolnego skonfigurowanego opóźnienia/timeoutu/SLA. Ograniczenia te zapobiegają temu, by literówka lub zbyt duży plik zamieniły walidację w nieograniczoną pracę pamięci lub harmonogramu.

```yaml
dag_id: daily_etl
schedule: "0 2 * * *"
start_date: 2026-06-01
catchup: true
max_active_runs: 1
default_retries: 2
tasks:
  - id: extract
    type: shell
    command: "python extract.py --date {{ logical_date }}"
    pool: default
  - id: transform
    command: "python transform.py --date {{ logical_date }}"
    deps: [extract]
  - id: load
    command: "psql -f load.sql"
    deps: [transform]
    retries: 3
    timeout: 1800
trigger_after:
  - dag_id: upstream_ingest
notify:
  url: https://hooks.example.com/cronova
  on: [failure]
```

## Pola na poziomie DAG-a

| Pole | Typ | Domyślnie | Opis |
|---|---|---|---|
| `dag_id` | string | — (wymagane) | Unikalny identyfikator DAG-a. |
| `schedule` | string | `""` (ręczny) | Wyrażenie cron (`"0 2 * * *"`) **lub** interwał (`"@every 30s"`). Puste = DAG uruchamia się tylko ręcznie, przez `trigger_after` lub `trigger_on_event`. |
| `timezone` | string | `""` (UTC) | Strefa IANA (np. `Asia/Shanghai`), w której oceniane są pola cron oraz `start_date` zawierające samą datę, z uwzględnieniem zmian czasu. |
| `start_date` | string daty | — | Najwcześniejsza logiczna data, dla której DAG jest planowany; kotwica dla catchup/backfill. |
| `catchup` | bool | `false` | Uzupełnij przegapione okresy między `start_date` a teraz. Uruchomienia backfill są dławione, by nie zalały systemu. |
| `max_active_runs` | int | `1` | Maksymalna liczba równoczesnych uruchomień tego DAG-a (0 traktowane jak 1). |
| `max_active_tasks` | int | `0` (nieograniczone) | Limit zadań tego DAG-a jednocześnie zakolejkowanych/działających we wszystkich jego uruchomieniach — budżet per DAG uzupełniający globalne pule. |
| `execution_policy` | string | `parallel` | Sposób przyjmowania zakolejkowanych uruchomień, gdy inne uruchomienie tego DAG-a jest aktywne: `parallel` (do `max_active_runs` równocześnie), `serial_wait` (po jednym; późniejsze uruchomienia kolejkują się w kolejności logicznych dat), `serial_discard` (po jednym; uruchomienia przychodzące podczas zajętości są **anulowane**, widocznie) lub `serial_priority` (po jednym; kolejka opróżniana według najwyższego priorytetu uruchomienia — priorytet ustawia się przy wyzwalaniu). Polityki szeregowe wymuszają co najwyżej **jedno** aktywne uruchomienie niezależnie od `max_active_runs`. |
| `worker_group` | string | `""` (lokalnie) | Domyślna grupa [workerów](#pola-na-poziomie-zadania), do której dzwonią wszystkie zadania nieustawiające własnej grupy. Puste = zadania działają na skonfigurowanym lokalnym executorze harmonogramu. |
| `trigger_on_event` | lista stringów | — | Klucze zdarzeń zewnętrznych, na które ten DAG subskrybuje: `POST /api/events {"key": …}` tworzy jedno uruchomienie wyzwalane zdarzeniem na każdego subskrybenta (idempotentnie względem klucza). Payload zdarzenia staje się parametrami uruchomienia. |
| `default_retries` | int | `0` | Liczba ponownych prób stosowana dla zadań, które nie ustawią własnego `retries`. |
| `default_retry_delay` | int (sekundy) | `0` | Opóźnienie ponownych prób stosowane dla zadań, które nie ustawią własnego `retry_delay`. |
| `sla` | int (sekundy) | `0` | Miękki deadline na poziomie uruchomienia, mierzony od jego startu. Przekroczenie generuje alert, ale nie anuluje uruchomienia. |
| `dagrun_timeout` | int (sekundy) | `0` | Twardy deadline na poziomie uruchomienia, mierzony od jego startu. `0` = brak limitu. |
| `tasks` | lista | — (wymagane) | Lista zadań (patrz niżej). |
| `trigger_after` | lista `{dag_id}` | — | Uruchom ten DAG po **sukcesie** innego DAG-a (zależność między DAG-ami). Wizualizowane w grafie DAG w konsoli. |
| `notify` | `{url, on, format, group}` | — | Powiadomienie po zakończeniu uruchomienia. `on` to lista `"failure"` i/lub `"success"`. `url` to webhook `http(s)://` **lub** `mailto:addr[,addr]` (dostarczany przez relay `smtp:` serwera). |
| `notify.format` | string | `raw` | Jedno z `raw`, `slack`, `feishu`, `dingtalk`, `email`. `raw` wysyła pełny payload JSON; formaty czatu owijają tekst podsumowania w kopertę webhooka platformy, więc wiadomość renderuje się w Slack/Feishu/DingTalk bez serwisu pośredniczącego; `email` to treść maila w czystym tekście używana dla celów `mailto:`. |
| `notify.group` | string | — | Nazwa [grupy alertów](#powiadomienia-webhook-e-mail-i-grupy-alertów) — nazwanego rozgałęzienia 1–16 kanałów zarządzanego w konsoli lub przez `POST /api/alert-groups/{name}`. Gdy ustawione, **wygrywa** z `notify.url` i każdy kanał grupy jest powiadamiany. |

Harmonogramy cron są domyślnie oceniane w **UTC**; poprzedź wyrażenie prefiksem `CRON_TZ=<strefa>`, by oceniać je w konkretnej strefie czasowej:

```yaml
schedule: "CRON_TZ=Asia/Shanghai 0 2 * * *"   # 02:00 czasu Szanghaju, codziennie
```

> `paused` **nie jest** polem YAML. Wstrzymywanie to stan operacyjny zarządzany z konsoli, CLI (`cronova pause <dag_id>`) lub API i jest zachowywany między przeładowaniami DAG-a.

### Powiadomienia: webhook, e-mail i grupy alertów

`notify.url` akceptuje dwa rodzaje celów:

- adres webhooka **przychodzącego** `http(s)://` — podsumowanie uruchomienia jest wysyłane metodą POST jako JSON, sformatowane według `notify.format`;
- `mailto:addr[,addr]` — alert jest wysyłany jako **e-mail** przez relay SMTP serwera. Wymaga to wypełnienia sekcji `smtp:` w konfiguracji serwera; bez niej kanały mailowe nie dostarczają alertów (logowane, nigdy nie blokują harmonogramu).

Zamiast wklejać ten sam URL do każdego DAG-a, `notify.group` odwołuje się do nazwanej **grupy alertów**: wielokrotnego zestawu 1–16 kanałów, z których każdy ma własny URL (webhook lub `mailto:`) i format. Grupy zarządza się w konsoli (Variables & Connections → Alert groups) lub przez API (`GET /api/alert-groups`, `POST`/`DELETE /api/alert-groups/{name}`), a jeden alert z uruchomienia rozsyła się do każdego kanału grupy.

```yaml
notify:
  group: oncall      # alertuj każdy kanał grupy "oncall"
  on: [failure]
```

Rozwiązywanie odbywa się od najbardziej szczegółowego: ustawiona `notify.group` wygrywa z `notify.url`; nazwa grupy, która już nie istnieje (np. została usunięta), powoduje powrót do własnego `notify.url` DAG-a, a następnie do instancyjnego domyślnego celu powiadomień — wiszące odwołanie jest logowane głośno, ale nigdy nie powoduje utraty alertu.

## Migawki definicji

Każde uruchomienie przechowuje dokładną kanoniczną postać YAML-a i hash SHA-256 definicji, z którą się rozpoczęło. Edycja DAG-a podczas aktywnego uruchomienia zmienia więc tylko przyszłe uruchomienia; aktywne uruchomienie zachowuje swój pierwotny graf zadań i nie może zostać zablokowane przez usunięte lub przemianowane zadanie. Wyjątkiem jest jawna ponowna próba: celowo przyjmuje najnowszą definicję DAG-a, zapisuje hash tej definicji w nowych próbach, a usunięte instancje zadań pozostawia jako historyczne wiersze zamiast ponownie je wysyłać.

## Pola na poziomie zadania

Każdy wpis pod `tasks:` opisuje jedno zadanie.

| Pole | Typ | Domyślnie | Opis |
|---|---|---|---|
| `id` | string | — (wymagane) | Identyfikator zadania, unikalny w obrębie DAG-a. |
| `type` | string | `shell` | Jedno z `shell`, `python`, `sql`, `jar`, `http`, `subdag`. Zobacz [Typy zadań](#typy-zadań). |
| `command` | string | — | Komenda (shell), kod (python) lub zapytanie (sql). Obsługuje [zmienne szablonowe](#zmienne-szablonowe). Nie używane dla `http`. |
| `deps` | lista id zadań | — | Zadania upstream, które muszą spełnić regułę `trigger_rule` tego zadania zanim zostanie ono uruchomione. Krawędzie są sprawdzane pod kątem cykli. |
| `pool` | string | `default` | [Pula zasobów](#pule-zasobów), z której to zadanie pobiera slot. |
| `priority` | int | `0` | Wyższe wartości pierwsze, gdy zadania konkurują o tę samą pulę. |
| `worker_group` | string | dziedziczy `worker_group` DAG-a | Kieruje to zadanie do grupy zdalnych workerów dzwoniących do systemu (etykieta `group` workerów, domyślnie `"default"`). Puste (i brak domyślnego na poziomie DAG-a) = uruchomienie na lokalnym executorze harmonogramu. |
| `retries` | int | dziedziczy `default_retries` | Liczba ponownych prób po niepowodzeniu. |
| `retry_delay` | int (sekundy) | dziedziczy `default_retry_delay` | Opóźnienie między ponownymi próbami. |
| `retry_backoff` | string | `fixed` | Sposób wzrostu czasu oczekiwania między próbami: `fixed` (stałe `retry_delay`) lub `exponential` (czeka `retry_delay·2^(n-1)` przed n-tą próbą). |
| `retry_delay_max` | int (sekundy) | `0` | Ogranicza wykładnicze oczekiwanie. `0` = brak jawnego limitu (obowiązuje wbudowane bezpieczne ograniczenie 24h). |
| `timeout` | int (sekundy) | `0` | Timeout wykonania na próbę; przy przekroczeniu zabijana jest cała grupa procesów. `0` = brak. |
| `sla` | int (sekundy) | `0` | Miękki deadline zadania od startu uruchomienia; tylko alert. |
| `trigger_rule` | string | `all_success` | Kiedy uruchomić się względem stanów upstream. Zobacz [Reguły wyzwalania](#reguły-wyzwalania). |
| `when` | string | — | Szablon warunku runtime (np. `"{{ params.env }}"` lub `"{{ ti.check.proceed }}"`), oceniany gdy zadanie jest już gotowe. Fałszywy wynik (`""`, `false`, `0`, `no` lub nierozwiązany placeholder) oznacza zadanie jako **skipped**. |
| `foreach` | lista stringów | — | Rozwija zadanie na jedno zadanie na element w czasie definicji: identyfikatory stają się `<id>_<index>`, `{{ item }}` / `{{ item_index }}` są podstawiane w `command`/`when`, a zależności `deps` downstream od oryginalnego id obejmują każdy shard. Każdy shard ma własne retries, log i stan. |
| `conn` | string | — | Identyfikator połączenia dla zadania `sql` (wybiera sterownik i buduje DSN). |
| `project` | string | — | Nazwa przesłanego katalogu projektu do wystawienia jako katalog roboczy (zadania shell; nie można łączyć z `worker_group`). Zobacz [Pierwsze kroki → Projekty](GETTING_STARTED.pl.md). |
| `http` | obiekt | — | Specyfikacja żądania HTTP dla zadań `http` (patrz niżej). |
| `subdag` | string | — | Dla `type: subdag`: DAG do uruchomienia jako **pod-workflow**. Zadanie uruchamia powiązane uruchomienie potomne (widoczne w historii z typem wyzwalania `subdag` i linkiem do rodzica) i odzwierciedla jego stan końcowy. Anulowanie rodzica kaskaduje się na potomka; ponowna próba zadania startuje nowe uruchomienie potomne (stare pozostaje w historii). Zagnieżdżanie jest ograniczone do 5 poziomów jako zabezpieczenie przed cyklami. |
| `depends_on_dag` | obiekt | — | Oczekiwanie między DAG-ami: wstrzymaj to zadanie do momentu, gdy pasujące uruchomienie innego DAG-a zakończy się *sukcesem*. Pola: `dag` (docelowy id), `offset` (który okres, w gramatyce wyrażeń datowych [date-expression](#wyrażenia-datowe) — `""`/`same`, `- 1d`, `.month_start`…), `timeout` (sekundy od startu uruchomienia; 0 = czekaj do `dagrun_timeout`), `on_timeout` (`fail` domyślnie lub `skip`). Nieudane docelowe uruchomienie utrzymuje oczekiwanie (można je ponowić); tylko timeout rozwiązuje impas. |

### Specyfikacja zadania `http`

Ustaw pod kluczem `http:` zadania, gdy `type: http`:

| Pole | Typ | Domyślnie | Opis |
|---|---|---|---|
| `method` | string | `GET` | Metoda HTTP. |
| `url` | string | — (wymagane) | URL żądania. Obsługuje szablony (np. `https://{{ conn.api.host }}/path`). |
| `headers` | mapa | — | Nazwa nagłówka → wartość; wartości obsługują szablony (np. `Authorization: Bearer {{ var.TOKEN }}`). |
| `body` | string | — | Ciało żądania; obsługuje szablony. |
| `expected_status` | lista int | `2xx` | Kody statusu uznawane za sukces (np. `[200, 201]`). |

## Typy zadań

| Typ | Uruchamiane jako | `command` zawiera | Wymaga na hoście |
|---|---|---|---|
| `shell` | podproces OS (`sh -c`) | dowolną komendę shell | narzędzia wywoływane przez komendę |
| `python` | podproces OS (`python3`) | kod Python | `python3` na `PATH` usługi |
| `sql` | w procesie (natywny sterownik) | zapytanie SQL; `conn` wybiera połączenie | nic dodatkowego |
| `jar` | podproces OS (`java`) | komendę `java -jar …` | JRE/JDK na `PATH` |
| `http` | klient HTTP w procesie | — (użyj specyfikacji `http:`) | nic dodatkowego |
| `subdag` | wewnętrznie w harmonogramie (uruchomienie potomne) | — (użyj pola `subdag:`) | nic dodatkowego |

Zadania `sql` i `http` są samowystarczalne w binarce. Zadania `shell`, `python` i `jar` (oraz wszystko, co wywołuje zadanie shell) wymagają zainstalowania tych narzędzi na **PATH** usługi — zobacz [Wdrożenie](DEPLOY.md).

```yaml
tasks:
  - id: shell_task
    type: shell
    command: "echo running {{ logical_date }}"
  - id: python_task
    type: python
    command: |
      import os
      print(os.environ['CRONOVA_LOGICAL_DATE'])
  - id: sql_task
    type: sql
    conn: warehouse
    command: "SELECT count(*) FROM events WHERE day = '{{ params.day }}'"
  - id: jar_task
    type: jar
    command: "java -jar app.jar --in {{ logical_date }}"
  - id: http_task
    type: http
    http:
      method: POST
      url: "https://{{ conn.api.host }}/ingest"
      headers: { Authorization: "Bearer {{ var.TOKEN }}" }
      body: '{"date":"{{ logical_date }}"}'
      expected_status: [200, 201]
```

## Zmienne szablonowe

Każde `command`, `url`, nagłówek, `body` lub zapytanie może odwoływać się do placeholderów `{{ name }}`, podstawianych przy wysyłce. Wbudowane zmienne uruchomienia są również wstrzykiwane do środowiska procesu jako `CRONOVA_<NAME>` (wielkimi literami):

| Zmienna | Zmienna środowiskowa | Znaczenie |
|---|---|---|
| `{{ logical_date }}` | `CRONOVA_LOGICAL_DATE` | Logiczna data uruchomienia (`YYYY-MM-DD`) — okres, który reprezentuje, co czyni catchup sensownym. |
| `{{ logical_datetime }}` | `CRONOVA_LOGICAL_DATETIME` | Logiczna data-czas, RFC3339. |
| `{{ run_id }}` | `CRONOVA_RUN_ID` | Unikalne id tego uruchomienia. |
| `{{ dag_id }}` | `CRONOVA_DAG_ID` | Id DAG-a. |
| `{{ task_id }}` | `CRONOVA_TASK_ID` | Id tego zadania. |
| `{{ try_number }}` | `CRONOVA_TRY_NUMBER` | Numer próby (rośnie przy retry). |

Gdy DAG deklaruje `timezone:`, `logical_date`/`logical_datetime` renderują się w tej strefie (własny dzień kalendarzowy uruchomienia), podczas gdy storage pozostaje w UTC.

### Wyrażenia datowe

`logical_date` / `logical_datetime` akceptują przesunięcia, kotwice i niestandardowe formaty bezpośrednio wewnątrz placeholdera:

```
{{ logical_date[.anchor][ ±N<unit> ]... [| format] }}
```

| Element | Wartości | Uwagi |
|---|---|---|
| anchor | `.month_start` `.month_end` `.week_start` `.week_end` | Wiąże się z bazową nazwą, stosowane jako pierwsze; tygodnie zaczynają się w poniedziałek; czas resetuje się do północy. |
| offset | `±N` + `d` (dni) `h` (godziny) `w` (tygodnie) `mo` (miesiące) | Powtarzalne, stosowane z lewej do prawej. `d`/`w`/`mo` to arytmetyka kalendarzowa (czas lokalny przetrwa DST); `h` to bezwzględny czas trwania. |
| format | `\|` + podzbiór strftime: `%Y %y %m %d %H %M %S %%` | Domyślnie: `YYYY-MM-DD` dla `logical_date`, RFC3339 dla `logical_datetime`. |

Przykłady:

```yaml
command: "python etl.py --day {{ logical_date - 1d | %Y%m%d }}"     # wczoraj jako 20260807
command: "report.sh --from {{ logical_date.month_start }} --to {{ logical_date.month_end }}"
command: "cleanup.sh --before {{ logical_date.month_start - 1d }}"  # ostatni dzień poprzedniego miesiąca
command: "sync.sh --since {{ logical_datetime - 6h }}"
```

Wyrażenie, które się nie parsuje (nieznana jednostka, zły token `%`, zbędny tekst), pozostaje w komendzie dosłownie — literówki pozostają widoczne w logu zadania zamiast cicho renderować się jako puste.

Zadania shell nie dziedziczą pełnego środowiska procesu harmonogramu. Cronova przekazuje mały zestaw bezpieczny runtime (`PATH`, locale, home/temp i zmienne certyfikatów) plus powyższe wartości `CRONOVA_*`. Zapobiega to przedostawaniu się poświadczeń serwera, takich jak `CRONOVA_ADMIN_PASSWORD`, do kodu zadania. Dodaj zmienną rodzica jawnie przez `CRONOVA_TASK_ENV_ALLOWLIST=name1,name2`, lub umieść wartość w rozwiązanym środowisku zadania.

Oprócz tego referencje zarządzane w UI, rozwiązywane po stronie serwera (sekrety nigdy nie trafiają do ogólnego env):

- `{{ var.KEY }}` — współdzielona [zmienna](AGENTS.md).
- `{{ conn.ID.FIELD }}` — pole połączenia: `host`, `port`, `login` (alias `user`), `password`, `type` lub dodatkowe pole JSON jako `extra.KEY`.
- `{{ params.KEY }}` — parametr ręcznego wyzwalania (również wstrzykiwany jako `CRONOVA_PARAM_<KEY>`). Uruchomienia wyzwalane zdarzeniem otrzymują payload zdarzenia jako params plus `{{ params.event_key }}`.
- `{{ ti.TASK_ID.KEY }}` — pole wyemitowanego wyjścia zadania upstream (tylko to uruchomienie).

### Przekazywanie danych między zadaniami

Zadanie może przekazywać niewielkie wartości (liczby wierszy, wygenerowane ścieżki plików, id) do zadań downstream, zapisując **płaską mapę stringów JSON** do pliku o nazwie w `$CRONOVA_OUTPUT` (do 64 KB):

```yaml
tasks:
  - id: produce
    command: 'echo "{\"rows\":\"1234\"}" > "$CRONOVA_OUTPUT"'
  - id: consume
    command: 'echo upstream wrote {{ ti.produce.rows }} rows'
    deps: [produce]
```

Wyjście jest zbierane po zakończeniu zadania sukcesem i przechowywane per (uruchomienie, zadanie); reguły wyzwalania gwarantują, że upstream zakończył się, zanim downstream odwołujący się do niego zostanie wysłany. To przekazywanie metadanych, nie kanał danych — prawdziwe zbiory danych przenoś przez zewnętrzną pamięć masową.

### Zadania samo-pomijające

Zadanie, które kończy się kodem **99**, jest zapisane jako `skipped` zamiast `failed` — sposób na poziomie shella do powiedzenia „dziś tu nic do roboty". Połącz z downstream `trigger_rule: none_failed` (skip przechodzi) lub domyślnym `all_success` (skip blokuje), by kształtować dalszy przebieg; `when:` (patrz pola zadania) to deklaratywna alternatywa oceniana przed uruchomieniem zadania.

W edytorze zadań konsoli są one wstawiane jako klikalne/przeciągalne **pigułki** — nie wpisujesz `{{ }}`.

## Reguły wyzwalania

`trigger_rule` decyduje, kiedy zadanie działa, biorąc pod uwagę stany zadań upstream (`deps`):

| Reguła | Uruchamia się gdy |
|---|---|
| `all_success` (domyślnie) | każde zadanie upstream zakończyło się sukcesem |
| `all_done` | każde zadanie upstream zakończyło się (dowolny stan) |
| `all_failed` | każde zadanie upstream zakończyło się niepowodzeniem |
| `one_success` | co najmniej jedno zadanie upstream zakończyło się sukcesem |
| `one_failed` | co najmniej jedno zadanie upstream zakończyło się niepowodzeniem |
| `none_failed` | żadne zadanie upstream nie zakończyło się niepowodzeniem (sukces lub skipped) |

## Pule zasobów

**Pula** to nazwany zbiór globalnych slotów współbieżności; zadanie zużywa jeden slot swojej `pool` podczas działania, a zadania o wyższym `priority` wygrywają w konkurencji o sloty. Pule to globalne zasoby konfigurowane poza pasmem (nie w YAML-u DAG-a):

```bash
cronova pools                    # listuj pule i użycie
cronova pools set reports 4      # utwórz/zmień rozmiar puli "reports" na 4 sloty
```

Każde zadanie domyślnie używa puli `default`. Zobacz [Dokumentację CLI](CLI.md) i [Architekturę](ARCHITECTURE.md).

## Zobacz też

- [Pierwsze kroki](GETTING_STARTED.pl.md) · [Dokumentacja CLI](CLI.md) · [Agenci AI (MCP)](AGENTS.md) · [Wdrożenie](DEPLOY.md) · [Architektura](ARCHITECTURE.md) · [FAQ](FAQ.pl.md)
