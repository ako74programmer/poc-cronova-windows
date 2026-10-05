# springboot-package-from-config.ps1

## Czym jest

`springboot-package-from-config.ps1` buduje wykonywalny JAR Spring Boot, kopiuje go do artefaktów i zapisuje manifest oraz hash.

## Kiedy używać

- po udanych testach,
- gdy chcesz opublikować artefakt backendu Spring Boot,
- gdy nazwa artefaktu i katalog publikacji są sterowane z configu.

## Jak używać

```powershell
& .\internal\scripts\springboot-package-from-config.ps1 -Config configs\sdlc-springboot.yaml
```

## Parametry

- `-Config` — workflow config Spring Boot.
- `-Workspace` — opcjonalny katalog workspace; jeśli nie zostanie podany, skrypt użyje wartości z configu.
- `-Artifacts` — opcjonalny katalog artefaktów; jeśli nie zostanie podany, skrypt użyje wartości z configu.

## Wejście i wyjście

- wejście: projekt Spring Boot z `mvnw.cmd`,
- wyjście: wynik `mvnw.cmd -B package -DskipTests`, skopiowany JAR, SHA256 i manifest backendu.

## Gdzie używany

- [dags/sdlc_springboot_rest.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_rest.yaml)
- [dags/sdlc_springboot_variant.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_variant.yaml)