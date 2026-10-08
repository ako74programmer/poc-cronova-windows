# sdlc_springboot_variant

## Czym jest

`sdlc_springboot_variant` to DAG SDLC dla projektu Spring Boot uruchamianego przez config wariantu.
Wariant jest wybierany per-run przez `params.variant`, a sam DAG używa wspólnego zestawu klocków PowerShell.

## Ścieżka sukcesu

1. `springboot_validate_config`
2. `springboot_validate_openapi`
3. `springboot_scaffold_from_config`
4. `springboot_maven_compile_from_config`
5. `springboot_maven_test_from_config`
6. `springboot_package_from_config`

## Jakich klocków używa

- [internal/scripts/springboot-validate-config.ps1](../internal/scripts/springboot-validate-config.ps1)
- [internal/scripts/springboot-validate-openapi.ps1](../internal/scripts/springboot-validate-openapi.ps1)
- [internal/scripts/springboot-scaffold-from-config.ps1](../internal/scripts/springboot-scaffold-from-config.ps1)
- [internal/scripts/springboot-maven-compile-from-config.ps1](../internal/scripts/springboot-maven-compile-from-config.ps1)
- [internal/scripts/springboot-maven-test-from-config.ps1](../internal/scripts/springboot-maven-test-from-config.ps1)
- [internal/scripts/springboot-package-from-config.ps1](../internal/scripts/springboot-package-from-config.ps1)

## Wejścia

- parametr uruchomienia `variant` przekazywany jako `{{ params.variant }}` lub `CRONOVA_PARAM_VARIANT`
- resolver [internal/scripts/resolve-springboot-variant-config.ps1](../internal/scripts/resolve-springboot-variant-config.ps1)
- workflow config wariantu:
	- [configs/sdlc-springboot.yaml](../configs/sdlc-springboot.yaml)
	- [configs/sdlc-springboot-crud.yaml](../configs/sdlc-springboot-crud.yaml)
	- [configs/sdlc-springboot-h2.yaml](../configs/sdlc-springboot-h2.yaml)
	- [configs/sdlc-springboot-security.yaml](../configs/sdlc-springboot-security.yaml)
- standardy wariantów dziedziczące po [configs/standards/springboot-base.yaml](../configs/standards/springboot-base.yaml)

## Wynik

Po sukcesie DAG zostawia skaffoldowany, skompilowany, przetestowany i spakowany projekt Spring Boot zgodny z wybranym configiem wariantu.

## Uwaga

Jeśli `variant` nie zostanie przekazany przy triggerze, DAG domyślnie używa wariantu `rest`.