# Tutorial Cronova — część 1: instalacja i pierwsze otwarcie

Ta instrukcja jest dla osoby, która dopiero poznaje Cronovę. Czytaj po kolei i wykonuj jeden krok naraz.

## Co to jest Cronova?

Pomyśl o Cronovie jak o pomocniku, który może uruchamiać zadania na komputerze. Na przykład: „codziennie o 8:00 uruchom ten program”.

Najpierw trzeba ją zainstalować i otworzyć jej stronę.

## Krok 1: Pobierz i rozpakuj program

1. Pobierz paczkę Cronovy dla Windows o nazwie `cronova_windows_amd64.zip`.
2. Kliknij pobrany plik prawym przyciskiem myszy i wybierz **Wyodrębnij wszystko**.
3. Otwórz folder, który powstał po rozpakowaniu.
4. W tym folderze znajdź plik **`setup.cmd`**.

> Jeśli nie widzisz pliku `setup.cmd`, sprawdź, czy na pewno otworzyłeś folder po rozpakowaniu, a nie sam plik ZIP.

## Krok 2: Uruchom instalator

Kliknij dwa razy **`setup.cmd`**.

Instalator wybierze jeden z dwóch sposobów instalacji:

- **Usługi Windows** — jeśli masz uprawnienia administratora i zgodzisz się na komunikat Windows. Cronova może wtedy działać jako usługa systemu.
- **Instalacja dla bieżącego użytkownika** — jeśli nie masz uprawnień administratora albo odmówisz w komunikacie. Cronova będzie uruchamiana po zalogowaniu na Twoje konto.

Jeśli Windows zapyta o zgodę administratora, wybierz zgodnie z tym, jak chcesz zainstalować program. Instalacja dla użytkownika nie wymaga tej zgody.

## Krok 3: Zapisz hasło

Pod koniec instalacji może pojawić się hasło dla konta `admin`.

**Zapisz je w bezpiecznym miejscu.** Jeśli instalator wygenerował hasło, może pokazać je tylko raz. Nie wysyłaj go innym osobom i nie wklejaj do publicznego czatu.

## Krok 4: Otwórz Cronovę

Po zakończeniu instalacji otwórz przeglądarkę i wpisz adres:

```text
http://127.0.0.1:8090
```

Powinna pojawić się strona logowania Cronovy. Zaloguj się nazwą użytkownika `admin` i hasłem zapisanym w poprzednim kroku.

Jeśli podczas instalacji wybrano inny port, instalator pokaże inny adres — użyj właśnie tego adresu.

## Jeśli strona się nie otwiera

1. Sprawdź, czy instalator zakończył działanie i nie pokazał błędu.
2. Jeśli instalator wypisał adres strony, skopiuj go dokładnie do przeglądarki.
3. Jeśli instalacja nadal trwa, poczekaj na jej zakończenie.
4. Jeśli problem nie znika, zapisz treść komunikatu błędu. Nie zapisuj ani nie wysyłaj hasła.

## Gotowe

Jeśli widzisz stronę Cronovy, część instalacyjna jest zakończona. W kolejnej części tutorialu poznamy ekran Cronovy i wyjaśnimy, do czego służą jego najważniejsze miejsca.

**Następna część:** poznawanie ekranu Cronovy — zostanie przygotowana osobno.
