# maven-compile.ps1

## Czym jest

`maven-compile.ps1` uruchamia `mvn compile` z `-DskipTests` dla projektu Maven.
To podstawowy klocek walidacji kompilacji kodu głównego.

## Kiedy używać

- po scaffoldingu projektu,
- przed generowaniem feature'a przez AI,
- gdy chcesz szybko sprawdzić, czy kod główny się kompiluje.

## Jak używać

```powershell
& .\internal\scripts\maven-compile.ps1 -w workspaces/springboot -p app
```

## Parametry

- `-w` / `-Workspace` — katalog workspace.
- `-p` / `-Project` — podkatalog projektu.

## Wejście i wyjście

- wejście: projekt Maven w `<Workspace>/<Project>`
- wyjście: wynik `mvn compile`

## Gdzie używany

- [dags/sdlc_maven_luhn.yaml](../../dags/sdlc_maven_luhn.yaml)
- [dags/sdlc_springboot_startio.yaml](../../dags/sdlc_springboot_startio.yaml)
- [dags/sdlc_springboot.yaml](../../dags/sdlc_springboot.yaml)
