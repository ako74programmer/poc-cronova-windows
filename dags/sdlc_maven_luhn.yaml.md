# sdlc_maven_luhn

## Czym jest

`sdlc_maven_luhn` to DAG pokazujący przepływ SDLC dla projektu Java + Maven generowanego z archetypu.
Buduje prosty projekt `luhn`, generuje feature z promptu, domyka kompilację przez AI i uruchamia testy.

## Ścieżka sukcesu

1. `generate_maven_archetype`
2. `maven_compile`
3. `ai_generate_java_maven_feature`
4. `java_maven_compile_fix_loop`
5. `maven_test`

## Jakich klocków używa

- [internal/scripts/generate-maven-archetype.ps1](../internal/scripts/generate-maven-archetype.ps1)
- [internal/scripts/maven-compile.ps1](../internal/scripts/maven-compile.ps1)
- [internal/scripts/ai-java-mvn-generate-feature.ps1](../internal/scripts/ai-java-mvn-generate-feature.ps1)
- [internal/scripts/java-maven-compile-fix-loop.ps1](../internal/scripts/java-maven-compile-fix-loop.ps1)
- [internal/scripts/maven-test.ps1](../internal/scripts/maven-test.ps1)

## Wejścia

- scaffold z archetypu `maven-archetype-quickstart`
- prompt [prompts/luhn.txt](../prompts/luhn.txt)
- workspace `workspaces/sdlc_maven_luhn/app`

## Wynik

Po sukcesie DAG zostawia gotowy projekt Maven z wygenerowaną funkcją Luhna i przechodzącymi testami.
