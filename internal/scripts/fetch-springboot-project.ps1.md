# fetch-springboot-project.ps1

## Czym jest

`fetch-springboot-project.ps1` pobiera projekt Spring Boot z `start.spring.io`, zapisuje archiwum tymczasowe i rozpakowuje je do wskazanego workspace'u.
To klocek scaffoldingu dla przepływów opartych o Spring Initializr.

## Kiedy używać

- gdy workflow ma startować od projektu generowanego przez Spring Initializr,
- gdy chcesz odtworzyć lokalnie dokładnie taki sam scaffold jak w DAG-u,
- gdy chcesz parametryzować wersję Boota, zależności i typ projektu.

## Jak używać

```powershell
& .\internal\scripts\fetch-springboot-project.ps1 -t maven-project -l java -b 4.0.8 -g com.example -a demo -n com.example.demo -Packaging jar -c properties -j 21 -d web -w workspaces/springboot-startio -Project app -Clean
```

## Parametry

- `-t` / `-Type` — typ projektu Initializr, np. `maven-project`.
- `-l` / `-Language` — język, np. `java`.
- `-b` / `-Boot` — wersja Spring Boot.
- `-g` / `-Group` — `groupId`.
- `-a` / `-Artifact` — `artifactId`.
- `-n` / `-Name` — nazwa pakietu Java.
- `-p` / `-Packaging` — typ pakowania, np. `jar`.
- `-c` / `-Config` — format konfiguracji, np. `properties`.
- `-j` / `-Java` — wersja Javy.
- `-d` / `-Dependencies` — zależności Initializr rozdzielone przecinkami.
- `-w` / `-Workspace` — katalog workspace.
- `-Project` — podkatalog projektu w workspace.
- `-y` / `-Python` — interpreter Python używany przez helpery.
- `-Clean` — czyści katalog docelowy przed rozpakowaniem.

## Wejście i wyjście

- wejście: parametry żądania do `start.spring.io`
- wyjście: rozpakowany projekt w `<Workspace>/<Project>`

## Gdzie używany

- [dags/sdlc_springboot_startio.yaml](../../dags/sdlc_springboot_startio.yaml)
