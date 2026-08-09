# Startup Prompt: ossify deep skill audit & enhancement pass

> Copy everything below the line into a fresh session.

---

## Context

We're working on the `ossify` plugin in the `claude-agent-scaffolding` repo at `/Users/draco/projects/claude-agent-scaffolding`. ossify is a skeleton-first lifecycle plugin (spec → skeleton → releases) that replaces our deprecated `scaffold-onboard` + `scaffold-dev` pair. It uses progressive disclosure: 5-6 entry skills with all ceremony depth in `references/` folders loaded only on entry, so the agent never bloats from skill frontmatter it isn't actively using.

ossify did NOT reinvent its skills from scratch. Most of its skill content was **ported from the deprecated scaffold-onboard and scaffold-dev plugins** and re-anchored to ossify's vocabulary (spines instead of slices, releases instead of sprints, bones registry, cumulative demo ledger, etc.). A lot of this content was ported as-is and **has not been enhanced or reviewed for quality since the port**. That's what this session is about.

## What I need you to do

### Phase 1 — Map the full skill surface

Before auditing, build a complete inventory of every shipped skill and reference doc in `ossify/skills/`. For each entry skill (`start`, `plan-release`, `plan-spine`, `work-item`, `close`, and the planned `doctor`), list:
- Its `SKILL.md` (the entry-point body)
- Every file in its `references/` folder
- File sizes (line count + approximate token count)

Also inventory `ossify/commands/` (the thin dispatchers) and `ossify/agents/` (the implementer-agent system prompt).

### Phase 2 — Deep audit of every skill and reference

Read every `SKILL.md` and every `references/*.md` in ossify, and for each one evaluate:

1. **Quality and depth** — Is the content actually useful guidance, or is it thin filler? Does it teach the agent what to do with enough specificity to be actionable, or does it hand-wave? Flag anything that reads like a placeholder, a restatement of the obvious, or a mechanical checklist pretending to be judgment.

2. **Over-bloat** — Is any skill or reference trying to do too much? Is content duplicated across references? Is there ceremony inflation (process steps that exist for completeness but add no value)? Flag anything that could be trimmed, merged, or restructured.

3. **Under-coverage** — Is anything too thin where it should be deep? Does any reference leave the agent without enough guidance for a judgment call it will actually face? Flag gaps in the guidance itself (distinct from the 7 capability gaps already specced — those are new capabilities; this is about existing content being insufficient).

4. **Staleness from the port** — ossify was ported from scaffold-dev/scaffold-onboard. Did anything keep old vocabulary, old concepts, or old references that no longer apply? Does anything reference slice/sprint concepts instead of spine/release? Does anything assume machinery that works differently now? Flag porting artifacts that need cleaning up.

5. **Consistency** — Do the skills use a consistent voice, structure, and formatting? Do cross-references between references resolve? Does each entry skill's routing logic correctly point to its references?

Produce a structured findings document — one section per skill, with findings tagged by severity (critical / important / minor / nit) and categorized by the five axes above. For each finding, state what's wrong and what the enhancement should be.

### Phase 3 — Enhancement plan

After the audit, produce an enhancement plan that:
- Prioritizes findings by impact (critical first)
- Groups related findings into batches that can be done together
- Estimates the effort per batch (trivial / moderate / significant)
- Identifies which enhancements are safe to do independently vs. which have cross-skill dependencies
- Sequences the work into a proposed execution order

Do NOT start implementing enhancements in this session. The deliverable is the audit findings + the enhancement plan. Implementation happens in a follow-up.

## Reference material you need to read first

Before the audit, read these to understand what ossify is supposed to be (so you can judge what the skills should say):

- **Main design spec**: `docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md` — the skeleton-first lifecycle, vocabulary (§3), lifecycle arc (§4), planning system (§5), execution engine (§6), architecture evolution (§7), skill tree (§9.1)
- **Public/private boundary companion**: `docs/superpowers/specs/2026-07-12-public-private-boundary-design.md` — posture, moat channels, boundary artifacts, multi-repo mechanics
- **Release roadmap**: `docs/superpowers/plans/2026-08-06-ossify-release-roadmap.md` — what shipped (v0.1.0), what's known-gap (v0.2 findings), what's planned (v0.3, v1.0)
- **Capability-gap absorption spec**: `docs/superpowers/specs/2026-08-09-ossify-capability-gap-absorption.md` — 7 new capabilities already specced (debugging, code-review, research, prototype, merge-conflict-resolution, domain-modeling, codebase-design); these are OUT OF SCOPE for this audit since they're new content, not enhancements to existing content

## Source plugins for port comparison

The deprecated plugins that ossify ported from are still in the repo. Use them to spot porting artifacts and assess whether the port improved on the original or just renamed things:

- `scaffold-dev/skills/` — 14 skills (executing-work-item, implementation-checking, closing-vertical-slice, planning-vertical-slice, handing-off-session, deferring-work-item, working-pull-request, etc.)
- `scaffold-onboard/skills/` — 10 skills (onboarding-project, planning-project-roadmap, scaffolding-memory-bank, scaffolding-governance-docs, amending-spec, validating-master-spec, etc.)

When you find an ossify reference that was clearly ported, read the original it came from and assess: did the port add ossify-specific value, or did it just rename terms?

## Constraints

- This is an audit + planning session. Do NOT modify any ossify skills, references, or code. The deliverable is findings + plan only.
- Read-only against the repo. You may create the findings document as a new file under `docs/superpowers/reviews/` when the audit is complete.
- The 7 capability gaps in the absorption spec are separate work — don't fold them into this audit. This is about enhancing what already ships.
- The ossify specs are the source of truth for what skills should do. If a skill deviates from the spec, that's a finding (the skill is wrong, not the spec).

## Token-budget awareness

ossify's progressive-disclosure design targets an every-call listing cost of ~0.3-0.4% of a 200k context window (the 5-6 entry skills' frontmatter descriptions only). All ceremony depth is in `references/` at zero listing cost. The audit should evaluate whether this budget is being respected and whether any skill's frontmatter description is bloated.
