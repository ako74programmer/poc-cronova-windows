<div align="center">

# cronova

**A lightweight, self-hosted workflow scheduler for Windows — an open-source [Apache Airflow](https://airflow.apache.org/) / Azkaban alternative customized and developed as an independent project.**

[![Repository](https://img.shields.io/badge/repository-ako74programmer%2Fpoc--cronova--windows-1f6feb?logo=github)](https://github.com/ako74programmer/poc-cronova-windows)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Go](https://img.shields.io/github/go-mod/go-version/ako74programmer/poc-cronova-windows?logo=go)](go.mod)
[![Platform](https://img.shields.io/badge/platform-Windows%20amd64-informational)](docs/DEPLOY.md)

**English** · [Polski](README.pl.md)

<sub>This repository is maintained independently at <b><a href="https://github.com/ako74programmer/poc-cronova-windows">ako74programmer/poc-cronova-windows</a></b>.</sub>

</div>

cronova is a **workflow scheduler and job orchestrator** in the spirit of Airflow and Azkaban, built for teams who want DAG-based scheduling **without the operational weight**. This repository is a customized, independently developed Windows-only project based on the ideas and source of the original [cronova repository](https://github.com/zoyluoblue/cronova). It ships as native Go services with an embedded SQLite database and a standalone executor that runs tasks through Git for Windows Bash.

The original repository is the source of inspiration and the starting point for this project. Development, customization, Windows support, release packaging, and maintenance now take place in this repository and are not releases of the original project.

<div align="center">
  <img src="docs/img/task-editor.png" alt="cronova web console — visual task editor with drag-and-drop template variable pills for a polyglot workflow scheduler" width="900">
  <br><em>The console task editor: build commands with click/drag variable pills (built-in, variables, connections, params).</em>
</div>

```bash
# Install the Windows services from an extracted release package (PowerShell as Administrator):
.\deploy\install.ps1
```

## Why cronova?

- 🟢 **Small native install, zero service dependencies.** Pure-Go, CGO-free scheduler plus standalone executor with embedded SQLite. The PowerShell installer registers Windows services; no Airflow-style stack or container runtime is required.
- 🗂️ **Airflow / Azkaban-style DAGs.** Declarative YAML DAGs with dependency edges, cron / `@every` schedules, cross-DAG triggers and waits (`trigger_after`, `depends_on_dag`), sub-workflows, catchup / backfill, per-task retries & timeouts, resource pools, run priorities & serial execution policies, and trigger rules — the orchestration primitives you already know.
- 📡 **Scale out when you need to — dial-in workers.** Remote workers join with a one-time token over mTLS and **dial in** (no inbound port, no shared filesystem, NAT-friendly); tasks route by `worker_group:`, logs stream back live, and a worker restart re-adopts its running tasks instead of re-running them. Zero workers configured = the same single binary as always.
- 🌐 **Polyglot tasks + project upload.** Every task runs as an OS subprocess, so write tasks in **shell, Python, SQL, a JAR, or HTTP** — any language on the host. Drag-and-drop a script, a whole project folder, or a `.zip` in the console and cronova runs it in an isolated working copy.
- 🤖 **AI-native.** A built-in **[Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server** and a remote JSON CLI let AI agents (Claude, and any MCP client) list, create, validate, trigger, and inspect DAGs through the same token-authenticated, role-gated API.
- 🛡️ **Crash-recoverable execution.** Run tasks in a decoupled gRPC executor so restarting or upgrading the scheduler never kills running jobs — on recovery it re-attaches to in-flight tasks with no double execution.
- 🖥️ **Batteries-included web console.** DAG dashboard, run history, task states, **live log tailing (SSE)**, manual triggers, variables & connections, an audit trail, and a visual command editor — all served in-process. REST API + OpenAPI included.

## What is cronova?

**cronova is an open-source, self-hosted workflow scheduler** (a.k.a. job scheduler / task orchestrator / DAG scheduler) written in Go. It schedules **DAGs** — directed acyclic graphs of tasks — on cron or interval triggers, runs each task as a Windows subprocess through Git for Windows Bash, and gives you a web console, a REST API, a CLI, and an MCP endpoint for AI agents. Think of it as a **cron replacement with dependencies, retries, backfill, and observability**, or a **lightweight Airflow alternative** shipped as a compact native service pair.

## Quick start on Windows

```bash
# 1. Build with Go 1.26.5+ — or use the Windows release package
$env:CGO_ENABLED = "0"
go build -o cronova.exe ./cmd/cronova

# 2. Start the scheduler + web console (in-process executor)
./cronova.exe serve             # console at http://localhost:8090

# 3. Drive it from the CLI (in another terminal)
./cronova.exe dags              # list DAGs from ./dags
./cronova.exe trigger example_etl
./cronova.exe runs example_etl
```

On Windows use the included `app.cmd` helper:

```powershell
# Development: clean temp DB, auth disabled
.\app.cmd start-dev

# Production: persistent data/cronova.db, reads cronova.yaml
.\app.cmd start

.\app.cmd stop
```

Open **http://localhost:8090** for the console — DAG list, run history, task states, live logs, and one-click manual triggers.

The development default is unauthenticated but loopback-only. A non-loopback
bind is refused unless login is enabled or the explicit
`-allow-unauthenticated-remote` escape hatch is set. Use `cronova init` for a
new deployed instance; it enables authentication by default.

<div align="center">
  <img src="docs/img/dashboard.png" alt="cronova dashboard — self-hosted workflow scheduler showing DAGs, run history, success rate, and schedules" width="900">
</div>

## cronova vs. Airflow vs. Azkaban vs. cron

| | **cronova** | Apache Airflow | Azkaban | plain cron |
|---|:---:|:---:|:---:|:---:|
| Install | **PowerShell package / Windows services** | Python stack + DB + broker | JVM + MySQL | built-in |
| Runtime deps | **none** (embedded SQLite) | Python, Postgres, Redis/Celery | Java, MySQL | none |
| DAGs & dependencies | ✅ | ✅ | ✅ | ❌ |
| Cron + interval + cross-DAG triggers | ✅ | ✅ | partial | cron only |
| Catchup / backfill | ✅ | ✅ | ❌ | ❌ |
| Retries, timeouts, pools | ✅ | ✅ | partial | ❌ |
| Crash recovery (no double-run) | ✅ | ✅ | partial | ❌ |
| Polyglot tasks (shell/Python/SQL/JAR/HTTP) | ✅ | ✅ (operators) | JVM-centric | any (no orchestration) |
| Web console + live logs | ✅ | ✅ | ✅ | ❌ |
| REST API + OpenAPI | ✅ | ✅ | partial | ❌ |
| AI agent / MCP integration | ✅ **built-in** | ❌ | ❌ | ❌ |
| Footprint | **two small native processes, tens of MB** | heavy | heavy (JVM) | tiny |

cronova targets the sweet spot between a bare `crontab` and a full Airflow deployment: **real DAG orchestration with almost no operational overhead.**

## Define a DAG

Drop a YAML file in `./dags/` (see [`dags/`](dags/) for runnable examples):

```yaml
dag_id: daily_etl
schedule: "0 2 * * *"        # cron; or "@every 30s"; omit for manual-only
start_date: 2026-06-01
catchup: true                # backfill missed periods
max_active_runs: 1
default_retries: 2
tasks:
  - id: extract
    type: shell
    command: "python extract.py --date {{ logical_date }}"
    pool: default
  - id: transform
    command: "python transform.py --date {{ logical_date }}"
    deps: [extract]
  - id: load
    command: "psql -f load.sql"
    deps: [transform]
    retries: 3
    timeout: 1800
trigger_after:               # optional: run after another DAG succeeds
  - dag_id: upstream_ingest
```

**Template variables** work in any command, URL, header, body, or query:
`{{ logical_date }}`, `{{ logical_datetime }}`, `{{ run_id }}`, `{{ dag_id }}`, `{{ task_id }}`, `{{ try_number }}` (also injected as `CRONOVA_*` env vars), plus UI-managed `{{ var.KEY }}`, `{{ conn.ID.host }}`, and `{{ params.KEY }}`. In the console you don't type the `{{ }}` — a **visual editor renders each variable as a color-coded pill** and a grouped palette inserts them by **click or drag**.

### Run your own scripts and projects

Upload a single script, a whole project folder, or a `.zip` in the console (task editor → **Project**), then point a shell task at it:

```yaml
tasks:
  - id: run_main
    type: shell
    command: python3 main.py     # runs with cwd = a clean copy of the project
    project: my_app
```

Each attempt gets a **fresh isolated copy** of the project as its working directory (`CRONOVA_PROJECT_DIR` points there), so re-uploads take effect next run and attempts never interfere. See [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md).

## AI agents (MCP + remote CLI)

Let an AI orchestrate cronova through the **same token-authenticated, role-gated API** — as native **MCP tools** or via the **remote JSON CLI**:

```bash
cronova tokens create my-agent -role admin     # mint a token (local, once)
cronova mcp                                     # MCP server over stdio (Claude, etc.)

export CRONOVA_SERVER=http://localhost:8090 CRONOVA_TOKEN=cnv_pat_…
cronova dags -o json                            # remote CLI, JSON output
cronova api POST /api/dags/validate '{"dag_id":"x","tasks":[…]}'   # dry-run validate
```

`cronova mcp` exposes ~30 catalog-derived tools (`list_dags`, `create_dag`, `validate_dag`, `trigger_dag`, `get_task_log`, `retry_task`, …); `-read-only` exposes just the reads. Guide + MCP config: **[docs/AGENTS.md](docs/AGENTS.md)**.

## Deploy in production

cronova is a **scheduler, not a runtime**: it launches each task using interpreters available on the Windows host. Managed installs run the scheduler and standalone executor as **Windows services**. Tasks are executed through Git for Windows Bash; Python, Java, Node, PostgreSQL clients, and other tools must be installed separately when a task needs them.

```powershell
.\deploy\install.ps1 -Start       # install and start both Windows services
cronova.exe start | stop | restart | status
.\deploy\uninstall.ps1          # remove services and binaries, retain data
.\deploy\uninstall.ps1 -Purge     # remove services, binaries, and data
```

The PowerShell installer must run as Administrator and requires Git for Windows Bash. Full guide, service configuration, and executor setup: **[docs/DEPLOY.md](docs/DEPLOY.md)**.

<div align="center">
  <img src="docs/img/graph.png" alt="cronova DAG graph — cross-DAG trigger dependencies visualized in the web console" width="820">
</div>

## Documentation

| Guide | What's inside |
|---|---|
| [Getting Started](docs/GETTING_STARTED.md) | Install, first DAG, projects, template variables |
| [Console Guide](docs/console/index.md) | Every page of the web UI — dashboard, task editor, runs & live logs, pools, tokens |
| [DAG Reference](docs/DAG_REFERENCE.md) | Every DAG/task field, task types, triggers, pools |
| [CLI Reference](docs/CLI.md) | Every `cronova` command and flag |
| [AI Agents (MCP)](docs/AGENTS.md) | MCP server, remote CLI, tokens, security |
| [Deployment](docs/DEPLOY.md) | Windows services, PowerShell installation, updates, crash-recoverable executor |
| [Architecture](docs/ARCHITECTURE.md) | Design rationale, execution model, diagrams |
| [cronova vs Airflow](docs/COMPARISON.md) | When to choose cronova, feature-by-feature |
| [FAQ](docs/FAQ.md) | Common questions, answered |

## FAQ

**Is cronova an Airflow alternative?**
Yes — for teams who want DAG scheduling (dependencies, retries, catchup, pools, a web UI, a REST API) without running a Python stack, a separate database, and a message broker. cronova is a compact native service pair with an embedded database. For very large, plugin-heavy data platforms, Airflow remains the richer ecosystem.

**Does cronova need a database, JVM, or Python?**
No. The scheduler and web console use an **embedded SQLite** database; the managed install adds a small standalone executor so scheduler restarts do not kill tasks. Python/Java/psql are only needed on the host if *your tasks* invoke them.

**What languages can tasks be written in?**
Any. Tasks are `shell`, `python`, `sql`, `jar`, or `http`; a shell task can invoke anything on the host (Node, Go, Rust binaries, …). The framework (Go) is fully decoupled from the task language.

**How is cronova different from cron?**
cron runs isolated commands on a clock. cronova runs **DAGs**: tasks with dependencies, retries, timeouts, backfill, concurrency pools, cross-DAG triggers, a web console with logs, and an API — the things you end up hand-rolling around cron.

**Can AI agents control cronova?**
Yes. It ships a built-in **MCP server** (`cronova mcp`) and a remote JSON CLI, so AI agents can manage workflows through the same authenticated, role-gated API as humans.

**Which platforms are supported?**
This project targets **Windows amd64**. The installer requires PowerShell with administrator privileges and Git for Windows Bash. Linux and macOS belong to the original project and are not supported targets of this repository.

**Is it production-ready / crash-safe?**
Managed installs use a decoupled gRPC executor, but Windows Job Objects and a full clean-machine installation test remain roadmap items. Review [ROADMAP.md](ROADMAP.md) before production adoption.

## Development

```bash
go test -race ./...      # full test suite

# regenerate gRPC code after editing proto/ (needs: buf + protoc-gen-go[-grpc])
buf generate

# UI dev: serve console assets from disk (edit + reload, no rebuild)
CRONOVA_WEB_DIR=internal/web/static go run ./cmd/cronova serve
```

Contributions welcome — see the [docs/](docs/) for architecture and design notes.

## License

[MIT](LICENSE) © cronova authors.

---

<div align="center">

### ⭐ Found cronova useful?

Give this project a **[star on GitHub](https://github.com/ako74programmer/poc-cronova-windows)** — it helps others discover this independent Windows implementation.

<sub>cronova — self-hosted <b>workflow scheduler</b> · <b>Airflow alternative</b> · DAG orchestration · single Go binary · MCP-ready for AI agents.</sub>

</div>
