# springboot-validate-config.ps1

## Czym jest

`springboot-validate-config.ps1` waliduje config Spring Boot, sprawdza toolchain Java/Maven i zapisuje podstawowe artefakty diagnostyczne.

## Kiedy używać

- na początku przepływu Spring Boot,
- gdy chcesz sprawdzić, czy config i runtime są gotowe do dalszych kroków,
- przed scaffoldem, kompilacją i testami.

## Jak używać

```powershell
& .\internal\scripts\springboot-validate-config.ps1 -Config configs\sdlc-springboot.yaml
```

## Parametry

- `-Config` — workflow config Spring Boot.
- `-Artifacts` — opcjonalny katalog artefaktów; jeśli nie zostanie podany, skrypt użyje wartości z configu.

## Wejście i wyjście

- wejście: workflow config i pośrednio standard wariantu/bazowy,
- wyjście: walidacja `project.kind`, dostępności `java`, zapis wersji Java i runtime toolchainu.

## Gdzie używany

- [dags/sdlc_springboot_rest.yaml](../../dags/sdlc_springboot_rest.yaml)
- [dags/sdlc_springboot_variant.yaml](../../dags/sdlc_springboot_variant.yaml)