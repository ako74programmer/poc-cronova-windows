# seed-cronova-admin.ps1

Seeduje konto administratora w bazie Cronova przez wbudowane CLI `cronova.exe users ...`.

## Parametry

- `-CronovaExe` — ścieżka do `cronova.exe`; domyślnie używa `C:\Program Files\Cronova\cronova.exe`, jeśli istnieje.
- `-DatabasePath` — ścieżka do bazy SQLite; domyślnie `C:\ProgramData\Cronova\cronova.db`.
- `-Username` — nazwa użytkownika; domyślnie `admin`.
- `-Password` — hasło użytkownika; domyślnie `admin123`.

## Przykłady

```powershell
.\internal\scripts\seed-cronova-admin.ps1
```

```powershell
.\internal\scripts\seed-cronova-admin.ps1 -CronovaExe .\dist\service-test\cronova.exe -DatabasePath .\.tmp\seed-test\cronova.db
```
