# Tutorial Cronova — część 6: znaleźliśmy błąd i poprawiamy go

Czasem task nie kończy się powodzeniem. To nie znaczy, że cała Cronova przestała działać. Zobaczymy, jak znaleźć przyczynę i spróbować jeszcze raz.

W tym przykładzie skrypt tylko wypisuje tekst, więc bezpiecznie pokażemy mały błąd w jego nazwie.

> Jeśli testujesz prawdziwy, ważny plan, nie zmieniaj działającego taska tylko po to, by wywołać błąd. W ćwiczeniu używamy naszego przykładowego planu.

## Krok 1: na chwilę wpisz złą nazwę pliku

1. Otwórz DAG `moj_pierwszy_plan`.
2. Wybierz task `skrypt_z_pliku`.
3. W polu **Command** zmień nazwę wiersza na:

   ```powershell
   & .\powitanie_brak.ps1
   ```

   To celowo błędna nazwa — takiego pliku nie dodaliśmy do project.

4. Poczekaj, aż pojawi się **Saved**.
5. Uruchom plan przyciskiem **▶ Trigger run**.

## Krok 2: znajdź błąd w logu

1. Otwórz nowe uruchomienie w zakładce **Runs**.
2. Znajdź task `skrypt_z_pliku`.
3. Otwórz jego log.

Task powinien mieć stan `failed`. W logu zobaczysz komunikat, że PowerShell nie może znaleźć pliku `powitanie_brak.ps1`.

To wskazówka: Cronova próbowała uruchomić plik o nazwie z pola **Command**, ale takiego pliku nie było w project.

## Krok 3: popraw nazwę

1. Wróć do edycji taska `skrypt_z_pliku`.
2. W polu **Command** wpisz prawidłową nazwę:

   ```powershell
   & .\powitanie.ps1
   ```

3. Poczekaj na **Saved**.

## Krok 4: uruchom poprawiony plan

Kliknij ponownie **▶ Trigger run**. Otwórz **najnowsze** uruchomienie i sprawdź task `skrypt_z_pliku`.

Jeśli nazwa się zgadza, task powinien zakończyć się stanem `success`, a log powinien zawierać zdania ze skryptu.

Poprzednie uruchomienie nadal będzie miało stan `failed`. To historia tego, co wydarzyło się wcześniej — poprawka nie zmienia wstecz starego wyniku.

## Co oznaczają te trzy stany?

- `failed` — task próbował działać, ale napotkał błąd.
- `upstream failed` — task nie wystartował, bo nie powiódł się wcześniejszy task, na który czekał.
- `success` — task zakończył się poprawnie.

Jeśli task ma `upstream failed`, zacznij sprawdzanie od wcześniejszego kroku z błędem. Późniejsze kroki mogły wcale nie zostać uruchomione.

## Naprawa a ponowienie — to nie to samo

Najpierw przeczytaj log i popraw przyczynę błędu. Dopiero potem uruchom plan jeszcze raz.

Przycisk **Retry** może ponownie wykonać nie tylko wybrany task, ale też zależne od niego dalsze taski. Jeśli te taski wykonują prawdziwe działania — na przykład wysyłają wiadomości albo zmieniają dane — ponowne wykonanie może powtórzyć te działania.

Dlatego w tym ćwiczeniu poprawiliśmy task, a potem uruchomiliśmy **nowy run** przyciskiem **▶ Trigger run**.

## Prosta kolejność sprawdzania problemu

Gdy coś nie działa:

1. Zobacz, który task ma stan `failed`.
2. Otwórz log właśnie tego taska.
3. Przeczytaj ostatni komunikat — często podpowiada, czego nie znaleziono albo co się nie udało.
4. Popraw polecenie, nazwę pliku lub ustawienie wskazane w komunikacie.
5. Poczekaj na **Saved**.
6. Uruchom nowy run i sprawdź jego wynik.

## Gotowe

Wiesz już, jak znaleźć i poprawić prosty błąd. Następna część pokaże, jak podać wartość do planu przy uruchamianiu, na przykładzie dnia, który ma przetworzyć.
