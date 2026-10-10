# Tutorial cronova

**[Polski](#tutorial-po-polsku)** · [English](#tutorial-in-english)

---

## Tutorial po polsku

Ten tutorial krok po kroku pokazuje cronova — lekki, samodzielnie hostowany **scheduler workflowów** i otwartoźródłową alternatywę dla Airflow — od instalacji wydania po uruchomienie pipeline’u gotowego do użycia w produkcji, z ponawianiem zadań, pulami zasobów i zależnościami między DAG-ami.

Każdy rozdział rozwija poprzedni, ale można go też czytać samodzielnie. Jeśli interesuje Cię konkretny temat, przejdź bezpośrednio do niego.

### Co zbudujesz

Krok po kroku rozbudujesz niewielki pipeline w stylu **ETL**. Zacznie się od pojedynczego zadania `echo` w pliku YAML, a następnie zyska harmonogram **cron** z backfillem, łańcuch zależności extract → transform → load, komendy z datami w szablonach, sekrety z zarządzanych połączeń, własny przesłany projekt kodu, ponawianie zadań i pulę zasobów — a na końcu podrzędny **DAG** raportujący po udanym zakończeniu pipeline’u.

Wszystko działa lokalnie: jeden plik binarny `cronova`, wbudowana baza SQLite i konsola webowa pod **http://localhost:8090**. Bez zewnętrznej bazy danych, brokera wiadomości czy kontenerów.

### Wymagania

- Komputer **Windows amd64** — wystarczy laptop. Pakiet dla Windows amd64 pobierzesz z [wydania v0.2.2](https://github.com/ako74programmer/poc-cronova-windows/releases/tag/v0.2.2).
- Terminal PowerShell.
- **Go 1.26.5+**, *tylko jeśli* zdecydujesz się budować ze źródeł. Gotowe archiwum ZIP nie wymaga toolchaina; `setup.cmd` służy do instalacji cronova na stałe.

> **Wskazówka:** Plik binarny nie korzysta z CGO (SQLite w czystym Go), więc nie trzeba niczego kompilować ani linkować — pobierz, rozpakuj i uruchom.

### Rozdziały

1. **[Instalacja cronova](install.pl.md)** — pobierz i rozpakuj archiwum ZIP dla Windows, uruchom `cronova.exe` bez instalowania usługi albo opcjonalnie zainstaluj program przez `setup.cmd`.
2. **[Twój pierwszy DAG](first-dag.pl.md)** — utwórz DAG jako plik YAML w `./dags`, wyzwól go i obserwuj przebieg w konsoli oraz CLI.
3. **[Harmonogram](scheduling.pl.md)** — wyrażenia cron i interwały `@every`, `start_date`, backfill `catchup` oraz znaczenie *daty logicznej*.
4. **[Zależności zadań](dependencies.pl.md)** — połącz zadania przez `deps` i określ, kiedy mają się uruchamiać, za pomocą reguł takich jak `all_success` i `one_failed`.
5. **[Zmienne szablonów](template-variables.pl.md)** — wstawiaj `{{ logical_date }}`, `{{ run_id }}` i inne wartości do komend albo odczytuj je jako zmienne środowiskowe `CRONOVA_*`.
6. **[Zmienne, połączenia i parametry](variables-connections-params.pl.md)** — przechowuj sekrety i ustawienia poza YAML-em, używając `{{ var.KEY }}`, `{{ conn.ID.field }}` oraz `{{ params.KEY }}` dla pojedynczego uruchomienia.
7. **[Projekty: uruchamianie własnego kodu](projects.pl.md)** — prześlij skrypt lub cały kod i uruchamiaj go w świeżym, odizolowanym katalogu roboczym dla każdej próby.
8. **[Typy zadań](task-types.pl.md)** — poznaj zadania `python`, `sql`, `jar` i `http` obok `powershell` oraz dowiedz się, kiedy używać każdego z nich.
9. **[Ponawianie, limity czasu i pule](retries-timeouts-pools.pl.md)** — zwiększ odporność pipeline’u za pomocą `retries`, `retry_delay`, `timeout`, SLA i globalnych pul współbieżności.
10. **[Zależności między DAG-ami](cross-dag.pl.md)** — łącz całe DAG-i przez `trigger_after` i otrzymuj powiadomienia webhook o sukcesie lub błędzie.

> **Uwaga:** Tutorial omawia pola i komendy używane na co dzień. Pełny schemat znajduje się w [referencji DAG](../DAG_REFERENCE.pl.md), a wszystkie komendy i flagi — w [referencji CLI](../CLI.md). Dodatkowe uruchamialne DAG-i są w katalogu repozytorium [`dags/`](https://github.com/ako74programmer/poc-cronova-windows/tree/main/dags).

### Jak czytać tutorial

Każdy rozdział ma podobny układ: krótkie wyjaśnienie, niewielki uruchamialny przykład (fragment YAML lub kilka komend powłoki) i punkt kontrolny — dokładny wynik CLI albo zmiana w konsoli, które potwierdzają, że wszystko działa. Wykonuj kolejne kroki; każdy zajmuje minutę lub dwie.

### Czego się nauczysz

- Rozwiniesz jeden pipeline w stylu ETL: od pojedynczego zadania po zaplanowany workflow z zależnościami i obsługą ponowień.
- Wystarczy komputer Windows amd64 — Go 1.26.5+ jest potrzebne wyłącznie do budowania ze źródeł.
- Dziesięć rozdziałów prowadzi od instalacji po orkiestrację między DAG-ami; szczegóły uzupełniają dokumenty referencyjne.

**Na początek:** pobierz archiwum ZIP dla Windows i wykonaj instrukcje w rozdziale [Instalacja cronova](install.pl.md).

---

## Tutorial in English

This tutorial teaches you cronova — the lightweight, self-hosted **workflow scheduler** and open-source Airflow alternative — step by step, from installing the release to running a production-shaped pipeline with retries, pools, and cross-DAG dependencies.

Each chapter builds on the previous one, but is also written to stand on its own. If you want a specific topic, jump straight to it.

### What you'll build

You'll grow one small **ETL-style pipeline** chapter by chapter. It starts as a single `echo` task in a YAML file, then gains a real **cron** schedule with backfill, an extract → transform → load dependency chain, date-templated commands, secrets from managed connections, your own uploaded project, retries and a resource pool — and finally a downstream reporting **DAG** that runs whenever the pipeline succeeds.

Everything runs locally: one `cronova` binary, an embedded SQLite database, and the web console at **http://localhost:8090**. No external database, no message broker, no containers.

### What you need

- A **Windows amd64** machine — a laptop is fine. Download the Windows ZIP from the [v0.2.2 release](https://github.com/ako74programmer/poc-cronova-windows/releases/tag/v0.2.2).
- A PowerShell terminal.
- **Go 1.26.5+**, *only* if you choose to build from source. The prebuilt release ZIP needs no toolchain; use `setup.cmd` only for a persistent installation.

> **Tip:** The binary is CGO-free (pure-Go SQLite), so there is nothing to compile or link against — download, extract, run.

### Chapters

1. **[Install cronova](install.md)** — download and extract the Windows ZIP, run `cronova.exe` directly for the tutorial, or optionally install it with `setup.cmd`.
2. **[Your first DAG](first-dag.md)** — write a DAG as a YAML file in `./dags`, trigger it, and watch the run in the console and CLI.
3. **[Scheduling](scheduling.md)** — cron expressions and `@every` intervals, `start_date`, `catchup` backfill, and what the *logical date* means.
4. **[Task dependencies](dependencies.md)** — wire tasks together with `deps` and control when they fire with trigger rules like `all_success` and `one_failed`.
5. **[Template variables](template-variables.md)** — inject `{{ logical_date }}`, `{{ run_id }}`, and friends into commands, or read them as `CRONOVA_*` environment variables.
6. **[Variables, connections & params](variables-connections-params.md)** — keep secrets and settings out of YAML with `{{ var.KEY }}`, `{{ conn.ID.field }}`, and per-run `{{ params.KEY }}`.
7. **[Projects: run your own code](projects.md)** — upload a script or a whole codebase and run it from a fresh, isolated working directory per attempt.
8. **[Task types](task-types.md)** — beyond `powershell`: `python`, `sql`, `jar`, and `http` tasks, and when to use each.
9. **[Retries, timeouts & pools](retries-timeouts-pools.md)** — make the pipeline resilient with `retries`, `retry_delay`, `timeout`, SLAs, and global concurrency pools.
10. **[Cross-DAG dependencies](cross-dag.md)** — chain whole DAGs with `trigger_after` and get webhook notifications on success or failure.

> **Note:** The tutorial covers the fields and commands you'll use daily. The exhaustive schema lives in the [DAG Reference](../DAG_REFERENCE.md), and every command and flag in the [CLI Reference](../CLI.md). Runnable example DAGs are in the repo's [`dags/`](https://github.com/ako74programmer/poc-cronova-windows/tree/main/dags) directory.

### How to read it

Every chapter follows the same rhythm: a short explanation, a small runnable snippet (a YAML fragment or a couple of shell commands), and a **check-it** moment — the exact CLI output or console change that proves it worked. Type along; each step takes a minute or two.

### What you'll learn

- The tutorial evolves one ETL-style pipeline from a single task into a scheduled, dependency-aware, retry-hardened workflow.
- You need only a Windows amd64 machine — Go 1.26.5+ is required only for source builds.
- Ten chapters take you from install to cross-DAG orchestration, with reference docs for everything deeper.

**Start here:** download the Windows ZIP and follow [Install cronova](install.md).
