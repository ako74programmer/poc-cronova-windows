# springboot-maven-test-from-config.ps1

## Czym jest

`springboot-maven-test-from-config.ps1` uruchamia testy Maven Wrapper dla projektu Spring Boot wskazanego przez config.

## Kiedy używać

- po udanej kompilacji,
- gdy chcesz uruchomić testy jednostkowe projektu Spring Boot,
- gdy workspace i wrapper Maven są sterowane z configu.

## Jak używać

```powershell
& .\internal\scripts\springboot-maven-test-from-config.ps1 -Config configs\sdlc-springboot.yaml
```

## Parametry

- `-Config` — workflow config Spring Boot.
- `-Workspace` — opcjonalny katalog workspace; jeśli nie zostanie podany, skrypt użyje wartości z configu.
- `-Artifacts` — opcjonalny katalog artefaktów; jeśli nie zostanie podany, skrypt użyje wartości z configu.

## Wejście i wyjście

- wejście: projekt Spring Boot z `mvnw.cmd`,
- wyjście: wynik `mvnw.cmd -B test` i log testów w artefaktach.

## Gdzie używany

- [dags/sdlc_springboot_rest.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_rest.yaml)
- [dags/sdlc_springboot_variant.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_variant.yaml)