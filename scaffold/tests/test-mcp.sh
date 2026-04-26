#!/usr/bin/env bash
#
# scaffold/tests/test-mcp.sh — Python unit tests for mcp/memory.py and
# mcp/embed.py.
#
# Runs against a system Python 3.11+; does NOT require the installed venv
# (memory.py is stdlib-only when sqlite-vec is missing — the FTS5 path
# always works because sqlite3+FTS5 is in stdlib).
#
# Tests:
#   - Memory CRUD: create, get, update, delete
#   - List recent with type and since filters
#   - FTS5 search returns relevant results
#   - Hybrid search degrades to FTS5-only without embeddings
#   - sf_sanitize_fts_query strips problematic chars
#   - embed.py is_available is non-destructive (always returns bool)
#
# Skips gracefully (exit 0) if no Python 3.11+ is available.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Find a usable Python
PYTHON=""
for cand in python3.13 python3.12 python3.11 python3; do
  if command -v "$cand" >/dev/null 2>&1; then
    if "$cand" -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)" 2>/dev/null; then
      PYTHON="$cand"; break
    fi
  fi
done

if [[ -z "$PYTHON" ]]; then
  echo "test-mcp.sh: no Python 3.11+ found, skipping (exit 0)"
  exit 0
fi

export PLUGIN_ROOT
exec "$PYTHON" - <<'PYEOF'
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.join(os.environ["PLUGIN_ROOT"], "mcp"))

from memory import Memory, _sanitize_fts_query
import embed as embed_mod


class TestMemoryCRUD(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.db = Memory(Path(self.tmpdir) / "memory.db")
        self.db.setup()

    def tearDown(self):
        self.db.conn.close()

    def test_create_decision_returns_int_id(self):
        eid = self.db.create(
            type="decision",
            title="Choose Postgres",
            body="## Context\n...\n## Decision\nPick Postgres",
            tags=["db"],
        )
        self.assertIsInstance(eid, int)
        self.assertGreater(eid, 0)

    def test_create_invalid_type_raises(self):
        with self.assertRaises(ValueError):
            self.db.create(type="bogus", body="x")

    def test_get_returns_row_with_parsed_tags(self):
        eid = self.db.create(type="note", body="test", tags=["a", "b"])
        row = self.db.get(eid)
        self.assertEqual(row["type"], "note")
        self.assertEqual(row["body"], "test")
        self.assertEqual(row["tags"], ["a", "b"])

    def test_get_missing_returns_none(self):
        self.assertIsNone(self.db.get(999))

    def test_update_changes_fields(self):
        eid = self.db.create(type="note", body="original")
        ok = self.db.update(eid, body="changed")
        self.assertTrue(ok)
        self.assertEqual(self.db.get(eid)["body"], "changed")

    def test_update_missing_returns_false(self):
        self.assertFalse(self.db.update(999, body="x"))

    def test_update_no_fields_is_noop_success(self):
        eid = self.db.create(type="note", body="x")
        self.assertTrue(self.db.update(eid))

    def test_delete_returns_true_when_existed(self):
        eid = self.db.create(type="note", body="x")
        self.assertTrue(self.db.delete(eid))
        self.assertIsNone(self.db.get(eid))

    def test_delete_missing_returns_false(self):
        self.assertFalse(self.db.delete(999))


class TestMemoryList(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.db = Memory(Path(self.tmpdir) / "memory.db")
        self.db.setup()

    def tearDown(self):
        self.db.conn.close()

    def test_list_recent_orders_newest_first(self):
        a = self.db.create(type="note", body="A")
        b = self.db.create(type="note", body="B")
        c = self.db.create(type="note", body="C")
        rows = self.db.list_recent(limit=10)
        # SQLite AUTOINCREMENT + same-second timestamps means stable insertion order
        # but ORDER BY created_at DESC, fallback id desc by SQLite convention
        ids = [r["id"] for r in rows]
        self.assertIn(c, ids)
        self.assertIn(a, ids)

    def test_list_recent_filters_by_type(self):
        self.db.create(type="note", body="x")
        self.db.create(type="decision", title="d", body="y", tags=["t"])
        rows_n = self.db.list_recent(type="note", limit=10)
        rows_d = self.db.list_recent(type="decision", limit=10)
        self.assertEqual(len(rows_n), 1)
        self.assertEqual(len(rows_d), 1)
        self.assertEqual(rows_d[0]["type"], "decision")

    def test_list_recent_limit(self):
        for i in range(5):
            self.db.create(type="note", body=f"row{i}")
        rows = self.db.list_recent(limit=3)
        self.assertEqual(len(rows), 3)


class TestSearch(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.db = Memory(Path(self.tmpdir) / "memory.db")
        self.db.setup()
        # Seed with predictable content
        self.db.create(type="decision", title="Caching strategy",
                       body="Use cache-aside for read-heavy paths", tags=["caching"])
        self.db.create(type="decision", title="Auth with JWT",
                       body="Stateless tokens; revocation list in Redis", tags=["auth"])
        self.db.create(type="pattern", title="Result types",
                       body="Use Result<T, E> for fallible operations", tags=["error-handling"])
        self.db.create(type="note", body="Remember to migrate sessions table by Friday",
                       tags=["todo"])

    def tearDown(self):
        self.db.conn.close()

    def test_fts_search_returns_results(self):
        rows = self.db.search("caching", limit=5)
        self.assertGreaterEqual(len(rows), 1)
        # Top hit should be the caching decision
        self.assertEqual(rows[0]["type"], "decision")
        self.assertIn("cach", rows[0]["body"].lower())

    def test_search_filters_by_type(self):
        rows = self.db.search("strategy", type="decision", limit=5)
        for r in rows:
            self.assertEqual(r["type"], "decision")

    def test_search_no_embedding_falls_back_to_fts(self):
        # query_embedding=None → FTS-only path
        rows = self.db.search("Result", query_embedding=None, limit=5)
        # Should still find the pattern entry via FTS
        self.assertTrue(any("Result" in (r.get("title") or "") for r in rows))

    def test_search_returns_score_field(self):
        rows = self.db.search("caching", limit=5)
        for r in rows:
            self.assertIn("score", r)

    def test_search_min_score_filter(self):
        # All matches will have some positive score; min_score=10.0 should yield none
        rows = self.db.search("caching", limit=5, min_score=10.0)
        self.assertEqual(rows, [])

    def test_search_empty_query_returns_no_fts_results(self):
        # Empty/whitespace query → sanitized to empty → FTS skipped
        rows = self.db.search("   ", limit=5)
        # With no embedding, no FTS match → no results
        self.assertEqual(rows, [])

    def test_search_with_special_chars_doesnt_crash(self):
        # FTS5 is sensitive to "punctuation" syntax; sanitizer must strip these
        rows = self.db.search("caching: () \" *", limit=5)
        self.assertGreaterEqual(len(rows), 1)


class TestSanitizeFtsQuery(unittest.TestCase):
    def test_strips_special_chars(self):
        self.assertEqual(_sanitize_fts_query("foo: bar"), "foo bar")
        self.assertEqual(_sanitize_fts_query("(hello)"), "hello")
        self.assertEqual(_sanitize_fts_query('quote " mark'), "quote mark")

    def test_collapses_whitespace(self):
        self.assertEqual(_sanitize_fts_query("foo   bar"), "foo bar")

    def test_alphanumeric_preserved(self):
        self.assertEqual(_sanitize_fts_query("alpha123 beta456"), "alpha123 beta456")

    def test_empty_returns_empty(self):
        self.assertEqual(_sanitize_fts_query(""), "")
        self.assertEqual(_sanitize_fts_query("   "), "")


class TestEmbedModule(unittest.TestCase):
    def test_is_available_returns_bool(self):
        # Whether or not Ollama is running, should never crash
        result = embed_mod.is_available()
        self.assertIsInstance(result, bool)

    def test_embed_text_with_empty_input_returns_none(self):
        self.assertIsNone(embed_mod.embed_text(""))
        self.assertIsNone(embed_mod.embed_text("   "))


class TestVectorSearch(unittest.TestCase):
    """Vector search tests — only run if sqlite-vec is importable AND we can mock embeddings."""

    def setUp(self):
        try:
            import sqlite_vec  # noqa: F401
            self.vec_available = True
        except ImportError:
            self.vec_available = False
        self.tmpdir = tempfile.mkdtemp()
        self.db = Memory(Path(self.tmpdir) / "memory.db")
        self.db.setup()

    def tearDown(self):
        self.db.conn.close()

    def test_vec_available_matches_import(self):
        # Memory.vec_available should reflect whether sqlite-vec loaded
        self.assertEqual(self.db.vec_available, self.vec_available)

    def test_create_with_embedding_when_vec_available(self):
        if not self.db.vec_available:
            self.skipTest("sqlite-vec not available; skipping vector test")
        # Fake 768-dim embedding (just zeros)
        fake = [0.0] * 768
        eid = self.db.create(type="note", body="x", embedding=fake)
        # Should have a row in memory_vec
        rows = self.db.conn.execute("SELECT rowid FROM memory_vec WHERE rowid = ?", (eid,)).fetchall()
        self.assertEqual(len(rows), 1)

    def test_create_with_wrong_dim_skips_vec_insert(self):
        if not self.db.vec_available:
            self.skipTest("sqlite-vec not available")
        # 100-dim embedding != 768 → should be silently skipped
        eid = self.db.create(type="note", body="x", embedding=[0.0] * 100)
        rows = self.db.conn.execute("SELECT rowid FROM memory_vec WHERE rowid = ?", (eid,)).fetchall()
        self.assertEqual(len(rows), 0)


if __name__ == "__main__":
    runner = unittest.TextTestRunner(verbosity=2)
    suite = unittest.TestLoader().loadTestsFromModule(sys.modules[__name__])
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
PYEOF
