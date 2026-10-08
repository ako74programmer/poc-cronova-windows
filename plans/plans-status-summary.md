# Status planów w `plans/`

## Cel tej notatki

Krótki kontekst porządków wykonanych w katalogu [plans/](../plans), żeby przy kolejnym powrocie było jasne:

- które plany są już historyczne,
- które zostały zarchiwizowane jako notatki wdrożeniowe,
- które nadal są aktywne i wymagają domknięcia.

## Stan na teraz

### Usunięte

- `sdlc_fullstack_refactor_plan.md`
  - plan został zrealizowany,
  - [dags/sdlc_fullstack.yaml](../dags/sdlc_fullstack.yaml) jest już DAG-iem integracyjnym,
  - ma tylko taski integracyjne,
  - ma `trigger_after` do [sdlc_angular.yaml](../dags/sdlc_angular.yaml) i [sdlc_springboot_rest.yaml](../dags/sdlc_springboot_rest.yaml).

### Zostawione jako aktywne / częściowo aktywne

- [windows-powershell-remediation-plan.md](../plans/windows-powershell-remediation-plan.md)
  - nadal aktywny,
  - większość najważniejszych zmian została wdrożona,
  - zostały głównie otwarte punkty formalne, końcowe porządki i testy wymagające pełnego środowiska lub uprawnień administratora.

- [sdlc_angular_refactor_plan.md](../plans/sdlc_angular_refactor_plan.md)
  - zaktualizowany,
  - migracja shell → PowerShell jest zakończona,
  - plan dotyczy już nie runtime, tylko przyszłego przejścia Angulara na model kontraktowy OpenAPI.

### Zostawione jako archiwalne notatki wdrożeniowe

- [ai-user-wiki-plan.md](../plans/ai-user-wiki-plan.md)
  - zrealizowany,
  - pozostawiony jako notatka archiwalna o wdrożeniu AI wiki i chatu użytkownika.

- [ai-wiki-iteration-2.md](../plans/ai-wiki-iteration-2.md)
  - zrealizowany,
  - pozostawiony jako notatka archiwalna o iteracji 2: BM25, LLM i rozszerzonych akcjach.

- [ai-wiki-docs-localization.md](../plans/ai-wiki-docs-localization.md)
  - zrealizowany,
  - pozostawiony jako notatka archiwalna o lokalizacji PL/EN i integracji `lang` w AI wiki.

## Najważniejsze ustalenia techniczne z tej sesji

### Windows / PowerShell

Wdrożone zostały między innymi:

- PowerShell-first execution na Windows,
- natywny launcher [app.ps1](../scripts/windows/app.ps1),
- [app.cmd](../app.cmd) zdegradowany do cienkiego wrappera PowerShell,
- testy:
  - [test-powershell-scripts.ps1](../scripts/windows/test-powershell-scripts.ps1)
  - [test-dags.ps1](../scripts/windows/test-dags.ps1)
  - [test-package-smoke.ps1](../scripts/windows/test-package-smoke.ps1)
  - [test-without-git-bash.ps1](../scripts/windows/test-without-git-bash.ps1)
  - [test-services.ps1](../scripts/windows/test-services.ps1)
- packaging i AI wiki zostały zwalidowane.

### AI wiki

Zostały domknięte i/lub potwierdzone:

- backend AI wiki w [internal/aiwiki/](../internal/aiwiki),
- endpoint `POST /api/ask`,
- BM25 retrieval,
- opcjonalna integracja z LLM,
- lokalizacja `lang` dla AI wiki,
- przebudowa [knowledge-base.json](../internal/aiwiki/knowledge-base.json),
- walidacja generatora AI wiki w [build-ai-wiki.ps1](../scripts/build-ai-wiki.ps1).

## Co warto zrobić przy następnym powrocie

1. Zacząć od [windows-powershell-remediation-plan.md](../plans/windows-powershell-remediation-plan.md) i przejrzeć tylko otwarte punkty.
2. Potem zdecydować, czy wracamy do [sdlc_angular_refactor_plan.md](../plans/sdlc_angular_refactor_plan.md), jeśli priorytetem będzie frontend kontraktowy OpenAPI.
3. Planów AI wiki nie traktować już jako aktywnych backlogów — są głównie materiałem archiwalnym i kontekstowym.

## Krótka decyzja robocza

- `windows-powershell-remediation-plan.md` — aktywny
- `sdlc_angular_refactor_plan.md` — aktywny, ale odłożony
- plany AI wiki — archiwalne
- `sdlc_fullstack_refactor_plan.md` — usunięty
