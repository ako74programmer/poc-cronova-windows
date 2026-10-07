# cronova-stop-process-by-name.ps1

Zatrzymuje procesy po nazwie przez `Stop-Process -Id`.

## Parametry

- `-Name` — jedna lub wiele nazw procesów bez `.exe`
- `-RequireMatch` — zgłasza błąd, jeśli nic nie znaleziono

## Przykład

```powershell
.\internal\scripts\cronova-stop-process-by-name.ps1 -Name notepad -RequireMatch
```
