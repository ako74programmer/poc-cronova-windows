package aiwiki

import (
	"math"
	"strings"
)

// bm25Index holds precomputed statistics for BM25 scoring.
type bm25Index struct {
	docs     []bm25Doc
	avgdl    float64
	idf      map[string]float64
	k1       float64
	b        float64
}

type bm25Doc struct {
	chunk  Chunk
	tokens []string
	length int
}

// newBM25Index builds a BM25 index from chunks.
func newBM25Index(chunks []Chunk) *bm25Index {
	idx := &bm25Index{
		k1:  1.5,
		b:   0.75,
		idf: make(map[string]float64),
	}

	var totalLen int
	docFreq := make(map[string]int)

	for _, c := range chunks {
		text := strings.ToLower(c.Section + " " + c.Text)
		tokens := tokenizeBM25(text)
		seen := make(map[string]bool)
		for _, t := range tokens {
			if !seen[t] {
				docFreq[t]++
				seen[t] = true
			}
		}
		idx.docs = append(idx.docs, bm25Doc{
			chunk:  c,
			tokens: tokens,
			length: len(tokens),
		})
		totalLen += len(tokens)
	}

	if len(idx.docs) > 0 {
		idx.avgdl = float64(totalLen) / float64(len(idx.docs))
	}

	N := float64(len(idx.docs))
	for term, df := range docFreq {
		// IDF with smoothing to avoid negative values for very common terms.
		idx.idf[term] = math.Log1p((N - float64(df) + 0.5) / (float64(df) + 0.5))
	}

	return idx
}

// search returns chunks scored by BM25, sorted by score descending.
func (idx *bm25Index) search(query string, topN int) []scoredChunk {
	qTokens := tokenizeBM25(strings.ToLower(query))
	if len(qTokens) == 0 {
		return nil
	}

	var results []scoredChunk
	for _, d := range idx.docs {
		score := idx.scoreDoc(d, qTokens)
		if score > 0 {
			results = append(results, scoredChunk{chunk: d.chunk, score: score})
		}
	}

	// Sort descending.
	for i := 0; i < len(results); i++ {
		for j := i + 1; j < len(results); j++ {
			if results[j].score > results[i].score {
				results[i], results[j] = results[j], results[i]
			}
		}
	}

	if topN > 0 && len(results) > topN {
		results = results[:topN]
	}
	return results
}

func (idx *bm25Index) scoreDoc(d bm25Doc, qTokens []string) float64 {
	if d.length == 0 {
		return 0
	}

	freq := make(map[string]int)
	for _, t := range d.tokens {
		freq[t]++
	}

	var score float64
	for _, t := range qTokens {
		idf, ok := idx.idf[t]
		if !ok {
			continue
		}
		f := float64(freq[t])
		denom := f + idx.k1*(1-idx.b+idx.b*(float64(d.length)/idx.avgdl))
		score += idf * (f * (idx.k1 + 1)) / denom
	}

	// Boost chunks from the DAG reference and getting-started docs, which are
	// the canonical sources for YAML field questions.
	src := strings.ToLower(d.chunk.Source)
	if strings.Contains(src, "dag_reference") || strings.Contains(src, "getting_started") {
		score *= 1.3
	}

	return score
}

type scoredChunk struct {
	chunk Chunk
	score float64
}

// tokenizeBM25 splits text into lowercase tokens, removing punctuation.
func tokenizeBM25(s string) []string {
	stop := map[string]bool{
		"jak": true, "co": true, "to": true, "jest": true, "w": true, "z": true,
		"a": true, "the": true, "is": true, "what": true, "how": true, "do": true,
		"i": true, "or": true, "and": true, "for": true, "in": true, "on": true,
		"czy": true, "wiesz": true, "ty": true, "wiem": true, "know": true, "you": true,
		"czym": true, "kim": true, "który": true, "ktora": true, "ktore": true,
	}
	var out []string
	for _, w := range strings.Fields(strings.TrimSpace(s)) {
		w = strings.Trim(w, "?.,!;:\"'()[]{}<>")
		if w == "" || stop[w] {
			continue
		}
		out = append(out, w)
	}
	return out
}
