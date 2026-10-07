# cronova-service-common.ps1

Wspólne funkcje PowerShell do obsługi usług Cronova na Windows.

## Zakres

Udostępnia helpery do:
- zatrzymywania usług,
- wymuszonego ubijania PID usług,
- usuwania usług,
- odczytu stanu i PID przez `sc.exe`,
- rozpakowania `cronova_windows_amd64.zip` do instalacji.

## Typowe użycie

Skrypt jest importowany przez cienkie wrappery, np. `deploy/install.ps1`, `deploy/uninstall.ps1`, `deploy/reinstall.ps1`.
