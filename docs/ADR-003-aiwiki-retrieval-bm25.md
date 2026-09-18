# ADR-003: AI wiki retrieval — BM25 instead of embeddings

## Status
Accepted

## Context
The cronova AI wiki chat needs a retrieval layer to find relevant knowledge-base chunks for a user question. We evaluated several options:

- **sqlite-vec** (vector extension for SQLite)
- **Local embeddings + flat index in Go** (ONNX)
- **External vector database** (Chroma, Qdrant, Pinecone)
- **BM25 / TF-IDF keyword scoring**

cronova is designed as a single self-contained binary with minimal runtime dependencies. Adding a vector extension, an embedding model, or an external service would conflict with that philosophy and complicate packaging, especially on Windows.

## Decision
Use **BM25** as the retrieval algorithm for the AI wiki.

BM25 is implemented in pure Go inside `internal/aiwiki/bm25.go`, requires no new runtime dependencies, works offline, and gives good results for the current documentation and DAG corpus. We added targeted boosts for reference docs (`DAG_REFERENCE.md`, `GETTING_STARTED.md`) and YAML field names to improve ranking for common questions.

## Consequences

### Positive
- Zero new runtime dependencies.
- Fast index build at startup.
- Works offline and on all platforms cronova supports.
- Simpler to reason about, test, and debug than a vector pipeline.

### Negative
- Less semantic than dense embeddings; synonyms and paraphrases may not match.
- Quality may degrade as the knowledge base grows beyond the current scale.
- Multilingual questions are not handled semantically; answers rely on the configured UI language and the LLM fallback.

## When embeddings make sense

Consider switching to embeddings (e.g. `sqlite-vec` or a local ONNX model) when:

- Users start asking semantic questions that keyword scoring cannot cover, for example *"jak zrobić, żeby zadanie próbowało ponownie po błędzie?"* where BM25 may not map *"ponownie"* to the `retry` field.
- The knowledge base grows to hundreds or thousands of pages and requires contextual understanding rather than term matching.
- We need to answer multilingual questions without relying on translation or a configured UI language.

## Related files
- `internal/aiwiki/bm25.go`
- `internal/aiwiki/aiwiki.go`
- `plans/ai-wiki-iteration-2.md`
