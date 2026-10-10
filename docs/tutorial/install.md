# Install cronova

cronova is a self-hosted **workflow scheduler** for Windows, distributed as a Windows ZIP containing the scheduler, executor, web console, REST API, CLI, and the supporting files used by the example DAGs. This chapter shows the quickest way to run the tutorial and, separately, how to install cronova for ongoing use.

## Option 1: Run the tutorial from the release ZIP (recommended)

Download **`cronova_windows_amd64.zip`** from the [cronova v0.2.3 release](https://github.com/ako74programmer/poc-cronova-windows/releases/tag/v0.2.3) and extract it into a working directory. The package includes `cronova.exe`, `cronova-executor.exe`, a `dags/` directory, the optional installer `setup.cmd`, and both installation guides: `README-INSTALL.en.md` (English) and `README-INSTALL.md` (Polish).

For this tutorial, **do not run `setup.cmd`**. Running the executable directly keeps the setup local to the extracted directory and avoids installing Windows services or a logon task:

```powershell
Set-Location .\cronova_windows_amd64
.\cronova.exe version
```

The version command prints the build version and platform, for example:

```
cronova v0.2.3 windows/amd64
```

If you extracted the ZIP into a directory with a different name, change to that directory instead. You do not need Go or administrator rights to run the prebuilt binaries.

## Option 2: Install cronova for ongoing use

To install cronova rather than just follow the tutorial, double-click **`setup.cmd`** in the extracted ZIP. The setup program chooses a mode based on your permissions:

- If you are an administrator, it offers to install the `Cronova` and `CronovaExecutor` Windows services. Accept the UAC prompt to install the services.
- If you decline UAC, or do not have administrator rights, it installs for your Windows user and starts at sign-in through Task Scheduler.

The installer configures a login and prints the console URL and password at the end. If it generates a password, **save it then**; it is shown only once. The default console address is **http://127.0.0.1:8090/**. For options and management commands, see the packaged [Windows installation guide](../DEPLOY.md) or `README-INSTALL.md` in the ZIP.

> **Important:** The installer starts cronova for you. If you install it, do not also start another `cronova serve` process on the same data directory. To continue this tutorial, use the direct-from-ZIP method above and leave `setup.cmd` unused.

## Option 3: Build the scheduler from source

To build the scheduler binary yourself, install **Go 1.26.5 or newer** and run these commands in PowerShell:

```powershell
git clone https://github.com/ako74programmer/poc-cronova-windows
Set-Location .\poc-cronova-windows
go build -o .\cronova.exe .\cmd\cronova
```

`git clone` creates the `poc-cronova-windows` directory; run the build from that directory. The build produces the scheduler, web console, and CLI in one binary. It uses pure-Go SQLite and does not require a C toolchain. A plain `go build` reports its version as `dev`.

To build the complete Windows installer ZIP (both executables and all runtime assets), use the project's Windows packaging and verification scripts. See [Deployment](../DEPLOY.md#build-and-package-from-source); building only `cronova.exe` is sufficient for the standalone tutorial, not for the service installer.

## Start the scheduler and open the console

From the directory containing `cronova.exe`, start the scheduler and the in-process executor:

```powershell
.\cronova.exe serve
```

By default, DAG YAML files load from `./dags` (created if missing), the SQLite database is stored at `data/cronova.db`, and task logs go to `logs/`, all relative to the current working directory. This is why a dedicated extracted working directory is convenient for the tutorial.

Open **http://localhost:8090** in your browser. The bundled DAG files in `dags/` appear in the console. From a second PowerShell window, verify that cronova loaded them:

```powershell
.\cronova.exe dags
```

Each loaded DAG is listed with its schedule. This confirms the scheduler is running and reading the directory. The same `serve` process provides the web console and REST API.

!!! warning
    A standalone development `serve` does not require login by default. Its default listener, `127.0.0.1:8090`, is reachable only from this machine. Cronova refuses an unauthenticated non-loopback bind unless you explicitly enable the dangerous override. Before allowing network access, enable login — see [Enabling login](../GETTING_STARTED.md#enabling-login).

Stop the server with ++ctrl+c++. Your DAGs, database, and logs remain on disk, ready for the next `cronova serve`.

## What you learned

- Download the Windows amd64 ZIP and run `cronova.exe` directly to follow the tutorial; this requires neither Go nor administrator rights.
- `setup.cmd` is the separate guided installer for Windows services or a per-user installation; it starts cronova itself.
- To build only the scheduler from source, use Go 1.26.5+ from the `poc-cronova-windows` repository directory.
- `cronova serve` runs the scheduler, web console, REST API, and in-process executor; DAGs, the database, and logs are relative to the working directory.

Next up: write and trigger your first DAG — [First DAG](first-dag.md).
