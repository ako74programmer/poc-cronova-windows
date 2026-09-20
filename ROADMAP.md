# Cronova — roadmap Windows-only

**Stan na 20 września 2026 r.**

Projekt jest rozwijany jako rozwiązanie uruchamiane wyłącznie w środowisku Windows. Ten dokument opisuje najbliższe cele techniczne. Nie jest specyfikacją wszystkich funkcji produktu.

## Zakończone

- Runner uruchamia zadania przez **Git for Windows Bash** (`bash.exe -lc`). Brak Bash jest zgłaszany jako jawny błąd.
- Lokalny scheduler–executor używa loopback TCP `127.0.0.1:port`. Zdalny TCP nadal wymaga wzajemnego TLS (mTLS).
- Dodano integrację z Windows Service Control Manager przez `sc.exe`.
- Dodano instalację i odinstalowanie przez `deploy/install.ps1` oraz `deploy/uninstall.ps1`.
- Dodano pakowanie `windows/amd64` do `cronova_windows_amd64.zip`.
- Dodano bramki CI na `windows-latest` oraz testy kompilacji obu binariów Windows.

## Najbliższe cele

### 1. Domknąć kontrolę procesów

Zastąpić obecne zarządzanie grupą procesów Windows przez **Job Objects**. Celem jest gwarantowane kończenie całego drzewa procesu po anulowaniu, przekroczeniu limitu czasu lub zatrzymaniu executora.

### 2. Zweryfikować instalację na Windows

Wykonać testy na wspieranej wersji Windows z uprawnieniami administratora. Zakres powinien obejmować pierwszą instalację, aktualizację, restart systemu, restart usług, logowanie, uprawnienia katalogów oraz odinstalowanie z zachowaniem i usunięciem danych.

### 3. Rozszerzyć testy Windows

Dodać do `windows-latest` testy Git Bash, ścieżek zawierających spacje i znaki Unicode, quoting-u poleceń, anulowania zadań, timeoutów, procesów potomnych oraz lokalnego endpointu loopback TCP.

### 4. Uporządkować dokumentację wdrożeniową

Utrzymywać instrukcje instalacji, konfiguracji Git Bash, rejestracji usług i diagnostyki w jednej ścieżce dokumentacyjnej. Dokumentacja nie powinna sugerować obsługi `systemd`, `launchd` ani Unix socketów jako elementów produktu Windows-only.

### 5. Ustabilizować release

Po przejściu testów na rzeczywistym Windows publikować wersjonowany ZIP Windows amd64 wraz z sumą SHA-256. Przed wydaniem należy potwierdzić instalator i workflow release w GitHub Actions.

## Poza zakresem bieżącej migracji

Nie planuje się obecnie kontenerów, Kubernetes ani natywnych instalatorów MSI. Nie należy też udostępniać lokalnego executora poza loopback bez konfiguracji mTLS.

## Kryteria gotowości

Migrację Windows-only można uznać za domkniętą po spełnieniu wszystkich poniższych warunków:

1. `go test ./...` przechodzi na `windows-latest`.
2. Oba binaria budują się dla `windows/amd64` bez CGO.
3. Zadania i ich procesy potomne są kończone przez Windows Job Objects.
4. Instalacja, aktualizacja, restart i odinstalowanie przechodzą na czystym Windows.
5. Workflow release publikuje działający pakiet oraz sumę SHA-256.
6. Dokumentacja wdrożeniowa opisuje wyłącznie wspieraną ścieżkę Windows.

## Dokumenty powiązane

- [Audyt migracji Windows-only](docs/WINDOWS_AUDIT_2026-09-20.md)
- [Dokumentacja architektury](docs/ARCHITECTURE.md)
- [Instrukcja wdrożenia](docs/DEPLOY.md)
- [Instalator Windows](deploy/install.ps1)

## Referencje

[1]: docs/WINDOWS_AUDIT_2026-09-20.md "Audyt migracji Windows-only"
[2]: docs/DEPLOY.md "Instrukcja wdrożenia"
