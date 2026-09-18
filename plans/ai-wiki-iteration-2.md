# Plan iteracji 2: AI wiki — lepszy retrieval, LLM i więcej akcji

## Cel
Usprawnić AI wiki chat w cronova: lepsze wyszukiwanie odpowiedzi, generowanie odpowiedzi przez skonfigurowanego LLM, więcej akcji testowych i wsparcie dla języka angielskiego.

## Decyzje do podjęcia

### 1. Retrieval — jaką technologię wybrać?

| Opcja | Technologia | Zalety | Wady | Rekomendacja |
|-------|-------------|--------|------|--------------|
| **A** | **sqlite-vec** (rozszerzenie SQLite do wektorów) | Pasuje do istniejącej SQLite w cronova; jeden plik; lokalne; dobre dla jednego exe | Wymaga rozszerzenia SQLite (może być trudne na Windows z pure-Go sqlite) | **Najlepsza dla cronova** |
| **B** | Lokalne embeddingi + flat index w Go (ONNX) | Brak nowej bazy danych | Duży model, złożoność, pamięć, wolne ładowanie | Odradzana na ten etap |
| **C** | Zewnętrzna baza wektorowa (Chroma, Qdrant, Pinecone) | Szybka implementacja, dobre wyniki | Zależność od usługi zewnętrznej — narusza filozofię „jeden exe, zero deps" | Tylko jako opcjonalny provider |
| **D** | Lepszy keyword scoring (BM25/TF-IDF) | Zero nowych zależności; działa offline; proste | Mniej semantyczne niż embeddingi | **Dobra alternatywa, jeśli A okaże się zbyt trudne** |

**Rekomendacja:** Rozpocząć od **opcji D (BM25)**, bo jest szybka i nie wymaga nowych zależności. Jeśli wyniki będą niewystarczające — przejść do **opcji A (sqlite-vec)**.

### 2. LLM — czy generować odpowiedzi przez AI providera?

Tak, ale jako **opcjonalna funkcja**. Domyślnie chat działa offline (RAG + szablony). Jeśli użytkownik skonfiguruje AI providera (`/api/ai-providers`), odpowiedzi są generowane przez LLM z kontekstem z retrieval.

### 3. Akcje testowe — co dodać?

- `show_logs` — otwiera logi ostatniego runu DAG-a.
- `copy_command` — kopiuje komendę CLI do schowka (np. `cronova trigger <dag_id>`).
- `open_dag_runs` — przechodzi do historii runów DAG-a.
- `open_docs` — otwiera dokumentację w nowej karcie.

### 4. Lokalizacja

- Domyślnie język zgodny z UI cronova (pl/en).
- Baza wiedzy pozostaje w języku źródłowym docs; odpowiedzi są tłumaczone przez szablony lub LLM.

## Zadania wykonywalne

### Zadanie 1: Zaimplementować BM25 retrieval
- Dodać prosty BM25 do `internal/aiwiki/`.
- Zamienić obecny keyword scoring na BM25.
- **Weryfikacja:** dla zapytania „retry timeout task" top-3 wyniki są trafniejsze niż obecnie.

### Zadanie 2: Dodać opcjonalne generowanie odpowiedzi przez LLM
- W `internal/aiwiki/` dodać strukturę `LLMClient`, który czyta domyślnego AI providera ze store.
- Jeśli provider skonfigurowany — wywołać `/v1/chat/completions` z promptem RAG.
- Jeśli nie — użyć obecnych szablonów.
- **Weryfikacja:** po skonfigurowaniu providera odpowiedź jest generowana przez LLM i zawiera źródła.

### Zadanie 3: Rozszerzyć akcje testowe
- Dodać `show_logs`, `copy_command`, `open_dag_runs`, `open_docs`.
- Zaimplementować obsługę w `aiwiki.js`.
- **Weryfikacja:** każda akcja działa w przeglądarce.

### Zadanie 4: Dodać lokalizację chatu
- Przygotować słowniki `pl` i `en` dla UI chatu.
- Używać języka z `localStorage` lub z API `/api/info`.
- **Weryfikacja:** UI chatu zmienia język po przełączeniu języka w konsoli.

### Zadanie 5: Test end-to-end iteracji 2
- Użytkownik pyta po angielsku „How do I set retry?" → dostaje odpowiedź w języku angielskim.
- Kliknie „Show logs" lub „Trigger DAG" → akcja działa.
- **Weryfikacja:** wszystkie scenariusze przechodzą w przeglądarce.

## Kryteria ukończenia

1. Każde zadanie ma test terminalowy lub w przeglądarce.
2. `go test ./internal/aiwiki/... ./internal/api/...` przechodzi.
3. Pełny scenariusz E2E działa w przeglądarce.

## Postęp

| # | Zadanie | Status | Uwagi |
|---|---------|--------|-------|
| 1 | BM25 retrieval | ✅ done | Zaimplementowano BM25 w internal/aiwiki/bm25.go, testy przechodzą, endpoint działa. |
| 2 | LLM integration | ✅ done | Odpowiedzi generowane przez skonfigurowanego AI providera; fallback do szablonów offline. |
| 3 | Więcej akcji | ✅ done | Dodano 4 nowe akcje; drobna poprawka routingów do zrobienia przy okazji. |
| 4 | Lokalizacja | ✅ done | Słowniki pl/en w base.js; aiwiki.js używa t() i reaguje na cronova:langchanged. |
| 5 | Test E2E | 🔄 in progress | |
