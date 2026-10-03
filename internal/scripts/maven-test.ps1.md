# maven-test.ps1

## Czym jest

`maven-test.ps1` uruchamia `mvn test` dla projektu Maven.
To klocek końcowej walidacji testowej.

## Kiedy używać

- po compile-fix loop,
- jako końcowy krok ścieżki sukcesu DAG-a,
- gdy chcesz ręcznie potwierdzić, że testy przechodzą.

## Jak używać

```powershell
& .\internal\scripts\maven-test.ps1 -w workspaces/springboot-startio -p app
```

## Parametry

- `-w` / `-Workspace` — katalog workspace.
- `-p` / `-Project` — podkatalog projektu.

## Wejście i wyjście

- wejście: projekt Maven w `<Workspace>/<Project>`
- wyjście: wynik `mvn test`

## Gdzie używany

- [dags/sdlc_maven_luhn.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_maven_luhn.yaml)
- [dags/sdlc_springboot_startio.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_startio.yaml)
- [dags/sdlc_springboot.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot.yaml)
