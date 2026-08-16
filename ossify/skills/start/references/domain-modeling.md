# Domain modeling

Onboarding already authors a domain vocabulary — implicitly. The journey map
names actors and actions; the bones name entities and ownership. This file
makes that implicit work an **explicit, repeatable discipline**: the terms the
project uses are challenged, defined where they live, and kept true as the
product's understanding deepens.

The failure this prevents is quiet: two artifacts using one word for two
things, or two words for one thing, and every later conversation paying a
small tax that compounds — until a work item ships the wrong behaviour because
"order" meant something different in the spec than in the schema.

---

## 1. When this file applies

- **At onboarding**, alongside the journey map (SKILL §5) and the bones
  registry (SKILL §7) — the moment the vocabulary is being minted anyway.
- **At close time**, when the product's understanding moved: a term changed
  meaning, a new concept emerged, an old one split or died (§4 names the
  mechanism — the bone retro's lessons section is the scheduled pass).
- **Whenever a conversation stumbles** — "wait, what do we mean by X?" asked
  twice about the same X is this file's trigger, not a coincidence.

---

## 2. Where the vocabulary lives — one term, one owner

This settles the absorption spec's open question 2, and the answer is **in
place — no new artifact**:

- **Actor-facing terms** (who does what, and what they see) are owned by the
  **journey map**. Its actor/action/evidence columns are the definition; a
  term used in a demo line means what the map says it means.
- **Decision-bearing terms** (entities, states, ownership) are owned by the
  **bone ADR whose decision defines them**. "What counts as an order" belongs
  to the ADR that chose the order model, next to its touch surface.
- The **vision narrative** and every spine spec *use* terms; they never
  *define* them. A definition appearing anywhere but the term's owner is a
  drift seed.

No `CONTEXT.md`, no glossary file, no new lean-spec section. A second home is
a second copy, and the lean spec's section set is deliberately closed
(`lean-spec-schema.md` §1). The cost of in-place ownership is that finding a
definition means knowing its owner — which is exactly the knowledge the
discipline builds.

---

## 3. The discipline — challenge, then define

Only **contested or load-bearing** terms earn written definitions. The move,
per term:

1. **Stress-test it with edge cases**, out loud: *"Is a refunded order still
   an order? A cancelled one? A draft?"* The definition that survives the
   edges is the one worth writing.
2. **A term that splits under stress is two terms.** If "order" means one
   thing in the ticket and another in the ledger, name both — and grep the
   tree for every site the old word now ambiguously occupies. A rename that
   touches docs but not code (or code but not docs) has made the drift worse,
   not better.
3. **A term two artifacts define differently is a finding, now.** Settle
   which owner is right and fix the other — deferring a definition conflict
   is deferring a bug that already exists.
4. **Write the surviving definition at its owner**, with the edge cases that
   tested it. "An order is X; a refunded order is still one; a draft is not"
   reads like case law because it is — the edges are the content.

---

## 4. Evolution — the model is never done

The domain model deepens as the product does, and its maintenance moments are
already in the lifecycle:

- **Bone-close retrospectives** are the scheduled pass: the full set's
  lessons section routes here (`close/references/retrospective.md` §8 — "we
  kept calling it X and meaning Y" *is* vocabulary drift). The retro
  **records and schedules**; the rename itself is planned work, never a
  mid-close edit. The lean flesh set deliberately has no lessons section,
  so between bone closes the §1 stumble trigger is the pass.
- **A bone superseding** is the architectural cousin of a term changing —
  when a bone's revisit trigger fires, check its terms too; the decision and
  its vocabulary usually move together.
- Between those moments, the §1 stumble-trigger applies: the second "what do
  we mean by X" is the work announcing itself.

---

## 5. Anti-patterns

- **A glossary artifact.** A standalone glossary is the definition's second
  home; it drifts from the owner and then outvotes it, because it *looks*
  authoritative.
- **Defining the uncontested.** A vocabulary where "user" gets a paragraph
  is one nobody reads; definitions are for terms that failed a stress test.
- **The half rename.** Docs say the new word, code says the old one — every
  future reader now translates, forever, and some translate wrong.
- **Settling a definition conflict by picking silently.** The other artifact's
  users don't know they lost; surface it like any contested cut
  (`onboarding-question-subset.md` §3's escalate-don't-decide-silently rule
  applies to words too).
- **Treating the model as finished.** A domain model with no changes across
  three releases is not stable — it is unread.

---

*Prior art: mattpocock `domain-modeling` (stress-test terms, update in
place). Lineage, not source — this doc is ossify's own; ossify's answer to
where vocabulary lives differs from mattpocock's `CONTEXT.md` by design.*
