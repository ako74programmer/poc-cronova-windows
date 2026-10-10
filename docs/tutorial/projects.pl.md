# Uruchamiaj własne skrypty i projekty

Jednolinijkowe polecenia `echo` szybko się wyczerpują — prawdziwe pipeline'y to skrypt albo cały katalog z kodem i plikami danych. Ten rozdział pokazuje, jak przesłać ten kod do cronova jako **project** i uruchomić go z zadania, z czystą, izolowaną kopią na każdą próbę.

## Dlaczego projekty

Zadanie `powershell` wykonuje swoją `command` z katalogu roboczego scheduler'a, więc `python main.py` zakończy się niepowodzeniem, chyba że `main.py` akurat tam istnieje. Możesz twardo wstawić ścieżki bezwzględne i wdrażać kod ręcznie obok scheduler'a — albo przesłać go raz jako projekt i pozwolić schedulerowi umieszczać go przy każdym uruchomieniu.

## Utwórz mały projekt

Stwórz niewielką aplikację na swoim komputerze — jeden skrypt plus plik danych czytany po ścieżce względnej:

```text
my_app/
├── main.py
└── data/
    └── greeting.txt
```

```python
# my_app/main.py
import os

print("cwd:", os.getcwd())
print("project dir:", os.environ["CRONOVA_PROJECT_DIR"])

with open("data/greeting.txt") as f:
    print(f.read().strip(), "on", os.environ["CRONOVA_LOGICAL_DATE"])
```

```text
hello from my_app
```

Punkt leży w względnej ścieżce `data/greeting.txt`: skrypt zakłada, że uruchamiany jest *z katalogu root projektu*, tak jak na twoim laptopie.

## Prześlij go w konsoli

Otwórz konsolę pod adresem **http://localhost:8090**, edytuj DAG i otwórz zadanie w edytorze zadań — sekcja **Project** to miejsce, gdzie odbywają się przesyłania. Prześlij pojedynczy skrypt, cały folder lub `.zip` (automatycznie rozpakowywany) i nadaj projektowi nazwę taką jak `my_app`. Nazwy projektów mogą zawierać litery, cyfry oraz `. _ -`; przesyłania mają limity rozmiaru (na plik i na projekt) i są zabezpieczone przed path traversal / zip-slip.

**Sprawdź to:** wylistuj przesłane projekty przez REST API:

```powershell
.\cronova.exe api GET /api/projects -server http://localhost:8090
```

```json
[{"name": "my_app", "files": 2, "size": 253}]
```

## Odwołanie w zadaniu

Wskaż zadanie `powershell` na projekt polem `project`. Utwórz `dags/my_app_report.yaml`:

```yaml
dag_id: my_app_report
tasks:
  - id: run_main
    type: powershell
    command: python main.py     # cwd is a clean copy of my_app, so this resolves
    project: my_app
```

Wyzwól je i obserwuj:

```powershell
.\cronova.exe trigger my_app_report
.\cronova.exe runs my_app_report
```

**Sprawdź to:** w konsoli otwórz **my_app_report** → najnowsze uruchomienie → **run_main**. Log pokazuje, że skrypt uruchomił się z świeżej kopii twojego projektu — katalogu dla danej próby pod systemowym katalogiem tymczasowym (dokładna ścieżka zależy od systemu operacyjnego):

```
cwd: C:\ProgramData\Cronova\workspaces\cronova-ws-9f8a3c21d4e5\my_app_report__manual_...-run_main
project dir: C:\ProgramData\Cronova\workspaces\cronova-ws-9f8a3c21d4e5\my_app_report__manual_...-run_main
hello from my_app on 2026-07-07
```

## Jak działa przygotowanie projektu

Gdy zadanie PowerShell ma ustawione `project`, scheduler przygotowuje kod przed każdą próbą:

- **Świeża, izolowana kopia** przesłanego projektu staje się katalogiem roboczym (`cwd`) próby. Próby nigdy nie wpływają na siebie nawzajem, a ponowienie zawsze zaczyna od czystej kopii — nigdy od półnapisanego stanu pozostawionego przez nieudaną próbę.
- Bezwzględna ścieżka tej kopii jest eksportowana jako **`CRONOVA_PROJECT_DIR`**, dzięki czemu skrypt może zlokalizować dołączone pliki danych nawet po wykonaniu `cd` gdzie indziej.
- Dołączone pliki są kopiowane bez zmian, więc skrypt dostarczony w projekcie może być wywołany bezpośrednio — `& .\run.ps1` zadziała.
- Kopia znajduje się pod systemowym katalogiem tymczasowym i jest **usuwana po sfinalizowaniu próby**.

!!! warning
    Katalog roboczy jest **ephemeralny** — to tymczasowa kopia na jedną próbę, usuwana po zakończeniu próby. Nie zostawiaj trwałych rezultatów w `cwd`. Wypisz je na stdout (zapisane w logu zadania), albo zapisz gdzieś zewnętrznie: do bazy danych, obiektu storage lub na ścieżkę bezwzględną poza workspace.

## Zaktualizuj swój kod

Edytowałeś `main.py`? Prześlij zmieniony plik — przesyłania są addytywne (upsert), więc nie musisz ponownie wysyłać całego folderu. Ponieważ każda próba kopiuje *aktualny* projekt, zmiana zaczyna obowiązywać przy **następnym uruchomieniu**; próby już trwające zachowują kopię, z jaką wystartowały.

!!! tip
    Zadanie `powershell` z projektem może uruchomić **dowolny język zainstalowany na hoście** — Python, Node, binarkę Go lub Rust, `psql`, JAR. Scheduler jest w pełni odseparowany od języka zadania: prześlij kod, wywołaj go przy użyciu odpowiedniego interpretera i gotowe.

## Tylko zadania PowerShell

Pole `project` jest uwzględniane tylko w zadaniach **`powershell`**. Typy `python`, `sql` i `http` działają w procesie lub mają własny model wykonania, gdzie przygotowany katalog roboczy nie ma sensu — [następny rozdział](task-types.pl.md) wyjaśnia, do czego służy każdy typ.

## Gdzie przechowywane są projekty

Przesłane projekty to zwykłe katalogi pod katalogiem projektów serwera — domyślnie `~/.cronova/projects`, można go nadpisać flagą `-projects` lub zmienną środowiskową `CRONOVA_PROJECTS`. Jeśli katalog projektów nie jest skonfigurowany, przesyłania są wyłączone, a każde zadanie odwołujące się do projektu kończy się niepowodzeniem w czasie wykonywania.

## Wykryj brakujący projekt przed jego uruchomieniem

DAG odwołujący się do projektu, który nigdy nie został przesłany, parsuje się poprawnie — a potem kończy się niepowodzeniem przy pierwszym uruchomieniu. Zweryfikuj najpierw; endpoint dry-run zgłasza dokładnie to:

```powershell
.\cronova.exe api POST /api/dags/validate `
  '{\"dag_id\":\"my_app_report\",\"tasks\":[{\"id\":\"run_main\",\"type\":\"powershell\",\"command\":\"python main.py\",\"project\":\"ghost\"}]}' `
  -server http://localhost:8090
```

**Sprawdź to:** odpowiedź zwraca `"valid": true`, ale zawiera ostrzeżenie:

```json
"warnings": ["task \"run_main\" references project \"ghost\" which is not uploaded yet"]
```

!!! note
    "Dlaczego moje zadanie projektowe nie powiodło się od razu?" to prawie zawsze jedna z dwóch rzeczy: projekt nie został przesłany, albo serwer nie ma skonfigurowanego katalogu projektów. `POST /api/dags/validate` ujawnia obie te kwestie jako ostrzeżenia, zanim cokolwiek się uruchomi.

## Czego się nauczyłeś

- Prześlij skrypt, folder lub `.zip` jako nazwany **project** w edytorze zadań konsoli i przypisz go do zadania PowerShell `project: my_app`.
- Każda próba uruchamia się w **świeżej, izolowanej kopii** projektu (jego `cwd`, także dostępnego w `CRONOVA_PROJECT_DIR`); kopia jest efemeryczna, więc trwałe wyniki kieruj na stdout lub do zewnętrznego storage.
- Ponowne przesłanie zaczyna obowiązywać przy następnym uruchomieniu; katalog projektów domyślnie to `~/.cronova/projects` (`-projects` / `CRONOVA_PROJECTS`).
- `POST /api/dags/validate` ostrzega o odwołaniu do projektu, który nie został przesłany — sprawdź to przed pierwszym uruchomieniem.

Następny rozdział: `powershell` to tylko jeden z pięciu typów zadań — zobacz, co potrafią [`python`, `sql`, `jar`, and `http` tasks](task-types.pl.md).
