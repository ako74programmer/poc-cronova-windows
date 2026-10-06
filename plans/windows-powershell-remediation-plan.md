z# Plan naprawczy po audycie Windows + PowerShell

## Cel

Doprowadzić repozytorium i produkt do spójnego modelu **Windows-only, PowerShell-first**, bez ukrytych zależności od Git Bash w aktywnej ścieżce produktu, z poprawnym instalatorem, UI, paczką release i dokumentacją.

## Jak używać tej checklisty

- `[ ]` oznacza zadanie otwarte,
- `[x]` oznacza zadanie zakończone,
- po zamknięciu zadania warto dopisać krótką notatkę z wynikiem lub link do commita,
- zadania są małe i mogą być realizowane etapami,
- dokumentację aktualizujemy razem ze zmianą kodu, nie wcześniej.

## Checklista wykonawcza

### Etap 0. Zamrożenie zakresu i potwierdzenie stanu

- [ ] **0.1 Potwierdzić formalnie zakres produktu**
  - [ ] potwierdzić decyzję: `Windows-only` albo `cross-platform z preferencją Windows`
  - [ ] wpisać decyzję do głównego dokumentu architektonicznego lub operacyjnego
  - [ ] zanotować jednoznaczny wynik decyzji

- [ ] **0.2 Skorygować tezy audytu o aktualny runner Windows**
  - [ ] dopisać notatkę, że [runner_windows.go](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/executor/runner_windows.go) uruchamia obecnie zadania przez `powershell.exe`
  - [ ] zostawić jako otwarte problemy: instalator, konfigurację, dokumentację i legacy alias `shell`
  - [ ] potwierdzić, że opis audytu nie wprowadza w błąd co do runtime

### Etap 1. Instalacja i usługi Windows

- [x] **1.1 Potwierdzić, czy binarki są prawdziwymi usługami Windows**
  - [x] sprawdzić [main.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/main.go)
  - [x] sprawdzić [main.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova-executor/main.go)
  - [x] potwierdzić brak lub obecność hosta usługi Windows
  - [x] opisać wynik krótką notatką techniczną

- [x] **1.2 Wybrać model uruchamiania usług**
  - [x] porównać opcję: natywny host usług Windows w Go
  - [x] porównać opcję: wspierany wrapper usługi
  - [x] wybrać jedną opcję
  - [x] opisać minimalny zakres zmian w kodzie i instalatorze

- [x] **1.3 Dodać obsługę hosta usługi dla `cronova`**
  - [x] dodać ścieżkę startu jako usługa
  - [x] obsłużyć start, stop i poprawne zamknięcie procesu
  - [x] zachować dotychczasowe uruchamianie konsolowe
  - [ ] zweryfikować działanie lokalne

- [x] **1.4 Dodać obsługę hosta usługi dla `cronova-executor`**
  - [x] dodać ścieżkę startu jako usługa
  - [x] dopilnować poprawnego zamykania listenera i cleanupu
  - [x] zachować dotychczasowe uruchamianie konsolowe
  - [ ] zweryfikować działanie lokalne

- [x] **1.5 Poprawić obsługę błędów `sc.exe` w [install.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/deploy/install.ps1)**
  - [x] po każdym wywołaniu `sc.exe` sprawdzać `$LASTEXITCODE`
  - [x] przerwać instalację przy błędzie
  - [x] dopisać końcową walidację stanu usług
  - [ ] zweryfikować przypadek niepowodzenia

- [ ] **1.6 Dodać test ręczny instalacji usług na czystym Windows**
  - [ ] zbudować paczkę
  - [ ] uruchomić instalację na czystym katalogu danych
  - [ ] wykonać `install`
  - [ ] wykonać `start`
  - [ ] wykonać `stop`
  - [ ] wykonać `restart`
  - [ ] wykonać `uninstall`
  - [ ] spisać wynik testu

### Etap 2. UI i edycja tasków PowerShell

- [x] **2.1 Dodać `powershell` do selektora typu taska**
  - [x] rozszerzyć listę typów w [views.js](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/web/static/views.js)
  - [x] upewnić się, że istniejący task `powershell` pozostaje zaznaczony po otwarciu formularza
  - [ ] sprawdzić zapis bez niejawnej podmiany na `shell`

- [ ] **2.2 Sprawdzić builder komendy dla typu `powershell`**
  - [ ] przejrzeć `commandFieldHtml`
  - [ ] przejrzeć `wireCommandField`
  - [ ] przejrzeć `computeCmdRaw`
  - [ ] upewnić się, że `powershell` korzysta z poprawnego wariantu formularza

- [x] **2.3 Dodać test round-trip DAG-a z taskiem PowerShell**
  - [x] wczytać DAG z `type: powershell`
  - [x] zapisać bez modyfikacji
  - [x] potwierdzić, że YAML nadal ma `type: powershell`
  - [x] potwierdzić, że komenda pozostała identyczna

### Etap 3. Packaging i kompletność release

- [x] **3.1 Spisać manifest runtime dla dołączanych DAG-ów**
  - [x] przejrzeć wszystkie aktywne DAG-i w [dags/](C:/Users/Andrzej/Downloads/sdlc/cronova/dags)
  - [x] wypisać zależności `internal/scripts`
  - [x] wypisać zależności `configs`
  - [x] wypisać zależności `contracts`
  - [x] wypisać zależności `templates`
  - [x] wypisać zależności `prompts`
  - [x] wypisać zależności `e2e`
  - [x] dopisać inne wymagane katalogi, jeśli występują

- [x] **3.2 Uzupełnić [package.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/scripts/package.ps1)**
  - [x] dodać kopiowanie brakujących katalogów z manifestu
  - [x] nie kopiować zbędnych artefaktów deweloperskich
  - [ ] zbudować nową paczkę testową

- [ ] **3.3 Dodać smoke test paczki release**
  - [ ] zbudować ZIP
  - [ ] rozpakować ZIP do czystego katalogu tymczasowego
  - [ ] sprawdzić obecność wszystkich ścieżek referencjonowanych przez dołączone DAG-i
  - [ ] spisać wynik walidacji

- [ ] **3.4 Zdecydować, które DAG-i mają być dystrybuowane**
  - [ ] ograniczyć zestaw DAG-ów w release albo
  - [ ] doprowadzić wszystkie dystrybuowane DAG-i do pełnej samowystarczalności
  - [ ] zapisać finalny zakres release

### Etap 4. Konfiguracja i usunięcie legacy Git Bash

- [ ] **4.1 Zinwentaryzować wszystkie miejsca użycia `bash_path`**
  - [ ] przejrzeć [config.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/config.go)
  - [ ] przejrzeć [main.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/main.go)
  - [ ] przejrzeć [start.cmd](C:/Users/Andrzej/Downloads/sdlc/cronova/start.cmd)
  - [ ] przejrzeć testy
  - [ ] spisać, które użycia są aktywne, a które historyczne

- [x] **4.2 Usunąć wymóg Git Bash z instalatora**
  - [x] usunąć wyszukiwanie `bash.exe` z [install.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/deploy/install.ps1)
  - [x] przestać ustawiać `CRONOVA_BASH_PATH`
  - [x] przestać nadpisywać `bash_path` w YAML
  - [ ] zweryfikować instalację bez Git Bash

- [ ] **4.3 Uprościć [start.cmd](C:/Users/Andrzej/Downloads/sdlc/cronova/start.cmd)**
  - [ ] usunąć detekcję `CRONOVA_BASH_PATH`
  - [ ] zostawić tylko wymagania realnie potrzebne dla aktywnej ścieżki
  - [ ] zweryfikować lokalny start po zmianie

- [x] **4.4 Usunąć `bash_path` z konfiguracji, jeśli nie jest już potrzebny**
  - [x] usunąć pole z [config.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/config.go)
  - [x] usunąć obsługę env `CRONOVA_BASH_PATH`
  - [x] poprawić przykładowe YAML
  - [x] poprawić testy

- [x] **4.5 Zadecydować o przyszłości aliasu `shell`**
  - [x] podjąć decyzję: alias na PowerShell albo blokada na etapie walidacji
  - [x] wdrożyć decyzję w parserze
  - [x] wdrożyć decyzję w UI
  - [x] wdrożyć decyzję w walidacji
  - [x] wdrożyć decyzję w dokumentacji

### Etap 5. Dokumentacja i AI Wiki

- [x] **5.1 Naprawić [DEPLOY.md](C:/Users/Andrzej/Downloads/sdlc/cronova/docs/DEPLOY.md)**
  - [x] usunąć nieobsługiwaną opcję `-BashPath`
  - [x] opisać realne parametry i kroki instalacji
  - [x] zsynchronizować dokument z aktualnym [install.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/deploy/install.ps1)

- [x] **5.2 Przejrzeć tutoriale pod kątem Bash/Linux/macOS**
  - [x] przejrzeć [docs/](C:/Users/Andrzej/Downloads/sdlc/cronova/docs)
  - [x] przejrzeć README
  - [x] poprawić opisy `sh -c`
  - [x] poprawić opisy `curl | sudo bash`
  - [x] poprawić opisy `systemd`
  - [x] poprawić opisy `launchd`, jeśli nie są już wspierane
  - [x] wskazać [app.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/scripts/windows/app.ps1) jako zalecany launcher Windows

- [x] **5.3 Odbudować [knowledge-base.json](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/aiwiki/knowledge-base.json)**
  - [x] przebudować indeks z aktualnych plików
  - [x] usunąć stare bashowe workflowy i ścieżki deweloperskie
  - [x] zweryfikować brak `#!/usr/bin/env bash`
  - [ ] zweryfikować brak nieaktualnego `type: shell`
  - [x] zweryfikować brak lokalnych ścieżek deweloperskich

- [x] **5.4 Dodać kontrolę jakości dla AI Wiki**
  - [x] dodać walidację albo test sprawdzający zakazane wzorce w wygenerowanej bazie
  - [x] potwierdzić, że regresja AI Wiki jest wykrywana automatycznie

### Etap 6. Porządki platformowe

- [ ] **6.1 Zinwentaryzować aktywny kod unixowy**
  - [ ] przejrzeć [runner_unix.go](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/executor/runner_unix.go)
  - [ ] przejrzeć [endpoint_unix.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova-executor/endpoint_unix.go)
  - [ ] przejrzeć [service.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/service.go)
  - [ ] przejrzeć pliki w [deploy/](C:/Users/Andrzej/Downloads/sdlc/cronova/deploy)
  - [ ] opisać, które elementy mają zostać, a które usunąć po decyzji `Windows-only`

- [ ] **6.2 Usunąć lub wyłączyć niewspierane ścieżki platformowe**
  - [ ] po decyzji architektonicznej usunąć lub wyłączyć nieużywane implementacje i assety deploy
  - [ ] zweryfikować, że repo odzwierciedla realny zakres wsparcia

### Etap 7. Testy i bramki jakości

- [x] **7.1 Dodać test walidujący wszystkie aktywne DAG-i**
  - [x] sprawdzić parsowanie wszystkich plików z [dags/](C:/Users/Andrzej/Downloads/sdlc/cronova/dags)
  - [x] wykrywać nieobsługiwane typy
  - [x] wykrywać brakujące pliki runtime

- [x] **7.2 Dodać test parsera skryptów PowerShell**
  - [x] uruchamiać walidację składni dla aktywnych skryptów w [internal/scripts/](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts)
  - [x] spisać minimalny sposób uruchamiania tej walidacji w CI lub lokalnie

- [x] **7.3 Dodać test packaging smoke**
  - [x] zautomatyzować scenariusz z zadania 3.3
  - [x] dodać go do regularnej walidacji

- [x] **7.4 Dodać test usług Windows**
  - [x] zautomatyzować minimalny scenariusz `install -> start -> status -> stop`
  - [x] potwierdzić, że wynik jest czytelny diagnostycznie

- [x] **7.5 Dodać test bez Git Bash**
  - [x] uruchomić testy runtime na Windows bez zainstalowanego Git Bash albo z wyczyszczonym `CRONOVA_BASH_PATH`
  - [x] potwierdzić zgodność aktywnej ścieżki z celem PowerShell-first

## Sugerowana kolejność realizacji

1. Etap 0 — decyzja zakresu i korekta audytu.
2. Etap 1 — usługi Windows i instalator.
3. Etap 2 — UI task type `powershell`.
4. Etap 3 — packaging release.
5. Etap 4 — usunięcie Git Bash z aktywnej ścieżki.
6. Etap 5 — dokumentacja i AI Wiki.
7. Etap 6 — porządki platformowe.
8. Etap 7 — testy i bramki jakości.

## Minimalny pierwszy sprint

- [ ] 1.1 Potwierdzić, czy binarki są prawdziwymi usługami Windows
- [ ] 1.2 Wybrać model uruchamiania usług
- [x] 1.5 Poprawić obsługę błędów `sc.exe` w instalatorze
- [x] 2.1 Dodać `powershell` do selektora typu taska
- [x] 2.3 Dodać test round-trip DAG-a z taskiem PowerShell
- [x] 3.1 Spisać manifest runtime dla dołączanych DAG-ów
- [x] 3.2 Uzupełnić `package.ps1`
- [x] 4.2 Usunąć wymóg Git Bash z instalatora
- [x] 5.1 Naprawić `DEPLOY.md`

Ten sprint daje mały, praktyczny pakiet: instalator mniej ryzykowny, UI nie psuje tasków PowerShell, release jest bliżej kompletności, a dokumentacja przestaje kłamać.

---
## Etap 0. Zamrożenie zakresu i potwierdzenie stanu

### Zadanie 0.1 — potwierdzić formalnie zakres produktu
**Cel:** ustalić, czy produkt ma być bezwzględnie Windows-only.

**Do zrobienia:**
- potwierdzić w repo i dokumentacji decyzję: `Windows-only` albo `cross-platform z preferencją Windows`,
- wpisać tę decyzję do głównego dokumentu architektonicznego lub operacyjnego.

**Wynik:** jedna, jawna decyzja architektoniczna.

### Zadanie 0.2 — skorygować tezy audytu o aktualny runner Windows
**Cel:** odróżnić problemy realne od już naprawionych.

**Do zrobienia:**
- dopisać notatkę, że [runner_windows.go](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/executor/runner_windows.go) uruchamia obecnie zadania przez `powershell.exe`,
- zostawić jako otwarty problem: instalator, konfiguracja, dokumentacja i legacy alias `shell`.

**Wynik:** audyt roboczy nie wprowadza w błąd co do bieżącego runtime.

---

## Etap 1. Instalacja i usługi Windows

### Zadanie 1.1 — potwierdzić, czy binarki są prawdziwymi usługami Windows
**Cel:** ustalić, czy obecna instalacja przez `sc.exe create` może działać.

**Do zrobienia:**
- sprawdzić entrypointy [cmd/cronova/main.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/main.go) i [cmd/cronova-executor/main.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova-executor/main.go),
- potwierdzić brak lub obecność hosta usługi Windows,
- opisać wynik krótką notatką techniczną.

**Wynik:** jednoznaczna odpowiedź, czy SCM może uruchomić obecne EXE jako usługę.

### Zadanie 1.2 — wybrać model uruchamiania usług
**Cel:** podjąć decyzję implementacyjną.

**Opcje:**
- natywny host usług Windows w Go,
- wspierany wrapper usługi.

**Do zrobienia:**
- wybrać jedną opcję,
- opisać minimalny zakres zmian w kodzie i instalatorze.

**Wynik:** zamknięta decyzja projektowa.

### Zadanie 1.3 — dodać obsługę hosta usługi dla `cronova`
**Cel:** umożliwić uruchamianie schedulera przez SCM.

**Do zrobienia:**
- dodać ścieżkę startu jako usługa,
- obsłużyć start, stop i poprawne zamknięcie procesu,
- zachować dotychczasowe uruchamianie konsolowe.

**Wynik:** `cronova.exe` działa zarówno interaktywnie, jak i jako usługa.

### Zadanie 1.4 — dodać obsługę hosta usługi dla `cronova-executor`
**Cel:** umożliwić uruchamianie executora przez SCM.

**Do zrobienia:**
- analogicznie do zadania 1.3,
- dopilnować poprawnego zamykania listenera i cleanupu.

**Wynik:** `cronova-executor.exe` działa jako usługa.

### Zadanie 1.5 — poprawić obsługę błędów `sc.exe` w [install.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/deploy/install.ps1)
**Cel:** instalator ma kończyć się błędem przy nieudanej operacji SCM.

**Do zrobienia:**
- po każdym wywołaniu `sc.exe` sprawdzać `$LASTEXITCODE`,
- przerwać instalację przy błędzie,
- dopisać końcową walidację stanu usług.

**Wynik:** brak fałszywie pozytywnej instalacji.

### Zadanie 1.6 — dodać test ręczny instalacji usług na czystym Windows
**Cel:** sprawdzić rzeczywiste zachowanie po zmianach.

**Do zrobienia:**
- zbudować paczkę,
- uruchomić instalację na czystym katalogu danych,
- wykonać `install`, `start`, `stop`, `restart`, `uninstall`.

**Wynik:** potwierdzona ścieżka wdrożeniowa.

---

## Etap 2. UI i edycja tasków PowerShell

### Zadanie 2.1 — dodać `powershell` do selektora typu taska
**Cel:** UI ma poprawnie prezentować aktualny typ taska.

**Do zrobienia:**
- rozszerzyć listę typów w [views.js](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/web/static/views.js),
- upewnić się, że istniejący task `powershell` pozostaje zaznaczony po otwarciu formularza.

**Wynik:** brak niejawnej podmiany `powershell` na `shell` w edytorze.

### Zadanie 2.2 — sprawdzić builder komendy dla typu `powershell`
**Cel:** UI ma renderować właściwe pole edycji dla tasków PowerShell.

**Do zrobienia:**
- przejrzeć logikę `commandFieldHtml`, `wireCommandField`, `computeCmdRaw`,
- upewnić się, że `powershell` korzysta z poprawnego wariantu formularza.

**Wynik:** task PowerShell daje się bezpiecznie edytować.

### Zadanie 2.3 — dodać test round-trip DAG-a z taskiem PowerShell
**Cel:** zapis w UI nie może zmieniać typu taska.

**Do zrobienia:**
- wczytać DAG z `type: powershell`,
- zapisać bez modyfikacji,
- potwierdzić, że YAML nadal ma `type: powershell` i tę samą komendę.

**Wynik:** brak regresji edytora DAG.

---

## Etap 3. Packaging i kompletność release

### Zadanie 3.1 — spisać manifest runtime dla dołączanych DAG-ów
**Cel:** wiedzieć dokładnie, jakie pliki są potrzebne po rozpakowaniu ZIP-a.

**Do zrobienia:**
- przejrzeć wszystkie aktywne DAG-i w [dags/](C:/Users/Andrzej/Downloads/sdlc/cronova/dags),
- wypisać zależności: `internal/scripts`, `configs`, `contracts`, `templates`, `prompts`, `e2e`, ewentualne inne katalogi.

**Wynik:** lista plików wymaganych przez każdy dystrybuowany DAG.

### Zadanie 3.2 — uzupełnić [package.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/scripts/package.ps1)
**Cel:** ZIP ma zawierać komplet zależności runtime.

**Do zrobienia:**
- dodać kopiowanie brakujących katalogów z manifestu,
- nie kopiować zbędnych artefaktów deweloperskich.

**Wynik:** paczka release jest samowystarczalna dla dołączonych DAG-ów.

### Zadanie 3.3 — dodać smoke test paczki release
**Cel:** wykrywać braki przed wydaniem.

**Do zrobienia:**
- zbudować ZIP,
- rozpakować do czystego katalogu tymczasowego,
- sprawdzić obecność wszystkich ścieżek referencjonowanych przez dołączone DAG-i.

**Wynik:** automatyczna kontrola kompletności paczki.

### Zadanie 3.4 — zdecydować, które DAG-i mają być dystrybuowane
**Cel:** nie wysyłać przykładów, które nie mają pełnych zależności.

**Do zrobienia:**
- albo ograniczyć zestaw DAG-ów w release,
- albo doprowadzić wszystkie dystrybuowane DAG-i do pełnej samowystarczalności.

**Wynik:** spójny zakres zawartości release.

---

## Etap 4. Konfiguracja i usunięcie legacy Git Bash

### Zadanie 4.1 — zinwentaryzować wszystkie miejsca użycia `bash_path`
**Cel:** znać pełny zasięg zmiany.

**Do zrobienia:**
- przejrzeć [config.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/config.go), [main.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/main.go), [start.cmd](C:/Users/Andrzej/Downloads/sdlc/cronova/start.cmd) i testy,
- spisać, które użycia są jeszcze aktywne, a które tylko historyczne.

**Wynik:** lista miejsc do usunięcia lub migracji.

### Zadanie 4.2 — usunąć wymóg Git Bash z instalatora
**Cel:** instalacja Windows nie wymaga już bash.exe.

**Do zrobienia:**
- usunąć wyszukiwanie `bash.exe` z [install.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/deploy/install.ps1),
- przestać ustawiać `CRONOVA_BASH_PATH`,
- przestać nadpisywać `bash_path` w YAML.

**Wynik:** instalator jest zgodny z modelem PowerShell-first.

### Zadanie 4.3 — uprościć [start.cmd](C:/Users/Andrzej/Downloads/sdlc/cronova/start.cmd)
**Cel:** lokalny start nie sugeruje zależności od Git Bash.

**Do zrobienia:**
- usunąć detekcję `CRONOVA_BASH_PATH`,
- zostawić tylko wymagania realnie potrzebne dla aktywnej ścieżki.

**Wynik:** lokalny bootstrap jest spójny z runtime.

### Zadanie 4.4 — usunąć `bash_path` z konfiguracji, jeśli nie jest już potrzebny
**Cel:** uprościć model konfiguracyjny.

**Do zrobienia:**
- usunąć pole z [config.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/config.go),
- usunąć obsługę env `CRONOVA_BASH_PATH`,
- poprawić przykładowe YAML i testy.

**Wynik:** brak martwego parametru konfiguracyjnego.

### Zadanie 4.5 — zadecydować o przyszłości aliasu `shell`
**Cel:** zamknąć temat zgodności wstecznej.

**Opcje:**
- zostawić `shell` jako alias na PowerShell,
- zablokować `shell` na etapie walidacji i migracji DAG-ów.

**Do zrobienia:**
- podjąć decyzję,
- wdrożyć ją konsekwentnie w parserze, UI, walidacji i dokumentacji.

**Wynik:** jasny kontrakt typów tasków na Windows.

---

## Etap 5. Dokumentacja i AI Wiki

### Zadanie 5.1 — naprawić [DEPLOY.md](C:/Users/Andrzej/Downloads/sdlc/cronova/docs/DEPLOY.md)
**Cel:** dokument ma odpowiadać rzeczywistemu interfejsowi instalatora.

**Do zrobienia:**
- usunąć nieobsługiwaną opcję `-BashPath`,
- opisać realne parametry i kroki instalacji,
- zsynchronizować z aktualnym [install.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/deploy/install.ps1).

**Wynik:** poprawna instrukcja wdrożenia Windows.

### Zadanie 5.2 — przejrzeć tutoriale pod kątem Bash/Linux/macOS
**Cel:** usunąć przekaz sprzeczny z kierunkiem produktu.

**Do zrobienia:**
- przejrzeć [docs/](C:/Users/Andrzej/Downloads/sdlc/cronova/docs), README i powiązane strony,
- poprawić opisy `sh -c`, `curl | sudo bash`, `systemd`, `launchd`, jeśli nie są już wspierane.

**Wynik:** dokumentacja nie sugeruje nieistniejącej ścieżki produktu.

### Zadanie 5.3 — odbudować [knowledge-base.json](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/aiwiki/knowledge-base.json)
**Cel:** AI Wiki ma bazować na aktualnych źródłach.

**Do zrobienia:**
- przebudować indeks z aktualnych plików,
- usunąć stare bashowe workflowy i ścieżki deweloperskie,
- zweryfikować, że nie ma `#!/usr/bin/env bash`, `type: shell` w nieaktualnym znaczeniu ani lokalnych ścieżek deweloperskich.

**Wynik:** AI Wiki nie propaguje przestarzałych instrukcji.

### Zadanie 5.4 — dodać kontrolę jakości dla AI Wiki
**Cel:** zapobiec powrotowi nieaktualnych danych.

**Do zrobienia:**
- dodać prostą walidację lub test sprawdzający zakazane wzorce w wygenerowanej bazie.

**Wynik:** regresja AI Wiki jest wykrywana automatycznie.

---

## Etap 6. Porządki platformowe

### Zadanie 6.1 — zinwentaryzować aktywny kod unixowy
**Cel:** oddzielić kod historyczny od nadal potrzebnego.

**Do zrobienia:**
- przejrzeć [internal/executor/runner_unix.go](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/executor/runner_unix.go), [cmd/cronova-executor/endpoint_unix.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova-executor/endpoint_unix.go), [cmd/cronova/service.go](C:/Users/Andrzej/Downloads/sdlc/cronova/cmd/cronova/service.go) oraz pliki w [deploy/](C:/Users/Andrzej/Downloads/sdlc/cronova/deploy),
- opisać, które elementy mają zostać, a które usunąć po decyzji `Windows-only`.

**Wynik:** bezpieczna lista porządków platformowych.

### Zadanie 6.2 — usunąć lub wyłączyć niewspierane ścieżki platformowe
**Cel:** produkt i repo mają odzwierciedlać realny zakres wsparcia.

**Do zrobienia:**
- po decyzji architektonicznej usunąć lub wyłączyć nieużywane implementacje i assety deploy.

**Wynik:** brak pozornej wieloplatformowości, jeśli nie jest wspierana.

---

## Etap 7. Testy i bramki jakości

### Zadanie 7.1 — dodać test walidujący wszystkie aktywne DAG-i
**Cel:** każdy DAG w aktywnej ścieżce ma poprawne typy i ścieżki.

**Do zrobienia:**
- sprawdzić parsowanie wszystkich plików z [dags/](C:/Users/Andrzej/Downloads/sdlc/cronova/dags),
- wykrywać nieobsługiwane typy i brakujące pliki runtime.

**Wynik:** szybka walidacja spójności DAG-ów.

### Zadanie 7.2 — dodać test parsera skryptów PowerShell
**Cel:** wcześnie wykrywać błędy składni `.ps1`.

**Do zrobienia:**
- uruchamiać walidację składni dla aktywnych skryptów w [internal/scripts/](C:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts).

**Wynik:** mniej awarii runtime przez błędny skrypt.

### Zadanie 7.3 — dodać test packaging smoke
**Cel:** CI wykrywa niekompletną paczkę release.

**Do zrobienia:**
- zautomatyzować scenariusz z zadania 3.3.

**Wynik:** release bez brakujących plików.

### Zadanie 7.4 — dodać test usług Windows
**Cel:** sprawdzać realny lifecycle usługi.

**Do zrobienia:**
- zautomatyzować minimalny scenariusz `install -> start -> status -> stop` na Windows.

**Wynik:** podstawowa gwarancja działania instalatora i hosta usług.

### Zadanie 7.5 — dodać test bez Git Bash
**Cel:** potwierdzić pełne odejście od Bash w aktywnej ścieżce.

**Do zrobienia:**
- uruchomić testy runtime na Windows bez zainstalowanego Git Bash albo z wyczyszczonym `CRONOVA_BASH_PATH`.

**Wynik:** rzeczywista zgodność z celem PowerShell-first.

---

## Sugerowana kolejność realizacji

1. Etap 0 — decyzja zakresu i korekta audytu.
2. Etap 1 — usługi Windows i instalator.
3. Etap 2 — UI task type `powershell`.
4. Etap 3 — packaging release.
5. Etap 4 — usunięcie Git Bash z aktywnej ścieżki.
6. Etap 5 — dokumentacja i AI Wiki.
7. Etap 6 — porządki platformowe.
8. Etap 7 — testy i bramki jakości.

## Minimalny pierwszy sprint

Jeśli celem jest szybkie domknięcie największych ryzyk, pierwszy sprint powinien objąć tylko:

1. Zadanie 1.1
2. Zadanie 1.2
3. Zadanie 1.5
4. Zadanie 2.1
5. Zadanie 2.3
6. Zadanie 3.1
7. Zadanie 3.2
8. Zadanie 4.2
9. Zadanie 5.1

To daje mały, praktyczny pakiet: instalator mniej ryzykowny, UI nie psuje tasków PowerShell, release jest bliżej kompletności, a dokumentacja przestaje kłamać.
