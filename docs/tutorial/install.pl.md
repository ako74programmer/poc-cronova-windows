# Instalacja cronova

cronova to samodzielnie hostowany **scheduler workflowów** dla Windows, dystrybuowany jako archiwum ZIP zawierające scheduler, executor, konsolę webową, REST API, CLI i pliki wymagane przez przykładowe DAG-i. W tym rozdziale pokażemy, jak uruchomić tutorial bezpośrednio z ZIP-a oraz — osobno — jak zainstalować cronova do stałego użycia.

## Opcja 1: Uruchom tutorial z archiwum ZIP (zalecane)

Pobierz **`cronova_windows_amd64.zip`** ze [strony GitHub Releases](https://github.com/ako74programmer/poc-cronova-windows/releases) i rozpakuj do katalogu roboczego. Pakiet zawiera `cronova.exe`, `cronova-executor.exe`, plik `cronova.yaml`, katalog `dags/`, opcjonalny instalator `setup.cmd` oraz polską i angielską instrukcję instalacji.

Na potrzeby tego tutoriala **nie uruchamiaj `setup.cmd`**. Bezpośrednie uruchomienie pliku binarnego zapisuje dane w rozpakowanym katalogu i nie instaluje usług Windows ani zadania uruchamianego przy logowaniu:

```powershell
Set-Location .\cronova_windows_amd64
.\cronova.exe version
```

Polecenie `version` wypisze wersję wydania i platformę, na przykład `cronova <wersja-wydania> windows/amd64`. Jeśli rozpakowałeś ZIP do katalogu o innej nazwie, przejdź do tego katalogu. Do uruchomienia gotowych binarek nie potrzebujesz Go ani uprawnień administratora.

### Utwórz początkowe konto administratora

W pliku `cronova.yaml` dołączonym do archiwum wydania uwierzytelnianie jest włączone, więc pojawienie się ekranu logowania jest **oczekiwane**. Konto administratora utwórz raz dla tego rozpakowanego katalogu i bazy danych.

Najpierw uruchom samodzielnie tę jedną linię:

```powershell
$securePassword = Read-Host -Prompt "Wpisz hasło, którego użyjesz do logowania (znaki będą ukryte)" -AsSecureString
```

Tekst w cudzysłowie jest tylko etykietą monitu, **a nie hasłem**. Gdy PowerShell wyświetli monit, wpisz hasło, którego chcesz używać do logowania, i naciśnij Enter. Wpisywane znaki nie będą widoczne na ekranie. Przed uruchomieniem kolejnego bloku poczekaj, aż wróci zwykły prompt `PS>`; nie wklejaj obu bloków jednocześnie.

Teraz uruchom ten blok jeden raz:

```powershell
$adminPassword = [System.Net.NetworkCredential]::new("", $securePassword).Password
.\cronova.exe users add admin -role admin -password $adminPassword -db "data\cronova.db"
Remove-Variable adminPassword, securePassword
```

Komunikat `created admin account "admin"` oznacza, że konto zostało utworzone. **Nie uruchamiaj ponownie `users add` dla tej bazy** — błąd „already exists” oznacza, że konto już istnieje. Jeśli przeglądarka zwraca `401`, zmień hasło istniejącego konta; nie próbuj dodawać go ponownie.

#### Zmiana hasła:
Jeśli serwer działa, pozostaw go uruchomionego i otwórz drugie okno PowerShell. Przejdź w nim do tego samego katalogu rozpakowanego ZIP-a, aby użyć tej samej bazy danych. Uruchom samodzielnie tę linię, aby poprosić o nowe hasło:

```powershell
$securePassword = Read-Host -Prompt "Wpisz nowe hasło dla admina (znaki będą ukryte)" -AsSecureString
```

Wpisz nowe hasło przy monicie i poczekaj, aż wróci prompt `PS>`. Następnie uruchom:

```powershell
$newPassword = [System.Net.NetworkCredential]::new("", $securePassword).Password
.\cronova.exe users passwd admin -password $newPassword -db "data\cronova.db"
Remove-Variable newPassword, securePassword
```

Zaloguj się nowym hasłem. Ścieżka bazy jest względna wobec bieżącego katalogu roboczego.

### Uruchom scheduler i otwórz konsolę

Z katalogu zawierającego `cronova.exe` uruchom scheduler oraz wbudowany executor:

```powershell
.\cronova.exe serve
```

Domyślnie pliki DAG YAML są wczytywane z `./dags` (katalog powstaje, jeśli go brakuje), baza SQLite jest zapisywana w `data\cronova.db`, a logi zadań w `logs/` — wszystkie ścieżki są względne wobec bieżącego katalogu roboczego. Dlatego osobny katalog dla rozpakowanego archiwum jest wygodny podczas pracy z tutorialem.

Otwórz w przeglądarce [**http://localhost:8090**](http://localhost:8090) i zaloguj się jako `admin`, używając hasła wpisanego w monicie. W konsoli pojawią się dołączone pliki DAG z katalogu `dags/`. W drugim oknie PowerShell sprawdź, czy cronova je załadowała:

```powershell
.\cronova.exe dags
```

Każdy załadowany DAG pojawi się na liście wraz ze swoim harmonogramem. To potwierdza, że scheduler działa i odczytuje katalog. Ten sam proces `serve` udostępnia konsolę webową i REST API. Zatrzymaj serwer, naciskając **Ctrl+C** (przytrzymaj Ctrl i naciśnij C); DAG-i, baza danych i logi pozostaną na dysku do następnego uruchomienia.

**WARNING:** Archiwum wydania włącza uwierzytelnianie i domyślnie nasłuchuje pod adresem `127.0.0.1:8090`. Podczas tutoriala pozostaw konsolę dostępną tylko lokalnie. Jeśli później udostępnisz cronova w sieci, zapoznaj się z zasadami bezpieczeństwa w sekcji: [Włączanie logowania](../GETTING_STARTED.pl.md#włączanie-logowania) oraz w przewodniku: [Wdrażanie](../DEPLOY.pl.md).

## Opcja 2: Zainstaluj cronova do stałego użycia

Jeśli chcesz używać cronova na stałe, a nie tylko przejść tutorial, uruchom **`setup.cmd`** z rozpakowanego ZIP-a. Instalator skonfiguruje uruchamianie jako usługi Windows albo dla bieżącego użytkownika — zależnie od uprawnień i wyboru w monicie UAC. Po instalacji sam uruchomi cronova; **nie uruchamiaj równocześnie drugiego `cronova serve` z tymi samymi danymi**.

Szczegółowe kroki, wybór portu, hasła i zarządzanie instalacją opisuje [polska instrukcja instalatora (`deploy/README-INSTALL.pl.md`)](https://github.com/ako74programmer/poc-cronova-windows/blob/feature/windows-cmd-runtime-sdlc-2026-09-26/deploy/README-INSTALL.pl.md). Jeśli chcesz kontynuować ten tutorial, wróć do **Opcji 1** i nie uruchamiaj `setup.cmd`.

## Opcja 3: Zbuduj scheduler ze źródeł

Aby samodzielnie zbudować binarkę schedulera, zainstaluj **Go 1.26.5 lub nowsze** i wykonaj te polecenia w PowerShell:

```powershell
git clone https://github.com/ako74programmer/poc-cronova-windows
Set-Location .\poc-cronova-windows
go build -o .\cronova.exe .\cmd\cronova
```

`git clone` tworzy katalog `poc-cronova-windows`; kompilację uruchom z tego katalogu. Build wytwarza jeden plik binarny zawierający scheduler, konsolę webową i CLI. Korzysta z SQLite w czystym Go i nie wymaga toolchaina C. Zwykłe `go build` raportuje wersję jako `dev`.

Aby zbudować kompletne archiwum instalacyjne Windows (obie binarki i wszystkie pliki runtime), użyj windowsowych skryptów pakowania i weryfikacji projektu; szczegóły opisuje przewodnik: [Wdrażanie](../DEPLOY.pl.md#budowanie-i-pakowanie-ze-źródeł). Samo zbudowanie `cronova.exe` wystarczy do samodzielnego przejścia tutoriala, ale nie do instalatora usług. Jeśli uruchamiasz binarkę z katalogu repozytorium, wykonaj też opisany wyżej krok tworzenia konta — znajdujący się tam `cronova.yaml` również włącza uwierzytelnianie.

## Czego się nauczyłeś

- Pobierz archiwum ZIP dla Windows amd64 i uruchom bezpośrednio `cronova.exe`, aby przejść tutorial; nie potrzebujesz do tego Go ani uprawnień administratora.
- W ZIP-ie wydania uwierzytelnianie jest włączone; przed pierwszym `serve` utwórz lokalne konto administratora.
- `setup.cmd` to osobny, prowadzony instalator usług Windows lub instalacji dla bieżącego użytkownika; sam uruchamia cronova.
- Aby zbudować ze źródeł tylko scheduler, użyj Go 1.26.5+ z katalogu repozytorium `poc-cronova-windows`.

Następnie napisz i uruchom swój pierwszy DAG — [Pierwszy DAG](first-dag.pl.md).
