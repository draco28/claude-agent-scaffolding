"""scaffold-memory FastMCP server.

Per-repo memory bank exposed as 10 MCP tools (4 record_*, recall, list_recent,
get_by_id, update, delete, reindex). Backing store: SQLite + (optional)
sqlite-vec + (optional) Ollama embeddings.

Launched by Claude Code via mcp/run-server.sh, which:
  1. Ensures the venv exists (lazy install on first run).
  2. Detects the current repo and sets SCAFFOLD_REPO_HASH/BRANCH env vars.
  3. Execs this script.

Server scope: bound to the repo where it was launched. If user cd's mid-session
the server doesn't follow — Claude Code re-launches per session, so this is fine
in practice.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from fastmcp import FastMCP  # noqa: E402

from embed import embed_text, is_available as ollama_available  # noqa: E402
from memory import Memory  # noqa: E402

# ── Configuration ──────────────────────────────────────────────────────────

DATA_DIR = Path(os.environ.get("SCAFFOLD_DATA_DIR", os.path.expanduser("~/.claude/plugins/data/scaffold")))
REPO_HASH = os.environ.get("SCAFFOLD_REPO_HASH", "_unknown")
BRANCH = os.environ.get("SCAFFOLD_REPO_BRANCH", "_unknown")
DB_PATH = DATA_DIR / "projects" / REPO_HASH / "memory.db"

# ── Initialization ─────────────────────────────────────────────────────────

memory = Memory(DB_PATH)
memory.setup()

OLLAMA_OK = ollama_available()
if not OLLAMA_OK:
    print(
        "scaffold-memory: Ollama not reachable; recall() will fall back to FTS5 keyword search. "
        "Run `ollama serve` and `/scaffold-memory-reindex` to enable semantic search.",
        file=sys.stderr,
    )

mcp = FastMCP("scaffold-memory")

# ── Tools ──────────────────────────────────────────────────────────────────


@mcp.tool()
def record_decision(
    title: str,
    context: str,
    decision: str,
    rationale: str,
    options: str = "",
    tags: list[str] | None = None,
) -> dict:
    """Record an architectural decision: title + context + options + decision + rationale."""
    parts = [f"## Context\n{context}"]
    if options:
        parts.append(f"## Options considered\n{options}")
    parts.append(f"## Decision\n{decision}")
    parts.append(f"## Rationale\n{rationale}")
    body = "\n\n".join(parts)
    embedding = embed_text(f"{title}\n\n{body}") if OLLAMA_OK else None
    entry_id = memory.create(
        type="decision", title=title, body=body, tags=tags or [], branch=BRANCH, embedding=embedding,
    )
    return {"id": entry_id, "type": "decision", "title": title, "embedded": embedding is not None}


@mcp.tool()
def record_pattern(
    name: str,
    description: str,
    example_files: list[str] | None = None,
    tags: list[str] | None = None,
) -> dict:
    """Record a code pattern observed in this codebase (e.g., conventions worth preserving)."""
    body = description
    if example_files:
        body += "\n\n**Example files:**\n" + "\n".join(f"- `{f}`" for f in example_files)
    embedding = embed_text(f"{name}\n\n{body}") if OLLAMA_OK else None
    entry_id = memory.create(
        type="pattern", title=name, body=body, tags=tags or [],
        related_files=example_files or [], branch=BRANCH, embedding=embedding,
    )
    return {"id": entry_id, "type": "pattern", "title": name, "embedded": embedding is not None}


@mcp.tool()
def record_note(text: str, tags: list[str] | None = None) -> dict:
    """Record a free-form note with optional tags. The catch-all sticky-note surface."""
    embedding = embed_text(text) if OLLAMA_OK else None
    entry_id = memory.create(
        type="note", title=None, body=text, tags=tags or [], branch=BRANCH, embedding=embedding,
    )
    return {"id": entry_id, "type": "note", "embedded": embedding is not None}


@mcp.tool()
def record_retrospective(
    slice_name: str,
    what_worked: str,
    what_didnt: str,
    learnings: str,
    tags: list[str] | None = None,
) -> dict:
    """Record a slice retrospective — what worked, what didn't, learnings. Use after slice completion."""
    body = (
        f"**Slice:** {slice_name}\n\n"
        f"## What worked\n{what_worked}\n\n"
        f"## What didn't\n{what_didnt}\n\n"
        f"## Learnings\n{learnings}"
    )
    embedding = embed_text(f"Retrospective: {slice_name}\n\n{body}") if OLLAMA_OK else None
    entry_id = memory.create(
        type="retrospective", title=f"Retrospective: {slice_name}", body=body,
        tags=tags or [], branch=BRANCH, embedding=embedding,
    )
    return {
        "id": entry_id, "type": "retrospective",
        "title": f"Retrospective: {slice_name}", "embedded": embedding is not None,
    }


@mcp.tool()
def recall(query: str, type: str | None = None, limit: int = 5, min_score: float = 0.0) -> list[dict]:
    """Search memory by hybrid (vector + FTS5 keyword) retrieval. `type` filters by kind."""
    qe = embed_text(query) if OLLAMA_OK else None
    return memory.search(query, query_embedding=qe, type=type, limit=limit, min_score=min_score)


@mcp.tool()
def list_recent(type: str | None = None, limit: int = 10, since: str | None = None) -> list[dict]:
    """List most-recent memory entries, newest first. Optional type filter and ISO date cutoff."""
    return memory.list_recent(type=type, since=since, limit=limit)


@mcp.tool()
def get_by_id(id: int) -> dict | None:
    """Fetch a single memory entry by id. Returns None if not found."""
    return memory.get(id)


@mcp.tool()
def update(
    id: int,
    title: str | None = None,
    body: str | None = None,
    tags: list[str] | None = None,
    related_files: list[str] | None = None,
) -> dict:
    """Update fields on an existing memory entry. Re-embeds if body changes (and Ollama is up)."""
    existing = memory.get(id)
    if existing is None:
        return {"ok": False, "reason": "not found"}
    new_embedding = None
    if body is not None and OLLAMA_OK:
        new_text = (title if title is not None else existing.get("title") or "") + "\n\n" + body
        new_embedding = embed_text(new_text)
    ok = memory.update(
        id, title=title, body=body, tags=tags, related_files=related_files, embedding=new_embedding,
    )
    return {"ok": ok, "id": id, "re_embedded": new_embedding is not None}


@mcp.tool()
def delete(id: int) -> dict:
    """Delete a memory entry permanently. Use deliberately — not reversible."""
    deleted = memory.delete(id)
    return {"ok": deleted, "id": id}


@mcp.tool()
def reindex() -> dict:
    """Re-embed entries with no vector indexing yet (e.g., recorded before Ollama was running)."""
    if not memory.vec_available:
        return {"reindexed": 0, "reason": "sqlite-vec extension not available"}
    if not OLLAMA_OK:
        return {"reindexed": 0, "reason": "Ollama not reachable"}
    n = memory.reindex_pending(embed_text)
    return {"reindexed": n}


# ── Entry point ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    mcp.run()
