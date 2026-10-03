# generate-maven-archetype.ps1

## Czym jest

`generate-maven-archetype.ps1` generuje projekt Java + Maven przez `mvn archetype:generate`, a następnie kopiuje wynik do docelowego workspace'u.
To klocek scaffoldingu dla przepływów opartych o archetyp Maven.

## Kiedy używać

- gdy workflow ma startować od archetypu Maven,
- gdy chcesz ręcznie odtworzyć scaffold dla DAG-a Maven,
- gdy potrzebujesz kontrolować `groupId`, `artifactId`, pakiet i wersję Javy.

## Jak używać

```powershell
& .\internal\scripts\generate-maven-archetype.ps1 -a maven-archetype-quickstart -g com.example -r luhn -k com.example.luhn -j 21 -w workspaces/sdlc_maven_luhn -p app -C
```

## Parametry

- `-a` / `-Archetype` — nazwa archetypu Maven.
- `-v` / `-ArchetypeVersion` — wersja archetypu.
- `-g` / `-Group` — `groupId`.
- `-r` / `-Artifact` — `artifactId`.
- `-k` / `-Package` — pakiet Java.
- `-j` / `-JavaVersion` — wersja Javy wpisywana do `pom.xml`.
- `-w` / `-Workspace` — katalog workspace.
- `-p` / `-Project` — podkatalog projektu.
- `-C` / `-Clean` — czyści katalog docelowy przed kopiowaniem.

## Wejście i wyjście

- wejście: parametry archetypu Maven
- wyjście: wygenerowany projekt w `<Workspace>/<Project>`

## Gdzie używany

- [dags/sdlc_maven_luhn.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_maven_luhn.yaml)
