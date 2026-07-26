# Demo authoring — the journey-line floor

Depth for SKILL.md §8. This is the binding contract for what a spine contributes
to the **cumulative product demo ledger**.

The ledger is an **operated asset**, not a list. Every `auto:` line joins a suite
re-run at *every* future spine close; every `user:` line joins a walkthrough a
human performs at *every* release close. A line you add today is paid for
repeatedly by everyone who works on this product afterwards. That is why the floor
is a floor and not a guideline.

---

## 1. The five floors

| | Floor | Applies to |
|---|---|---|
| **F1** | Every spine contributes **≥1 demo line** | every spine |
| **F2** | A user-facing spine contributes **≥1 `user:` journey line** = verb + observable outcome. Inspector phrasing banned | user-facing spines |
| **F3** | An internal spine contributes **`auto:` lines only**, and is admitted only if it **names the committed consuming user-facing spine**, scheduled in the current or next release | internal spines |
| **F4** | A pass claiming a **measured quality** (performance, reliability, cost) states **before/after evidence** in its demo contribution | deepening passes |
| **F5** | Every `auto:` line binds to a **runnable command + declared expected** (`exit:<n>` \| `contains:<str>`) at authoring time | every `auto:` line |

An internal spine **cannot claim product value** — not in its own demo lines, not
in the release's exit criteria, not in the retro.

---

## 2. The read-out

Judge the whole contribution once, out loud, before any `oss ledger_add_*` call:

```text
Demo contribution — <spine-id> "<name>"   [user-facing | internal]
  F1  at least one line        pass|fail       <n> lines
  F2  user: journey line       pass|fail|n/a   "<the line>"
  F3  enabler names consumer   pass|fail|n/a   <consumer spine-id> in <release-id>
  F4  measured-quality proof   pass|fail|n/a   before <x> → after <y>, via <command>
  F5  auto: lines bind         pass|fail       <command> → exit:<n>|contains:<str>
  Verdict: ACCEPT | REJECT — <the floor that decided it>
```

`n/a` is specific, never a dodge:

- **F2 `n/a`** only for an *admitted internal* spine (which may not have one).
- **F3 `n/a`** only for a user-facing spine (which needs no consumer).
- **F4 `n/a`** only for a spine claiming no measured quality. A spine whose plan
  says "faster", "more reliable", "cheaper" anywhere is claiming one.

**REJECT ⇒ no ledger call.** The remedy is always to fix the contribution, never
to record it and plan a follow-up: re-phrase (F2), name a consumer or send the
spine back to the feature map (F3), measure (F4), state the command (F5).

---

## 3. F2 — judging a `user:` journey line

### 3.1 The test

> **Who performs this action, and why?**

A **user** places a trade, exports a report, resumes a session, cancels an order,
recovers a password — for the value the action produces. A **developer** inspects
a schema, views a record, opens a file, confirms a table exists, checks that a
row was written — to verify an artifact is present.

If the line only makes sense with a developer and a debugger behind it, it is not
a journey line, whatever verb it opens with.

### 3.2 Banned shapes

- **Artifact inspection** — "inspect the schema", "view the record", "open the
  generated file".
- **Artifact existence as the outcome** — "…to confirm the table exists", "…and
  see the row is there", "…and the file is present". Existence is not an outcome
  a user came for.
- **Protocol-level evidence** — "the endpoint returns 200", "the job exits 0".
  Those are `auto:` lines wearing a `user:` label.
- **The passive dodge** — "the report is available to the user". No actor
  performs anything; nothing is observed.

### 3.3 The ban is on the action, not on the outcome

Every journey line ends in something the user can **see** — that is exactly what
"observable outcome" means. A line whose outcome is visible is **meeting** the
floor, not violating it.

Rejecting a line because the words *see*, *appear*, *shows*, or *displays* occur
in its outcome half is the **false-reject** failure mode. It is as damaging as
letting an inspector line through, because it pushes authors toward vague lines
with no observable half at all — which is how a ledger fills with `user:` lines
nobody can actually walk.

**Read the verb the user performs, and judge that.**

### 3.4 Worked pairs

| Proposed line | Verdict | Why |
|---|---|---|
| "view the generated invoice record to confirm the totals column is populated" | **REJECT** | Inspection verb *and* artifact-existence outcome. A developer checking a column, not a user getting value |
| "export last month's invoices as a PDF and see the download land with the right totals" | **ACCEPT** | Action = exporting (value); outcome = the file the user wanted, with the number that makes it correct. The visible outcome is the floor being met |
| "open the settings file and change the retention window" | **REJECT** | The action is editing a file by hand. If retention is a product setting, the line is "change the retention window to 30 days from settings and see old records stop appearing" |
| "the search index is queryable" | **REJECT** | Passive; no actor, no action, no observed outcome |
| "search for a customer by partial name and see matching records ranked by recency" | **ACCEPT** | Verb + observable outcome, both halves present |
| "resume an interrupted upload and see it finish from where it stopped" | **ACCEPT** | The visible "finish" is the evidence; the action is resuming |

### 3.5 The mechanical backstop and its exact scope

`oss ledger_add_user <spine> <text> <outcome>` lowercases `<text>`, trims leading
whitespace, and rejects it **only if it begins with** `inspect `, `view `, or
`open ` — exit **2**, nothing written.

The check is **prefix-only and three words long**. All of these are accepted by
the lib and are still inspector lines you must reject yourself:

- "lets the user open the settings file" (the ban word is not first)
- "review the generated schema"
- "confirm the audit table exists"
- "check that the record was written"
- "the report is available to the user"

**A rc 0 from `ledger_add_user` is not a verdict.** The lib exists so a typo
cannot smuggle the obvious case past you; the floor lives in this document and in
your judgment. Never cite "the command accepted it" as evidence a line is a
journey line.

---

## 4. F3 — internal-spine admission

Two judgments, in order. Conflating them is how the anti-foundation-phase rule
gets defeated.

**Judgment 1 — is it internal?** The spine has no actor-to-outcome journey: its
evidence of completion is that an artifact exists. **`plan-release` makes this
call** — its own `references/class-declaration.md` owns the ladder — and declares
it at release-planning time by prefixing the spine's name with `[internal]` and
recording the admission in the `class_set` reason. **Read that, do not recall it**
(SKILL.md §3 resolves `$name` alongside `$class`):

```bash
case "$name" in "[internal]"*) echo "internal — auto: lines only" ;; esac
oss get ".class_overrides[] | select(.spine == \"$spine\") | .reason"   # the admission record
```

You may be re-entered in a session that never saw the planning conversation. The
name marker and the reason string are the only durable carriers of this fact —
`.class` is `bone|flesh` and cannot express it (`spine_add` rejects
`internal-enabler` with exit 2, so an admitted enabler is stored under its
structural class). A spine that looks internal *here* but carries neither marker
nor admission reason is a planning miss: surface it, do not quietly re-label it.

**Judgment 2 — is it admitted?** Admitted **only if** it names:

1. a **committed user-facing spine** that consumes it — a real spine, with an id
   or a named candidate, not a capability area; **and**
2. that spine is scheduled in the **current release or the next** — the
   one-release-ahead cap.

Check both against state, not against recollection (`$rel` is the spine's release,
resolved at SKILL.md §3):

```bash
oss spine_list | jq -r '.[] | "\(.id)\t\(.release)\t\(.name)"'          # every planned spine
oss get ".releases[] | select(.id == \"$rel\") | .next_sketch"          # next release's candidates
```

A consumer named among the current release's spines, or in the current release's
`next_sketch.candidates`, satisfies the cap. A consumer three releases out, or on
the feature map only, does not.

Both reads are `jq -r` without `-e`: a no-match is **rc 0 with empty output**, so
judge the *output*. An empty `next_sketch` means `plan-release` never sketched the
next release — then the cap has nothing to read and the enabler is **not
admitted** until it does. That is the correct fail direction: the sketch is the
data structure this rule reads, not a courtesy to the reader.

**Silence is not a named consumer.** If the plan in front of you does not name
one, the answer is *not admitted* — do not assume a consumer exists because one
plausibly could. Send it back:

```bash
oss feature_add "<name>" "<the value it would enable>" bone feature-map-return
```

If the consuming spine is later **dropped**, the internal spine returns to the
feature map too. The dependency runs both ways.

### 4.1 Worked pairs

| Proposed contribution | Verdict | Why |
|---|---|---|
| An auth-token refresh layer contributing `auto:` lines only, justified as *"the mobile app will use it eventually"* | **REJECT — not admitted** | "Eventually" names no spine and no release. This is the exact phrasing the rule exists to reject; back to the feature map |
| A search-index writer contributing `auto:` lines only, naming the committed spine "saved searches" scheduled in **this** release | **ACCEPT — admitted** | Named, committed, in range. `auto:` only; it may not claim product value |
| A session-replay store contributing `auto:` lines only, naming a committed spine scheduled in the **next** release's sketch | **ACCEPT — admitted** | The one-release-ahead cap is *inclusive* of the next release; the sketch is the recorded object the rule reads |
| A normalization layer contributing `auto:` lines only, whose consumer is "the reporting area, sometime after v1" | **REJECT — not admitted** | A capability area is not a spine, and "after v1" is outside the cap |
| An internal spine that also proposes a `user:` line so it "has product value" | **REJECT** | An internal spine contributes `auto:` only. If it genuinely has a journey, it was misclassified at release planning — go fix that, do not launder it here |

---

## 5. F4 — before/after evidence

A pass claiming a measured quality must state, in its demo contribution:

1. the **before** number, measured on the pre-spine build, with the command that
   produced it;
2. the **after** target, as a bound (not a hope);
3. an `auto:` line that **re-measures and fails when the bound is missed**.

Closing green on the pre-existing test suite measures nothing — the suite was
green before the spine too. That is the failure this floor exists to block.

The `expected` grammar has **no comparison form** (`exit:<n>` | `contains:<str>`
only), so **the threshold lives inside the command**: the benchmark script does
the comparison and exits non-zero when the bound is missed.

```bash
# before: recorded in the spine plan — `hyperfine ./target/release/app --json` → cold start 4.2s
oss ledger_add_auto "$spine" "cold start ≤ 2.0s (was 4.2s)" "bash scripts/bench-coldstart.sh --max 2.0" "exit:0"
```

| Proposed contribution | Verdict |
|---|---|
| "cut cold-start time in half" — closes on the existing smoke test, no numbers stated | **REJECT** — no before, no after, nothing measured |
| "cold start 4.2s → ≤2.0s", bound to `bench-coldstart.sh --max 2.0` | **ACCEPT** |
| "make the importer more reliable" — no failure-rate baseline | **REJECT** — reliability is a measured quality; measure it or drop the claim |
| "importer retries transient failures" with an `auto:` line asserting the retry path, and **no** reliability claim in the plan | **ACCEPT** — F4 is `n/a`; nothing measured is being claimed |

The last row matters: F4 is not a tax on every spine. It fires on the **claim**.
A spine that does not claim a measured quality does not owe a measurement — and a
spine that wants to keep its claim owes one.

---

## 6. F5 — `auto:` line binding

```bash
oss ledger_add_auto "$spine" "<text>" "<command>" "exit:0|contains:<str>"
```

`<expected>` is validated as `exit:<n>` or `contains:<str>`; anything else exits
**2** and writes nothing. The command must be runnable from the composition root
against **canonical post-merge state** — not from a worktree, not with a developer's
local env var, not with a manual setup step in someone's head. If setup is
required, the command performs it.

**A line that can't state its command doesn't enter the ledger.** "We'll figure
out how to test this later" is a rejected line, not a recorded one.

Watch the cost: `oss ledger_active_auto` lists what the ledger already carries,
and the release's `ledger_budget` (set at `plan-release`) is the wall-clock
ceiling. A contribution that will not fit forces a prune / parallelize / deepen
decision — raise it now, with the user, rather than letting the suite grow past
its budget silently.

---

## 7. Anti-patterns

- **Citing `ledger_add_user`'s rc 0 as proof a line is a journey line.** Prefix
  check, three words, backstop only (§3.5).
- **Rejecting a line because its outcome is visible** (§3.3).
- **Admitting an enabler on an unnamed or out-of-range consumer** (§4).
- **Letting an internal spine contribute a `user:` line** or claim product value.
- **A measured-quality claim that closes green on the pre-existing suite** (§5).
- **Recording a line you intend to fix later.** The ledger is cumulative.
- **Authoring demo lines at roadmap time** — the reason they moved here is that
  roadmap time has no implementation context.
- **Running the demo here.** `close` owns the run; you author the criteria.
