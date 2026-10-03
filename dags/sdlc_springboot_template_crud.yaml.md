# sdlc_springboot_template_crud

## Czym jest

`sdlc_springboot_template_crud` to DAG SDLC dla projektu Spring Boot startującego z lokalnego template'u.
Kopiuje template, kompiluje szkielet, generuje prosty CRUD z promptu, domyka kompilację przez AI i uruchamia testy.

## Ścieżka sukcesu

1. `copy_template_to_workspace`
2. `maven_compile`
3. `ai_generate_java_maven_feature`
4. `java_maven_compile_fix_loop`
5. `maven_test`

## Jakich klocków używa

- [internal/scripts/copy-template-to-workspace.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/copy-template-to-workspace.ps1)
- [internal/scripts/maven-compile.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-compile.ps1)
- [internal/scripts/ai-java-mvn-generate-feature.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/ai-java-mvn-generate-feature.ps1)
- [internal/scripts/java-maven-compile-fix-loop.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/java-maven-compile-fix-loop.ps1)
- [internal/scripts/maven-test.ps1](c:/Users/Andrzej/Downloads/sdlc/cronova/internal/scripts/maven-test.ps1)

## Wejścia

- template `templates/springboot-simple`
- prompt [prompts/springboot_crud.txt](c:/Users/Andrzej/Downloads/sdlc/cronova/prompts/springboot_crud.txt)
- workspace `workspaces/springboot/app`

## Wynik

Po sukcesie DAG zostawia projekt Spring Boot z prostym CRUD-em `Item` i przechodzącymi testami.
