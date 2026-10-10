# Tutorial Cronova — część 3: zbudujmy pierwszy prosty plan

W tej części utworzymy plan z trzema bezpiecznymi krokami. Każdy krok wyświetli tylko krótki tekst — niczego nie pobierze ani nie zmieni na komputerze.

## Nasz plan

Wyobraź sobie, że układamy trzy karteczki w kolejności:

1. „Zaczynam”.
2. „Wykonuję środkowy krok”.
3. „Kończę”.

W Cronovie cały taki plan nazywa się **DAG**. Każda karteczka to **task**. Połączenie między karteczkami mówi Cronovie: „poczekaj z następnym krokiem, aż poprzedni się skończy”.

Nasz plan będzie wyglądał tak:

```text
krok_1 → krok_2 → krok_3
```

## Krok 1: utwórz pusty plan

1. Na stronie **DAGs** kliknij **+ New DAG**.
2. Wybierz szablon **Blank** (pusty plan).
3. W polu **DAG ID** wpisz:

   ```text
   moj_pierwszy_plan
   ```

   To identyfikator planu. Używamy prostej nazwy z literami, cyframi i podkreśleniem.

4. Zostaw harmonogram w trybie **Manual**. To znaczy, że plan uruchomimy sami przyciskiem — nie będzie startował o określonej godzinie.
5. Kliknij **Create**.

Otworzy się strona nowego planu. Jest pusty, więc najpierw dodamy do niego kroki.

## Krok 2: dodaj pierwszy task

1. Otwórz zakładkę **Structure**.
2. Kliknij **+ Add task**.
3. W edytorze taska w polu **Task ID** wpisz:

   ```text
   krok_1
   ```

4. W polu **Type** wybierz `powershell`.
5. W polu **Command** wpisz:

   ```powershell
   Write-Output "Krok 1: zaczynam"
   ```

Ta komenda każe komputerowi wypisać zdanie w logu. Nie zmienia plików ani ustawień — używamy jej tylko do nauki.

Wróć do planu przyciskiem **← back**. Poczekaj, aż przy nazwie planu pojawi się **Saved**. To znaczy, że zmiana została zapisana.

## Krok 3: dodaj drugi i trzeci task

Dodaj drugi task przyciskiem **+ Add task** i ustaw:

- **Task ID:** `krok_2`
- **Type:** `powershell`
- **Command:**

  ```powershell
  Write-Output "Krok 2: wykonuję środkowy krok"
  ```

W polu **Depends on** wybierz `krok_1`. To znaczy: „krok 2 ma poczekać na krok 1”. Wróć do planu i zaczekaj na **Saved**.

Dodaj trzeci task i ustaw:

- **Task ID:** `krok_3`
- **Type:** `powershell`
- **Command:**

  ```powershell
  Write-Output "Krok 3: kończę"
  ```

W polu **Depends on** wybierz `krok_2`.

Poczekaj, aż Cronova pokaże **Saved**. W zakładce **Structure** połączenia powinny tworzyć łańcuch:

```text
krok_1 → krok_2 → krok_3
```

Czyli: krok 2 czeka na krok 1, a krok 3 czeka na krok 2.

## Krok 4: uruchom plan

1. Wróć na stronę planu.
2. Kliknij **▶ Trigger run**.
3. Otwórz zakładkę **Runs**. Powinno pojawić się nowe uruchomienie.
4. Kliknij uruchomienie, a potem sprawdź poszczególne taski i ich logi.

Taski mogą najpierw mieć stan `queued` (czekają) albo `running` (działają). Jeśli wszystko pójdzie dobrze, powinny zakończyć się stanem `success` (sukces). W logach zobaczysz tekst wpisany w każdej komendzie.

## Ważne różnice

- **Saved** oznacza, że plan zapisano. Nie oznacza, że plan został uruchomiony.
- **Trigger run** uruchamia plan teraz — niezależnie od tego, że harmonogram jest ustawiony na **Manual**.
- **Depends on** ustala kolejność kroków. Bez tych połączeń Cronova nie wie, że krok 2 ma czekać na krok 1.
- Tutaj wpisaliśmy krótkie komendy bezpośrednio w edytorze. W kolejnej części wyjaśnimy prostymi słowami, czym jest skrypt i czym różni się od pojedynczej komendy.

## Jeśli coś nie zadziała

- **Nie widzisz przycisku uruchomienia?** Sprawdź, czy dodano taski i czy masz uprawnienia do edycji.
- **Widzisz `Fix errors to save`?** Cronova wykryła błąd. Sprawdź, czy każdy task ma nazwę i komendę.
- **Task ma stan `failed`?** Otwórz jego log i przeczytaj komunikat. Sprawdź, czy typ taska to `powershell` i czy komenda została wpisana dokładnie.
- **Nie widzisz `Saved`?** Poczekaj chwilę i sprawdź, czy nie pojawił się komunikat o błędzie zapisu.

## Gotowe

Utworzyłeś plan z trzema krokami i zobaczyłeś, gdzie sprawdzić wynik każdego z nich. Kolejna część wyjaśni, czym jest skrypt i jak można użyć go jako zadania w Cronovie.
