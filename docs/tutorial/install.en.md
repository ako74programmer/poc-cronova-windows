# Install cronova

cronova is a self-hosted **workflow scheduler** for Windows, distributed as a ZIP containing the scheduler, executor, web console, REST API, CLI, and the files used by the example DAGs. This chapter shows how to run the tutorial directly from the ZIP and, separately, how to install cronova for ongoing use.

## Option 1: Run the tutorial from the release ZIP (recommended)

Download **`cronova_windows_amd64.zip`** from the [GitHub Releases page](https://github.com/ako74programmer/poc-cronova-windows/releases) and extract it into a working directory. The package includes `cronova.exe`, `cronova-executor.exe`, `cronova.yaml`, the `dags/` directory, the optional installer `setup.cmd`, and Polish and English installation guides.

For this tutorial, **do not run `setup.cmd`**. Running the executable directly keeps data in the extracted working directory and avoids installing Windows services or a logon task:

```powershell
Set-Location .\cronova_windows_amd64
.\cronova.exe version
```

The version command prints the release version and platform, for example `cronova <release-version> windows/amd64`. If you extracted the ZIP into a directory with a different name, change to that directory instead. You do not need Go or administrator rights to run the prebuilt binaries.

### Create the initial admin account

The release ZIP includes a `cronova.yaml` with authentication enabled, so seeing a login page is **expected**. Create the admin account once for this extracted directory and database.

First, run this single line by itself:

```powershell
$securePassword = Read-Host -Prompt "Type the password you want to use at login (input is hidden)" -AsSecureString
```

The quoted text is only the prompt label, **not** your password. When PowerShell displays the prompt, type the password you want to use to log in and press Enter. The characters will not appear on screen. Wait until the normal `PS>` prompt returns before running the next block; do not paste both blocks at once.

Now run this block once:

```powershell
$adminPassword = [System.Net.NetworkCredential]::new("", $securePassword).Password
.\cronova.exe users add admin -role admin -password $adminPassword -db "data\cronova.db"
Remove-Variable adminPassword, securePassword
```

The success message is `created admin account "admin"`. Do **not** run `users add` again for this database: an “already exists” error means the account was created earlier. If the browser returns `401`, reset the existing account's password; do not try to add it again.

#### Change the password:

If the server is running, leave it running and open a second PowerShell window. Change to the same extracted ZIP directory so the command uses the same database. Run this line by itself to request a new password:

```powershell
$securePassword = Read-Host -Prompt "Type a new password for admin (input is hidden)" -AsSecureString
```

Type the new password at the prompt and wait for `PS>` to return. Then run:

```powershell
$newPassword = [System.Net.NetworkCredential]::new("", $securePassword).Password
.\cronova.exe users passwd admin -password $newPassword -db "data\cronova.db"
Remove-Variable newPassword, securePassword
```

Sign in with the new password. The database path is relative to the current working directory.

### Start the scheduler and open the console

From the directory containing `cronova.exe`, start the scheduler and the in-process executor:

```powershell
.\cronova.exe serve
```

By default, DAG YAML files load from `./dags` (created if missing), the SQLite database is stored at `data\cronova.db`, and task logs go to `logs/`, all relative to the current working directory. This is why a dedicated extracted working directory is convenient for the tutorial.

Open **http://localhost:8090** in your browser and sign in as `admin` with the password you typed at the prompt. The bundled DAG files in `dags/` appear in the console. From a second PowerShell window, verify that cronova loaded them:

```powershell
.\cronova.exe dags
```

Each loaded DAG is listed with its schedule. This confirms the scheduler is running and reading the directory. The same `serve` process provides the web console and REST API. Stop the server by pressing **Ctrl+C** (hold Ctrl and press C); your DAGs, database, and logs remain on disk for the next run.

**WARNING:** The release ZIP enables authentication and binds the console to `127.0.0.1:8090` by default. Keep the listener local while following this tutorial. If you later expose cronova to a network, review the security guidance in [Enabling login](../GETTING_STARTED.md#enabling-login) and [Deployment](../DEPLOY.md).

## Option 2: Install cronova for ongoing use

To install cronova rather than just follow the tutorial, double-click **`setup.cmd`** in the extracted ZIP. The setup program chooses a mode based on your permissions:

- If you are an administrator, it offers to install the `Cronova` and `CronovaExecutor` Windows services. Accept the UAC prompt to install the services.
- If you decline UAC, or do not have administrator rights, it installs for your Windows user and starts at sign-in through Task Scheduler.

If port 8090 is already in use, the installer stops instead of choosing another port automatically. Open PowerShell in the extracted ZIP directory and rerun it with a free port, for example:

```powershell
.\setup.cmd -Port 8091
```

`setup.cmd` forwards the argument to the installer. The console will then be available at `http://127.0.0.1:8091/` (or the port you selected).

The installer configures the admin account and prints the actual console URL and password at the end. The default address is **http://127.0.0.1:8090/**; if you pass `-Port`, the printed URL uses the selected port. If the password is generated automatically, **save it then**; it is shown only once. For options and management commands, see the packaged [Windows installation guide](../DEPLOY.md), `README-INSTALL.en.md` (English), or `README-INSTALL.md` (Polish) in the ZIP.

You can change the generated password later with the same `users passwd` command in any installation mode. The command is the same, but the database location depends on the installation: Option 1 uses `data\cronova.db`; a per-user install stores it directly at `%LOCALAPPDATA%\Cronova\cronova.db`, and a service install at `%ProgramData%\Cronova\cronova.db` (those installed modes do not have a `data` subdirectory). Choose **one** path pair for the installation you are using:

```powershell
$cronovaExe = (Resolve-Path ".\cronova.exe").Path
$dbPath = (Resolve-Path ".\data\cronova.db").Path
```

The pair above is for Option 1; run it in PowerShell opened in the extracted ZIP directory. For a per-user installation, run PowerShell as the same Windows user and use:

```powershell
$cronovaExe = "$env:LOCALAPPDATA\Programs\Cronova\cronova.exe"
$dbPath = "$env:LOCALAPPDATA\Cronova\cronova.db"
```

For a Windows service installation, run PowerShell as an administrator and use:

```powershell
$cronovaExe = "$env:ProgramFiles\Cronova\cronova.exe"
$dbPath = "$env:ProgramData\Cronova\cronova.db"
```

After setting the paths for your installation, enter the new password. The characters you type are hidden:

```powershell
$securePassword = Read-Host -Prompt "Enter a new admin password (input is hidden)" -AsSecureString
$newPassword = [System.Net.NetworkCredential]::new("", $securePassword).Password
& $cronovaExe users passwd admin -password $newPassword -db $dbPath
Remove-Variable securePassword, newPassword, cronovaExe, dbPath
```

Changing the password revokes existing sessions; sign in again with the new password.

**Important:** The installer starts cronova for you. After installation, do not start another `cronova serve` process using the same data directory.

To check that a per-user installation is running and registered to start through Task Scheduler, run:

```powershell
& "$env:LOCALAPPDATA\Cronova\internal\scripts\cronova-user.ps1" status
```

The output should include `cronova.exe RUNNING`, `cronova-executor.exe RUNNING`, and `Autostart: scheduled task 'Cronova (user)'`. For a Windows service installation, check both services instead, from an elevated PowerShell:

```powershell
Get-Service Cronova, CronovaExecutor
```

To continue this tutorial, use Option 1 and leave `setup.cmd` unused.

## Option 3: Build the scheduler from source

To build the scheduler binary yourself, install **Go 1.26.5 or newer** and run these commands in PowerShell:

```powershell
git clone https://github.com/ako74programmer/poc-cronova-windows
Set-Location .\poc-cronova-windows
go build -o .\cronova.exe .\cmd\cronova
```

`git clone` creates the `poc-cronova-windows` directory; run the build from that directory. The build produces the scheduler, web console, and CLI in one binary. It uses pure-Go SQLite and does not require a C toolchain. A plain `go build` reports its version as `dev`.

To build the complete Windows installer ZIP (both executables and all runtime assets), use the project's Windows packaging and verification scripts. See [Deployment](../DEPLOY.md#build-and-package-from-source); building only `cronova.exe` is sufficient for the standalone tutorial, not for the service installer. When running the binary from the repository's working directory, follow the initial-account step in Option 1 because the repository's `cronova.yaml` also enables authentication.

## What you learned

- Download the Windows amd64 ZIP and run `cronova.exe` directly to follow the tutorial; this requires neither Go nor administrator rights.
- The release ZIP enables authentication, so create a local admin account once before the first `serve` run.
- `setup.cmd` is the separate guided installer for Windows services or a per-user installation; it starts cronova itself.
- To build only the scheduler from source, use Go 1.26.5+ from the `poc-cronova-windows` repository directory.

Next up: write and trigger your first DAG — [First DAG](first-dag.md).
