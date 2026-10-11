# Tutorial Cronova — część 8: pytamy AI Wiki i sprawdzamy odpowiedź

**AI Wiki** to okno w Cronovie, w którym możesz zadać pytanie o program. Możesz na przykład zapytać, czym jest DAG albo gdzie znaleźć informacje o ponawianiu taska.

## Krok 1: otwórz AI Wiki

1. Otwórz konsolę Cronovy.
2. W menu po lewej stronie kliknij **AI wiki**.
3. Zobaczysz wiadomość powitalną i pole, w którym można wpisać pytanie.

## Krok 2: zadaj proste pytanie

Kliknij pole z podpowiedzią **„Zapytaj np. jak zrobić DAG…”** i wpisz:

```text
Co to jest DAG w cronova?
```

Kliknij **Wyślij** albo naciśnij **Enter**.

Możesz też spróbować pytań:

```text
Jak działa retry?
```

```text
Gdzie ustawia się harmonogram DAG-a?
```

```text
Jak uruchomić skrypt jako task?
```

Lepiej pytać o jedną rzecz naraz. Konkretne pytanie, takie jak „Gdzie ustawia się harmonogram DAG-a?”, jest łatwiejsze do sprawdzenia niż „Opowiedz mi wszystko o Cronovie”.

## Krok 3: przeczytaj odpowiedź i sprawdź źródła

Pod odpowiedzią może pojawić się sekcja **Źródła**.

Źródło mówi, z jakiego dokumentu, przykładowego DAG-a albo skryptu pochodzi pasująca informacja. Kliknij nazwę źródła:

- jeśli jest to dokument, otworzy się w oknie nad konsolą;
- jeśli jest to DAG, Cronova otworzy stronę tego DAG-a.

AI Wiki może pokazać kilka źródeł. Porównaj je z odpowiedzią — zwłaszcza jeśli chcesz później zmienić działający DAG.

## Krok 4: przeczytaj otwarty dokument

Gdy klikniesz źródło będące dokumentem, możesz:

- przeczytać je w otwartym oknie;
- kliknąć **🔊 Czytaj dokumentację**, jeśli przeglądarka obsługuje czytanie tekstu;
- zamknąć okno przyciskiem **✕**, klawiszem **Escape** albo klikając obszar poza dokumentem.

Jeśli przeglądarka nie obsługuje czytania tekstu, przycisk może pokazać ostrzeżenie zamiast odczytać dokument.

## Krok 5: uważaj na przyciski działań

Czasem odpowiedź zawiera także przyciski do wykonania następnego kroku, na przykład:

- **Uruchom ten DAG**;
- **Historia runów**;
- **Pokaż logi**;
- **Kopiuj komendę CLI**.

Ważne: **Uruchom ten DAG naprawdę rozpoczyna uruchomienie przepływu** — to nie jest tylko podgląd ani przykład. Jeśli nie wiesz, co dany DAG robi, nie klikaj tego przycisku. Najpierw otwórz DAG i sprawdź jego taski.

Przycisk **Kopiuj komendę CLI** kopiuje tekst polecenia. Samo kopiowanie nie uruchamia go.

## Skąd AI Wiki bierze informacje?

Cronova przeszukuje swoją wbudowaną bazę wiedzy, zbudowaną z wybranych dokumentów projektu, przykładowych DAG-ów i skryptów. Jeśli skonfigurowano **AI Provider**, może użyć go do ułożenia odpowiedzi na podstawie znalezionych fragmentów.

AI Wiki nie musi znać każdego DAG-a utworzonego przez Ciebie ani każdej zmiany w Twoim projekcie. Traktuj ją jak pomoc w odnajdywaniu informacji, a nie jak kogoś, kto na pewno widział wszystko, co znajduje się na Twoim komputerze.

## Czy AI Provider jest potrzebny?

**AI Wiki może działać również bez skonfigurowanego AI Provider.** Wtedy Cronova nadal przeszukuje bazę wiedzy, ale odpowiedź może być prostsza i oparta na przygotowanych podpowiedziach.

Po skonfigurowaniu providera odpowiedzi mogą być układane przez model. To jednak nie gwarantuje, że model będzie dostępny ani że zawsze odpowie poprawnie. Przed ważną zmianą sprawdź podane źródło lub dokumentację.

## Jeśli odpowiedź nie pomaga

Spróbuj kolejno:

1. Zadaj krótsze i bardziej konkretne pytanie.
2. Dodaj nazwę funkcji, o którą pytasz, na przykład `DAG`, `task`, `retry` albo `harmonogram`.
3. Otwórz podane źródło i sprawdź, czy dotyczy Twojego pytania.
4. Jeśli odpowiedź wspomina, że nie znalazła informacji w bazie Cronovy, nie traktuj dalszego tekstu jako odpowiedzi potwierdzonej przez dokumentację.
5. Jeśli ekran pokaże **Błąd połączenia z AI wiki**, sprawdź, czy jesteś zalogowany i czy konsola Cronovy działa. Jeśli problem powtarza się po skonfigurowaniu providera, administrator powinien sprawdzić jego endpoint, model, token i dostępność usługi.

Jeśli AI Provider nie odpowie na zapytanie, AI Wiki może pokazać prostszą odpowiedź zastępczą zamiast wyraźnego komunikatu o błędzie providera.

## Czy rozmowa zostaje zapisana?

Na ekranie AI Wiki nie ma funkcji zapisywania ani przeglądania historii rozmów. Nie zakładaj więc, że odpowiedź będzie dostępna po opuszczeniu strony albo odświeżeniu konsoli. Jeśli jest ważna, skopiuj ją samodzielnie.

## Gotowe

Potrafisz już zadać pytanie w AI Wiki, sprawdzić źródło i odróżnić zwykłą odpowiedź od przycisku, który może naprawdę uruchomić DAG.
