# Deploying cronova on Windows

Cronova in this repository targets Windows 10/11 and Windows Server on `amd64`. It consists of `cronova.exe` (scheduler, REST API and web console) and `cronova-executor.exe` (task process owner). The `shell` task type runs through Git for Windows `bash.exe -lc`; it does not use `cmd.exe` or PowerShell semantics.

## Requirements

Install Git for Windows and ensure `bash.exe` is available. Run installation from an elevated PowerShell. The installer checks `CRONOVA_BASH_PATH`, `PATH`, and the standard Git installation directories.

## Install from a release ZIP

Extract `cronova_windows_amd64.zip`, open an elevated PowerShell in the extracted directory, and run:

```powershell
.\deploy\install.ps1
# Non-standard Git installation:
.\deploy\install.ps1 -BashPath 'D:\Tools\Git\bin\bash.exe'
```

The installer installs binaries below `C:\Program Files\Cronova`, creates the data root `C:\ProgramData\Cronova`, and registers two Windows Services: `CronovaExecutor` and `Cronova`. The scheduler depends on the executor and both services have failure recovery configured.

## Data and configuration

The default data root contains `cronova.yaml`, `cronova.db`, `dags`, `projects`, `workspaces`, `logs` and `executor-state`. The selected Bash path is stored as `bash_path` and can also be overridden by `CRONOVA_BASH_PATH` or `-bash-path`.

The local scheduler–executor endpoint is loopback TCP, normally `tcp://127.0.0.1:19090` for the installed service. It must not be bound to a public interface. Remote executor connections use mTLS; loopback-only local traffic may use the local transport without TLS.

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

## Shell tasks and process containment

Shell tasks are executed by Git Bash with `bash.exe -lc`. A missing or non-runnable Bash executable fails the task with an explicit error. The Windows runner creates a Job Object per task, enables `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, assigns the task process to it, and uses `TerminateJobObject` for timeout and cancellation. A controlled executor restart removes the kill-on-close flag before closing the local handle so persisted tasks can continue; a hard executor termination still requires native Windows recovery testing.

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

The script builds both `windows/amd64` executables and creates `dist\cronova_windows_amd64.zip` with a SHA-256 checksum. The package includes the three PowerShell lifecycle scripts, `cronova.yaml`, example DAGs and this deployment guide.

## Verification status

The repository workflow runs on `windows-latest` and performs formatting, module verification, vet, tests and Windows builds. The Linux development environment can run `go test ./...` and cross-build `windows/amd64`, but it cannot replace native validation of Windows Services, Job Objects, ACLs, clean installation, service recovery or descendant-process termination.
