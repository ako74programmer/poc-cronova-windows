#!/usr/bin/env bash
set -e

PROJECT_DIR=/c/Users/Andrzej/Downloads/sdlc/cronova/workspaces/springboot-demo/demo
M2=/c/Users/Andrzej/Downloads/sdlc/cronova/.m2/repository
PYTHON=/c/Users/Andrzej/AppData/Local/Programs/Python/Python313/python
SCRIPT_DIR=/c/Users/Andrzej/Downloads/sdlc/cronova/workflows/sdlc_springboot
TMP_DIR=/c/Users/Andrzej/Downloads/sdlc/cronova/.tmp

mkdir -p "$M2"
mkdir -p "$TMP_DIR"
cd "$PROJECT_DIR"

export JAVA_HOME=/c/Program\ Files/Java/jdk-25
export PATH="/c/apache-maven-3.9.14/bin:/mingw64/bin:/usr/bin:/bin:/c/Windows/system32:/c/Windows:$PATH"

MAX_ITER=3
ITER=1
while [ "$ITER" -le "$MAX_ITER" ]; do
  echo "=== compile iteration $ITER / $MAX_ITER ==="
  if mvn -B -Dmaven.repo.local="$M2" -DskipTests compile > "$TMP_DIR/compile.log" 2>&1; then
    echo "Compile succeeded on iteration $ITER"
    exit 0
  fi

  echo "Compile failed. Sending report to AI reviewer..."
  tail -n 80 "$TMP_DIR/compile.log"

  if [ "$ITER" -eq "$MAX_ITER" ]; then
    echo "Max iterations reached. Giving up."
    cat "$TMP_DIR/compile.log"
    exit 1
  fi

  SRC_FILES=$(find src/main/java -name "*.java" -exec echo "--- {} ---" \; -exec cat {} \;)
  POM=$(cat pom.xml)
  LOG=$(tail -n 80 "$TMP_DIR/compile.log")

  cat > "$TMP_DIR/ai_review_prompt.txt" <<PROMPT_EOF
You are a Java build-error reviewer. The Spring Boot project below failed to compile.
Fix the code (and pom.xml if needed) so it compiles. Keep the Item CRUD functionality.
Return ONLY a JSON object with keys: pom_xml, and for each Java file you change, key = relative path like "src/main/java/com/example/demo/api/ItemController.java".
Escape newlines in strings as \\n and quotes as \\".

pom.xml:
$POM

Compile error:
$LOG

Source files:
$SRC_FILES
PROMPT_EOF

  $PYTHON "$SCRIPT_DIR/ai_review_fix_v2.py" "$PROJECT_DIR" "$PACKAGE" "$TMP_DIR/ai_review_prompt.txt" "$TMP_DIR/ai_review_request.json" "$TMP_DIR/ai_review.json"

  ITER=$((ITER + 1))
done
