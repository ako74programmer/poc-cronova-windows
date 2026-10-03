# ai-java-mvn-generate-feature.ps1

## Czym jest

`ai-java-mvn-generate-feature.ps1` to generyczny klocek generowania feature'a dla projektów Java + Maven na podstawie promptu tekstowego.
Czyta istniejący `pom.xml`, buduje pełny prompt dla modelu AI i zapisuje wygenerowane pliki do projektu.

## Kiedy używać

- gdy chcesz generować feature z promptu w `prompts/`,
- gdy chcesz używać jednego technicznego klocka dla różnych feature'ów,
- gdy AI ma aktualizować `pom.xml` tylko wtedy, gdy są potrzebne nowe zależności.

## Jak używać

```powershell
& .\internal\scripts\ai-java-mvn-generate-feature.ps1 -f prompts/springboot_crud.txt -w workspaces/springboot -p app -k com.example.demo -r default -y python
```

## Parametry

- `-f` / `-PromptFile` — plik promptu; wymagane.
- `-w` / `-Workspace` — katalog workspace.
- `-p` / `-Project` — podkatalog projektu.
- `-k` / `-Package` — pakiet Java.
- `-r` / `-ProviderId` — identyfikator providera AI.
- `-m` / `-Model` — model AI.
- `-y` / `-Python` — interpreter Python.
- `-s` / `-IncludeSources` — dołącza istniejące źródła Java do promptu.

## Wejście i wyjście

- wejście: `pom.xml`, prompt tekstowy i opcjonalnie istniejące źródła
- wyjście: nowe lub zmienione pliki Java oraz opcjonalnie zaktualizowany `pom.xml`

## Gdzie używany

- [dags/sdlc_maven_luhn.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_maven_luhn.yaml)
- [dags/sdlc_springboot_startio.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_startio.yaml)
- [dags/sdlc_springboot.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot.yaml)
