#!/usr/bin/env bash
set -e

PROJECT_DIR=/c/Users/Andrzej/Downloads/sdlc/cronova/workspaces/springboot-demo/demo
PACKAGE=com/example/demo
PYTHON=/c/Users/Andrzej/AppData/Local/Programs/Python/Python313/python
SCRIPT_DIR=/c/Users/Andrzej/Downloads/sdlc/cronova/workflows/sdlc_springboot

mkdir -p "$PROJECT_DIR/src/main/java/$PACKAGE/api"
mkdir -p "$PROJECT_DIR/src/main/java/$PACKAGE/model"

POM=$(cat "$PROJECT_DIR/pom.xml")
APP=$(cat "$PROJECT_DIR/src/main/java/$PACKAGE/DemoApplication.java")

PROMPT_FILE=/c/Users/Andrzej/Downloads/sdlc/cronova/.tmp/ai_prompt.txt
REQ_FILE=/c/Users/Andrzej/Downloads/sdlc/cronova/.tmp/ai_request.json
RESP_FILE=/c/Users/Andrzej/Downloads/sdlc/cronova/.tmp/ai_response.json
mkdir -p /c/Users/Andrzej/Downloads/sdlc/cronova/.tmp

cat > "$PROMPT_FILE" <<PROMPT_EOF
You are a Java/Spring Boot code generator.
Given the pom.xml and DemoApplication.java below, do two things:
1. Rewrite pom.xml to add spring-boot-starter-web and spring-boot-starter-validation dependencies (keep everything else intact).
2. Add a simple Item CRUD: create Item.java in model package and ItemController.java in api package.
   Item fields: Long id, String name. Controller: REST endpoints GET /items, POST /items, GET /items/{id}, DELETE /items/{id}.
   Store items in a java.util.Map<Long, Item> in the controller.
Return ONLY a JSON object with keys: pom_xml, Item_java, ItemController_java.
Escape newlines in strings as \\n and quotes as \\".

pom.xml:
$POM

DemoApplication.java:
$APP
PROMPT_EOF

echo "Calling AI proxy to generate CRUD..."
$PYTHON "$SCRIPT_DIR/ai_add_crud.py" "$PROJECT_DIR" "$PACKAGE" "$PROMPT_FILE" "$REQ_FILE" "$RESP_FILE"

echo "AI added CRUD to skeleton"
