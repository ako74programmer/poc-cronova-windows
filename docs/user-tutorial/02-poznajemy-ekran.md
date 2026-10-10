# Tutorial Cronova — część 2: poznajemy ekran

Po zalogowaniu zobaczysz główny ekran Cronovy. Jeśli interfejs jest po angielsku, możesz przełączyć go na polski przyciskiem **EN / PL** u góry.

Na razie tylko rozejrzyj się po ekranie. Nie musisz niczego zmieniać ani uruchamiać.

## Najpierw: co znaczy „DAG”?

**DAG** to plan zadań ułożonych w odpowiedniej kolejności. Wyobraź sobie przygotowanie kanapki:

1. Wyjmij chleb.
2. Posmaruj go masłem.
3. Połóż ser.

Krok 2 nie powinien zacząć się przed krokiem 1, a krok 3 — przed krokiem 2. Cronova potrafi zapisać taki plan i pamiętać, które kroki zależą od innych.

W Cronovie jeden DAG to **jeden taki plan**. Pojedynczy krok planu nazywa się **taskiem** (po polsku: zadaniem). Na razie zapamiętaj tylko tę różnicę:

- **DAG** — cały plan;
- **task** — jeden krok w planie;
- **run** — jedno wykonanie całego planu.

## 1. Menu po lewej stronie

### DAGs — lista planów

To główna lista planów Cronovy. Każdy wiersz oznacza jeden DAG. Klikając jego nazwę, przejdziesz do szczegółów planu.

**Przykład:** możesz mieć DAG `poranna_kawa`, w którym są taski `zagotuj_wode`, `zaparz_kawe` i `podaj`. W menu **DAGs** znajdziesz cały plan `poranna_kawa`.

Jeśli lista jest pusta, to znaczy, że nie dodano jeszcze żadnego DAG-a. To normalne po świeżej instalacji.

### Graph — mapa zależności między planami

**Graph** pokazuje połączenia między całymi DAG-ami. Nie jest to to samo co plan zadań wewnątrz jednego DAG-a.

**Przykład:** najpierw działa plan `pobierz_zamowienia`, a dopiero po jego sukcesie ma zacząć się plan `wyslij_raport`. W **Graph** można zobaczyć strzałkę między tymi dwoma planami.

Jeśli żadne plany nie są od siebie zależne, widok Graph może być pusty. To nie znaczy, że Cronova jest zepsuta — po prostu nie ma połączeń do pokazania.

### Pools — limity dla jednoczesnej pracy

**Pool** (pula) to limit mówiący, ile zadań może korzystać z danego rodzaju zasobu w tym samym czasie. To jak ograniczona liczba stanowisk przy stole: jeśli są dwa stanowiska, najwyżej dwie osoby mogą pracować przy tym stole jednocześnie.

**Przykład:** trzy taski pobierają dane z jednego powolnego serwera. Przypisujesz je do puli `serwer_danych`, która ma dwa miejsca. Cronova pozwoli działać dwóm taskom naraz; trzeci poczeka na wolne miejsce.

Pool **nie** tworzy nowego komputera ani serwera. To tylko licznik ograniczający równoczesne uruchomienia zadań przypisanych do tej puli. Wartość limitu można sprawdzić lub zmienić w tym widoku.

### Variables & Connections — zapisane wartości i połączenia

Ta pozycja menu łączy dwie różne rzeczy:

- **Variables** to nazwane wartości, które można wykorzystać w wielu zadaniach. Przykład: zmienna `KOLOR` ma wartość `niebieski`; zadanie może wstawić tę wartość zamiast wpisywać ją osobno w kilku miejscach.
- **Connections** to zapisane informacje potrzebne do połączenia z inną usługą, na przykład adresem serwera bazy danych i danymi dostępowymi.

**Przykład:** jeżeli kilka zadań używa adresu tej samej usługi, można trzymać go w jednym miejscu i odwoływać się do niego z zadań. Gdy adres się zmieni, poprawiasz go raz, a nie w każdym zadaniu.

Connections mogą zawierać hasła. Nie wpisuj prawdziwych haseł do publicznego pliku DAG ani do logów. Dostępne szyfrowanie haseł zależy od konfiguracji administratora.

### Workers — dodatkowe komputery do wykonywania zadań

**Worker** (pracownik) to dodatkowy komputer skonfigurowany do wykonywania przydzielonych mu zadań.

**Przykład:** główny komputer Cronovy planuje pracę, a drugi komputer ma zainstalowane specjalne narzędzie potrzebne do jednego taska. Po odpowiedniej konfiguracji Cronova może skierować ten task do workera.

To funkcja dodatkowa. Jeśli nikt jej nie skonfigurował, nie musisz niczego robić w tym miejscu. Samo otwarcie strony Workers nie podłącza nowego komputera.

### Audit — historia ważnych działań

**Audit** to dziennik zapisanych operacji, na przykład zmian w konfiguracji lub ręcznych działań na DAG-ach. Pomaga sprawdzić, co się wydarzyło.

**Przykład:** jeśli ktoś zmienił ustawienie planu i później zachowuje się on inaczej, wpis w Audit może pomóc ustalić, że dokonano zmiany.

Audit nie jest listą zwykłych kroków taska. Wyniki i szczegółowe logi wykonań sprawdza się w widoku uruchomienia.

### API — dostęp dla innych programów

**API** to sposób, w jaki inny program może poprosić Cronovę o informacje lub działanie — podobnie jak użytkownik klika przycisk w konsoli.

W tym widoku można między innymi zarządzać **API tokens** (kluczami dostępu) i otworzyć opis dostępnych zapytań. Token działa jak sekret pozwalający programowi rozpoznać się w Cronovie.

**Przykład:** administrator może utworzyć token dla programu, który ma odczytywać status planów. Nie udostępniaj tokenu innym osobom i nie wklejaj go do publicznych miejsc. Jeśli nie korzystasz z integracji, nie musisz niczego zmieniać w API.

## 2. Górny pasek

- **Wyszukiwarka DAG-ów** pomaga znaleźć plan po fragmencie jego nazwy. Możesz użyć jej także wtedy, gdy jesteś w innym widoku.
- **EN / PL** przełącza język interfejsu.
- **Motyw jasny/ciemny** zmienia wygląd strony.
- **+ New DAG** rozpoczyna tworzenie nowego planu. Na razie nie klikaj — do tworzenia przejdziemy w kolejnej części.
- W niektórych widokach zobaczysz też **Saved** lub **Saving…**. Oznaczają, czy zmiana została już zapisana.

## 3. Główna strona DAGs

Na stronie **DAGs** możesz zobaczyć podsumowania, listę planów i ostatnie uruchomienia.

- **Active DAGs** — plany, które nie są wstrzymane.
- **Running runs** — plany aktualnie wykonywane.
- **Recent success** — informacja o powodzeniu ostatnich wykonań.
- **Failed DAGs** — plany, których ostatnie wykonanie zakończyło się błędem lub przekroczyło czas.

W tabeli kliknij nazwę planu, aby otworzyć szczegóły. Ikona **▶** oznacza ręczne uruchomienie — później nauczymy się, kiedy bezpiecznie jej używać.

## 4. Dwie ważne różnice

### Graph a plan tasków

- **Graph w menu bocznym** pokazuje relacje między całymi DAG-ami.
- **Structure** na stronie jednego DAG-a pokazuje taski i ich kolejność wewnątrz tego planu.

Możesz myśleć o tym jak o mapie miasta i planie jednego domu: obie rzeczy pokazują połączenia, ale na innym poziomie.

### Variables a Connections

- **Variable** przechowuje pojedynczą wartość, np. nazwę środowiska `test`.
- **Connection** przechowuje informacje potrzebne do połączenia z usługą, np. host i dane dostępowe.

Nie musisz teraz niczego tworzyć. Wrócimy do tego na przykładzie, gdy będziemy budować pierwszy DAG.

## Gotowe

Wiesz już, że DAG to cały plan, task to krok, a run to jedno wykonanie planu. Znasz też przeznaczenie pozycji menu i wiesz, że **Graph**, **Pools** i **Variables & Connections** rozwiązują różne problemy.

**Następna część tutorialu** wyjaśni na prostym przykładzie, jak wygląda DAG złożony z kilku tasków i jak te taski łączą się zależnościami.
