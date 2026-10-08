# Deploying cronova on Windows

Cronova in this repository targets Windows 10/11 and Windows Server on `amd64`. It consists of `cronova.exe` (scheduler, REST API and web console) and `cronova-executor.exe` (task process owner). Repository workflows are being standardized on Windows-native execution, with PowerShell as the primary scripting path. On Windows, `shell` is treated only as a legacy alias for PowerShell and should not be used in new DAGs.

## Requirements

Run installation from an elevated PowerShell.

## Install from a release ZIP

Extract `cronova_windows_amd64.zip`, open an elevated PowerShell in the extracted directory, and run:

```powershell
.\deploy\install.ps1
```

The installer installs binaries below `C:\Program Files\Cronova`, creates the data root `C:\ProgramData\Cronova`, and registers two Windows Services: `CronovaExecutor` and `Cronova`. The scheduler depends on the executor and both services have failure recovery configured.

DAG runtime assets (`internal\scripts`, `scripts\sdlc`, `prompts`, `templates`, `configs`, `contracts`, `e2e\playwright`) are copied to `C:\ProgramData\Cronova`, and the executor runs tasks from that directory (`-workdir`), so relative paths in DAGs resolve. The installer verifies every DAG path with `internal\scripts\cronova-verify-dag-paths.ps1`.

Services run as `LocalSystem`, which does not see the installing user's environment. The installer detects the toolchain (JDK, Maven, Python, Node/npm, Git) and stores `JAVA_HOME`, `MAVEN_HOME`, `CRONOVA_*` and `PATH` as the `CronovaExecutor` service environment. Re-run the installer after installing or moving tools.

For AI DAG tasks on a fresh database either configure an AI provider in the web UI, or pass a default endpoint during install:

```powershell
.\deploy\install.ps1 -Start -AiBaseUrl http://127.0.0.1:4141/v1 -AiModel gpt-4o-mini
```

## Data and configuration

The default data root contains `cronova.yaml`, `cronova.db`, `dags`, `projects`, `workspaces`, `logs` and `executor-state`.

The local scheduler–executor endpoint is loopback TCP, normally `tcp://127.0.0.1:19090` for the installed service. It must not be bound to a public interface. Remote executor connections use mTLS; loopback-only local traffic may use the local transport without TLS. Both installed binaries are intended to run as native Windows Services under Service Control Manager.

## Service operations

```powershell
sc.exe query CronovaExecutor
sc.exe query Cronova
sc.exe start CronovaExecutor
sc.exe start Cronova
sc.exe stop Cronova
sc.exe stop CronovaExecutor
```

The CLI commands `cronova start`, `cronova stop`, `cronova restart` and `cronova status` use Windows Service Control Manager on Windows. A development run can use `cronova serve` directly, but production should use both services.

## Task execution and process containment

Tasks are executed as Windows subprocesses using the configured runtime for the task type. The Windows runner creates a Job Object per task, enables `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, assigns the task process to it, and uses `TerminateJobObject` for timeout and cancellation. A controlled executor restart removes the kill-on-close flag before closing the local handle so persisted tasks can continue; a hard executor termination still requires native Windows recovery testing.

When started with [app.ps1](C:/Users/Andrzej/Downloads/sdlc/cronova/scripts/windows/app.ps1), Cronova runs a Windows PowerShell discovery helper before launch and sets missing `CRONOVA_*` runtime paths in the child process environment. It searches per-user Python under `%LOCALAPPDATA%\Programs\Python\Python*`, Node.js under `%ProgramFiles%\nodejs`, JDKs under `%ProgramFiles%\Java\jdk-*` or Eclipse Adoptium/Microsoft directories, and Maven under `%ProgramFiles%\Apache\Maven` or `%SystemDrive%\apache-maven-*`. The task runner also has a Go-side discovery fallback. Explicit `CRONOVA_PYTHON`, `CRONOVA_NODE`, `CRONOVA_NPM`, `CRONOVA_JAVA_HOME`, `CRONOVA_MAVEN_HOME`, `JAVA_HOME`, and `MAVEN_HOME` values take precedence. Installations in other locations must be added to the Windows `PATH` or configured with those `CRONOVA_*` overrides before starting Cronova.

## Upgrade and uninstall

Run the update script from an elevated PowerShell. It stops both services, copies each new executable through a temporary file, replaces the installed binary, and starts the services again without modifying `ProgramData`:

```powershell
.\deploy\update.ps1
```

Uninstall preserves data by default. Use `-Purge` only when the data root must be permanently removed:

```powershell
.\deploy\uninstall.ps1
.\deploy\uninstall.ps1 -Purge
```

Back up `C:\ProgramData\Cronova`, including the database and encryption key, before destructive maintenance. Restore the complete directory before reinstalling.

## Build and package from source

On Windows with Go 1.26.5 or newer:

```powershell
.\scripts\package.ps1
```

The script builds both `windows/amd64` executables and creates `dist\cronova_windows_amd64.zip` with a SHA-256 checksum. The package includes the three PowerShell lifecycle scripts, `cronova.yaml`, example DAGs, runtime PowerShell scripts from `internal/scripts`, and supporting `configs`, `contracts`, `prompts`, `templates`, and Playwright assets required by distributed DAGs.

## Verification status

The repository workflow runs on `windows-latest` and performs formatting, module verification, vet, tests and Windows builds. The Linux development environment can run `go test ./...` and cross-build `windows/amd64`, but it cannot replace native validation of Windows Services, Job Objects, ACLs, clean installation, service recovery or descendant-process termination.
