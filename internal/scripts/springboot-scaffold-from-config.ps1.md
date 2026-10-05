# springboot-scaffold-from-config.ps1

## Czym jest

`springboot-scaffold-from-config.ps1` generuje projekt Spring Boot z `start.spring.io` na podstawie configu workflow i standardu wariantu.

## Kiedy używać

- gdy przepływ ma startować od Spring Initializr,
- gdy chcesz, aby zależności, `groupId`, `artifactId` i `packageName` pochodziły z configu,
- gdy chcesz odtworzyć scaffold dla konkretnego wariantu aplikacji.

## Jak używać

```powershell
& .\internal\scripts\springboot-scaffold-from-config.ps1 -Config configs\sdlc-springboot.yaml
```

## Parametry

- `-Config` — workflow config Spring Boot.
- `-Workspace` — opcjonalny katalog workspace; jeśli nie zostanie podany, skrypt użyje wartości z configu.
- `-Artifacts` — opcjonalny katalog artefaktów; jeśli nie zostanie podany, skrypt użyje wartości z configu.

## Wejście i wyjście

- wejście: config z danymi Spring Initializr i listą starterów,
- wyjście: rozpakowany projekt Spring Boot w katalogu workspace oraz ZIP scaffoldingu w artefaktach.

## Gdzie używany

- [dags/sdlc_springboot_rest.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_rest.yaml)
- [dags/sdlc_springboot_variant.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_variant.yaml)