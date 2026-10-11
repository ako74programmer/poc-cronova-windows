# Cronova — Windows installation

**Language: English | [Polski](README-INSTALL.pl.md)**

1. Extract the ZIP into a directory of your choice.
2. Double-click **`setup.cmd`**.

The installer selects a mode based on your permissions:

| Your permissions | What happens |
|---|---|
| Administrator | It asks for UAC approval and installs the **Windows services** `Cronova` and `CronovaExecutor`. They start with Windows and restart after a failure. Program: `C:\Program Files\Cronova`; data: `C:\ProgramData\Cronova`. |
| Administrator, but you decline UAC | Installs for the current user, as described below. |
| No administrator rights | Installs **for the current user**: program in `%LOCALAPPDATA%\Programs\Cronova`, data in `%LOCALAPPDATA%\Cronova`. It starts at sign-in through Task Scheduler and restarts after a failure. |

At the end, the installer prints the console URL (default: http://127.0.0.1:8090/), the login `admin`, and a **randomly generated password shown only once**. Save the password.

In per-user mode, the default database is `%LOCALAPPDATA%\Cronova\data\cronova.db`, as selected by `db: data/cronova.db` in `cronova.yaml`. Before updating, copy the entire `%LOCALAPPDATA%\Cronova` directory as a backup. When updating an older per-user installation, setup moves the former `%LOCALAPPDATA%\Cronova\cronova.db` (and any SQLite `-wal`, `-shm`, or `-journal` sidecars) to the configured location if that target does not already exist. If both locations contain database files, setup stops without overwriting either; back up and reconcile them before retrying. AI DAG scripts receive the same resolved database path through `CRONOVA_DB`.

## PowerShell options

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Mode user -Port 8091 -AdminPassword 'YourPassword'
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -AiBaseUrl http://127.0.0.1:4141/v1 -AiModel gpt-4o-mini
```

- `-Mode auto|service|user` — choose the installation mode (default: `auto`).
- `-Port` — set the console port if 8090 is already in use.
- `-AdminPassword` — use your own password instead of a generated one.

## Management

| | Windows services (admin) | Per-user mode |
|---|---|---|
| Status | `cronova status` | `.\internal\scripts\cronova-user.ps1 status` |
| Stop / start | `cronova stop` / `cronova start` (in an elevated console) | `.\internal\scripts\cronova-user.ps1 stop` / `start` |
| Update | New ZIP → `deploy\update.ps1` (admin) | New ZIP → `setup.cmd` (data is retained) |
| Uninstall | `deploy\uninstall.ps1` (admin) | `.\internal\scripts\cronova-user.ps1 uninstall` (`-Purge` also removes data) |

## Per-user mode limitations

- cronova runs only while you are signed in; it does not start at system boot.
- DAG tasks run with your Windows user permissions.
- The console is available only locally (`127.0.0.1`).

## Tools required by example DAGs

Java (JDK 21+), Maven, Node.js/npm, and Python are needed only by DAGs that use them. The installer detects these tools; a missing tool affects only the tasks that require it.
