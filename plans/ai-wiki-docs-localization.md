# Plan: PL/EN documentation localization for AI wiki

## Goal
Make the AI wiki documentation links open in the user's UI language (Polish or English). Remove Chinese (`.zh.md`) documentation versions.

## Decisions

### 1. File naming convention
- English = default file, e.g. `docs/DAG_REFERENCE.md`
- Polish = `.pl.md` suffix, e.g. `docs/DAG_REFERENCE.pl.md`
- Chinese `.zh.md` files will be removed.

### 2. Language detection
The `/doc/{path}` endpoint will detect language from (in order):
1. Query parameter `?lang=pl|en`
2. Cookie `cnv_lang` (set by the console when switching language)
3. `Accept-Language` header
4. Default to English

### 3. Fallback behavior
If a Polish translation does not exist, serve the English version. Never return 404 when the English file exists.

### 4. AI wiki integration
- The knowledge base remains in English for now (chunks are small and LLM translates answers well).
- The `open_docs` action will include the current UI language so the backend can serve the right file.
- Frontend passes `lang` when calling `/api/ask` and when opening docs.

### 5. Scope of translations (MVP)
Translate the most-asked-about docs first:
- `docs/DAG_REFERENCE.md` → `docs/DAG_REFERENCE.pl.md`
- `docs/GETTING_STARTED.md` → `docs/GETTING_STARTED.pl.md`
- `docs/FAQ.md` → `docs/FAQ.pl.md`
- `docs/tutorial/first-dag.md` → `docs/tutorial/first-dag.pl.md`
- `docs/tutorial/retries-timeouts-pools.md` → `docs/tutorial/retries-timeouts-pools.pl.md`

Other docs fall back to English until translated.

## Tasks

### Task 1: Remove Chinese docs
- Delete all `*.zh.md` files in `docs/`, `docs/console/`, `docs/tutorial/`.
- Remove any links to `.zh.md` files from English/Polish docs.
- Update `mkdocs.yml` if it references Chinese files.

### Task 2: Add language-aware `/doc/{path}` endpoint
- Modify `internal/api/server.go` `docFile` handler to detect language and serve `.pl.md` or `.md`.
- Add helper `resolveDocPath(path, lang) string`.

### Task 3: Translate key docs to Polish
- Create `.pl.md` versions for the 5 MVP docs.
- Keep YAML examples and CLI commands unchanged (they are language-independent).

### Task 4: Update AI wiki to pass language
- Frontend: send `lang` in `/api/ask` request body.
- Backend: store current language in `Answer` or `Action`.
- `open_docs` action path should include `?lang=pl` or `?lang=en`.

### Task 5: Rebuild embedded docs
- Copy updated `docs/` into `internal/docs/docs/` (current build-time workaround).
- Rebuild `cronova.exe`.

### Task 6: Test E2E
- Ask in Polish → click „Otwórz dokumentację" → verify `/doc/DAG_REFERENCE.pl.md` opens.
- Switch to English → ask → click „Open documentation" → verify `/doc/DAG_REFERENCE.md` opens.

### Task 7: Commit and push
- Commit all changes with clear messages.
- Push to `main`.

## Acceptance criteria
- No `.zh.md` files remain in `docs/`.
- `/doc/DAG_REFERENCE.pl.md` returns Polish content.
- `/doc/DAG_REFERENCE.md` returns English content.
- AI wiki `open_docs` respects UI language.
- `go test ./internal/aiwiki/...` passes.
- Build succeeds.
