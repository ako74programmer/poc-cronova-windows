# java-maven-compile-fix-loop.ps1

## Czym jest

`java-maven-compile-fix-loop.ps1` to samodzielny klocek orkiestracyjny dla projektów Java + Maven.
Uruchamia `mvn test-compile`, a gdy kompilacja się nie powiedzie, buduje prompt z błędem i wywołuje AI review/fix, po czym ponawia próbę.

## Kiedy używać

- gdy feature wygenerowany przez AI wymaga domknięcia zależności lub poprawek kodu,
- gdy chcesz mieć automatyczny loop `test-compile -> AI -> retry`,
- jako klocek po `ai-java-mvn-generate-feature.ps1` i przed `maven-test.ps1`.

## Jak używać

```powershell
& .\internal\scripts\java-maven-compile-fix-loop.ps1 -LoopWorkspace workspaces/springboot-startio -LoopProject app -LoopPackage com.example.demo -LoopProvider default -LoopPython python
```

## Parametry

- `-LoopWorkspace` — katalog workspace.
- `-LoopProject` — podkatalog projektu.
- `-LoopPackage` — pakiet Java.
- `-LoopIterations` — maksymalna liczba iteracji; domyślnie `3`.
- `-LoopProvider` — identyfikator providera AI.
- `-LoopModel` — model AI.
- `-LoopPython` — interpreter Python.

## Wejście i wyjście

- wejście: projekt Maven po scaffoldingu i generacji feature'a
- wyjście: projekt, który przechodzi `mvn test-compile`, albo błąd po wyczerpaniu iteracji

## Gdzie używany

- [dags/sdlc_maven_luhn.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_maven_luhn.yaml)
- [dags/sdlc_springboot_startio.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_startio.yaml)
- [dags/sdlc_springboot.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot.yaml)
