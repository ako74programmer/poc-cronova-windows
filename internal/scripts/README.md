# Reuzywalne klocki SDLC

Katalog `internal/scripts/` zawiera techniczne klocki używane przez DAG-i Cronova.
Każdy klocek ma własny plik `.md` w tym samym katalogu z opisem celu, parametrów i przykładowego użycia.

## Jak czytać ten katalog

- skrypt `.ps1` to wykonywalny klocek,
- odpowiadający mu plik `.ps1.md` to dokumentacja tego klocka,
- DAG w katalogu `dags/` pokazuje, jak te klocki są składane w przepływ.

## Klocki scaffoldingu

- [internal/scripts/copy-template-to-workspace.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/copy-template-to-workspace.ps1)
  Dokumentacja: [internal/scripts/copy-template-to-workspace.ps1.md](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/copy-template-to-workspace.ps1.md)
- [internal/scripts/fetch-springboot-project.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/fetch-springboot-project.ps1)
  Dokumentacja: [internal/scripts/fetch-springboot-project.ps1.md](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/fetch-springboot-project.ps1.md)
- [internal/scripts/generate-maven-archetype.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/generate-maven-archetype.ps1)
  Dokumentacja: [internal/scripts/generate-maven-archetype.ps1.md](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/generate-maven-archetype.ps1.md)
- [internal/scripts/resolve-springboot-variant-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/resolve-springboot-variant-config.ps1)

## Klocki Spring Boot config-driven

- [internal/scripts/springboot-validate-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-validate-config.ps1)
- [internal/scripts/springboot-validate-openapi.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-validate-openapi.ps1)
- [internal/scripts/springboot-scaffold-from-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-scaffold-from-config.ps1)
- [internal/scripts/springboot-maven-compile-from-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-maven-compile-from-config.ps1)
- [internal/scripts/springboot-maven-test-from-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-maven-test-from-config.ps1)
- [internal/scripts/springboot-package-from-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/springboot-package-from-config.ps1)

Te klocki są używane przez:

- [dags/sdlc_springboot_rest.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_rest.yaml)
- [dags/sdlc_springboot_variant.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_variant.yaml)

W przypadku DAG-a wariantowego config jest wybierany per-run przez `CRONOVA_PARAM_VARIANT` i resolver [internal/scripts/resolve-springboot-variant-config.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/resolve-springboot-variant-config.ps1).

## Klocki walidacji Maven

- [internal/scripts/maven-compile.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-compile.ps1)
  Dokumentacja: [internal/scripts/maven-compile.ps1.md](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-compile.ps1.md)
- [internal/scripts/maven-test-compile.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-test-compile.ps1)
  Dokumentacja: [internal/scripts/maven-test-compile.ps1.md](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-test-compile.ps1.md)
- [internal/scripts/maven-test.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-test.ps1)
  Dokumentacja: [internal/scripts/maven-test.ps1.md](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-test.ps1.md)

## Klocki AI dla Java + Maven

- [internal/scripts/ai-java-mvn-generate-feature.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/ai-java-mvn-generate-feature.ps1)
  Dokumentacja: [internal/scripts/ai-java-mvn-generate-feature.ps1.md](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/ai-java-mvn-generate-feature.ps1.md)
- [internal/scripts/ai-review-java-maven-errors.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/ai-review-java-maven-errors.ps1)
  Dokumentacja: [internal/scripts/ai-review-java-maven-errors.ps1.md](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/ai-review-java-maven-errors.ps1.md)
- [internal/scripts/java-maven-compile-fix-loop.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/java-maven-compile-fix-loop.ps1)
  Dokumentacja: [internal/scripts/java-maven-compile-fix-loop.ps1.md](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/java-maven-compile-fix-loop.ps1.md)

## Jak używać klocków lego

Najprostszy wzorzec dla projektu Java + Maven wygląda tak:

1. scaffold projektu,
2. kompilacja szkieletu,
3. wygenerowanie feature'a z promptu,
4. compile-fix loop,
5. testy.

### Template Spring Boot

1. [internal/scripts/copy-template-to-workspace.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/copy-template-to-workspace.ps1)
2. [internal/scripts/maven-compile.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-compile.ps1)
3. [internal/scripts/ai-java-mvn-generate-feature.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/ai-java-mvn-generate-feature.ps1)
4. [internal/scripts/java-maven-compile-fix-loop.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/java-maven-compile-fix-loop.ps1)
5. [internal/scripts/maven-test.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-test.ps1)

Zobacz DAG: [dags/sdlc_springboot_template_crud.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_template_crud.yaml)
Dokumentacja DAG-a: [dags/sdlc_springboot_template_crud.yaml.md](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_template_crud.yaml.md)

### Spring Initializr

1. [internal/scripts/fetch-springboot-project.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/fetch-springboot-project.ps1)
2. [internal/scripts/maven-compile.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-compile.ps1)
3. [internal/scripts/ai-java-mvn-generate-feature.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/ai-java-mvn-generate-feature.ps1)
4. [internal/scripts/java-maven-compile-fix-loop.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/java-maven-compile-fix-loop.ps1)
5. [internal/scripts/maven-test.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-test.ps1)

Zobacz DAG: [dags/sdlc_springboot_startio.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_startio.yaml)
Dokumentacja DAG-a: [dags/sdlc_springboot_startio.yaml.md](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_startio.yaml.md)

### Maven archetype

1. [internal/scripts/generate-maven-archetype.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/generate-maven-archetype.ps1)
2. [internal/scripts/maven-compile.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-compile.ps1)
3. [internal/scripts/ai-java-mvn-generate-feature.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/ai-java-mvn-generate-feature.ps1)
4. [internal/scripts/java-maven-compile-fix-loop.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/java-maven-compile-fix-loop.ps1)
5. [internal/scripts/maven-test.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-test.ps1)

Zobacz DAG: [dags/sdlc_maven_luhn.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_maven_luhn.yaml)
Dokumentacja DAG-a: [dags/sdlc_maven_luhn.yaml.md](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_maven_luhn.yaml.md)

## Referencje do DAG-ów

- [dags/sdlc_maven_luhn.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_maven_luhn.yaml)
- [dags/sdlc_springboot_template_crud.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_template_crud.yaml)
- [dags/sdlc_springboot_startio.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_startio.yaml)
- [dags/sdlc_springboot_rest.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_rest.yaml)
- [dags/sdlc_springboot_variant.yaml](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_variant.yaml)
- [dags/sdlc_maven_luhn.yaml.md](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_maven_luhn.yaml.md)
- [dags/sdlc_springboot_template_crud.yaml.md](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_template_crud.yaml.md)
- [dags/sdlc_springboot_startio.yaml.md](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_startio.yaml.md)
- [dags/sdlc_springboot_variant.yaml.md](c:/Users/Andrzej/Downloads/sdlc/cronova/dags/sdlc_springboot_variant.yaml.md)

Każdy aktywny DAG `.yaml` opisany w tym README ma teraz własny plik `.md` w katalogu `dags/`.
