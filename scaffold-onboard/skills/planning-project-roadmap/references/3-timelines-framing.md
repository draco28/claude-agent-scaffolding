# 3-Timelines Framing — Why Phase / Sprint / Vertical Slice Map to Three Horizons

> Companion reference for `planning-project-roadmap` §4. Read this when you're about to open R1.A and want to internalise the *why* behind the three verbatim framing prompts before pasting them into the conversation.

---

## 1. Source

The 3-timelines framing originates from the **"Hidden Rules of Success" transcript, principle #4** — captured in the internal ghost-notes notes (lines 90-122) and the `project_thinking_discipline_content` auto-memory, then integrated into scaffold-onboard v0.2 per HANDOFF §3.5 (2026-05-22 spec-review pass).

The principle compresses to three success orientations:

- **Be a visionary** — operate on the 5-year horizon.
- **Be valuable** — ship 12-18 month value windows that compound.
- **Be visible** — close demoable 90-day cycles that others can see.

scaffold-onboard's R1 hierarchy is a 1:1 mapping of these three horizons onto its three node types:

| Horizon (transcript) | R1 node | Timeframe band |
|---|---|---|
| Visionary | **Phase** | ~5-year shape |
| Valuable | **Sprint** | ~12-18 months |
| Visible | **Vertical Slice** | ~90 days |

This is the only legitimate mental model for the hierarchy. Anything else (annual roadmaps, quarterly planning grids, sprint-of-Scrum) is a different framing and will produce a different shape of decomposition.

---

## 2. The three verbatim framing prompts

These three strings are **canonical onboarding vocabulary**. They appear unchanged in SPEC §5.4, the SKILL.md body (§4.1 / §4.2 / §4.3), and the eval (S4). The em-dashes are load-bearing — paste them verbatim, do not normalise to ASCII hyphens.

### R1.A — Phases

> Your Phases are your visionary horizon — what's the project's 5-year shape?

### R1.B — Sprints

> Sprints are your value-building windows — what gets built over 12-18 months that compounds?

### R1.C — Vertical Slices

> Vertical slices are your visibility cycles — what ships demoably in 90-day-ish windows?

Eval scenario S4 explicitly FAILs on substantive deviation. *"Long-term vision"* in place of *"visionary horizon"* is a fail. *"Phases represent..."* in place of *"Your Phases are..."* is a fail. The framing is treated as a fixed string, not a paraphrasable explanation.

---

## 3. Why this framing? (vs. the obvious alternatives)

### Avoids the micro trap

The obvious failure mode in roadmap authoring is **collapsing the highest horizon into work-items**. Users frequently come in with backlogs of week-by-week tasks ("auth refactor", "deploy script", "fix the export bug") and want to call those phases. That produces a 40-phase roadmap that is really a TODO list — no actual visionary content, no compounding value windows, no demoable cycles.

The 5-year framing forces the user to answer a different question: *what does the project SHAPE look like at the end?* Not what gets done first. Not what's hardest. What's the eventual silhouette.

### Avoids the macro trap

The other failure mode is **10-year wishlists**: vague aspirational phases ("become the industry standard", "achieve product-market fit", "ship to enterprise") with no anchoring on shippable value. That produces a roadmap that reads like a pitch deck — emotionally satisfying, but R1.B and R1.C have nothing concrete to bite into.

The 12-18 month framing for sprints forces the user to commit to a value window: *something tangible that compounds, observable within roughly a year, not handwavy ambition*. And the 90-day framing for slices forces concrete visibility: *something demoable*, not internal-only progress.

### Forces VALUE articulation at each horizon

The three horizons each correspond to a different kind of question the user must answer:

- **Phase** — what's the project's *shape*? (visionary — what does it look like from far away?)
- **Sprint** — what *value compounds*? (valuable — what builds on what?)
- **Vertical slice** — what's *demoable*? (visible — what can someone else see?)

Each is a forcing function. Skipping the framing — or paraphrasing it into a generic "describe your phases" prompt — collapses the three different questions into one, and the user defaults to the most familiar one (usually a sprint-of-Scrum frame). That hollows out R1.A and R1.C.

---

## 4. When to gently push back on the user's first answer

The framing is canonical; the user's answer to it is not. You're allowed (and expected) to push back when the answers don't fit the horizon they were asked about.

### Signal: user proposes 8+ phases

This almost always means the user is confusing **phases with sprints**. The visionary horizon doesn't have 8 distinguishable shapes — at 5 years out, projects have 3-6 visible silhouettes, not 8+. When you see 8+ proposed phases, gently offer:

> *Quick check — at a 5-year horizon, projects tend to have 3-6 distinguishable shapes. The list you gave me looks more like 12-18 month sprints. Would you like to step back and group these into 3-5 visionary phases, then we'll capture the sprint-level detail in R1.B?*

This is an offer, not a correction. The user has final authority (per §15). But the gentle nudge protects them from authoring a roadmap that flattens the three horizons into one.

### Signal: user proposes 1-month vertical slices

This usually means the user is confusing **vertical slices with work items** (tickets, PRs, individual tasks). A 1-month slice almost certainly isn't visible end-to-end — it's mid-implementation. When you see proposed slices that are clearly sub-90-day, offer:

> *Quick check — vertical slices are the 90-day visibility cycle: each one should be demoable end-to-end at close. A 1-month chunk usually maps to a work item inside a slice, not the slice itself. Want to group these into 2-3 month visibility windows?*

Again: offer, not correction. The user retains agency over their hierarchy.

### Signal: user names 2 phases, both very large

This often means the user is comfortable in the macro frame (5-year vision) but hasn't divided it into distinguishable shapes. With only 2 phases, R1.B and R1.C have very little structure to hang on. Offer:

> *2 phases is on the low end of the visionary horizon. Some users find it useful to break the second phase into "first half" and "second half" — what's distinguishable about the silhouette early vs. late? Optional — 2 phases is valid if it really is two shapes.*

---

## 5. Anti-patterns: things this framing is NOT

### Sprint ≠ Scrum sprint

A Scrum sprint is a 1-2 week timeboxed development cycle with a backlog refinement ritual. **R1's Sprint is not that.** R1's Sprint is a 12-18 month value-building window — closer to what some teams call a "quarter theme" or "annual objective" than to a Scrum iteration.

If a user starts using Scrum vocabulary ("velocity", "story points", "burndown"), gently re-anchor:

> *Heads up — this skill's "Sprint" is a 12-18 month value window, not a Scrum 2-week sprint. You can still run Scrum sprints inside a Sprint, but the R1 hierarchy itself isn't tracking Scrum cadence.*

### Vertical slice ≠ single PR

A vertical slice in R1 is a **90-day demoable cycle**. It usually spans many PRs, multiple feature branches, possibly several work-streams. It is NOT a single pull-request-sized unit of work — that's a work-item, which lives inside a slice (and is scaffold-dev's concern, not scaffold-onboard's).

If a user proposes slices that look PR-sized ("add login endpoint", "write user model migration"), they've collapsed the visibility horizon into a work-item horizon. Offer the re-frame in §4 ("1-month vertical slices" signal).

### Phase ≠ release version

A Phase isn't "v1.0" / "v2.0" / "v3.0". Release versions are an *outcome* of the roadmap (often roughly aligned to phase boundaries), but a Phase is the **visionary horizon shape**, not a release label. Users sometimes try to align Phases 1:1 with semver majors — that's fine if it happens to fit the project, but don't enforce it. The horizon-shape question is the primary one.

### Phase ≠ team / org structure

A Phase isn't "the platform team's work" or "the frontend phase". The horizons are time-based (5y / 12-18m / 90d), not org-chart-based. If a user proposes phases by team ("Phase 1: data team, Phase 2: ML team"), that's a different decomposition — probably useful, but not the R1 hierarchy. Offer:

> *That looks like an org-chart decomposition rather than a time-horizon one. R1's Phases are 5-year shapes — what's the project's silhouette in 5 years, regardless of which team builds it? The team mapping can land in a separate doc.*

---

## 6. Quick reference card

| Horizon | R1 node | Verbatim prompt opener | Push back when... |
|---|---|---|---|
| Visionary (~5y) | Phase | *"Your Phases are your visionary horizon..."* | 8+ proposed; org-chart frame; release-version frame |
| Valuable (~12-18m) | Sprint | *"Sprints are your value-building windows..."* | Scrum-cadence frame; 1-2 week sprints proposed |
| Visible (~90d) | Vertical Slice | *"Vertical slices are your visibility cycles..."* | PR-sized proposed; internal-only "slices" proposed |

When in doubt, read the verbatim prompt out loud. If the user's answer would still make sense as a response to that exact wording, accept it. If their answer is responding to a different question than the one you asked, surface the gentle reframe.
