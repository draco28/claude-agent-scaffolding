"""Ollama embedding client — fail-soft.

If Ollama isn't running or the embedding model isn't pulled, embed_text
returns None. Callers handle None as "vector indexing unavailable for this
entry; FTS5 keyword search still works."

Uses urllib from stdlib so this module has no extra dependencies.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
EMBEDDING_MODEL = os.environ.get("SCAFFOLD_EMBEDDING_MODEL", "nomic-embed-text:latest")
EMBEDDING_DIM = 768  # nomic-embed-text dimension
TIMEOUT_SECONDS = 10


def is_available() -> bool:
    """One-shot check whether Ollama is reachable. Used at startup to log status."""
    try:
        with urllib.request.urlopen(f"{OLLAMA_HOST}/api/tags", timeout=2) as resp:
            return resp.status == 200
    except Exception:
        return False


def embed_text(text: str) -> list[float] | None:
    """Embed a string via Ollama. Returns None on any error (Ollama down, model
    missing, network issue). The caller should treat None as "skip vector indexing
    for this item; keyword search via FTS5 still functions."
    """
    if not text or not text.strip():
        return None
    payload = json.dumps({"model": EMBEDDING_MODEL, "prompt": text}).encode("utf-8")
    req = urllib.request.Request(
        f"{OLLAMA_HOST}/api/embeddings",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            data = json.loads(resp.read())
            embedding = data.get("embedding")
            if not isinstance(embedding, list) or len(embedding) != EMBEDDING_DIM:
                return None
            return embedding
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError, OSError):
        return None
