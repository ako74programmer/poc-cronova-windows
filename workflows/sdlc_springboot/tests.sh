#!/usr/bin/env bash
set -e

export JAVA_HOME=/c/Program\ Files/Java/jdk-25
export PATH="/c/apache-maven-3.9.14/bin:/mingw64/bin:/usr/bin:/bin:/c/Windows/system32:/c/Windows:$PATH"

mkdir -p /c/Users/Andrzej/Downloads/sdlc/cronova/.m2/repository
cd /c/Users/Andrzej/Downloads/sdlc/cronova/workspaces/springboot-demo/demo
mvn -B -Dmaven.repo.local=/c/Users/Andrzej/Downloads/sdlc/cronova/.m2/repository test
echo "All tests passed"
