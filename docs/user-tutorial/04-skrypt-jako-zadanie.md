# Tutorial Cronova — część 4: czym jest skrypt?

W poprzedniej części zbudowaliśmy plan z trzema krokami. Teraz dodamy do niego skrypt — czyli plik, w którym zapisano kilka poleceń.

Wyobraź sobie przepis: **skrypt jest zapisanym przepisem**, a **task mówi Cronovie, kiedy go użyć**.

W tym przykładzie skrypt tylko wypisze zdania w logu. Nie zmienia plików ani ustawień komputera.

## Krok 1: dodaj nowy task do planu

1. Otwórz DAG `moj_pierwszy_plan`.
2. Wejdź w zakładkę **Structure**.
3. Kliknij **+ Add task**.
4. Ustaw nazwę taska na `skrypt_z_pliku`.
5. Wybierz typ `powershell`.

Nie wpisuj jeszcze niczego w **Command**. Najpierw utworzymy skrypt, który ta komenda będzie uruchamiać.

## Krok 2: utwórz plik skryptu

1. W edytorze taska znajdź sekcję **Project**.
2. Otwórz **Upload / new project**.
3. Wybierz **Write a script**.
4. Jako nazwę pliku wpisz:

   ```text
   powitanie.ps1
   ```

5. W polu treści skryptu wpisz:

   ```powershell
   Write-Output "Czesc! To jest moj pierwszy skrypt."
   Write-Output "Cronova uruchomila ten plik."
   ```

6. Wpisz nazwę projektu, na przykład:

   ```text
   pierwszy_skrypt
   ```

7. Kliknij **Upload**.

**Project** to nazwana paczka z plikiem lub plikami, których task potrzebuje. Po przesłaniu Cronova powinna przypisać projekt do tego taska.

## Krok 3: powiedz taskowi, żeby uruchomił skrypt

W polu **Command** wpisz:

```powershell
& .\powitanie.ps1
```

To polecenie oznacza: „uruchom plik `powitanie.ps1` znajdujący się w projekcie”.

Jeśli chcesz, aby skrypt działał dopiero po trzech krokach z poprzedniej części, w **Depends on** wybierz `krok_3`. Wtedy kolejność będzie taka:

```text
krok_1 → krok_2 → krok_3 → skrypt_z_pliku
```

Wróć do planu i poczekaj, aż pojawi się **Saved**.

## Krok 4: uruchom plan i zobacz, co wypisał skrypt

1. Wróć do strony DAG-a.
2. Kliknij **▶ Trigger run**.
3. Otwórz nowe uruchomienie w zakładce **Runs**.
4. Wybierz task `skrypt_z_pliku`.
5. Otwórz jego log.

Powinny się tam pojawić dwa zdania zapisane w skrypcie. Log to miejsce, w którym Cronova pokazuje tekst wypisany przez task.

## Skrypt a task — czym się różnią?

- **Skrypt** to plik z zapisanymi poleceniami: tutaj `powitanie.ps1`.
- **Command** w tasku to polecenie, które mówi Cronovie, żeby uruchomiła ten plik.
- **Task** to krok w planie, który może uruchomić skrypt.
- **DAG** to cały plan, w którym znajdują się taski.

Możesz też wpisać krótką komendę bezpośrednio w **Command**, bez osobnego pliku. Osobny skrypt przydaje się, gdy poleceń jest więcej albo chcesz zachować je w czytelnym pliku.

## Ważne: project jest kopią roboczą

Przed każdym uruchomieniem Cronova przygotowuje świeżą kopię plików projektu dla taska. Ta kopia jest tymczasowa i znika po zakończeniu próby. W naszym przykładzie to nie przeszkadza, bo skrypt tylko wypisuje tekst.

Jeśli skrypt zapisuje wyniki, nie zakładaj, że zostaną w tej tymczasowej kopii. W tym tutorialu niczego jeszcze nie zapisujemy.

## Jeśli coś nie zadziała

- **Task kończy się błędem „plik nie znaleziony”?** Sprawdź, czy projekt `pierwszy_skrypt` został przesłany i przypisany do taska oraz czy nazwa pliku to dokładnie `powitanie.ps1`.
- **Nie widzisz tekstu w logu?** Otwórz log taska `skrypt_z_pliku`, a nie log innego kroku.
- **Zmiana nie jest zapisana?** Poczekaj na **Saved** przed uruchomieniem.
- **Task jest `queued`?** Czeka na swoją kolej. Przy ustawionej zależności musi najpierw zakończyć się `krok_3`.

## Gotowe

Wiesz już, jak task może uruchomić skrypt zapisany jako plik projektu. Następna część pokaże, jak sprawdzać statusy uruchomienia i czytać logi.
