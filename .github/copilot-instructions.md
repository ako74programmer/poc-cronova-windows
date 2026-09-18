# Copilot instructions — cronova SDLC workflows

## Core rule: reusable scripts first

When the user asks for a new workflow, task, or automation in this repo, **always build it from reusable scripts in `internal/scripts/`**. Do not embed long shell commands directly in DAG YAML files or workflow wrappers.

- If a suitable reusable script already exists, use it.
- If no script fits, create a new reusable script in `internal/scripts/` and then call it from a thin wrapper in `workflows/<workflow>/`.
- Keep workflow wrappers small: they should only set parameters and `exec` the reusable script.

## Existing reusable scripts

| Script | Purpose | Typical wrapper |
|---|---|---|
| `internal/scripts/copy-template-to-workspace` | Copy a local template from `templates/` to a workspace | `scaffold.sh` |
| `internal/scripts/fetch-springboot-project` | Download a Spring Boot project from `start.spring.io` | `scaffold.sh` |
| `internal/scripts/generate-maven-archetype` | Generate a Java + Maven project via `mvn archetype:generate` | `scaffold.sh` |
| `internal/scripts/compile-project` | Compile a Maven project | `compile*.sh` |
| `internal/scripts/run-tests` | Run Maven tests | `tests.sh` |
| `internal/scripts/ai-generate-crud` | Generate a Spring Boot CRUD feature via AI | `ai_add_crud.sh` |
| `internal/scripts/ai-generate-feature` | Generate any feature from a prompt file via AI | `ai_add_feature.sh` |
| `internal/scripts/ai-review-fix-loop` | Compile → AI reviewer → fix loop | `compile_loop.sh` |

## Workflow wrapper pattern

Every wrapper must:

1. Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
2. Compute `SCRIPT_DIR` and `REPO_ROOT`.
3. Call the reusable script with explicit parameters using `exec`.

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec "$REPO_ROOT/internal/scripts/compile-project" \
  -w "$REPO_ROOT/workspaces/sdlc_maven_luhn" \
  -p app
```

## DAG conventions

- Place DAG definitions in `dags/<workflow>.yaml`.
- Use absolute Windows/Git Bash paths in `command`, e.g. `bash /c/Users/Andrzej/Downloads/sdlc/cronova/workflows/.../step.sh`.
- Keep `command` short: it should only invoke the wrapper script.
- Set realistic `timeout` values (scaffold 300s, compile 600s, AI tasks 300s, compile loop 900s, tests 300s).
- Use `default_retries: 0` for deterministic AI/compile tasks unless the user explicitly wants retries.

## AI prompt conventions

- Store feature prompts in `prompts/<feature>.txt`.
- Prompts must be explicit about:
  - Using `jakarta.*` instead of `javax.*` for Spring Boot 4.x.
  - Avoiding hardcoded `<version>` tags for managed dependencies.
  - Avoiding regex backslashes or other constructs that break plain Java string literals.
- The Python helper `internal/scripts/ai_generate_feature.py` strips markdown fences from AI responses before parsing JSON.

## Validation checklist

Before declaring a workflow done:

1. Run the pipeline locally step-by-step (or via `cronova trigger`).
2. Verify in the browser at `http://127.0.0.1:8090` that all tasks succeed.
3. Check `git status` is clean or that only intended files are modified.
4. Ensure `.tmp/`, `.zip`, and generated workspace artifacts are ignored by `.gitignore`.
5. Update `internal/scripts/README.md` with any new reusable script and usage example.

## Environment assumptions

- Git Bash is the shell on Windows.
- Maven 3.9.14 is at `/c/apache-maven-3.9.14`.
- Java JDK 25 is at `/c/Program Files/Java/jdk-25`.
- Python 3.13 is at `/c/Users/Andrzej/AppData/Local/Programs/Python/Python313/python`.
- AI proxy is at `http://127.0.0.1:4141/v1/chat/completions` using `gpt-4o-mini`.

## Reference workflows

- `workflows/sdlc_springboot/` — local Spring Boot template workflow.
- `workflows/sdlc_springboot_startio/` — Spring Boot from `start.spring.io`.
- `workflows/sdlc_maven_luhn/` — Maven archetype + AI-generated feature.
- `dags/sdlc_*.yaml` — corresponding DAG definitions.
