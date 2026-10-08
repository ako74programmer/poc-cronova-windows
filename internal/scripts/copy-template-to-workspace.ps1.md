# copy-template-to-workspace.ps1

## Czym jest

`copy-template-to-workspace.ps1` kopiuje lokalny template z katalogu `templates/` do wskazanego workspace'u.
To klocek scaffoldingu dla przepływów, które startują z gotowego szablonu repozytorium zamiast pobierać projekt z zewnętrznego źródła.

## Kiedy używać

- gdy workflow ma zacząć od lokalnego template'u,
- gdy chcesz odtworzyć workspace testowy ręcznie,
- gdy chcesz zbudować cienki wrapper workflow wokół istniejącego template'u.

## Jak używać

```powershell
& .\internal\scripts\copy-template-to-workspace.ps1 -t springboot-simple -w workspaces/springboot -p app -c
```

## Parametry

- `-t` / `-Template` — nazwa katalogu template'u w `templates/`; wymagane.
- `-w` / `-Workspace` — katalog workspace docelowego; jeśli pominięty, używany jest domyślny workspace Spring Boot.
- `-p` / `-Project` — podkatalog projektu wewnątrz workspace; domyślnie `demo`.
- `-c` / `-Clean` — czyści katalog docelowy przed kopiowaniem.

## Wejście i wyjście

- wejście: katalog `templates/<Template>`
- wyjście: skopiowany projekt w `<Workspace>/<Project>`

## Gdzie używany

- [dags/sdlc_springboot.yaml](../../dags/sdlc_springboot.yaml)
