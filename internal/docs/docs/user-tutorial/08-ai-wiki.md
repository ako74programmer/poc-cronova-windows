# Tutorial Cronova — część 8: pytamy AI Chat i sprawdzamy odpowiedź

**AI Chat** to okno w Cronovie, w którym możesz zadać pytanie o program. Możesz na przykład zapytać, czym jest DAG albo gdzie znaleźć informacje o ponawianiu taska.

## Krok 1: otwórz AI Chat

1. Otwórz konsolę Cronovy.
2. W menu po lewej stronie kliknij **AI Chat**.
3. Zobaczysz wiadomość powitalną i pole, w którym można wpisać pytanie.

## Krok 2: zadaj pytanie o dokumentację

Kliknij pole z podpowiedzią **„Zapytaj np. jak zrobić DAG…”** i wpisz:

```text
Co to jest DAG w cronova?
```

Kliknij **Wyślij** albo naciśnij **Enter**.

Możesz też kliknąć ikonę mikrofonu i wypowiedzieć pytanie. Rozpoznany tekst pojawi się w polu — **sprawdź go i kliknij Wyślij**, bo samo mówienie nie wysyła pytania. Przeglądarka może poprosić o dostęp do mikrofonu; rozpoznawanie głosu zależy od przeglądarki i połączenia z usługą mowy. Jeśli mikrofon jest niedostępny, wpisz pytanie z klawiatury.

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

Odpowiedź może być sformatowana, na przykład zawierać **pogrubienie**, listę, tabelę albo blok kodu. Czytaj treść razem ze źródłami poniżej.

Źródło mówi, z jakiego dokumentu, przykładowego DAG-a, skryptu albo danych runu pochodzi informacja. Kliknij nazwę źródła:

- jeśli jest to dokument, otworzy się w oknie nad konsolą;
- jeśli jest to DAG, Cronova otworzy stronę tego DAG-a;
- jeśli źródłem jest `runs/<run_id>`, Cronova otworzy szczegóły tego uruchomienia.

AI Chat może pokazać kilka źródeł. Porównaj je z odpowiedzią — zwłaszcza jeśli chcesz później zmienić działający DAG.

## Krok 4: przeczytaj otwarty dokument

Gdy klikniesz źródło będące dokumentem, możesz:

- przeczytać je w otwartym oknie;
- kliknąć **🔊 Czytaj dokumentację**, jeśli przeglądarka obsługuje czytanie tekstu;
- zamknąć okno przyciskiem **✕**, klawiszem **Escape** albo klikając obszar poza dokumentem.

Jeśli przeglądarka nie obsługuje czytania tekstu, przycisk może pokazać ostrzeżenie zamiast odczytać dokument.

## Krok 5: zapytaj o konkretne uruchomienie DAG-a

AI Chat może sprawdzić bieżące dane **konkretnego** uruchomienia (runu). Najpierw znajdź run w historii DAG-a i skopiuj jego **Run ID** z nagłówka strony szczegółów.

W pytaniu podaj pełny identyfikator, na przykład:

```text
Jaki jest stan runu etl__r1 i które taski się nie powiodły?
```

AI Chat pobiera wtedy stan runu, jego DAG, daty rozpoczęcia/zakończenia i stany tasków. Źródło `runs/<run_id>` możesz kliknąć, aby wrócić do strony tego runu. AI Chat nie wyszukuje w tym trybie „najnowszego runu” za Ciebie — potrzebuje dokładnego Run ID. Jeśli podasz kilka ID naraz, poprosi o jeden konkretny.

Możesz zadać pytanie uzupełniające w tej samej rozmowie, na przykład:

```text
A dlaczego ten run się nie powiódł?
```

AI Chat użyje Run ID z poprzedniej wiadomości i pobierze aktualne dane ponownie. Historia rozmowy nie jest zapisywana na stałe.

## Krok 6: poproś o logi tylko wtedy, gdy ich potrzebujesz

Logi nie są pobierane przy zwykłym pytaniu o stan runu. Poproś o nie wprost, na przykład:

```text
Pokaż logi taska extract z runu etl__r1.
```

AI Chat dołącza maksymalnie trzy końcowe fragmenty logów, po maksymalnie 8 KiB każdy. Najpierw wybiera task wymieniony w pytaniu, a potem taski zakończone błędem lub timeoutem. Fragmenty są redagowane pod kątem typowych zapisów sekretów, ale **redakcja może nie wykryć każdego sekretu**.

Gdy w konsoli jest skonfigurowany AI Provider, dane runu/tasków z pytania o Run ID są wysyłane do tego providera w celu ułożenia odpowiedzi. Jeśli poprosisz o logi, do providera trafią również wybrane, ograniczone fragmenty logów. Nie proś o analizę logów zawierających dane, których nie wolno wysyłać do skonfigurowanego providera. Pełne logi nadal sprawdzisz na stronie runu.

## Krok 7: uważaj na przyciski działań

Czasem odpowiedź dotycząca dokumentacji zawiera także przyciski do wykonania następnego kroku, na przykład:

- **Uruchom ten DAG**;
- **Historia runów**;
- **Pokaż logi**;
- **Kopiuj komendę CLI**.

Ważne: **Uruchom ten DAG naprawdę rozpoczyna uruchomienie przepływu** — to nie jest tylko podgląd ani przykład. Jeśli nie wiesz, co dany DAG robi, nie klikaj tego przycisku. Najpierw otwórz DAG i sprawdź jego taski.

Przycisk **Kopiuj komendę CLI** kopiuje tekst polecenia. Samo kopiowanie nie uruchamia go.

## Skąd AI Chat bierze informacje?

Przy pytaniu o funkcje Cronovy aplikacja przeszukuje wbudowaną bazę wiedzy, zbudowaną z wybranych dokumentów projektu, przykładowych DAG-ów i skryptów. Jeśli skonfigurowano **AI Provider**, może użyć go do ułożenia odpowiedzi na podstawie znalezionych fragmentów.

Przy pytaniu z konkretnym Run ID aplikacja pobiera stan tego runu i jego tasków bezpośrednio z bazy Cronovy. Logi odczytuje dopiero wtedy, gdy poprosisz o nie wprost. AI Chat nie musi znać każdego DAG-a utworzonego przez Ciebie ani każdej zmiany w Twoim projekcie. Traktuj ją jak pomoc w odnajdywaniu informacji, a nie jak kogoś, kto na pewno widział wszystko, co znajduje się na Twoim komputerze.

## Czy AI Provider jest potrzebny?

**AI Chat może działać również bez skonfigurowanego AI Provider.** Wtedy Cronova nadal przeszukuje bazę wiedzy, a pytanie o konkretny run pokaże dostępne dane runtime bez modelu. Odpowiedź może być prostsza.

Po skonfigurowaniu providera odpowiedzi mogą być układane przez model. To jednak nie gwarantuje, że model będzie dostępny ani że zawsze odpowie poprawnie. Przed ważną zmianą sprawdź podane źródło lub dokumentację.

## Jeśli odpowiedź nie pomaga

Spróbuj kolejno:

1. Zadaj krótsze i bardziej konkretne pytanie.
2. Dodaj nazwę funkcji, o którą pytasz, na przykład `DAG`, `task`, `retry` albo `harmonogram`.
3. Otwórz podane źródło i sprawdź, czy dotyczy Twojego pytania.
4. Jeśli pytasz o live run, sprawdź, czy skopiowałeś dokładny Run ID, np. `etl__r1`, a nie nazwę DAG-a.
5. Jeśli AI Chat odpowie, że runu nie znaleziono, sprawdź identyfikator i upewnij się, że run nie został już usunięty przez retencję.
6. Jeśli ekran pokaże **Błąd połączenia z AI Chat**, sprawdź, czy jesteś zalogowany i czy konsola Cronova działa. Jeśli problem powtarza się po skonfigurowaniu providera, administrator powinien sprawdzić jego endpoint, model, token i dostępność usługi.
7. Jeśli generowanie odpowiedzi przez AI się nie powiedzie, sprawdź wyświetlone dane/źródło runtime; sama awaria modelu nie oznacza, że odczyt stanu runu się nie udał.

## Czy rozmowa zostaje zapisana?

Na ekranie AI Chat nie ma funkcji trwałego zapisywania ani przeglądania historii rozmów. W tej samej otwartej stronie AI Chat może użyć ostatnich wiadomości, aby zrozumieć pytanie uzupełniające, na przykład „A dlaczego?”. Rozmowa nie jest przechowywana na stałe. Jeśli odpowiedź jest ważna, skopiuj ją samodzielnie.

## Gotowe

Potrafisz już zadać pytanie w AI Chat, sprawdzić źródło, odczytać stan wskazanego runu i poprosić o ograniczone fragmenty jego logów — wiedząc, że logi mogą zostać wysłane do skonfigurowanego AI Provider.
