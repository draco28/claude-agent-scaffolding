"""scaffold-memory: per-repo memory bank backed by SQLite.

Three indexes share one table:
  memory       — primary rows (id, type, title, body, tags, branch, related_files, timestamps)
  memory_fts   — FTS5 virtual table mirroring memory via triggers (always available)
  memory_vec   — sqlite-vec vec0 virtual table for embeddings (when sqlite-vec is importable)

Vector search degrades gracefully to FTS5-only when sqlite-vec is unavailable.
"""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

try:
    import sqlite_vec  # type: ignore[import-not-found]
    VEC_AVAILABLE = True
except ImportError:
    VEC_AVAILABLE = False

EMBEDDING_DIM = 768
VALID_TYPES = ("decision", "pattern", "note", "retrospective")
SCHEMA_VERSION = 1


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def _row_to_dict(row: sqlite3.Row | None) -> dict | None:
    if row is None:
        return None
    d = dict(row)
    for k in ("tags", "related_files"):
        if d.get(k):
            try:
                d[k] = json.loads(d[k])
            except json.JSONDecodeError:
                d[k] = []
        else:
            d[k] = []
    return d


class Memory:
    """Per-repo memory store. Constructed once at server startup."""

    def __init__(self, db_path: Path | str):
        self.db_path = Path(db_path)
        self.conn: sqlite3.Connection | None = None
        self.vec_available = VEC_AVAILABLE

    def setup(self) -> None:
        """Open the database, load sqlite-vec if importable, run schema migration."""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(str(self.db_path))
        self.conn.row_factory = sqlite3.Row
        if VEC_AVAILABLE:
            try:
                self.conn.enable_load_extension(True)
                sqlite_vec.load(self.conn)
                self.conn.enable_load_extension(False)
            except (sqlite3.OperationalError, AttributeError):
                # Some Python builds disable load_extension; fall back to FTS-only.
                self.vec_available = False
        self._migrate()

    def _migrate(self) -> None:
        c = self.conn.cursor()
        c.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)")
        c.execute("INSERT OR IGNORE INTO meta(key, value) VALUES ('schema_version', ?)", (str(SCHEMA_VERSION),))
        c.execute(f"""
            CREATE TABLE IF NOT EXISTS memory (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL CHECK(type IN {VALID_TYPES!r}),
              title TEXT,
              body TEXT NOT NULL,
              tags TEXT,
              branch TEXT,
              related_files TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
        """)
        c.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS memory_fts USING fts5(
              title, body, tags,
              content='memory', content_rowid='id'
            )
        """)
        if self.vec_available:
            c.execute(f"""
                CREATE VIRTUAL TABLE IF NOT EXISTS memory_vec USING vec0(
                  embedding float[{EMBEDDING_DIM}]
                )
            """)
        # Triggers keep FTS5 in sync. (Vector index is updated explicitly in create/update/delete.)
        c.execute("""
            CREATE TRIGGER IF NOT EXISTS memory_ai AFTER INSERT ON memory BEGIN
              INSERT INTO memory_fts(rowid, title, body, tags)
              VALUES (new.id, COALESCE(new.title, ''), new.body, COALESCE(new.tags, ''));
            END
        """)
        c.execute("""
            CREATE TRIGGER IF NOT EXISTS memory_ad AFTER DELETE ON memory BEGIN
              INSERT INTO memory_fts(memory_fts, rowid, title, body, tags)
              VALUES ('delete', old.id, COALESCE(old.title, ''), old.body, COALESCE(old.tags, ''));
            END
        """)
        c.execute("""
            CREATE TRIGGER IF NOT EXISTS memory_au AFTER UPDATE ON memory BEGIN
              INSERT INTO memory_fts(memory_fts, rowid, title, body, tags)
              VALUES ('delete', old.id, COALESCE(old.title, ''), old.body, COALESCE(old.tags, ''));
              INSERT INTO memory_fts(rowid, title, body, tags)
              VALUES (new.id, COALESCE(new.title, ''), new.body, COALESCE(new.tags, ''));
            END
        """)
        self.conn.commit()

    # ── CRUD ────────────────────────────────────────────────────────────────

    def create(
        self,
        *,
        type: str,
        body: str,
        title: str | None = None,
        tags: list[str] | None = None,
        related_files: list[str] | None = None,
        branch: str | None = None,
        embedding: list[float] | None = None,
    ) -> int:
        if type not in VALID_TYPES:
            raise ValueError(f"invalid type {type!r}; must be one of {VALID_TYPES}")
        now = _now()
        c = self.conn.cursor()
        c.execute(
            """
            INSERT INTO memory (type, title, body, tags, branch, related_files, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (type, title, body, json.dumps(tags or []), branch, json.dumps(related_files or []), now, now),
        )
        entry_id = c.lastrowid
        if self.vec_available and embedding is not None and len(embedding) == EMBEDDING_DIM:
            c.execute(
                "INSERT INTO memory_vec(rowid, embedding) VALUES (?, ?)",
                (entry_id, json.dumps(embedding)),
            )
        self.conn.commit()
        return entry_id

    def get(self, entry_id: int) -> dict | None:
        row = self.conn.execute("SELECT * FROM memory WHERE id = ?", (entry_id,)).fetchone()
        return _row_to_dict(row)

    def update(
        self,
        entry_id: int,
        *,
        title: str | None = None,
        body: str | None = None,
        tags: list[str] | None = None,
        related_files: list[str] | None = None,
        embedding: list[float] | None = None,
    ) -> bool:
        existing = self.get(entry_id)
        if existing is None:
            return False
        sets: list[str] = []
        vals: list[Any] = []
        if title is not None:
            sets.append("title = ?")
            vals.append(title)
        if body is not None:
            sets.append("body = ?")
            vals.append(body)
        if tags is not None:
            sets.append("tags = ?")
            vals.append(json.dumps(tags))
        if related_files is not None:
            sets.append("related_files = ?")
            vals.append(json.dumps(related_files))
        if not sets:
            return True  # no-op update is success
        sets.append("updated_at = ?")
        vals.append(_now())
        vals.append(entry_id)
        self.conn.execute(f"UPDATE memory SET {', '.join(sets)} WHERE id = ?", vals)
        if self.vec_available and embedding is not None and len(embedding) == EMBEDDING_DIM:
            # Replace the vec row
            self.conn.execute("DELETE FROM memory_vec WHERE rowid = ?", (entry_id,))
            self.conn.execute(
                "INSERT INTO memory_vec(rowid, embedding) VALUES (?, ?)",
                (entry_id, json.dumps(embedding)),
            )
        self.conn.commit()
        return True

    def delete(self, entry_id: int) -> bool:
        c = self.conn.cursor()
        c.execute("DELETE FROM memory WHERE id = ?", (entry_id,))
        deleted = c.rowcount > 0
        if self.vec_available:
            self.conn.execute("DELETE FROM memory_vec WHERE rowid = ?", (entry_id,))
        self.conn.commit()
        return deleted

    def list_recent(
        self,
        *,
        type: str | None = None,
        since: str | None = None,
        limit: int = 10,
    ) -> list[dict]:
        sql = "SELECT * FROM memory WHERE 1=1"
        params: list[Any] = []
        if type:
            sql += " AND type = ?"
            params.append(type)
        if since:
            sql += " AND created_at >= ?"
            params.append(since)
        sql += " ORDER BY created_at DESC LIMIT ?"
        params.append(limit)
        rows = self.conn.execute(sql, params).fetchall()
        return [_row_to_dict(r) for r in rows]

    # ── Hybrid search ───────────────────────────────────────────────────────

    def search(
        self,
        query: str,
        *,
        query_embedding: list[float] | None = None,
        type: str | None = None,
        limit: int = 5,
        fts_weight: float = 0.4,
        vec_weight: float = 0.6,
        min_score: float = 0.0,
    ) -> list[dict]:
        """Hybrid retrieval: union of FTS5 BM25 and vector cosine, weighted blend.

        If query_embedding is None or sqlite-vec is unavailable, returns FTS5-only.
        If FTS5 returns no rows but vectors exist, returns vector-only.
        Always filters by type when provided. Returns up to `limit` results sorted
        by combined score descending.
        """
        # FTS5 search — defensive: bad query strings can crash fts5 with a syntax error.
        fts_results: dict[int, float] = {}
        try:
            fts_query = _sanitize_fts_query(query)
            if fts_query:
                pool = max(limit * 4, 20)
                rows = self.conn.execute(
                    "SELECT rowid, bm25(memory_fts) AS rank FROM memory_fts WHERE memory_fts MATCH ? ORDER BY rank LIMIT ?",
                    (fts_query, pool),
                ).fetchall()
                # bm25 is lower=better; normalize so higher=better
                if rows:
                    raw = [(r["rowid"], -r["rank"]) for r in rows]
                    if len(raw) == 1:
                        # Single result: can't normalize a range, give top score.
                        fts_results[raw[0][0]] = 1.0
                    else:
                        max_score = max(s for _, s in raw)
                        min_score_raw = min(s for _, s in raw)
                        span = max_score - min_score_raw
                        if span > 0:
                            for rid, s in raw:
                                fts_results[rid] = (s - min_score_raw) / span
                        else:
                            # All BM25 ranks equal — flat score 1.0 for everyone.
                            for rid, _ in raw:
                                fts_results[rid] = 1.0
        except sqlite3.OperationalError:
            fts_results = {}

        # Vector search
        vec_results: dict[int, float] = {}
        if self.vec_available and query_embedding is not None and len(query_embedding) == EMBEDDING_DIM:
            try:
                pool = max(limit * 4, 20)
                rows = self.conn.execute(
                    "SELECT rowid, distance FROM memory_vec WHERE embedding MATCH ? ORDER BY distance LIMIT ?",
                    (json.dumps(query_embedding), pool),
                ).fetchall()
                # Distance is lower=better; convert to similarity (higher=better) via 1/(1+d)
                if rows:
                    for r in rows:
                        vec_results[r["rowid"]] = 1.0 / (1.0 + float(r["distance"]))
            except sqlite3.OperationalError:
                vec_results = {}

        # Combine
        combined: dict[int, float] = {}
        all_ids = set(fts_results) | set(vec_results)
        for rid in all_ids:
            score = fts_weight * fts_results.get(rid, 0.0) + vec_weight * vec_results.get(rid, 0.0)
            combined[rid] = score

        # Fetch rows + filter by type
        results: list[dict] = []
        for rid, score in sorted(combined.items(), key=lambda kv: kv[1], reverse=True):
            if score < min_score:
                continue
            entry = self.get(rid)
            if entry is None:
                continue
            if type and entry.get("type") != type:
                continue
            entry["score"] = round(score, 4)
            results.append(entry)
            if len(results) >= limit:
                break
        return results

    def reindex_pending(self, embed_fn) -> int:
        """Re-embed entries that have no vec row yet. Returns count embedded."""
        if not self.vec_available:
            return 0
        rows = self.conn.execute(
            """
            SELECT m.id, m.title, m.body FROM memory m
            LEFT JOIN memory_vec v ON v.rowid = m.id
            WHERE v.rowid IS NULL
            """
        ).fetchall()
        n = 0
        for r in rows:
            text = (r["title"] or "") + "\n\n" + r["body"]
            emb = embed_fn(text)
            if emb is not None and len(emb) == EMBEDDING_DIM:
                self.conn.execute(
                    "INSERT INTO memory_vec(rowid, embedding) VALUES (?, ?)",
                    (r["id"], json.dumps(emb)),
                )
                n += 1
        self.conn.commit()
        return n


def _sanitize_fts_query(q: str) -> str:
    """Strip characters that have special meaning in FTS5 query syntax.
    Keeps the query as a free-text MATCH against any column.
    """
    # FTS5 special chars: " * : ( ) - . , ' (apostrophe via doubling)
    cleaned = "".join(ch if ch.isalnum() or ch.isspace() else " " for ch in q)
    cleaned = " ".join(cleaned.split())  # collapse whitespace
    return cleaned
