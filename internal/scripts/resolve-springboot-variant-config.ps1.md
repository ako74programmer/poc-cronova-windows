# resolve-springboot-variant-config.ps1

## Czym jest

`resolve-springboot-variant-config.ps1` mapuje nazwę wariantu Spring Boot na odpowiadający mu workflow config.
To cienki klocek pomocniczy używany przez DAG wariantowy.

## Kiedy używać

- gdy run wybiera wariant aplikacji per-run,
- gdy chcesz zamienić `rest`, `crud`, `h2` albo `security` na konkretny plik configu,
- gdy chcesz utrzymać wspólne klocki wykonawcze bez duplikowania DAG-ów.

## Jak używać

```powershell
& .\internal\scripts\resolve-springboot-variant-config.ps1 -Variant h2
```

## Parametry

- `-Variant` — nazwa wariantu: `rest`, `crud`, `h2`, `security`.

## Wejście i wyjście

- wejście: nazwa wariantu Spring Boot,
- wyjście: ścieżka do workflow configu, np. `configs/sdlc-springboot-h2.yaml`.

## Gdzie używany

- [dags/sdlc_springboot_variant.yaml](../../dags/sdlc_springboot_variant.yaml)