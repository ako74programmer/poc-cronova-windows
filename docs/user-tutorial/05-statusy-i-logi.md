# Tutorial Cronova — część 5: sprawdzamy uruchomienie i czytamy logi

W poprzedniej części dodaliśmy skrypt `powitanie.ps1` do planu `moj_pierwszy_plan`. Teraz sprawdzimy, czy Cronova go uruchomiła i co skrypt wypisał.

## Krok 1: uruchom plan

1. Otwórz `moj_pierwszy_plan`.
2. Poczekaj, aż przy planie będzie napis **Saved**.
3. Kliknij **▶ Trigger run**.
4. Otwórz zakładkę **Runs**.

Powinno pojawić się nowe uruchomienie. Każde kliknięcie **Trigger run** tworzy kolejne uruchomienie planu — czyli nową próbę wykonania całego DAG-a.

## Krok 2: wybierz uruchomienie

Kliknij najnowszy wiersz w zakładce **Runs**. Otworzy się strona tego uruchomienia.

Na górze zobaczysz stan całego planu i postęp, na przykład ile kroków z ilu już się zakończyło. Niżej jest graf pokazujący kroki z tego uruchomienia.

## Krok 3: zobacz, co stało się z taskami

Na liście **Task instances** znajdziesz osobny wiersz dla każdego taska:

- `krok_1`
- `krok_2`
- `krok_3`
- `skrypt_z_pliku`

Obok każdego taska pojawi się jego stan. Najczęściej spotkasz:

- `queued` — czeka na swoją kolej;
- `running` — jest wykonywany;
- `success` — zakończył się poprawnie;
- `failed` — zakończył się błędem;
- `retrying` — Cronova ponawia próbę;
- `upstream failed` — task nie ruszył, bo wcześniejszy wymagany task zakończył się błędem;
- `cancelled` — uruchomienie zostało anulowane;
- `timed out` — przekroczono ustawiony limit czasu.

Jeśli wszystko działa, taski po kolei osiągną stan `success`.

## Krok 4: otwórz log skryptu

1. Znajdź wiersz `skrypt_z_pliku`.
2. Kliknij **logs** przy tym wierszu.
3. Odczytaj tekst w panelu logów.

Powinieneś zobaczyć zdania zapisane w `powitanie.ps1`, na przykład:

```text
Czesc! To jest moj pierwszy skrypt.
Cronova uruchomila ten plik.
```

**Log** to zapis tego, co task wypisał podczas działania, oraz komunikatów o błędach. Jeśli task trwa, nowe linie mogą pojawiać się na bieżąco. Możesz wybrać inny task, żeby zobaczyć jego log.

## Jak rozpoznać, gdzie pojawił się problem?

- Jeśli `krok_1` ma `failed`, problem zaczął się już na pierwszym kroku.
- Jeśli `krok_1` działał poprawnie, ale `krok_2` ma `upstream failed`, sprawdź zależność — `krok_2` czeka na powodzenie `krok_1`.
- Jeśli wcześniejsze kroki mają `success`, a `skrypt_z_pliku` ma `failed`, wybierz log właśnie tego taska. Sprawdź, czy project `pierwszy_skrypt` jest przypisany i czy nazwa pliku w komendzie zgadza się z `powitanie.ps1`.
- Jeśli widzisz `queued`, task jeszcze czeka. Przy połączeniu **Depends on** musi zaczekać na poprzedni krok.

## Run a task — ważna różnica

- **Run** (uruchomienie) to jedna próba wykonania całego DAG-a.
- **Task instance** to konkretny task podczas tej jednej próby.
- **Log** pokazuje, co wydarzyło się podczas wykonywania tego taska.

Możesz więc mieć wiele uruchomień tego samego planu. Każde ma własny wynik i logi.

## Na razie nie klikaj przycisków naprawczych

Na stronie możesz zobaczyć przyciski **Cancel run**, **Retry** albo **Mark**. Na razie ich nie używaj:

- **Cancel run** przerywa aktywne uruchomienie.
- **Retry** uruchamia ponownie nieudany task i kroki, które od niego zależą.
- **Mark** ręcznie zmienia zapisany stan — nie naprawia przyczyny błędu.

Najpierw otwórz log i przeczytaj komunikat. Ponowienie może jeszcze raz wykonać polecenia taska.

## Jeśli nie widzisz logu

1. Upewnij się, że otworzyłeś najnowsze uruchomienie.
2. Wybierz wiersz właściwego taska, na przykład `skrypt_z_pliku`.
3. Kliknij **logs**.
4. Jeśli task nadal działa, poczekaj chwilę na kolejne linie.

## Gotowe

Wiesz już, jak sprawdzić stan całego uruchomienia, stan poszczególnych kroków i tekst zapisany w ich logach. Kolejna część pokaże, jak ostrożnie diagnozować i naprawiać prosty błąd w tasku.
