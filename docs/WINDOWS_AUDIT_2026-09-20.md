# Audyt migracji Cronova do Windows-only

## Zakres i punkt odniesienia

Audyt wykonano względem `main` repozytorium `ako74programmer/poc-cronova-windows` zgodnie z planem migracji dostarczonym 20 września 2026 r. Zmiany zostały wykonane na gałęzi `fix/windows-audit-2026-09-20`. Celem tej iteracji było usunięcie blokad kompilacji Windows, ustanowienie bezpiecznych domyślnych ścieżek wykonania z Git for Windows oraz dodanie powtarzalnych artefaktów i bramki CI dla `windows-latest`.

## Najważniejsze ustalenia przed zmianami

Kod zawierał Unix socket jako domyślny kanał executora, `/tmp` jako domyślny katalog endpointu, `Setpgid` i grupy procesów Unix, fallback zadań Windows do `cmd.exe`, a także bezpośrednio kompilowaną obsługę `systemd`, `launchd`, `sudo` i `syscall.Exec` w CLI. Repozytorium nie miało natywnego instalatora PowerShell ani Windowsowego workflowu testowego. Dokumentacja i workflowy nadal reklamowały Linux/macOS jako platformy produktu.

## Wprowadzone zmiany

| Obszar | Zmiana | Weryfikacja |
|---|---|---|
| Runner Windows | Git Bash jest wyszukiwany w `CRONOVA_BASH_PATH`, `PATH` i typowych lokalizacjach Git for Windows; zadania są uruchamiane przez `bash.exe -lc`; brak Bash kończy uruchomienie jednoznacznym błędem; usunięto fallback do `cmd.exe`. | Kompilacja `windows/amd64`; istniejące testy runnera przechodzą na hoście Linux. |
| Lokalny transport executora | Na Windows `-sock` oznacza loopback TCP `127.0.0.1:port`; listener odrzuca inne adresy. Unixowy listener został przeniesiony do pliku `endpoint_unix.go`. | Kompilacja obu binariów Windows; testy Unix endpointu pozostają oznaczone `!windows`. |
| Klient executora | `tcp://127.0.0.1:port` jest dozwolony bez TLS wyłącznie dla loopback; zdalny TCP nadal wymaga mTLS. | Kompilacja pakietu executora. |
| Konfiguracja Bash | Dodano `bash_path` oraz `CRONOVA_BASH_PATH`; konfiguracja propaguje ścieżkę do procesu lokalnego. | Parsowanie konfiguracji i kompilacja. |
| CLI usług | Dodano wariant Windows korzystający z `sc.exe`/Windows Service Control Manager; unixowa implementacja usług nie jest kompilowana na Windows. | `go build` dla `windows/amd64`. |
| Instalacja | Dodano `deploy/install.ps1` i `deploy/uninstall.ps1`; instalator sprawdza Git Bash, tworzy katalogi w `ProgramData`, instaluje dwa binaria i rejestruje usługi. Odinstalowanie bez `-Purge` zachowuje dane. | Przegląd statyczny skryptów; pełne uruchomienie wymaga Windows z uprawnieniami administratora. |
| Pakowanie | Dodano `scripts/package.ps1`, który buduje `cronova_windows_amd64.zip` i wypisuje SHA-256. | Skrypt jest używany w workflow release. |
| CI | `test.yml` ma główną bramkę `windows-latest`; `release.yml` buduje i publikuje wyłącznie ZIP Windows amd64. | Walidacja struktury workflow i lokalny build. |
| Testy Unix-only | Testy oparte bezpośrednio na `net.Listen("unix", ...)` są wyłączone na Windows tagiem `!windows`; nie są przedstawiane jako testy Windows. | Audyt źródeł i kompilacja Windows. |

## Wyniki lokalnej weryfikacji

Wykonano następujące polecenia przy użyciu Go 1.27.1:

```text
go test ./...                         PASS
go build ./...                       PASS
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build ./cmd/cronova             PASS
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build ./cmd/cronova-executor   PASS
```

Nie wykonano natywnego uruchomienia `.exe`, testu Windows Service, testu Job Objects ani świeżej instalacji na czystym Windows w sandboxie Linux. Brak lokalnego Go w obrazie bazowym został obejściowo pokryty tymczasowym Go 1.27.1.

## Ograniczenia i ryzyka pozostające po tej iteracji

1. **Job Objects nie zostały jeszcze zaimplementowane.** Windows runner nadal używa `CREATE_NEW_PROCESS_GROUP` oraz `taskkill /T`; jest to rozwiązanie przejściowe i nie daje takiej gwarancji kontroli drzewa procesu jak Windows Job Object. Nie należy na tej podstawie deklarować bezwarunkowego braku osieroconych procesów.
2. **Loopback TCP bez TLS** jest dopuszczony tylko dla `127.0.0.1` i jest przeznaczony dla scheduler–executor na tej samej maszynie. Zdalny executor musi używać mTLS. Nie należy wiązać lokalnego endpointu do `0.0.0.0`.
3. **Instalator wymaga testu na Windows 10/11 lub Windows Server** z uprawnieniami administratora. Nie zweryfikowano jeszcze ACL katalogów, restartu po restarcie systemu, kolejności usług ani polityki konta usługi.
4. **Dokumentacja publiczna nie została jeszcze w całości przepisana.** W repozytorium pozostały historyczne sekcje i kod nieużywany w kompilacji Windows odnoszący się do Linux/macOS, `systemd`, `launchd`, `/var` oraz `/etc`. Przed finalnym wydaniem trzeba przepisać README, dokumentację wdrożenia i komendy aktualizacji albo usunąć nieaktywne ścieżki.
5. **Workflow release wymaga pierwszego uruchomienia w GitHub Actions.** Lokalne środowisko nie może potwierdzić działania `windows-latest`, publikacji artefaktu ani podpisu release.
6. **Testy Unix-only nie zostały zastąpione pełnym zestawem testów TCP Windows.** Przed zamknięciem migracji należy dodać test loopback endpointu, test `bash.exe -lc`, quotingu, Unicode, ścieżek ze spacjami, timeoutu/cancel oraz procesu potomnego na `windows-latest`.
7. **Minimalna wersja Windows i minimalna wersja Git for Windows nie są jeszcze formalnie przypięte.** Instalator sprawdza obecność i uruchamialność Bash, ale nie egzekwuje wersji systemu ani wersji Git.

## Ocena względem kryteriów zakończenia

Ta gałąź jest **iteracją naprawczą, nie pełnym zakończeniem migracji**. Spełnia kompilację `windows/amd64`, wymusza Git Bash w runnerze, dodaje Windows Service/PowerShell jako ścieżkę produktu i ustanawia bramkę CI. Nie spełnia jeszcze kryteriów Job Objects, pełnej świeżej instalacji Windows, kompletnego przepisania dokumentacji, testów SCM oraz testów recovery po twardym zakończeniu executora.
