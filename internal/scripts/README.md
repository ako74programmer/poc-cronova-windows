# Reuzywalne klocki SDLC

Katalog `internal/scripts/` zawiera techniczne klocki używane przez DAG-i Cronova.
Każdy klocek ma własny plik `.md` w tym samym katalogu z opisem celu, parametrów i przykładowego użycia.

Aktywne entrypointy workflow w tym katalogu są PowerShellowe (`.ps1`). Historyczne odpowiedniki bashowe są usuwane z głównej ścieżki Windows-only.

## Jak czytać ten katalog

- skrypt `.ps1` to wykonywalny klocek,
- odpowiadający mu plik `.ps1.md` to dokumentacja tego klocka,
- DAG w katalogu `dags/` pokazuje, jak te klocki są składane w przepływ.

## Klocki scaffoldingu

- [internal/scripts/copy-template-to-workspace.ps1](../../internal/scripts/copy-template-to-workspace.ps1)
  Dokumentacja: [internal/scripts/copy-template-to-workspace.ps1.md](../../internal/scripts/copy-template-to-workspace.ps1.md)
- [internal/scripts/fetch-springboot-project.ps1](../../internal/scripts/fetch-springboot-project.ps1)
  Dokumentacja: [internal/scripts/fetch-springboot-project.ps1.md](../../internal/scripts/fetch-springboot-project.ps1.md)
- [internal/scripts/generate-maven-archetype.ps1](../../internal/scripts/generate-maven-archetype.ps1)
  Dokumentacja: [internal/scripts/generate-maven-archetype.ps1.md](../../internal/scripts/generate-maven-archetype.ps1.md)
- [internal/scripts/resolve-springboot-variant-config.ps1](../../internal/scripts/resolve-springboot-variant-config.ps1)
- [internal/scripts/cronova-service-common.ps1](../../internal/scripts/cronova-service-common.ps1)
  Dokumentacja: [internal/scripts/cronova-service-common.ps1.md](../../internal/scripts/cronova-service-common.ps1.md)
- [internal/scripts/cronova-uninstall.ps1](../../internal/scripts/cronova-uninstall.ps1)
  Dokumentacja: [internal/scripts/cronova-uninstall.ps1.md](../../internal/scripts/cronova-uninstall.ps1.md)
- [internal/scripts/cronova-get-service-state.ps1](../../internal/scripts/cronova-get-service-state.ps1)
  Dokumentacja: [internal/scripts/cronova-get-service-state.ps1.md](../../internal/scripts/cronova-get-service-state.ps1.md)
- [internal/scripts/cronova-get-service-pid.ps1](../../internal/scripts/cronova-get-service-pid.ps1)
  Dokumentacja: [internal/scripts/cronova-get-service-pid.ps1.md](../../internal/scripts/cronova-get-service-pid.ps1.md)
- [internal/scripts/cronova-stop-service.ps1](../../internal/scripts/cronova-stop-service.ps1)
  Dokumentacja: [internal/scripts/cronova-stop-service.ps1.md](../../internal/scripts/cronova-stop-service.ps1.md)
- [internal/scripts/cronova-force-kill-pid.ps1](../../internal/scripts/cronova-force-kill-pid.ps1)
  Dokumentacja: [internal/scripts/cronova-force-kill-pid.ps1.md](../../internal/scripts/cronova-force-kill-pid.ps1.md)
- [internal/scripts/cronova-force-clean-services.ps1](../../internal/scripts/cronova-force-clean-services.ps1)
  Dokumentacja: [internal/scripts/cronova-force-clean-services.ps1.md](../../internal/scripts/cronova-force-clean-services.ps1.md)
- [internal/scripts/cronova-remove-service.ps1](../../internal/scripts/cronova-remove-service.ps1)
  Dokumentacja: [internal/scripts/cronova-remove-service.ps1.md](../../internal/scripts/cronova-remove-service.ps1.md)
- [internal/scripts/cronova-resolve-package-source.ps1](../../internal/scripts/cronova-resolve-package-source.ps1)
  Dokumentacja: [internal/scripts/cronova-resolve-package-source.ps1.md](../../internal/scripts/cronova-resolve-package-source.ps1.md)
- [internal/scripts/cronova-install-from-source.ps1](../../internal/scripts/cronova-install-from-source.ps1)
  Kopiuje zasoby DAG-ów (`internal\scripts`, `scripts\sdlc`, `prompts`, `templates`, `configs`, `contracts`, `e2e\playwright`) do `C:\ProgramData\Cronova` i uruchamia executor z `-workdir C:\ProgramData\Cronova`, więc względne ścieżki w DAG-ach działają po instalacji.
- [internal/scripts/cronova-verify-dag-paths.ps1](../../internal/scripts/cronova-verify-dag-paths.ps1)
  Sprawdza, czy każda względna ścieżka (skrypty, prompty, template'y, configi) użyta w `dags\*.yaml` istnieje pod wskazanym katalogiem. Używany przez smoke test paczki i instalator.
  Przykład: `.\internal\scripts\cronova-verify-dag-paths.ps1 -Root C:\ProgramData\Cronova`
- [internal/scripts/cronova-configure-service-env.ps1](../../internal/scripts/cronova-configure-service-env.ps1)
  Wykrywa toolchain (JDK, Maven, Python, Node/npm, Git) i zapisuje `JAVA_HOME`, `MAVEN_HOME`, `CRONOVA_*` oraz `PATH` jako środowisko usługi (`LocalSystem` nie widzi zmiennych użytkownika). Wywoływany przez instalator.
  Przykład: `.\internal\scripts\cronova-configure-service-env.ps1 -ServiceName CronovaExecutor -Extra 'CRONOVA_DB=C:\ProgramData\Cronova\cronova.db'`
- [internal/scripts/seed-cronova-admin.ps1](../../internal/scripts/seed-cronova-admin.ps1)
  Dokumentacja: [internal/scripts/seed-cronova-admin.ps1.md](../../internal/scripts/seed-cronova-admin.ps1.md)

## Klocki Spring Boot config-driven

- [internal/scripts/springboot-validate-config.ps1](../../internal/scripts/springboot-validate-config.ps1)
- [internal/scripts/springboot-validate-openapi.ps1](../../internal/scripts/springboot-validate-openapi.ps1)
- [internal/scripts/springboot-scaffold-from-config.ps1](../../internal/scripts/springboot-scaffold-from-config.ps1)
- [internal/scripts/springboot-maven-compile-from-config.ps1](../../internal/scripts/springboot-maven-compile-from-config.ps1)
- [internal/scripts/springboot-maven-test-from-config.ps1](../../internal/scripts/springboot-maven-test-from-config.ps1)
- [internal/scripts/springboot-package-from-config.ps1](../../internal/scripts/springboot-package-from-config.ps1)

Te klocki są używane przez:

- [dags/sdlc_springboot_rest.yaml](../../dags/sdlc_springboot_rest.yaml)
- [dags/sdlc_springboot_variant.yaml](../../dags/sdlc_springboot_variant.yaml)

W przypadku DAG-a wariantowego config jest wybierany per-run przez `CRONOVA_PARAM_VARIANT` i resolver [internal/scripts/resolve-springboot-variant-config.ps1](../../internal/scripts/resolve-springboot-variant-config.ps1).

## Klocki walidacji Maven

- [internal/scripts/maven-compile.ps1](../../internal/scripts/maven-compile.ps1)
  Dokumentacja: [internal/scripts/maven-compile.ps1.md](../../internal/scripts/maven-compile.ps1.md)
- [internal/scripts/maven-test-compile.ps1](../../internal/scripts/maven-test-compile.ps1)
  Dokumentacja: [internal/scripts/maven-test-compile.ps1.md](../../internal/scripts/maven-test-compile.ps1.md)
- [internal/scripts/maven-test.ps1](../../internal/scripts/maven-test.ps1)
  Dokumentacja: [internal/scripts/maven-test.ps1.md](../../internal/scripts/maven-test.ps1.md)

Te klocki zastępują stare bashowe entrypointy `compile-project` i `run-tests`, które nie są już częścią aktywnej ścieżki Windows-only.

## Klocki AI dla Java + Maven

- [internal/scripts/ai-java-mvn-generate-feature.ps1](../../internal/scripts/ai-java-mvn-generate-feature.ps1)
  Dokumentacja: [internal/scripts/ai-java-mvn-generate-feature.ps1.md](../../internal/scripts/ai-java-mvn-generate-feature.ps1.md)
- [internal/scripts/ai-review-java-maven-errors.ps1](../../internal/scripts/ai-review-java-maven-errors.ps1)
  Dokumentacja: [internal/scripts/ai-review-java-maven-errors.ps1.md](../../internal/scripts/ai-review-java-maven-errors.ps1.md)
- [internal/scripts/java-maven-compile-fix-loop.ps1](../../internal/scripts/java-maven-compile-fix-loop.ps1)
  Dokumentacja: [internal/scripts/java-maven-compile-fix-loop.ps1.md](../../internal/scripts/java-maven-compile-fix-loop.ps1.md)

Te klocki zastępują stare bashowe entrypointy `ai-generate-crud`, `ai-generate-feature` i `ai-review-fix-loop`, które nie są już częścią aktywnej ścieżki Windows-only.

## Jak używać klocków lego

Najprostszy wzorzec dla projektu Java + Maven wygląda tak:

1. scaffold projektu,
2. kompilacja szkieletu,
3. wygenerowanie feature'a z promptu,
4. compile-fix loop,
5. testy.

### Template Spring Boot

1. [internal/scripts/copy-template-to-workspace.ps1](../../internal/scripts/copy-template-to-workspace.ps1)
2. [internal/scripts/maven-compile.ps1](../../internal/scripts/maven-compile.ps1)
3. [internal/scripts/ai-java-mvn-generate-feature.ps1](../../internal/scripts/ai-java-mvn-generate-feature.ps1)
4. [internal/scripts/java-maven-compile-fix-loop.ps1](../../internal/scripts/java-maven-compile-fix-loop.ps1)
5. [internal/scripts/maven-test.ps1](../../internal/scripts/maven-test.ps1)

Zobacz DAG: [dags/sdlc_springboot_template_crud.yaml](../../dags/sdlc_springboot_template_crud.yaml)
Dokumentacja DAG-a: [dags/sdlc_springboot_template_crud.yaml.md](../../dags/sdlc_springboot_template_crud.yaml.md)

### Spring Initializr

1. [internal/scripts/fetch-springboot-project.ps1](../../internal/scripts/fetch-springboot-project.ps1)
2. [internal/scripts/maven-compile.ps1](../../internal/scripts/maven-compile.ps1)
3. [internal/scripts/ai-java-mvn-generate-feature.ps1](../../internal/scripts/ai-java-mvn-generate-feature.ps1)
4. [internal/scripts/java-maven-compile-fix-loop.ps1](../../internal/scripts/java-maven-compile-fix-loop.ps1)
5. [internal/scripts/maven-test.ps1](../../internal/scripts/maven-test.ps1)

Zobacz DAG: [dags/sdlc_springboot_startio.yaml](../../dags/sdlc_springboot_startio.yaml)
Dokumentacja DAG-a: [dags/sdlc_springboot_startio.yaml.md](../../dags/sdlc_springboot_startio.yaml.md)

### Maven archetype

1. [internal/scripts/generate-maven-archetype.ps1](../../internal/scripts/generate-maven-archetype.ps1)
2. [internal/scripts/maven-compile.ps1](../../internal/scripts/maven-compile.ps1)
3. [internal/scripts/ai-java-mvn-generate-feature.ps1](../../internal/scripts/ai-java-mvn-generate-feature.ps1)
4. [internal/scripts/java-maven-compile-fix-loop.ps1](../../internal/scripts/java-maven-compile-fix-loop.ps1)
5. [internal/scripts/maven-test.ps1](../../internal/scripts/maven-test.ps1)

Zobacz DAG: [dags/sdlc_maven_luhn.yaml](../../dags/sdlc_maven_luhn.yaml)
Dokumentacja DAG-a: [dags/sdlc_maven_luhn.yaml.md](../../dags/sdlc_maven_luhn.yaml.md)

## Referencje do DAG-ów

- [dags/sdlc_maven_luhn.yaml](../../dags/sdlc_maven_luhn.yaml)
- [dags/sdlc_springboot_template_crud.yaml](../../dags/sdlc_springboot_template_crud.yaml)
- [dags/sdlc_springboot_startio.yaml](../../dags/sdlc_springboot_startio.yaml)
- [dags/sdlc_springboot_rest.yaml](../../dags/sdlc_springboot_rest.yaml)
- [dags/sdlc_springboot_variant.yaml](../../dags/sdlc_springboot_variant.yaml)
- [dags/sdlc_maven_luhn.yaml.md](../../dags/sdlc_maven_luhn.yaml.md)
- [dags/sdlc_springboot_template_crud.yaml.md](../../dags/sdlc_springboot_template_crud.yaml.md)
- [dags/sdlc_springboot_startio.yaml.md](../../dags/sdlc_springboot_startio.yaml.md)
- [dags/sdlc_springboot_variant.yaml.md](../../dags/sdlc_springboot_variant.yaml.md)

Każdy aktywny DAG `.yaml` opisany w tym README ma teraz własny plik `.md` w katalogu `dags/`.
