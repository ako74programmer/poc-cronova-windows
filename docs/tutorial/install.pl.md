# Instalacja cronova

cronova to samodzielnie hostowany **scheduler workflowów** dla Windows, dystrybuowany jako archiwum ZIP zawierające scheduler, executor, konsolę webową, REST API, CLI i pliki wymagane przez przykładowe DAG-i. Ten rozdział pokazuje najszybszy sposób uruchomienia tutoriala oraz — osobno — instalację cronova do stałego użycia.

## Opcja 1: Uruchom tutorial z archiwum ZIP (zalecane)

Pobierz **`cronova_windows_amd64.zip`** z [wydania cronova v0.2.3](https://github.com/ako74programmer/poc-cronova-windows/releases/tag/v0.2.3) i rozpakuj do katalogu roboczego. Pakiet zawiera `cronova.exe`, `cronova-executor.exe`, katalog `dags/`, opcjonalny instalator `setup.cmd` oraz obie instrukcje instalacji: `README-INSTALL.md` (polską) i `README-INSTALL.en.md` (angielską).

Na potrzeby tego tutoriala **nie uruchamiaj `setup.cmd`**. Bezpośrednie uruchomienie pliku binarnego ogranicza konfigurację do rozpakowanego katalogu i nie instaluje usług Windows ani zadania uruchamianego przy logowaniu:

```powershell
Set-Location .\cronova_windows_amd64
.\cronova.exe version
```

Polecenie `version` wypisze wersję buildu i platformę, na przykład:

```
cronova v0.2.3 windows/amd64
```

Jeśli rozpakowałeś ZIP do katalogu o innej nazwie, przejdź do tego katalogu. Do uruchomienia gotowych binarek nie potrzebujesz Go ani uprawnień administratora.

## Opcja 2: Zainstaluj cronova do stałego użycia

Aby zainstalować cronova, zamiast tylko przejść tutorial, kliknij dwukrotnie **`setup.cmd`** w rozpakowanym ZIP-ie. Instalator wybiera tryb na podstawie Twoich uprawnień:

- Jeśli masz uprawnienia administratora, zaproponuje instalację usług Windows `Cronova` i `CronovaExecutor`. Zaakceptuj monit UAC, aby zainstalować usługi.
- Jeśli odmówisz UAC lub nie masz uprawnień administratora, program zainstaluje się dla bieżącego użytkownika i będzie uruchamiany przy logowaniu za pomocą Harmonogramu zadań.

Instalator skonfiguruje logowanie, a na końcu wypisze adres konsoli i hasło. Jeśli hasło zostanie wygenerowane automatycznie, **zapisz je od razu** — jest wyświetlane tylko raz. Domyślny adres konsoli to **http://127.0.0.1:8090/**. Opcje i polecenia zarządzania opisuje dołączony [przewodnik instalacji Windows](../DEPLOY.md) oraz `README-INSTALL.md` w archiwum ZIP.

> **Ważne:** instalator sam uruchamia cronova. Po instalacji nie uruchamiaj dodatkowego procesu `cronova serve` korzystającego z tego samego katalogu danych. Aby kontynuować tutorial, wybierz metodę bezpośredniego uruchomienia z ZIP-a i nie uruchamiaj `setup.cmd`.

## Opcja 3: Zbuduj scheduler ze źródeł

Aby samodzielnie zbudować binarkę schedulera, zainstaluj **Go 1.26.5 lub nowsze** i wykonaj te polecenia w PowerShell:

```powershell
git clone https://github.com/ako74programmer/poc-cronova-windows
Set-Location .\poc-cronova-windows
go build -o .\cronova.exe .\cmd\cronova
```

`git clone` tworzy katalog `poc-cronova-windows`; kompilację uruchom z tego katalogu. Build wytwarza jeden plik binarny zawierający scheduler, konsolę webową i CLI. Korzysta z SQLite w czystym Go i nie wymaga toolchaina C. Zwykłe `go build` raportuje wersję jako `dev`.

Aby zbudować kompletne archiwum instalacyjne Windows (obie binarki i wszystkie pliki runtime), użyj windowsowych skryptów pakowania i weryfikacji projektu. Zobacz [Wdrażanie](../DEPLOY.md#build-and-package-from-source); samo zbudowanie `cronova.exe` wystarczy do samodzielnego przejścia tutoriala, ale nie do instalatora usług.

## Uruchom scheduler i otwórz konsolę

Z katalogu zawierającego `cronova.exe` uruchom scheduler oraz wbudowany executor:

```powershell
.\cronova.exe serve
```

Domyślnie pliki DAG YAML są wczytywane z `./dags` (katalog powstaje, jeśli go brakuje), baza SQLite jest zapisywana w `data/cronova.db`, a logi zadań w `logs/` — wszystkie ścieżki są względne wobec bieżącego katalogu roboczego. Dlatego osobny katalog dla rozpakowanego archiwum jest wygodny podczas pracy z tutorialem.

Otwórz w przeglądarce **http://localhost:8090**. W konsoli pojawią się dołączone pliki DAG z katalogu `dags/`. W drugim oknie PowerShell sprawdź, czy cronova je załadowała:

```powershell
.\cronova.exe dags
```

Każdy załadowany DAG pojawi się na liście wraz ze swoim harmonogramem. To potwierdza, że scheduler działa i odczytuje katalog. Ten sam proces `serve` udostępnia konsolę webową i REST API.

!!! warning
    Samodzielnie uruchomiony deweloperski `serve` domyślnie nie wymaga logowania. Domyślny listener `127.0.0.1:8090` jest dostępny tylko z tego komputera. Cronova odmawia niezabezpieczonego bindowania pod adresem innym niż loopback, chyba że jawnie włączysz niebezpieczne nadpisanie. Przed udostępnieniem dostępu przez sieć włącz logowanie — zobacz [Włączanie logowania](../GETTING_STARTED.pl.md#włączanie-logowania).

Zatrzymaj serwer, naciskając ++ctrl+c++. DAG-i, baza danych i logi pozostaną na dysku, gotowe do następnego uruchomienia `cronova serve`.

## Czego się nauczyłeś

- Pobierz archiwum ZIP dla Windows amd64 i uruchom bezpośrednio `cronova.exe`, aby przejść tutorial; nie potrzebujesz do tego Go ani uprawnień administratora.
- `setup.cmd` to osobny, prowadzony instalator usług Windows lub instalacji dla bieżącego użytkownika; sam uruchamia cronova.
- Aby zbudować ze źródeł tylko scheduler, użyj Go 1.26.5+ z katalogu repozytorium `poc-cronova-windows`.
- `cronova serve` uruchamia scheduler, konsolę webową, REST API i wbudowany executor; DAG-i, baza danych i logi są umieszczane względem katalogu roboczego.

Następnie napisz i uruchom swój pierwszy DAG — [Pierwszy DAG](first-dag.pl.md).
