# sdlc_springboot_rest

## Czym jest

`sdlc_springboot_rest` to ręczny DAG SDLC dla wariantu REST API w rodzinie config-driven Spring Boot.
Jest kompatybilnym entrypointem dla wariantu `rest` i używa tego samego zestawu klocków co DAG wariantowy.

## Ścieżka sukcesu

1. `springboot_validate_config`
2. `springboot_validate_openapi`
3. `springboot_scaffold_from_config`
4. `springboot_maven_compile_from_config`
5. `springboot_maven_test_from_config`
6. `springboot_package_from_config`

## Jakich klocków używa

- [internal/scripts/springboot-validate-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-validate-config.ps1)
- [internal/scripts/springboot-validate-openapi.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-validate-openapi.ps1)
- [internal/scripts/springboot-scaffold-from-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-scaffold-from-config.ps1)
- [internal/scripts/springboot-maven-compile-from-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-maven-compile-from-config.ps1)
- [internal/scripts/springboot-maven-test-from-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-maven-test-from-config.ps1)
- [internal/scripts/springboot-package-from-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-package-from-config.ps1)

## Wejścia

- workflow config [configs/sdlc-springboot.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/configs/sdlc-springboot.yaml)
- standard wariantu [configs/standards/springboot-rest-api.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/configs/standards/springboot-rest-api.yaml)
- standard bazowy [configs/standards/springboot-base.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/configs/standards/springboot-base.yaml)

## Wynik

Po sukcesie DAG zostawia skaffoldowany, skompilowany, przetestowany i spakowany projekt Spring Boot dla wariantu REST API.