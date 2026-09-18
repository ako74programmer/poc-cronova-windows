import json, math

with open('internal/aiwiki/knowledge-base.json', 'r', encoding='utf-8') as f:
    kb = json.load(f)

stop = {'jak', 'co', 'to', 'jest', 'w', 'z', 'a', 'the', 'is', 'what', 'how', 'do',
        'i', 'or', 'and', 'for', 'in', 'on', 'czy', 'wiesz', 'ty', 'wiem', 'know', 'you',
        'czym', 'kim', 'który', 'ktora', 'ktore'}


def tokenize(s):
    out = []
    for w in s.lower().split():
        w = w.strip('?.,!;:\"\'()[]{}<>')
        if w and w not in stop:
            out.append(w)
    return out


N = len(kb['chunks'])
docfreq = {}
chunks = []
totlen = 0
for c in kb['chunks']:
    text = (c['section'] + ' ' + c['text']).lower()
    tokens = tokenize(text)
    seen = set(tokens)
    for t in seen:
        docfreq[t] = docfreq.get(t, 0) + 1
    chunks.append({'chunk': c, 'tokens': tokens, 'len': len(tokens)})
    totlen += len(tokens)
avgdl = totlen / N
k1 = 1.5
b = 0.75
idf = {}
for t, df in docfreq.items():
    idf[t] = math.log1p((N - df + 0.5) / (df + 0.5))

q = 'jak zrobić dag?'
qt = tokenize(q)
print('query tokens:', qt)
results = []
for d in chunks:
    freq = {}
    for t in d['tokens']:
        freq[t] = freq.get(t, 0) + 1
    score = 0.0
    for t in qt:
        if t not in idf:
            continue
        f = freq.get(t, 0)
        denom = f + k1 * (1 - b + b * (d['len'] / avgdl))
        score += idf[t] * (f * (k1 + 1)) / denom
    src = d['chunk']['source'].lower()
    if 'dag_reference' in src or 'getting_started' in src:
        score *= 1.3
    if score > 0:
        results.append((score, d['chunk']['source'], d['chunk']['section'][:60]))
results.sort(reverse=True)
for r in results[:5]:
    print(r)
