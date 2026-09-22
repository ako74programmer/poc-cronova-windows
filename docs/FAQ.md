# cronova FAQ — Frequently Asked Questions

> **Windows-only:** This repository targets Windows amd64. Use `deploy\install.ps1`, Windows Services, Git for Windows Bash and `deploy\update.ps1`. Any older Unix deployment examples in historical sections are not supported here; the authoritative instructions are in [Deployment](DEPLOY.md).

Answers to the most common questions about cronova, the lightweight, self-hosted **workflow scheduler** and open-source Airflow / Azkaban alternative — what it is, how it installs, where it stores data, and how to run it in production.

This page expands on the short FAQ in the [README](https://github.com/zoyluoblue/cronova#readme). For task-by-task guides see [Getting Started](GETTING_STARTED.md), [DAG Reference](DAG_REFERENCE.md), [CLI Reference](CLI.md), [AI Agents (MCP)](AGENTS.md), [Deployment](DEPLOY.md), and [Architecture](ARCHITECTURE.md).

## What is cronova?

cronova is an open-source, self-hosted **workflow scheduler** (a.k.a. job scheduler / DAG orchestrator) written in Go. It schedules **DAGs** — directed acyclic graphs of tasks — on cron or interval triggers, runs each task as an OS subprocess using the host's own interpreters, and ships a web console, a REST API, a CLI, and an MCP endpoint for AI agents. Managed installs use a static scheduler plus a static standalone executor and embedded SQLite.

## Is cronova an Apache Airflow alternative?

Yes. cronova is a lightweight alternative to [Apache Airflow](https://airflow.apache.org/) and Azkaban for teams who want DAG scheduling — dependencies, retries, catchup / backfill, resource pools, a web UI, and a REST API — **without** running a Python stack, a separate database, and a message broker. It is a compact native service pair with an embedded database. For very large, plugin-heavy data platforms, Airflow remains the richer ecosystem. See [cronova vs Airflow](COMPARISON.md) for a feature-by-feature breakdown.

## Does cronova need a separate database, a JVM, or Python?

No. The scheduler and web console use an **embedded SQLite** database (pure-Go `modernc.org/sqlite`, CGO-free), so there is no external Postgres/MySQL, no Redis or Celery broker, no JVM, and no Python runtime to install. Managed deployments add only the standalone executor binary. Python, Java, `psql`, and other interpreters are needed on the host only if *your tasks* invoke them.

## What languages can tasks be written in?

Any language on the host. Tasks have a `type` of `shell`, `python`, `sql`, `jar`, or `http`, and a `shell` task can invoke anything on the machine — Node, Go, Rust binaries, CLIs, and more. The scheduler (Go) is fully decoupled from the task language: each task runs as an OS subprocess with the host's own interpreters. The `sql` and `http` task types run in-process (drivers/HTTP client are built into the binary) and need nothing extra installed. See the [DAG Reference](DAG_REFERENCE.md) for every task type.

## How is cronova different from cron?

Plain `cron` runs isolated commands on a clock. cronova runs **DAGs**: tasks with dependencies, retries, timeouts, catchup / backfill, concurrency pools, cross-DAG triggers, a web console with live log tailing, and a REST API — the orchestration you normally end up hand-rolling around a `crontab`. cronova still speaks cron syntax (`schedule: "0 2 * * *"`) and also supports `@every 30s` intervals and manual-only DAGs.

## Can AI agents control cronova (MCP)?

Yes. cronova ships a built-in **Model Context Protocol (MCP) server** (`cronova mcp`) that exposes ~30 tools (`list_dags`, `create_dag`, `validate_dag`, `trigger_dag`, `get_task_log`, `retry_task`, …), plus a remote JSON CLI. Agents drive cronova through the **same token-authenticated, role-gated API** humans use — an agent's reach is exactly its token's role (`admin` = full CRUD + operate, `viewer` = read-only), and `cronova mcp -read-only` exposes only the read tools. Tokens are minted locally with `cronova tokens create`, never via the API. Full setup: [AI Agents (MCP)](AGENTS.md).

## Which platforms are supported, and how do I install cronova?

This repository supports **Windows 10/11 and Windows Server on amd64**. Install Git for Windows, extract `cronova_windows_amd64.zip`, and run the elevated PowerShell installer:

```powershell
.\deploy\install.ps1
```

The installer registers `CronovaExecutor` and `Cronova` as Windows Services. Prefer to build from source? With Go 1.26.5+:

```powershell
go build -o cronova.exe ./cmd/cronova
go build -o cronova-executor.exe ./cmd/cronova-executor
.\cronova.exe serve                 # console at http://localhost:8090
```

Prebuilt binaries are on the [Releases](https://github.com/ako74programmer/poc-cronova-windows/releases) page. Full deployment guide: [Deployment](DEPLOY.md).

## What port does the console use?

The web console and REST API default to **`127.0.0.1:8090`** (loopback only). Open `http://localhost:8090` after `cronova serve`. Change it with `-http`, `CRONOVA_HTTP`, or the `http:` key in `cronova.yaml`. A non-loopback bind with auth disabled is refused unless the explicit dangerous override is set.

## How do I upgrade cronova?

Run the PowerShell update script from an elevated session. It replaces both binaries through temporary files, preserves `ProgramData`, and restarts the services:

```powershell
.\deploy\update.ps1
```

The script does not download releases or alter configuration, database, DAGs, projects, workspaces or logs. See [Deployment](DEPLOY.md#upgrade-and-uninstall).

## Is the update safe if it fails halfway?

`update.ps1` writes each new executable to a temporary file before replacing the installed binary. It stops both services first and starts them again after the replacement. Native rollback and service-recovery behavior must be validated on Windows.

## Is cronova crash-safe / production-ready?

cronova is designed for reliable operation. Managed installs use the decoupled **gRPC executor** by default, so the scheduler can restart or upgrade **without killing running jobs** — on recovery it re-attaches to in-flight tasks with no double execution. A manual `serve` with no executor target remains in-process and ends active tasks on exit. Managed services also expose executor-aware readiness, atomic self-updates with rollback, and an audit trail. See [Deployment](DEPLOY.md) and [Architecture](ARCHITECTURE.md) for the execution model.

## Where does cronova store its data?

State lives in an **embedded SQLite database** plus on-disk DAG YAML, task logs, and uploaded projects. The Windows service installer uses this layout:

| Purpose | Windows service path |
|---|---|
| SQLite DB, config, DAGs | `C:\ProgramData\Cronova\` |
| task logs | `C:\ProgramData\Cronova\logs\` |
| uploaded projects | `C:\ProgramData\Cronova\projects\` |
| attempt workspaces | `C:\ProgramData\Cronova\workspaces\` |
| executor state | `C:\ProgramData\Cronova\executor-state\` |

Override these with the matching `-db` / `-dags` / `-logs` / `-projects` / `-workspaces` flags, `CRONOVA_*` environment variables, or `cronova.yaml`.

## How long does cronova keep run history?

**90 days by default.** The server automatically deletes finished runs — their database rows and their log directories — once they are older than the retention window (default `2160h`, i.e. 90 days). Change it with the `retention:` key in `cronova.yaml`, the `-retention` flag on `cronova serve`, or the `CRONOVA_RETENTION` env var; set it to `0` to keep everything forever. Only finished runs age out — in-flight runs are never touched.

Audit records have an independent one-year default (`audit_retention: 8760h` /
`CRONOVA_AUDIT_RETENTION` / `-audit-retention`) so shortening run-history
retention does not erase the operations trail at the same time.

For a one-off cleanup (or a deployment that runs with retention disabled), use `cronova prune`:

```bash
cronova prune                    # delete finished runs older than 90 days (asks first)
cronova prune -older-than 720h   # custom window
cronova prune -yes               # skip the confirmation prompt (scripts / cron)
```

## Are connection passwords encrypted?

Yes. Connection passwords are encrypted **at rest with AES-256-GCM**. On first start, `cronova serve` auto-generates an encryption key file — `cronova.key`, permissions `0600` — in its working directory (for service installs that is next to the DB, see [Deployment → Platform layout](DEPLOY.md#platform-layout)); point it elsewhere with the `key_file:` key in `cronova.yaml` or the `CRONOVA_KEY_FILE` env var. **Back this file up alongside the database** — without it, the stored connection passwords are unreadable and must be re-entered. Connections saved before encryption existed (legacy plaintext rows) are upgraded in place automatically on the next server startup. To opt out, set `key_file: none` — passwords are then stored in plaintext and the server logs a warning at startup.

## How do I run cronova behind a reverse proxy?

Bind cronova to localhost and terminate TLS at your proxy (nginx, Caddy, Traefik, …). The one-click wizard offers a **"this machine only (127.0.0.1)"** bind option for exactly this, or set `CRONOVA_HTTP=127.0.0.1:8090` (or `-http 127.0.0.1:8090`). When serving over HTTPS, set `CRONOVA_SECURE_COOKIE=true`. List non-loopback proxy peers in `auth.trusted_proxies` or `CRONOVA_TRUSTED_PROXIES`; `X-Forwarded-*` from every other source is ignored. The console, REST API, and live-log SSE stream all share the one HTTP listener. See [Deployment](DEPLOY.md).

## Do I need Docker or Kubernetes?

No. cronova is a subprocess scheduler that runs tasks with the **host's own interpreters**, so it deploys as two small Windows binaries registered as Windows Services — no container image to build and no runtime to bundle. Shell tasks require Git for Windows Bash. See [Deployment](DEPLOY.md).

## How do I uninstall cronova?

Run the PowerShell uninstall script. It stops and removes the Windows Services and binaries but **keeps your data** by default. Add `-Purge` to also delete the data:

```powershell
.\deploy\uninstall.ps1         # remove services and binaries, keep data
.\deploy\uninstall.ps1 -Purge  # also delete ProgramData
```

Run it from an elevated PowerShell. See [Deployment](DEPLOY.md#upgrade-and-uninstall).

## What license is cronova released under?

cronova is released under the **[MIT License](https://github.com/zoyluoblue/cronova/blob/main/LICENSE)** — a permissive license that allows commercial and private use, modification, and redistribution.

## See also

- [README](https://github.com/zoyluoblue/cronova#readme) — project overview and quick start
- [Getting Started](GETTING_STARTED.md) — install, first DAG, projects, template variables
- [DAG Reference](DAG_REFERENCE.md) — every DAG/task field, task types, triggers, pools
- [CLI Reference](CLI.md) — every `cronova` command and flag
- [AI Agents (MCP)](AGENTS.md) — MCP server, remote CLI, tokens, security
- [Deployment](DEPLOY.md) — Windows Services, Git Bash, Job Objects, updates and backup
- [Architecture](ARCHITECTURE.md) — design rationale, execution model, diagrams
- [cronova vs Airflow](COMPARISON.md) — when to choose cronova, feature-by-feature
