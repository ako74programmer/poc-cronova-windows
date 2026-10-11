# Tutorial Cronova — część 7: ustawiamy AI Provider

**AI Provider** to ustawienie, które mówi Cronovie, z jakiej usługi AI może korzystać. Można to porównać do podania adresu usługi i informacji, z którego modelu ma skorzystać Cronova.

Samo skonfigurowanie providera **nie uruchamia żadnego zadania**.

## Zanim zaczniesz

Potrzebujesz danych od dostawcy usługi AI albo administratora, który skonfigurował lokalny serwer AI:

- adresu zgodnego z **OpenAI-compatible Chat Completions API**;
- dokładnej nazwy modelu dostępnego pod tym adresem;
- API Token.

Nie zgaduj tych wartości. Różne usługi mogą wymagać różnych adresów i nazw modeli. W polu **Base URL** podaj bazowy adres OpenAI-compatible API, zwykle kończący się na `/v1`, np. `http://127.0.0.1:4141/v1`. Cronova dopisuje `/chat/completions` podczas wysyłania zapytania. Jeśli dostawca podał pełny adres endpointu, można wpisać go bez zmian.

Formularz **wymaga API Token nawet przy tworzeniu lokalnego providera**. Jeśli Twój lokalny serwer nie używa tokenów, ekran może nie pozwolić zapisać ustawienia. Nie wymyślaj sekretu — skonsultuj tę sytuację z administratorem.

Nie wklejaj prawdziwego tokena do czatu, dokumentu ani publicznego pliku.

## Krok 1: otwórz AI Provider

1. W konsoli Cronovy znajdź menu po lewej stronie.
2. Kliknij **AI Provider**.
3. Jeśli lista jest pusta, to znaczy, że provider nie został jeszcze dodany.

Ta strona pokazuje zapisane konfiguracje, ale ukrywa sam token.

## Krok 2: otwórz formularz

Kliknij **Nowy provider**. Zobaczysz pola:

- **ID** — krótka nazwa techniczna, np. `default`. Dozwolone są litery, cyfry, kropka, myślnik i podkreślenie.
- **Nazwa wyświetlana** — czytelna nazwa, np. `Moja usługa AI`. To pole jest opcjonalne.
- **Base URL** — dokładny adres endpointu API podany przez dostawcę.
- **Model** — dokładna nazwa modelu, do którego masz dostęp.
- **API Token** — sekret dostępu od dostawcy. Formularz ukrywa wpisywane znaki.
- **Ustaw jako domyślny** — określa, czy Cronova ma traktować tę konfigurację jako domyślną.

## Krok 3: wpisz dane

1. W polu **ID** możesz zostawić `default`.
2. Wpisz własną, rozpoznawalną nazwę w **Nazwa wyświetlana**, np. `Moja usługa AI`.
3. Wklej adres API otrzymany od dostawcy w **Base URL**.
4. Wpisz dokładną nazwę modelu w **Model**.
5. Wklej token w **API Token**.
6. Zaznacz **Ustaw jako domyślny**, jeśli ta konfiguracja ma być domyślna.

**Przykład formatu — to nie jest prawdziwy adres ani działające dane:**

```text
ID:             default
Nazwa:          Moja usługa AI
Base URL:       https://adres-od-dostawcy.example/...
Model:          nazwa-modelu-od-dostawcy
API Token:      [własny token — nie wklejaj go do dokumentacji]
```

Zastąp przykładowe wartości danymi otrzymanymi od swojego dostawcy. Nie kopiuj adresu z przykładu.

## Krok 4: zapisz ustawienie

Kliknij **Zapisz provider**.

Jeśli formularz zgłosi błąd, sprawdź, czy:

- **ID** nie jest puste i zawiera tylko dozwolone znaki;
- podano **Base URL** i **Model**;
- wpisano **API Token**;
- adres zaczyna się od `http://` lub `https://`.

## Krok 5: sprawdź, co oznacza zapis

Po zapisaniu provider pojawi się na liście. Zobaczysz jego ID, nazwę, adres, model i informację, czy token został zapisany. **Samego tokena nie da się potem odczytać z listy.**

W formularzu nie ma przycisku **Test connection**. Zapisanie konfiguracji oznacza, że Cronova ją przyjęła — **nie potwierdza**, że adres, token i model zadziałają podczas prawdziwego zapytania. Sprawdzimy to w kolejnej części, używając AI Wiki.

## Jeśli edytujesz istniejący provider

Pole tokena przy edycji może być puste. Jeśli token był już zapisany i chcesz go zachować, zostaw to pole puste. Wpisanie nowego tokena zastąpi poprzedni.

Nie usuwaj konfiguracji, jeśli nie masz pewności, czy korzysta z niej AI Wiki albo automatyzacja SDLC.

## Co z tego korzysta?

AI Wiki używa domyślnego providera. Jeśli nie ma providera ustawionego jako domyślny, kod wybiera pierwszy dostępny. Niektóre skrypty SDLC mogą wskazywać provider osobno. To, że provider pojawił się na liście, nie oznacza jeszcze, że każde zadanie Cronovy będzie korzystać z AI.

## Gotowe

Wiesz już, jakie informacje są potrzebne i gdzie ustawić AI Provider. Następna część pokaże, jak zadać pytanie w **AI Wiki**, jak czytać podane źródła i co zrobić, gdy odpowiedź nie pasuje.
