# maven-test-compile.ps1

## Czym jest

`maven-test-compile.ps1` uruchamia `mvn test-compile` z `-DskipTests` dla projektu Maven.
To klocek walidacji kompilacji kodu głównego i testowego bez uruchamiania testów.

## Kiedy używać

- gdy chcesz złapać brakujące zależności testowe,
- jako tani check przed pełnym `mvn test`,
- jako lokalny odpowiednik tego, co robi compile-fix loop.

## Jak używać

```powershell
& .\internal\scripts\maven-test-compile.ps1 -w workspaces/sdlc_maven_luhn -p app
```

## Parametry

- `-w` / `-Workspace` — katalog workspace.
- `-p` / `-Project` — podkatalog projektu.

## Wejście i wyjście

- wejście: projekt Maven w `<Workspace>/<Project>`
- wyjście: wynik `mvn test-compile`

## Gdzie używany

- używany jako lokalny klocek walidacyjny i przez logikę compile-fix loop.
