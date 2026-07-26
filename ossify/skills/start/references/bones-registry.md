# Bones registry (forced-enumeration ADRs)

Depth for SKILL.md §7. The bones registry replaces the legacy always-Accepted
ADR-0001 blob. Every bone is **an ADR from birth**, with a declared **touch
surface** and an optional **revisit trigger**.

---

## 1. Why forced enumeration

The failure mode is not wrong answers — it is *unasked questions*. A category
silently omitted at spec-core resurfaces as an unplanned rewrite three releases
later. So every category below is answered **or explicitly marked
`not-applicable` with a one-line reason**. Never silently skipped.

`not-applicable` is a legitimate and common answer at Release 0. "No persistent
state yet — not-applicable, revisit when the first store lands" is a *complete*
answer to the data-ownership category, and it doubles as a revisit trigger.

---

## 2. The nine categories

| # | Category | The question it forces |
|---|---|---|
| 1 | **System shape & deployment topology** | What runs where? One process, client+server, desktop app, CLI, job + worker? What is the deployment unit? |
| 2 | **Module boundaries & dependency direction** | What are the top-level modules and which way do dependencies point? Is there a core that must not depend on adapters? |
| 3 | **Data ownership & migration posture** | Who owns each piece of persistent state? What is the migration story — expand/contract, destructive, none-yet? |
| 4 | **Public contracts & compatibility policy** | What is promised to callers (API, CLI flags, file formats, DB schema)? What is the breaking-change policy? |
| 5 | **Trust boundaries & destructive operations** | Where does untrusted input enter? Which operations are irreversible (spend money, delete data, send to a third party)? |
| 6 | **Failure visibility** | How does a failure become *visible* — logs, metrics, a user-facing error, a dead-letter queue? What must never fail silently? |
| 7 | **Rollback & evolution strategy** | How is a bad release backed out? What is designed to be replaceable vs. what is deliberately load-bearing? |
| 8 | **Stack** | Language, runtime, key frameworks/crates, storage, build/test tooling — and which of those choices are reversible. |
| 9 | **Cross-cutting constraints** | Auth, tenancy, identity, licensing/posture, determinism, i18n, accessibility — whatever cuts across every module. |

The **privacy posture** (§10 of the skill body) lands as a bone in category 9 —
its decision is the posture + channel design, its touch surface is the
private-side modules plus the seam files, its revisit trigger is seeded from
revenue intent. See `references/posture-block.md`.

---

## 3. Anatomy of a bone

Each answered category produces one ADR (or occasionally two, when a category
holds two genuinely separable decisions). Four required parts:

1. **ADR reference** — `ADR-NNNN`, minted in the project's ADR sequence. Bones
   default to the **proposed-then-flip** status protocol: authored `Proposed`
   here, flipped to `Accepted` (with an empirical-validation note) once a real
   release exercised them. A bone that was never exercised has not been
   validated, and saying so in its status is honest.
2. **Title** — the decision in a noun phrase. "Hexagonal core with six port
   traits", not "Architecture".
3. **Touch surface** — the glob set that, when a later spine's plan touches it,
   reclassifies that spine to `bone`. This is the mechanical teeth of the whole
   registry (§4).
4. **Revisit trigger** (optional but strongly encouraged) — the *condition* that
   reopens the decision. Not a date. "Revisit when a second storage backend is
   needed", "revisit when the SaaS decision lands", "revisit at MVP".

### Recording it

```bash
oss bone_add "<ADR-ref>" "<title>" "<touch-glob-csv>" "<revisit trigger>"
```

Worked example:

```bash
oss bone_add "ADR-0002" "Hexagonal core with six port traits" \
  "src/domain/**,src/port.rs,src/adapters/**" \
  "revisit when a second storage backend is needed"

oss bone_add "ADR-0005" "No persistent state at Release 0" \
  "not-applicable" \
  "revisit when the first store lands"
```

The registry entry is the *index*; the ADR file carries the full context /
decision / consequences prose. Keep them consistent — the index is what the
mechanical checks read.

---

## 4. Touch-surface glob semantics

Touch surfaces are matched with **bash `case` glob semantics**, evaluated by
`oss touch_check <path>...`:

- `*` matches **any characters including `/`**. So `src/domain/**` behaves as a
  plain prefix wildcard: it matches `src/domain/order.rs` *and*
  `src/domain/pricing/rules.rs`. There is no real double-star operator — write
  `**` for readability, but understand it as "everything under here".
- `?` matches one character; `[abc]` matches a character class.
- Paths are matched as written in the spine plan — keep them repo-relative and
  consistent with how plans list changed paths.
- `oss touch_check` returns **rc 0 when a path matched** (a hit) and **rc 1 when
  clean** — the inversion is deliberate and callers depend on it. It prints
  `bone <adr>` / `risk_gate <name>` per match. **rc 2 is a third answer, not a
  clean one**: no paths were given, or the state could not be read. It says why
  on stderr; never let a two-branch `if` fold it into "clean".

**Write surfaces that are neither too tight nor too loose.** `src/**` catches
everything and makes every spine a bone (ceremony inflation). `src/domain/order.rs`
alone misses the sibling file the next change lands in. Aim at the directory or
module that embodies the decision.

### The downstream consequence (not this skill's job, but why it matters)

At release planning, a spine whose plan touches **any** registered bone or
risk-gate surface is auto-reclassified to `bone` — independently of, and in
addition to, the architect-critic veto. That is the mechanical, non-skippable
half of class declaration. `plan-release` owns that step; `start` owns making
the surfaces exist and be accurate.

---

## 5. Release-0 minimum

**Only the bones the skeleton actually touches.** The other categories are still
*answered* — most of them with `not-applicable` plus a revisit trigger — but
they do not get elaborate ADR prose at bootstrap. A Release-0 registry of five
short ADRs and four `not-applicable` lines is a complete registry.

Bones grow at release closes, like everything else.

---

## 6. Anti-patterns

- **Skipping a category silently.** The whole point. Answer or mark
  `not-applicable`.
- **A bone with no touch surface.** Then nothing can ever detect that a spine
  moved it; it is a comment, not a bone. (`not-applicable` is the one legitimate
  placeholder — and it matches nothing, deliberately.)
- **Architecture astrology.** A bone for a decision that has no consequence in
  code this year. If you cannot name the touch surface, you are not making a
  decision, you are speculating.
- **Date-based revisit triggers.** "Revisit in Q3" is not a condition; it will
  be ignored. Name the event.
- **Authoring all nine categories at full depth on day one.** See §5.
