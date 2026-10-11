# Wdrażanie cronova w systemie Windows

Cronova w tym repozytorium działa w systemie Windows 10/11 oraz Windows Server na architekturze `amd64`. Składa się z `cronova.exe` (scheduler, REST API i konsola webowa) oraz `cronova-executor.exe` (proces zarządzający zadaniami). Workflowy repozytorium są ujednolicane pod kątem natywnego uruchamiania w Windows, a PowerShell jest podstawową ścieżką skryptową. Zadania poleceń są uruchamiane wyłącznie przez PowerShell (`powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command`); domyślnym typem zadania jest `powershell`, a `type: shell` jest odrzucany podczas parsowania DAG-a.

**Język: [English](DEPLOY.md) | Polski**

## Wymagania

Instalację uruchom w podwyższonej sesji PowerShell (jako administrator).

## Szybka instalacja dla odbiorców pakietu (`setup.cmd`)

W katalogu głównym ZIP-a znajdują się `setup.cmd`, `setup.ps1`, `README-INSTALL.md` (po polsku) i `README-INSTALL.en.md` (po angielsku). Kliknij dwukrotnie `setup.cmd`; przed uruchomieniem instalatora wyświetli on nazwy obu instrukcji:

- usuwa z rozpakowanych plików znacznik pochodzenia z Internetu (`Unblock-File`);
- członek grupy Administratorzy otrzymuje monit UAC z pytaniem o instalację usług Windows; wybranie tej opcji uruchamia `deploy\install.ps1 -Start`;
- w pozostałych przypadkach — również po odmowie UAC — Cronova jest instalowana **dla bieżącego użytkownika, bez uprawnień administratora**: pliki programu trafiają do `%LOCALAPPDATA%\Programs\Cronova`, dane do `%LOCALAPPDATA%\Cronova`, a uruchamianie po zalogowaniu zapewnia zadanie Harmonogramu zadań `Cronova (user)`. Nadzorca `internal\scripts\cronova-user-run.ps1` ponownie uruchamia executor i scheduler po awarii (rezygnuje po 5 awariach w ciągu 5 minut);
- jeśli nie podasz `-AdminPassword`, generowane jest losowe hasło, które zostaje wyświetlone jeden raz.

Opcje: `setup.ps1 -Mode auto|service|user -Port 8091 -AdminUser admin -AdminPassword ... -AiBaseUrl ... -AiModel ...`. Jeśli port jest zajęty, instalacja zostaje przerwana przed wprowadzeniem zmian. Log instalacji usług znajduje się w `%TEMP%\cronova-setup.log`.

Zarządzanie instalacją dla użytkownika:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\Cronova\internal\scripts\cronova-user.ps1" status   # start|stop|restart|uninstall [-Purge]
```

Autorzy tworzą ZIP poleceniem `scripts\release.ps1 [-Version x.y.z]` (check-all, pakowanie, smoke test i SHA-256).

## Instalacja z archiwum ZIP wydania

Rozpakuj `cronova_windows_amd64.zip`, otwórz podwyższoną sesję PowerShell w rozpakowanym katalogu i uruchom:

```powershell
.\deploy\install.ps1
```

Instalator umieszcza pliki programu w `C:\Program Files\Cronova`, tworzy katalog danych `C:\ProgramData\Cronova` i rejestruje dwie usługi Windows: `CronovaExecutor` oraz `Cronova`. Scheduler zależy od executora; dla obu usług skonfigurowano automatyczne odzyskiwanie po awarii.

Zasoby runtime DAG-ów (`internal\scripts`, `scripts\sdlc`, `prompts`, `templates`, `configs`, `contracts`, `e2e\playwright`) są kopiowane do `C:\ProgramData\Cronova`. Executor uruchamia zadania z tego katalogu (`-workdir`), dzięki czemu ścieżki względne w DAG-ach są rozwiązywane prawidłowo. Instalator weryfikuje każdą ścieżkę DAG-a za pomocą `internal\scripts\cronova-verify-dag-paths.ps1`.

Usługi działają jako `LocalSystem` i nie widzą środowiska użytkownika, który przeprowadził instalację. Instalator wykrywa narzędzia (JDK, Maven, Python, Node/npm, Git) i zapisuje zmienne `JAVA_HOME`, `MAVEN_HOME`, `CRONOVA_*` oraz `PATH` w środowisku usługi `CronovaExecutor`. Po zainstalowaniu lub przeniesieniu narzędzi uruchom instalator ponownie.

Dla zadań DAG korzystających z AI i nowej bazy danych skonfiguruj dostawcę AI w interfejsie webowym albo przekaż domyślny endpoint podczas instalacji:

```powershell
.\deploy\install.ps1 -Start -Port 8095 -AiBaseUrl http://127.0.0.1:4141/v1 -AiModel gpt-4o-mini
```

## Dane i konfiguracja

Domyślny katalog danych zawiera `cronova.yaml`, `cronova.db`, `dags`, `projects`, `workspaces`, `logs` i `executor-state`.

Lokalny punkt połączenia scheduler–executor wykorzystuje TCP loopback; dla zainstalowanej usługi jest to zwykle `tcp://127.0.0.1:19090`. Nie wolno wiązać go z publicznym interfejsem. Zdalne połączenia executorów korzystają z mTLS; lokalny ruch ograniczony do loopback może używać lokalnego transportu bez TLS. Obie zainstalowane binarki są przeznaczone do natywnego uruchamiania jako usługi Windows zarządzane przez Service Control Manager.

## Obsługa usług

```powershell
sc.exe query CronovaExecutor
sc.exe query Cronova
sc.exe start CronovaExecutor
sc.exe start Cronova
sc.exe stop Cronova
sc.exe stop CronovaExecutor
```

Polecenia CLI `cronova start`, `cronova stop`, `cronova restart` i `cronova status` korzystają w Windows z Windows Service Control Manager. W trybie deweloperskim można uruchomić bezpośrednio `cronova serve`, ale w środowisku produkcyjnym należy używać obu usług.

## Wykonywanie zadań i izolowanie procesów

Zadania są wykonywane jako podprocesy Windows, z użyciem runtime właściwego dla danego typu zadania. Zadania poleceń (`powershell`) są uruchamiane przez `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command`. Windowsowy runner tworzy dla każdego zadania obiekt Job Object, włącza `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, przypisuje do niego proces zadania, a przy timeoutach i anulowaniu używa `TerminateJobObject`. Podczas kontrolowanego restartu executora flaga kill-on-close jest wyłączana przed zamknięciem lokalnego uchwytu, dzięki czemu utrwalone zadania mogą być kontynuowane. Twarde zakończenie procesu executora nadal wymaga testów odzyskiwania w natywnym środowisku Windows.

Po uruchomieniu przez skrypt `app.ps1` Cronova przed startem uruchamia pomocniczy skrypt wykrywania narzędzi Windows PowerShell i ustawia brakujące ścieżki runtime `CRONOVA_*` w środowisku procesu potomnego. Skrypt wyszukuje Python zainstalowany dla użytkownika w `%LOCALAPPDATA%\Programs\Python\Python*`, Node.js w `%ProgramFiles%\nodejs`, JDK w `%ProgramFiles%\Java\jdk-*` lub katalogach Eclipse Adoptium/Microsoft, a Maven w `%ProgramFiles%\Apache\Maven` lub `%SystemDrive%\apache-maven-*`. Runner zadań ma także awaryjne wykrywanie po stronie Go. Jawne wartości `CRONOVA_PYTHON`, `CRONOVA_NODE`, `CRONOVA_NPM`, `CRONOVA_JAVA_HOME`, `CRONOVA_MAVEN_HOME`, `JAVA_HOME` i `MAVEN_HOME` mają pierwszeństwo. Instalacje w innych lokalizacjach dodaj do windowsowego `PATH` albo skonfiguruj odpowiednie zmienne `CRONOVA_*` przed uruchomieniem Cronova.

## Aktualizacja i odinstalowanie {#updating}

Skrypt aktualizacji uruchom w podwyższonej sesji PowerShell. Zatrzymuje obie usługi, podmienia pliki wykonywalne (zachowując poprzednie jako `*.bak`), uruchamia obie usługi i sprawdza, czy mają status `RUNNING`. Jeśli dowolny krok się nie powiedzie, poprzednie binarki są przywracane i uruchamiane ponownie, a skrypt kończy działanie z błędem. Katalog `ProgramData` nie jest modyfikowany:

```powershell
.\deploy\update.ps1
```

Odinstalowanie domyślnie zachowuje dane. Opcji `-Purge` używaj tylko wtedy, gdy katalog danych ma zostać trwale usunięty:

```powershell
.\deploy\uninstall.ps1
.\deploy\uninstall.ps1 -Purge
```

Przed nieodwracalnymi pracami serwisowymi wykonaj kopię zapasową `C:\ProgramData\Cronova`, w tym bazy danych i klucza szyfrowania. Przed ponowną instalacją odtwórz cały katalog.

## Budowanie i pakowanie ze źródeł

W systemie Windows z Go w wersji 1.26.5 lub nowszej uruchom:

```powershell
.\scripts\package.ps1
```

Skrypt buduje obie binarki `windows/amd64` i tworzy `dist\cronova_windows_amd64.zip` oraz `dist\SHA256SUMS` (plik wymagany przez `cronova update`; publikując wydanie, dołącz oba pliki). Pakiet zawiera trzy skrypty PowerShell do zarządzania cyklem życia, `cronova.yaml`, przykładowe DAG-i, skrypty PowerShell runtime z `internal/scripts` oraz zasoby `configs`, `contracts`, `prompts`, `templates` i Playwright wymagane przez dystrybuowane DAG-i.

## Status weryfikacji

Projekt nie ma hostowanego CI. Wszystkie kontrole są uruchamiane lokalnie w Windows jednym skryptem, który może być bez zmian użyty przez przyszły pipeline (np. GitLab Runner w Windows):

```powershell
.\scripts\windows\check-all.ps1            # gofmt, go mod verify, synchronizacja dokumentacji, baza wiedzy AI, vet, testy i testy PowerShell
.\scripts\windows\check-all.ps1 -Full      # dodatkowo race detector i govulncheck
.\scripts\windows\check-all.ps1 -Package   # dodatkowo zbuduj ZIP wydania i zweryfikuj odwołania DAG-ów
```

Kompilacja krzyżowa `windows/amd64` na innym systemie nie zastępuje natywnej weryfikacji usług Windows, Job Objects, ACL-i, czystej instalacji, odzyskiwania usług ani kończenia procesów potomnych.
