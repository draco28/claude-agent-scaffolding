# Prototype

Depth for SKILL.md §9a's sibling case. The feasibility spike answers *"can
this architecture work at all?"* This file answers the question the spike
cannot: *"what should this **feel** like?"* — a flow whose right shape nobody
can specify until they see it, a state model that reads fine in prose and may
be miserable to drive.

**The boundary with the spike is the falsifier** (this settles the absorption
spec's open question 3): if you can write a check that could *fail*, it is a
spike — build the falsifier. If the answer requires a person looking at
variants and choosing, it is a prototype. Technical uncertainty falsifies;
experiential uncertainty is judged.

---

## 1. When this file applies, and when it does not

**Read this when spec-core surfaces a design question like:**

- "what should this flow look like?" — the journey map names the step but its
  shape is genuinely open;
- "will this state model feel right to drive?" — undo, drafts, optimistic
  updates, anything where the model's ergonomics are the question;
- "which of these interaction patterns do we build?" — and the honest answer
  is that nobody knows until they compare them.

**Do not read this when** the uncertainty is technical (§9a's spike — write
the falsifier), the question is an external fact (`smoke-test-pass.md` or
`research.md`), or the answer is already knowable from the journey map — a
prototype for a question prose has already answered is theatre.

### Its neighbours

| | Uncertainty | Resolved by |
|---|---|---|
| **Feasibility spike** (`spike-contract.md`) | *Technical* — "can it work?" | A falsifier that can fail |
| **This file** | *Experiential* — "which shape is right?" | A person choosing between built variants |
| **Smoke test / research** | *Factual* — "is this true?" | Running a script / reading sources |

Both this file and the spike share one non-negotiable: **`code_fate:
discard`**. They differ only in what the throwaway artifact is.

---

## 2. The contract — written before any code

- **One design question**, named. A prototype answering two questions answers
  neither; cut a second prototype instead.
- **Radically different variants, 2-4 of them.** Variants that differ by
  spacing and color are one variant with moods. If choosing between them
  feels easy, they were not different enough to need building.
- **One shareable HTML file.** State and logic run in the browser; no
  backend, no build step, no dependency on the product tree. A file the
  decision-maker opens is the whole deliverable.
- **One route, variants toggleable** — side-by-side comparison is the point,
  and forcing the chooser to open four files kills it.
- **A named decision-maker and a decision moment.** The prototype exists to
  be judged; unjudged, it is clutter with a deadline nobody set.
- **`code_fate: discard`, non-negotiable.** Scratch location, never merged,
  never "tidied up into" the product. The learned decision is
  **reimplemented** under normal spine ceremony. SKILL.md §9a names the
  failure mode — *prototype laundering* — and it applies here verbatim.

---

## 3. Building it

Only the question's surface is real; everything else is honestly fake. Data
is hardcoded and labeled as such; the parts of the flow not under question
are painted, not built. A prototype that quietly grows real persistence is a
spike wearing makeup — and its `discard` just got expensive to honour.

Keep each variant's *idea* nameable: "modal flow", "inline expand", "wizard".
If a variant cannot be named in three words, it is probably two variants.

---

## 4. The decision record

The prototype is discarded; the **decision** is what survives. Record it
where the question came from:

- a journey-map step's shape settled → the map's row and marks update (SKILL
  §5), and the harvest already covered the non-skeleton steps;
- a state-model choice that is load-bearing and hard to reverse → it is a
  **bone**: ADR with the variant chosen, the ones rejected, and why (SKILL
  §7);
- a surface-level pattern choice → it lands in the spine spec of the spine
  that builds it, at plan time.

One sentence of the record names the prototype's question and outcome, so a
later reader knows the choice was *seen*, not asserted.

---

## 5. Anti-patterns

- **Variant shades.** Three spacings of one idea. The comparison the chooser
  needed never got built.
- **Keeping it.** "It's already written, let's just tidy it up" — the exact
  laundering sentence §9a bans for spikes. Same ban, same reason.
- **Backend creep.** The moment it needs a server, it has left this contract
  — either the question was technical (spike) or the build is product work
  (spine ceremony).
- **Deciding in prose what only eyes can decide.** "We discussed and chose
  the wizard" with nothing built is how a flow ships that nobody ever drove.
- **Prototyping a falsifiable question.** If a check could have failed, the
  spike was cheaper and its answer stronger.

---

*Prior art: mattpocock `prototype` (single-file HTML, variants on one route).
Lineage, not source — this doc is ossify's own.*
