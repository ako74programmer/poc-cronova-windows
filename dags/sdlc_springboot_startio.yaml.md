# sdlc_springboot_startio

## Czym jest

`sdlc_springboot_startio` to DAG SDLC dla projektu Spring Boot pobieranego z `start.spring.io`.
Pobiera scaffold z Initializr, kompiluje szkielet, generuje prosty CRUD z promptu, domyka kompilację przez AI i uruchamia testy.

## Ścieżka sukcesu

1. `fetch_springboot_project`
2. `maven_compile`
3. `ai_generate_java_maven_feature`
4. `java_maven_compile_fix_loop`
5. `maven_test`

## Jakich klocków używa

- [internal/scripts/fetch-springboot-project.ps1](../internal/scripts/fetch-springboot-project.ps1)
- [internal/scripts/maven-compile.ps1](../internal/scripts/maven-compile.ps1)
- [internal/scripts/ai-java-mvn-generate-feature.ps1](../internal/scripts/ai-java-mvn-generate-feature.ps1)
- [internal/scripts/java-maven-compile-fix-loop.ps1](../internal/scripts/java-maven-compile-fix-loop.ps1)
- [internal/scripts/maven-test.ps1](../internal/scripts/maven-test.ps1)

## Wejścia

- scaffold z `start.spring.io`
- prompt [prompts/springboot_crud.txt](../prompts/springboot_crud.txt)
- workspace `workspaces/springboot-startio/app`

## Wynik

Po sukcesie DAG zostawia projekt Spring Boot wygenerowany z Initializr, rozszerzony o prosty CRUD `Item` i przechodzące testy.
