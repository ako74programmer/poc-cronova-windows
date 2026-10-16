# Tutorial Cronova — część 8: pytamy AI Chat i sprawdzamy odpowiedź

**AI Chat** to okno w Cronovie, w którym możesz zadać pytanie o program. Możesz na przykład zapytać, czym jest DAG albo gdzie znaleźć informacje o ponawianiu taska.

## Krok 1: otwórz AI Chat

1. Otwórz konsolę Cronovy.
2. W menu po lewej stronie kliknij **AI Chat**.
3. Zobaczysz wiadomość powitalną i pole, w którym można wpisać pytanie.

## Krok 2: wybierz tryb Dokumentacja i zadaj pytanie

Nad oknem rozmowy znajdziesz listę **Tryb**. Wybierz **Dokumentacja**, gdy pytasz o funkcje Cronovy, DAG-i, taski, konfigurację lub instrukcje. Ten tryb przeszukuje dokumentację i nie odczytuje danych runów z bazy.

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

## Krok 5: wybierz tryb Analiza runów

Gdy chcesz sprawdzić wykonania zapisane w bazie Cronovy, na liście **Tryb** wybierz **Analiza runów**. To tryb rozmowy z agentem: model może samodzielnie wywoływać ograniczone, tylko do odczytu narzędzia Cronovy. Nie musi rozpoznawać pytania po jednym sztywnym słowie i nie musisz za każdym razem powtarzać identyfikatorów z poprzednich wiadomości.

Agent potrzebuje skonfigurowanego AI Provider, którego model obsługuje **OpenAI-compatible tool/function calling**. Bez providera aplikacja nadal może pokazać prostą listę runów lub dane runu wskazanego pełnym Run ID, ale nie ma wtedy modelowego agenta, który rozumie pytania uzupełniające.

Możesz poprosić o listę najnowszych runów:

```text
Pokaż ostatnie runy
```

Agent użyje narzędzia do pobrania maksymalnie 10 najnowszych runów należących do aktywnych DAG-ów. W odpowiedzi pojawią się źródła i przycisk **Analizuj ten run**. Kliknij go, aby zadać pytanie o wskazane wykonanie. Możesz też kliknąć źródło `runs/<run_id>`, aby otworzyć stronę szczegółów runu.

Jeśli znasz identyfikator, możesz pominąć listę i wpisać **Run ID** ręcznie. Znajdziesz go w nagłówku szczegółów runu. Jeśli znasz tylko nazwę taska, możesz o niego zapytać — agent sprawdzi tę nazwę w maksymalnie 10 najnowszych runach. Gdy znajdzie kilka pasujących wykonań, poprosi Cię o wskazanie właściwego zamiast zgadywać.

W pytaniu podaj pełny identyfikator, na przykład:

```text
Jaki jest stan runu etl__r1 i które taski się nie powiodły?
```

Agent pobiera wtedy z bazy stan runu, daty i stany tasków. Narzędzia w tym trybie są tylko do odczytu — nie uruchamiają ani nie zmieniają DAG-ów. Jeśli podasz kilka Run ID i nie będzie jasne, które analizować, agent poprosi o wybór jednego konkretnego.

Możesz zadać pytanie uzupełniające w tej samej rozmowie, na przykład:

```text
A dlaczego ten run się nie powiódł?
```

Agent użyje kontekstu wcześniejszych pytań i źródeł, aby odnaleźć Run ID oraz task. Następnie pobierze potrzebne dane ponownie, zamiast zgadywać na podstawie opisu. Nie musisz powtarzać Run ID, jeśli rozmowa jasno wskazuje właściwy run. Historia jest tymczasowa i nie jest zapisywana na stałe.

## Krok 6: poproś o logi tylko wtedy, gdy ich potrzebujesz

Pozostań w trybie **Analiza runów**. Logi nie są pobierane przy zwykłym pytaniu o stan runu. Poproś o nie wprost, na przykład:

```text
Pokaż logi taska extract z runu etl__r1.
```

Agent użyje narzędzia do odczytania końcówki logu wskazanego taska. Na jedną odpowiedź może odczytać logi maksymalnie trzech tasków, a każdy fragment ma limit 8 KiB. Fragmenty są redagowane pod kątem typowych zapisów sekretów, ale **redakcja może nie wykryć każdego sekretu**.

Po odpowiedzi o logach możesz dopytać zwykłym językiem, na przykład:

```text
Jaki skrypt był użyty w tym kroku?
```

Agent powinien użyć kontekstu rozmowy, odnaleźć Run ID i task, a potem odczytać polecenie z zapisanej definicji runu. Nie trzeba powtarzać całego Run ID. Jeśli nie ma dość kontekstu albo task występuje w kilku runach, agent powinien poprosić o wskazanie właściwego.

Gdy w konsoli jest skonfigurowany AI Provider, agent wysyła do niego pytanie i tylko te dane runu/taska, których potrzebuje do odpowiedzi. Gdy pytasz o użyty skrypt, może przekazać modelowi polecenie zapisane w definicji runu. Gdy prosisz o logi (albo odpowiedź wymaga sprawdzenia wyniku wykonania), do providera trafiają również wybrane, ograniczone fragmenty logów. Nie proś o analizę danych, których nie wolno wysyłać do skonfigurowanego providera. Pełne logi nadal sprawdzisz na stronie runu.

## Krok 7: uważaj na przyciski działań

Czasem odpowiedź dotycząca dokumentacji zawiera także przyciski do wykonania następnego kroku, na przykład:

- **Uruchom ten DAG**;
- **Historia runów**;
- **Pokaż logi**;
- **Kopiuj komendę CLI**.

Ważne: **Uruchom ten DAG naprawdę rozpoczyna uruchomienie przepływu** — to nie jest tylko podgląd ani przykład. Jeśli nie wiesz, co dany DAG robi, nie klikaj tego przycisku. Najpierw otwórz DAG i sprawdź jego taski.

Przycisk **Kopiuj komendę CLI** kopiuje tekst polecenia. Samo kopiowanie nie uruchamia go.

## Skąd AI Chat bierze informacje?

W trybie **Dokumentacja** aplikacja przeszukuje wbudowaną bazę wiedzy, zbudowaną z wybranych dokumentów projektu, przykładowych DAG-ów i skryptów. Jeśli skonfigurowano **AI Provider**, może użyć go do ułożenia odpowiedzi na podstawie znalezionych fragmentów. Ten tryb nie odczytuje danych runtime.

W trybie **Analiza runów** agent korzysta z ograniczonych narzędzi odczytowych: może znaleźć maksymalnie 10 najnowszych runów, sprawdzić konkretny run lub task, odczytać polecenie taska z niezmiennej definicji runu oraz — gdy jest to potrzebne — pobrać redagowaną końcówkę logu. Nie ma narzędzi do uruchamiania, edycji ani usuwania danych. Agent widzi tylko dane dostępne w bazie Cronovy i dostępnych plikach logów; może nie widzieć każdej zmiany w plikach projektu.

## Czy AI Provider jest potrzebny?

W trybie **Dokumentacja** provider jest opcjonalny: bez niego Cronova nadal przeszukuje bazę wiedzy i pokazuje znalezione fragmenty. W trybie **Analiza runów** do naturalnej rozmowy, wyszukiwania taska bez Run ID i pytań uzupełniających potrzebny jest AI Provider z modelem obsługującym tool/function calling. Bez providera pozostaje prostszy odczyt listy lub runu wskazanego pełnym Run ID.

Po skonfigurowaniu providera odpowiedzi mogą być układane przez model. To jednak nie gwarantuje, że model będzie dostępny ani że zawsze odpowie poprawnie. Przed ważną zmianą sprawdź podane źródło lub dokumentację.

## Jeśli odpowiedź nie pomaga

Spróbuj kolejno:

1. Zadaj krótsze i bardziej konkretne pytanie.
2. Dodaj nazwę funkcji, o którą pytasz, na przykład `DAG`, `task`, `retry` albo `harmonogram`.
3. Otwórz podane źródło i sprawdź, czy dotyczy Twojego pytania.
4. Jeśli pytasz o dane runtime, wybierz tryb **Analiza runów**. Możesz podać Run ID, nazwać task albo poprosić o listę; jeśli jest kilka pasujących runów, wskaż właściwy.
5. Jeśli AI Chat odpowie, że runu nie znaleziono, sprawdź identyfikator i upewnij się, że run nie został już usunięty przez retencję.
6. Jeśli ekran pokaże **Błąd połączenia z AI Chat**, sprawdź, czy jesteś zalogowany i czy konsola Cronova działa. Jeśli Analiza runów pokaże, że provider/model nie obsługuje tool/function calling, wybierz model zgodny z OpenAI-compatible tool calling.
7. Jeśli generowanie odpowiedzi przez AI się nie powiedzie, sprawdź wyświetlone dane/źródło runtime; sama awaria modelu nie oznacza, że odczyt stanu runu się nie udał.

## Czy rozmowa zostaje zapisana?

Na ekranie AI Chat nie ma funkcji trwałego zapisywania ani przeglądania historii rozmów. W tej samej otwartej stronie AI Chat zachowuje oddzielny, tymczasowy kontekst dla każdego trybu, aby pytania z Dokumentacji nie mieszały się z Analizą runów. W trybie Analiza kontekst pomaga agentowi odnaleźć wcześniejsze Run ID i taski; pełne logi nie są dopisywane do kolejnych pytań, a potrzebne dane agent pobiera ponownie przez narzędzia. Historia nie jest przechowywana na stałe. Jeśli odpowiedź jest ważna, skopiuj ją samodzielnie.

## Gotowe

Potrafisz już wybrać tryb AI Chat, znaleźć dokumentację, rozmawiać z agentem o runach i taskach, odszukać task bez powtarzania Run ID oraz poprosić o ograniczone fragmenty logów — wiedząc, że potrzebne dane runtime, polecenia i żądane logi mogą zostać wysłane do skonfigurowanego AI Provider.
