# ai-review-java-maven-errors.ps1

## Czym jest

`ai-review-java-maven-errors.ps1` to niski klocek AI review/fix dla projektów Java + Maven.
Nie uruchamia Mavena i nie robi pętli retry. Dostaje gotowy prompt, wywołuje model AI i zapisuje odpowiedź do projektu.

## Kiedy używać

- gdy masz już przygotowany prompt z błędem builda lub testów,
- gdy chcesz zbudować własny loop orkiestracyjny nad jednym wspólnym wywołaniem AI,
- gdy chcesz oddzielić logikę retry od logiki wywołania modelu.

## Jak używać

```powershell
& .\internal\scripts\ai-review-java-maven-errors.ps1 -w workspaces/springboot -p app -k com.example.demo -r default -y python -PromptFile .tmp\ai_review_prompt.txt -RequestFile .tmp\ai_review_request.json -ResponseFile .tmp\ai_review.json
```

## Parametry

- `-w` / `-Workspace` — katalog workspace.
- `-p` / `-Project` — podkatalog projektu.
- `-k` / `-Package` — pakiet Java.
- `-r` / `-ProviderId` — identyfikator providera AI.
- `-m` / `-Model` — model AI.
- `-y` / `-Python` — interpreter Python.
- `-PromptFile` — plik z gotowym promptem; wymagane.
- `-RequestFile` — plik request JSON; wymagane.
- `-ResponseFile` — plik response JSON; wymagane.

## Wejście i wyjście

- wejście: gotowy prompt i ścieżki plików request/response
- wyjście: zapisane poprawki AI w projekcie

## Gdzie używany

- [internal/scripts/java-maven-compile-fix-loop.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/java-maven-compile-fix-loop.ps1)
