# TDD loop per AC worked example — work-3.2.01

After pre-flight passes (see `pre-flight-check-worked-example.md`), the implementer-agent subagent enters the TDD loop. This walks one AC end-to-end. Composes with `superpowers:test-driven-development` (red-green-refactor) + `superpowers:verification-before-completion`.

## Setup

Work item: `work-3.2.01` — Backend query + endpoint
ACs (5 total): AC-1 query function, AC-2 endpoint, AC-3 auth, AC-4 empty result, AC-5 integration test

Subagent processes ACs in declared order. Each AC: write failing test -> implement -> verify pass -> refactor if needed -> move on.

## AC-1 — `select_action_needed_for_user` query function

### Red — failing test first

Subagent creates `tests/unit/test_insights.py` (does not exist yet — verified during pre-flight):

```python
import pytest
from uuid import uuid4
from db.insights import select_action_needed_for_user, ActionNeededRow

def test_select_action_needed_returns_rows_for_user(seeded_db):
    user_id = seeded_db["users"]["alice"]
    rows = select_action_needed_for_user(user_id)
    assert isinstance(rows, list)
    assert len(rows) == 2  # alice has 2 action_needed rows in fixture
    assert all(isinstance(r, ActionNeededRow) for r in rows)
```

Subagent runs:

```bash
cd /Users/draco/projects/insight-platform/.worktrees/work-3.2.01-backend-query-endpoint && pytest tests/unit/test_insights.py::test_select_action_needed_returns_rows_for_user -x
```

Expected RED: `ImportError: cannot import name 'select_action_needed_for_user' from 'db.insights'` -> confirmed.

### Green — implement minimally

Subagent edits `db/insights.py`:

```python
from dataclasses import dataclass
from uuid import UUID
from db.session import Session  # typed wrapper per banned-imports rule

@dataclass
class ActionNeededRow:
    id: UUID
    user_id: UUID
    title: str
    severity: str
    created_at: str

def select_action_needed_for_user(user_id: UUID) -> list[ActionNeededRow]:
    with Session() as s:
        rows = s.execute(
            "SELECT id, user_id, title, severity, created_at "
            "FROM action_needed WHERE user_id = :uid",
            {"uid": user_id},
        ).fetchall()
    return [ActionNeededRow(**dict(r)) for r in rows]
```

Re-runs test. GREEN -> confirmed.

### Refactor — minimal

No refactor needed; signature matches spec, no duplication. Move on.

## AC-2 — FastAPI endpoint

### Red

Subagent adds endpoint test to `tests/integration/test_insights_endpoint.py`:

```python
def test_get_action_needed_returns_200_with_rows(authed_client, seeded_db):
    response = authed_client.get("/api/insights/action-needed")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
```

Runs: `pytest tests/integration/test_insights_endpoint.py::test_get_action_needed_returns_200_with_rows -x` -> 404 (route doesn't exist). RED confirmed.

### Green

Adds to `api/routes/insights.py`:

```python
from fastapi import APIRouter, Depends
from api.auth import verify_bearer_token
from db.insights import select_action_needed_for_user

router = APIRouter(prefix="/api/insights")

@router.get("/action-needed")
def get_action_needed(user=Depends(verify_bearer_token)):
    rows = select_action_needed_for_user(user.id)
    return [r.__dict__ for r in rows]
```

Re-runs test. GREEN.

## AC-3 — Auth: 401 on unauthenticated

### Red

```python
def test_get_action_needed_returns_401_without_auth(client):
    response = client.get("/api/insights/action-needed")
    assert response.status_code == 401
    assert response.json() == {"detail": "unauthorized"}
```

Per handoff Clarifications section: auth via `verify_bearer_token`, body `{"detail": "unauthorized"}`. Subagent verifies that `verify_bearer_token` already returns this shape -> existing infrastructure. Test passes immediately (GREEN on first run because AC-2 implementation wired in the Depends).

Subagent NOTES this in report.md — "AC-3 verified without new implementation; existing auth dependency satisfies."

## AC-4 — Empty result returns `[]`

### Red

```python
def test_get_action_needed_returns_empty_for_user_with_no_rows(authed_client, seeded_db):
    # bob has no action_needed rows in fixture
    bob_client = authed_client_for(seeded_db["users"]["bob"])
    response = bob_client.get("/api/insights/action-needed")
    assert response.status_code == 200
    assert response.json() == []
```

Runs. GREEN immediately — `select_action_needed_for_user` returns `[]` from DB when no rows match. Endpoint serializes `[]` correctly.

## AC-5 — Integration test covers AC-1..AC-4

Subagent re-runs the integration test file:

```bash
cd /Users/draco/projects/insight-platform/.worktrees/work-3.2.01-backend-query-endpoint && pytest tests/integration/test_insights_endpoint.py -v
```

All 3 tests pass. AC-5 verified (the test file exists and covers AC-1..AC-4 via the endpoint contract).

## Step — Run full verification commands (handoff section 8)

Handoff section 8 lists:
- `pytest tests/unit/test_insights.py -v` -> 1 test passing
- `pytest tests/integration/test_insights_endpoint.py -v` -> 3 tests passing
- `ruff check db/insights.py api/routes/insights.py` -> no findings
- `mypy db/insights.py api/routes/insights.py` -> no errors

All pass. Subagent invokes `superpowers:verification-before-completion` as a sanity check — re-runs the full test suite to confirm no regressions:

```bash
cd /Users/draco/projects/insight-platform/.worktrees/work-3.2.01-backend-query-endpoint && pytest
```

Result: 47 tests pass (the 4 new + 43 pre-existing). No regressions.

## Step — Author report.md

Subagent writes `report.md` at the path specified in handoff section 10 template. See `complete-mode-return-example.md` for the report shape.

## Step — Stage changes (NO commit)

```bash
git -C /Users/draco/projects/insight-platform/.worktrees/work-3.2.01-backend-query-endpoint add -A
git -C /Users/draco/projects/insight-platform/.worktrees/work-3.2.01-backend-query-endpoint status --porcelain
```

Expected output shows the staged changes:
```
A  api/routes/insights.py
M  db/insights.py
A  tests/integration/test_insights_endpoint.py
A  tests/unit/test_insights.py
```

Subagent does NOT run `git commit`. Per SPEC §6.1, the implementer-agent does not have commit capability and the skill body forbids it. Orchestrator commits.

## Step — Return mode=complete

See `complete-mode-return-example.md`.

## Common TDD-loop pitfalls

- **Skipping RED.** Writing implementation first, then test. Detected via missing intermediate `pytest -x` runs in the subagent transcript. The implementer-agent skill body REQUIRES RED-first per TDD discipline.
- **Over-implementing during GREEN.** Writing code beyond what's needed to make the test pass. Refactor step exists separately for cleanup.
- **Combining ACs.** Implementing AC-1 + AC-2 in one go before verifying AC-1. Verification gate becomes opaque; if something breaks, can't isolate. Skill body forces per-AC loop.
- **Forgetting to re-run full suite.** verification-before-completion catches this; check `pytest` (full) ran after all ACs done.
