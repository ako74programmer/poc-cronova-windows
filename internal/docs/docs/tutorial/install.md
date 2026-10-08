# Install cronova

cronova is a self-hosted **workflow scheduler** that ships as one static Go binary — scheduler, web console, REST API, and CLI included, with an embedded SQLite database. In this chapter you install it, start it, and open the console for the first time.

There are three ways to get the `cronova` binary. For this tutorial, use the plain binary and run it from a working directory — no administrator rights, no service, easy to throw away.

## Option 1: Prebuilt release (recommended for the tutorial)

Grab the latest release (currently **v0.2.1**) from the [Releases page](https://github.com/zoyluoblue/cronova/releases). Releases are published for Windows amd64 as a ZIP archive. Download it, then extract it into a working directory:

```powershell
New-Item -ItemType Directory cronova-tutorial; Set-Location cronova-tutorial
Expand-Archive ..\cronova_windows_amd64.zip -DestinationPath .
```

Each release attaches `SHA256SUMS`; verify the archive (for example with `Get-FileHash`) before extracting it.

!!! tip
    The ZIP is more than the binary: it also unpacks a `dags/` folder with runnable [example DAGs](https://github.com/zoyluoblue/cronova/tree/main/dags), a `cronova.yaml.example` config template, and the standalone `cronova-executor`. Starting from the release ZIP means the console won't be empty on first launch.

## Option 2: Build from source

With **Go 1.26.5+** installed:

```powershell
git clone https://github.com/zoyluoblue/cronova
cd cronova
go build -o cronova.exe .\cmd\cronova
```

This builds the scheduler, web console, and CLI into one static binary. It is CGO-free (pure-Go SQLite), so no C toolchain is required.

!!! note
    A plain `go build` reports its version as `dev` — that's expected. Release binaries carry the real version tag.

## Option 3: Windows service installer

For a real deployment, extract the release ZIP and run the installer from an elevated PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\install.ps1
```

It installs the binaries in `C:\Program Files\Cronova`, creates the data root `C:\ProgramData\Cronova`, and registers the Windows services `Cronova` and `CronovaExecutor` (manage them with `Get-Service` or `sc.exe`). The web console is at http://127.0.0.1:8090.

A service install manages its own lifecycle afterwards: `deploy\update.ps1` upgrades in place, `deploy\reinstall.ps1` reinstalls, and `deploy\uninstall.ps1` removes it (data is kept unless you pass `-Purge`). For local development use `scripts\windows\app.ps1`. The full production guide is in [Deployment](../DEPLOY.md).

For the rest of the tutorial, stick with the plain binary from Option 1 or 2.

## Check it: `cronova version`

From the directory with your binary:

```powershell
.\cronova.exe version
```

You'll see the build version and platform, in the form `cronova <version> <os>/<arch>`:

```
cronova v0.2.1 windows/amd64
```

If that prints, the install is done.

## Start the scheduler and open the console

`cronova serve` runs the scheduling loop **and** the web console + REST API in one process:

```powershell
.\cronova.exe serve
```

By default it works relative to the current directory: DAG YAML files load from `./dags` (created if missing), the SQLite database lives at `data/cronova.db`, and task logs go to `logs/`. That's why running it from a dedicated working directory is the cleanest way to follow along.

Now open **<http://localhost:8090>** in your browser. You'll see the cronova console — the DAG list, run history, task states, and one-click manual triggers. If you installed from the release ZIP, the bundled example DAGs (like `example_etl` and `ticker`) already appear in the list.

You can check the same thing from a second terminal with the CLI:

```powershell
.\cronova.exe dags
```

Each loaded DAG is listed with its schedule — proof the scheduler is up and reading your DAG directory.

!!! warning
    Authentication is **off** for this plain development `serve`, but the default listener is `127.0.0.1:8090`, so it is reachable only from this machine. Cronova refuses an unauthenticated non-loopback bind unless you explicitly enable the dangerous override. Before network access, enable login — see [Enabling login](../GETTING_STARTED.md#enabling-login).

Stop the server anytime with ++ctrl+c++ — your DAGs and the database stay on disk, ready for the next `.\cronova.exe serve`.

## What you learned

- Three ways to install cronova: a prebuilt release binary, `go build` from source, or `deploy\install.ps1`, which sets up the Windows services.
- `.\cronova.exe version` confirms the binary works and prints `cronova <version> <os>/<arch>`.
- `.\cronova.exe serve` runs the scheduler, web console, and REST API in one process, with everything (DAGs, DB, logs) relative to your working directory — console at <http://localhost:8090>.

Next up: write and trigger your first DAG — [First DAG](first-dag.md).
