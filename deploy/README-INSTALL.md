# Cronova – instalacja (Windows)

**Język: [English](README-INSTALL.en.md) | Polski**

1. Rozpakuj ZIP do dowolnego katalogu.
2. Kliknij dwukrotnie **`setup.cmd`**.

Skrypt sam wybiera tryb:

| Twoje uprawnienia | Co się dzieje |
|---|---|
| Administrator | Pyta o zgodę (UAC) i instaluje **usługi Windows** `Cronova` i `CronovaExecutor`. Startują z systemem, restartują się po awarii. Program: `C:\Program Files\Cronova`, dane: `C:\ProgramData\Cronova`. |
| Administrator, ale odmówisz UAC | Instalacja dla bieżącego użytkownika (jak niżej). |
| Brak uprawnień administratora | Instalacja **dla bieżącego użytkownika**: program w `%LOCALAPPDATA%\Programs\Cronova`, dane w `%LOCALAPPDATA%\Cronova`. Start po zalogowaniu (Harmonogram zadań), restart po awarii. |

Na końcu skrypt wypisze adres konsoli (domyślnie http://127.0.0.1:8090/), login `admin` i **jednorazowo** wygenerowane hasło — zapisz je.

## Opcje (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Mode user -Port 8091 -AdminPassword 'TwojeHaslo'
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -AiBaseUrl http://127.0.0.1:4141/v1 -AiModel gpt-4o-mini
```

- `-Mode auto|service|user` – wymuszenie trybu (domyślnie `auto`).
- `-Port` – port konsoli, gdy 8090 jest zajęty.
- `-AdminPassword` – własne hasło zamiast wygenerowanego.

## Zarządzanie

| | Usługi Windows (admin) | Tryb użytkownika |
|---|---|---|
| Status | `cronova status` | `.\internal\scripts\cronova-user.ps1 status` |
| Stop / start | `cronova stop` / `cronova start` (konsola admina) | `.\internal\scripts\cronova-user.ps1 stop` / `start` |
| Aktualizacja | nowy ZIP → `deploy\update.ps1` (admin) | nowy ZIP → `setup.cmd` (dane zostają) |
| Odinstalowanie | `deploy\uninstall.ps1` (admin) | `.\internal\scripts\cronova-user.ps1 uninstall` (`-Purge` usuwa też dane) |

## Ograniczenia trybu użytkownika

- Działa tylko, gdy jesteś zalogowany (nie od startu systemu).
- Zadania DAG wykonują się z Twoimi uprawnieniami.
- Konsola dostępna tylko lokalnie (127.0.0.1).

## Wymagane narzędzia dla przykładowych DAG-ów

Java (JDK 21+), Maven, Node.js/npm, Python – zależnie od DAG-a. Instalator wykrywa je automatycznie; brak narzędzia powoduje błąd tylko w zadaniach, które go używają.
