#!/usr/bin/env python3
"""Build a RAG knowledge base for the cronova AI wiki chat.

Reads selected docs, DAGs, workflows and reusable scripts, splits them into
chunks, and writes internal/ai-wiki/knowledge-base.json.
"""

import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
OUT_FILE = REPO_ROOT / "internal" / "aiwiki" / "knowledge-base.json"

DOC_SOURCES = [
    "README.md",
    "docs/GETTING_STARTED.md",
    "docs/DAG_REFERENCE.md",
    "docs/AGENTS.md",
    "docs/CLI.md",
    "docs/ARCHITECTURE.md",
]

DAG_SOURCES = [
    "dags/sdlc_springboot.yaml",
    "dags/sdlc_maven_luhn.yaml",
    "dags/sdlc_springboot_startio.yaml",
]

WORKFLOW_SOURCES = [
    "workflows/sdlc_springboot/scaffold.sh",
    "workflows/sdlc_springboot/compile_skeleton.sh",
    "workflows/sdlc_springboot/ai_add_crud.sh",
    "workflows/sdlc_springboot/compile_loop.sh",
    "workflows/sdlc_springboot/tests.sh",
]

SCRIPT_SOURCES = [
    "internal/scripts/copy-template-to-workspace",
    "internal/scripts/compile-project",
    "internal/scripts/run-tests",
    "internal/scripts/ai-generate-crud",
    "internal/scripts/ai-review-fix-loop",
]


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9_-]+", "-", text.lower()).strip("-")


def chunk_markdown(path: Path, text: str, max_chars: int = 1200):
    """Split markdown into chunks by top-level headings."""
    chunks = []
    current_heading = "intro"
    current_lines = []

    for line in text.splitlines():
        if line.startswith("# ") or line.startswith("## "):
            if current_lines:
                body = "\n".join(current_lines).strip()
                if body:
                    chunks.append({
                        "heading": current_heading,
                        "body": body,
                    })
            current_heading = line.lstrip("# ").strip()
            current_lines = []
        else:
            current_lines.append(line)

    if current_lines:
        body = "\n".join(current_lines).strip()
        if body:
            chunks.append({
                "heading": current_heading,
                "body": body,
            })

    # Further split oversized chunks by paragraphs.
    result = []
    for chunk in chunks:
        body = chunk["body"]
        if len(body) <= max_chars:
            result.append(chunk)
            continue
        paragraphs = body.split("\n\n")
        current = ""
        for para in paragraphs:
            if len(current) + len(para) > max_chars and current:
                result.append({"heading": chunk["heading"], "body": current.strip()})
                current = para
            else:
                current = current + "\n\n" + para if current else para
        if current:
            result.append({"heading": chunk["heading"], "body": current.strip()})
    return result


def chunk_yaml(path: Path, text: str):
    """Return a single chunk for a DAG YAML with a short summary."""
    return [{"heading": f"DAG {path.stem}", "body": text.strip()}]


def chunk_script(path: Path, text: str):
    """Return a single chunk for a shell script."""
    return [{"heading": f"Script {path.name}", "body": text.strip()}]


def build():
    chunks = []
    chunk_id = 0

    for rel in DOC_SOURCES:
        path = REPO_ROOT / rel
        if not path.exists():
            print(f"skip missing doc: {rel}")
            continue
        text = path.read_text(encoding="utf-8")
        for c in chunk_markdown(path, text):
            chunk_id += 1
            chunks.append({
                "id": f"doc-{slugify(path.stem)}-{chunk_id}",
                "type": "doc",
                "source": rel,
                "section": c["heading"],
                "text": c["body"],
                "topics": infer_topics(c["heading"] + " " + c["body"]),
            })

    for rel in DAG_SOURCES:
        path = REPO_ROOT / rel
        if not path.exists():
            print(f"skip missing dag: {rel}")
            continue
        text = path.read_text(encoding="utf-8")
        for c in chunk_yaml(path, text):
            chunk_id += 1
            chunks.append({
                "id": f"dag-{slugify(path.stem)}-{chunk_id}",
                "type": "dag",
                "source": rel,
                "section": c["heading"],
                "text": c["body"],
                "topics": infer_topics(c["heading"] + " " + c["body"]),
            })

    for rel in WORKFLOW_SOURCES + SCRIPT_SOURCES:
        path = REPO_ROOT / rel
        if not path.exists():
            print(f"skip missing script: {rel}")
            continue
        text = path.read_text(encoding="utf-8")
        for c in chunk_script(path, text):
            chunk_id += 1
            chunks.append({
                "id": f"script-{slugify(path.name)}-{chunk_id}",
                "type": "script",
                "source": rel,
                "section": c["heading"],
                "text": c["body"],
                "topics": infer_topics(c["heading"] + " " + c["body"]),
            })

    OUT_FILE.write_text(
        json.dumps({"chunks": chunks}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"wrote {OUT_FILE} with {len(chunks)} chunks")


def infer_topics(text: str) -> list[str]:
    """Simple keyword-based topic inference."""
    topics = []
    lowered = text.lower()
    keywords = {
        "dag": ["dag", "directed acyclic", "tasks", "deps"],
        "schedule": ["schedule", "cron", "@every", "start_date", "catchup"],
        "retry": ["retry", "retries", "timeout", "retry_delay"],
        "pool": ["pool", "max_active_runs", "concurrency"],
        "project": ["project", "upload", "zip", "cronova_project_dir"],
        "ai": ["ai", "mcp", "generate", "crud", "feature", "llm"],
        "template": ["template", "copy-template-to-workspace"],
        "compile": ["compile", "maven", "mvn"],
        "test": ["test", "tests", "run-tests"],
        "install": ["install", "bootstrap", "serve"],
        "variable": ["variable", "var.", "connection", "conn.", "params"],
    }
    for topic, words in keywords.items():
        if any(w in lowered for w in words):
            topics.append(topic)
    return topics


if __name__ == "__main__":
    build()
