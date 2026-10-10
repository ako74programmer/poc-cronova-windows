# Instalacja cronova

cronova to samodzielnie hostowany system planowania zadań (workflow scheduler), dostarczany jako jedna statyczna binarka Go — scheduler, konsola webowa, REST API i CLI w jednym, z wbudowaną bazą SQLite. W tym rozdziale zainstalujesz go, uruchomisz i po raz pierwszy otworzysz konsolę.

Są trzy sposoby, by zdobyć binarkę `cronova`. Do tego tutoriala użyj zwykłej binarki i uruchom ją z katalogu roboczego — bez praw administratora, bez usługi, łatwo do usunięcia.

## Opcja 1: Wstępnie zbudowane wydanie (zalecane do tutoriala)

Pobierz najnowsze wydanie (obecnie **v0.2.1**) ze strony [Releases page](https://github.com/ako74programmer/poc-cronova-windows/releases). Wydania dla Windows amd64 są publikowane jako archiwum ZIP. Pobierz je, a następnie rozpakuj do katalogu roboczego:

```powershell
New-Item -ItemType Directory cronova-tutorial; Set-Location cronova-tutorial
Expand-Archive ..\cronova_windows_amd64.zip -DestinationPath .
```

Do każdego wydania dołączony jest plik `SHA256SUMS`; zweryfikuj archiwum (na przykład za pomocą `Get-FileHash`) przed rozpakowaniem.

!!! tip
    ZIP zawiera nie tylko binarkę: rozpakowuje też folder `dags/` z gotowymi do uruchomienia [example DAGs](https://github.com/ako74programmer/poc-cronova-windows/tree/main/dags), szablon konfiguracji `cronova.yaml.example` oraz samodzielny `cronova-executor`. Rozpoczęcie od ZIP-a z wydania oznacza, że konsola nie będzie pusta przy pierwszym uruchomieniu.

## Opcja 2: Budowanie ze źródeł

Z zainstalowanym **Go 1.26.5+**:

```powershell
git clone https://github.com/ako74programmer/poc-cronova-windows
cd cronova
go build -o cronova.exe .\cmd\cronova
```

To zbuduje scheduler, konsolę webową i CLI w jednej statycznej binarce. Jest wolne od CGO (czyste Go SQLite), więc nie jest wymagany toolchain C.

!!! note
    Zwykłe `go build` raportuje swoją wersję jako `dev` — to oczekiwane zachowanie. Binarki z wydania niosą prawdziwy tag wersji.

## Opcja 3: Instalator usługi Windows

Dla rzeczywistego wdrożenia rozpakuj ZIP z wydania i uruchom instalator z podniesionego PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\install.ps1
```

Instaluje binarki w `C:\Program Files\Cronova`, tworzy katalog danych `C:\ProgramData\Cronova` oraz rejestruje usługi Windows `Cronova` i `CronovaExecutor` (zarządzaj nimi przez `Get-Service` lub `sc.exe`). Konsola webowa dostępna jest pod adresem http://127.0.0.1:8090.

Instalacja jako usługa zarządza swoim cyklem życia samodzielnie: `deploy\update.ps1` uaktualnia in-place, `deploy\reinstall.ps1` reinstaluje, a `deploy\uninstall.ps1` usuwa ją (dane zostają zachowane, chyba że podasz `-Purge`). Do lokalnego rozwoju używaj `scripts\windows\app.ps1`. Pełny przewodnik produkcyjny znajduje się w [Deployment](../DEPLOY.md).

Na resztę tutoriala trzymaj się zwykłej binarki z Opcji 1 lub 2.

## Sprawdź: `cronova version`

Z katalogu z binarką:

```powershell
.\cronova.exe version
```

Zobaczysz wersję builda i platformę w formacie `cronova <version> <os>/<arch>`:

```
cronova v0.2.1 windows/amd64
```

Jeżeli to się wydrukuje, instalacja została zakończona.

## Uruchom scheduler i otwórz konsolę

`cronova serve` uruchamia pętlę planowania **oraz** konsolę webową i REST API w jednym procesie:

```powershell
.\cronova.exe serve
```

Domyślnie działa względem bieżącego katalogu: pliki DAG YAML ładowane są z `./dags` (tworzony jeśli brak), baza SQLite znajduje się w `data/cronova.db`, a logi zadań trafiają do `logs/`. Dlatego uruchamianie z dedykowanego katalogu roboczego jest najczystszym sposobem na śledzenie tutoriala.

Otwórz teraz **<http://localhost:8090>** w przeglądarce. Zobaczysz konsolę cronova — listę DAG-ów, historię uruchomień, stany zadań oraz możliwość ręcznego uruchamiania jednym kliknięciem. Jeśli instalowałeś z ZIP-a wydania, dołączone przykładowe DAG-i (jak `example_etl` i `ticker`) już pojawią się na liście.

To samo możesz sprawdzić z drugiego terminala przy pomocy CLI:

```powershell
.\cronova.exe dags
```

Każdy załadowany DAG jest wypisany z jego harmonogramem — dowód, że scheduler działa i czyta twój katalog DAG-ów.

!!! warning
    Uwierzytelnianie jest wyłączone dla tego prostego trybu `serve`, ale domyślny listener to `127.0.0.1:8090`, więc dostępny jest tylko z tej maszyny. Cronova odmawia nieuwierzytelnionego wiązania na interfejsie innym niż loopback, chyba że explicite włączysz niebezpieczne nadpisanie. Przed udostępnieniem w sieci włącz logowanie — zobacz [Enabling login](../GETTING_STARTED.pl.md#włączanie-logowania).

Zatrzymaj serwer w dowolnym momencie przez ++ctrl+c++ — twoje DAG-i i baza danych pozostaną na dysku, gotowe do następnego `.\cronova.exe serve`.

## Czego się nauczyłeś

- Trzy sposoby instalacji cronova: gotowa binarka z wydania, `go build` ze źródeł albo `deploy\install.ps1`, który konfiguruje usługi Windows.
- `.\cronova.exe version` potwierdza, że binarka działa i wypisuje `cronova <version> <os>/<arch>`.
- `.\cronova.exe serve` uruchamia scheduler, konsolę webową i REST API w jednym procesie, a wszystko (DAG-i, DB, logi) jest względne względem twojego katalogu roboczego — konsola dostępna pod <http://localhost:8090>.

Następnie: napisz i uruchom swój pierwszy DAG — [Pierwszy DAG](first-dag.pl.md).
