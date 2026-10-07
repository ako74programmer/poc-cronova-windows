# cronova-uninstall.ps1

Całkowicie odinstalowuje Cronovę z Windows (wymaga uprawnień administratora):

1. wyłącza auto-restart (recovery) i autostart usług, żeby SCM nie wskrzeszał procesów,
2. zabija drzewa procesów usług `Cronova` i `CronovaExecutor` (łącznie z procesami zadań) oraz każdy proces uruchomiony z katalogu instalacyjnego,
3. zatrzymuje i usuwa usługi z SCM,
4. usuwa `C:\Program Files\Cronova` (z ponawianiem, jeśli pliki są zablokowane),
5. z `-Purge` usuwa też dane `C:\ProgramData\Cronova`,
6. weryfikuje, że nic nie zostało — w przeciwnym razie kończy się błędem.

Parametry: `-Purge`, `-KillAll` (zabija też `cronova.exe`/`cronova-executor.exe` spoza katalogu instalacyjnego, np. z `dist`), `-ServiceName`, `-InstallDir`, `-DataDir`, `-RetrySeconds`.

```powershell
.\deploy\uninstall.ps1            # usuwa usługi i binaria, zostawia dane
.\deploy\uninstall.ps1 -Purge     # usuwa wszystko
```
