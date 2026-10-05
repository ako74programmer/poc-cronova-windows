# springboot-validate-openapi.ps1

## Czym jest

`springboot-validate-openapi.ps1` wykonuje lekki smoke test kontraktu OpenAPI wskazanego przez config Spring Boot.

## Kiedy używać

- po walidacji configu,
- przed scaffoldem i kompilacją,
- gdy chcesz szybko wykryć brak podstawowych markerów kontraktu.

## Jak używać

```powershell
& .\internal\scripts\springboot-validate-openapi.ps1 -Config configs\sdlc-springboot.yaml
```

## Parametry

- `-Config` — workflow config Spring Boot.
- `-Artifacts` — opcjonalny katalog artefaktów; jeśli nie zostanie podany, skrypt użyje wartości z configu.

## Wejście i wyjście

- wejście: config wskazujący `api.openapi_file`,
- wyjście: log walidacji OpenAPI w katalogu artefaktów.

## Gdzie używany

- [dags/sdlc_springboot_rest.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_rest.yaml)
- [dags/sdlc_springboot_variant.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_variant.yaml)