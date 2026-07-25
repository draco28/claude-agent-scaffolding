# Feasibility spike contract

Depth for SKILL.md §9a. The feasibility spike is lifecycle **station 3** (spec
§4) — optional, explicit, and **disposable by contract**. It is routed under
`start` because the uncertainty it resolves is a spec-core uncertainty.

---

## 1. When to offer a spike

Offer a spike only when spec-core surfaces **genuine architectural
uncertainty** — you cannot responsibly write the bone because you do not know
whether the shape works at all.

Signals that the bar is met:

- A bone's decision hinges on behavior nobody in the room has observed (e.g.
  "can an agent-first modeling core hold a coherent 3D scene graph?").
- Two candidate architectures differ so much that picking wrong means a rewrite,
  and no cheap fact distinguishes them.
- The core product hypothesis itself is technical ("is this even possible with
  today's models?").

Signals that the bar is **not** met — do a smoke test instead
(`references/smoke-test-pass.md`):

- You need to confirm a crate name, a version, an API signature, a platform fact.
- You are "just not sure it'll be fast enough" with no bone depending on it.
- You want to try a library you find interesting.

Offer it **explicitly**, as a question with a cost attached, and accept "no" as
the default answer. Most projects should not need a spike.

---

## 2. The contract (all six fields, written before any code)

A spike without a written contract is just unsupervised coding with a good
excuse. Record all six:

| Field | Rule |
|---|---|
| **Hypothesis** | Exactly **one**, stated as a falsifiable proposition. "An LLM-driven modeling loop can produce a valid, editable scene graph from three successive natural-language edits." |
| **Falsifier** | The concrete observation that would make you say *no*. "Any of the three edits corrupts the graph, or requires hand-editing the file to continue." Written **before** the run; a spike with no falsifier always succeeds. |
| **Timebox** | Wall-clock, decided upfront (hours, at most a couple of days). At expiry you stop and answer with what you have — an expired spike is a *no* by default, not an extension request. |
| **`code_fate: discard`** | Non-negotiable. Scratch branch or throwaway worktree, **never merged**. |
| **Evidence retained** | What survives deletion: transcripts, measurements, screenshots, the decision note. Named upfront so it actually gets captured. |
| **Decision it enables** | Which bone this unblocks. If you cannot name the bone, you are not spiking, you are exploring. |

---

## 3. `code_fate: discard` — what it really forbids

The sole sanctioned output of a spike is **learnings folded into the spec**.

- The spike branch is **never merged**, and never "cleaned up and merged".
- Learned behavior is **reimplemented** inside the product, under the normal
  spine ceremony (spec, TDD, demo line, review). Not copy-pasted.
- "It's already written, let's just tidy it" is **prototype laundering** — the
  named failure mode this contract exists to block. The predecessor stack's
  most expensive defects entered exactly this way.
- Spikes **inherit applicable risk-gate controls**. A spike never touches live
  money, live customer data, or any destructive surface — if the hypothesis
  requires that, the hypothesis is wrong for a spike.

A two-track "semi-disposable tracer" (keep the good parts) was proposed and
**rejected on record** (spec §15 decision #11): it reintroduces the laundering
seam. The disposable spike plus a lean Release 0 covers both tracks without it.

---

## 4. Running one

1. Write the contract (§2). Show it to the user; get an explicit go.
2. Create a scratch branch or throwaway worktree, clearly named
   (`spike/<hypothesis-slug>`).
3. Build the *least* thing that can trip the falsifier. Not a demo, not a
   prototype of the product — an experiment.
4. Stop at the timebox or at the first clear answer, whichever comes first.
5. Write the decision note: hypothesis, what happened, falsifier tripped or not,
   the decision, the evidence links.
6. **Delete the code.** Fold the decision into the bone's ADR (and, if it
   changed the plan, into the lean MASTER-SPEC).
7. If the spike surfaced work, `oss feature_add "<name>" "<value>" "<class>" spec`.

---

## 5. Reading the result

- **Falsifier not tripped** → the bone is written with the spike cited as
  evidence. The bone can flip from `Proposed` to `Accepted` earlier than usual.
- **Falsifier tripped** → the bone is written the *other* way, and that is a
  success. A spike that kills a bad architecture before a line of product code
  paid for itself many times over.
- **Timebox expired, inconclusive** → record `inconclusive`, take the
  reversible option, and give the bone a revisit trigger. Do not extend by
  reflex; an inconclusive spike is itself information (the question was too big
  or badly framed).

"PoC" is reserved for exactly this output — disposable proof. Per the doctrine
companion: *if code is expected to survive, it is not a PoC.*

---

## 6. Anti-patterns

- **Merging the spike.** Every other rule here exists to prevent this one.
- **A spike with no falsifier**, or one written after the fact.
- **Multiple hypotheses in one spike.** You will not know which one the result
  belongs to.
- **Spiking to avoid deciding.** If the decision is reversible and cheap, decide,
  add a revisit trigger, and move.
- **Skipping the spike offer entirely when the uncertainty is real.** Writing a
  bone you cannot justify is architecture astrology.
