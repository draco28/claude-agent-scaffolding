---
description: Incrementally amend an existing MASTER-SPEC.md for a single change (new capability / hardening NFR / scope tweak) — classify, impact-analyze, targeted edit + revision trail — instead of a greenfield whole-bundle re-derive
argument-hint: "<change-request>"
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Capture the free-text change request from `$ARGUMENTS` using the env-var bridge
(no positional `$1`/`$2`/`$N`), then invoke the `scaffold-onboard:amending-spec`
skill. The skill body owns classification, impact analysis, the targeted edit,
SSoT fold-forward, and the propagation handoff (per scaffold-onboard SPEC; design
of record `docs/agent-driven-program/specs/SS-8-amend-spec.md`).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  if [ -z "${ARGS// /}" ]; then
    echo "amend-spec: no change request given — the skill will ask for one."
  else
    echo "amend-spec: change request = ${ARGS}"
  fi
'
```

Now invoke the skill in-conversation:

**`Skill(scaffold-onboard:amending-spec)`** — pass the change-request text above.
The skill body handles:
- **Preflight** — resolve + validate `MASTER-SPEC.md`; route to `/onboard` if it's absent; acquire the onboarding lock.
- **Classify** — net-new capability / NFR-hardening (touch the spec) vs pure maintenance (route to `/defer`, no spec edit).
- **Impact analysis** — which phase section the change lands in, which existing requirements/slices it touches, the prospective new requirement (surfaced, not minted); presented for confirmation before any edit.
- **Targeted edit** — fold the change into the right phase section + a `## Revision History` entry + a bumped `**Spec revision:**` (the schema `**Spec version:**` stays pinned); re-validate.
- **SSoT fold** — merge an amendment note into the affected phase's `phase_record` so `/onboard --regenerate` reconciles it forward instead of clobbering.
- **Handoff** — name what to run to propagate (`/scaffold-docs` to refresh SRS/BACKLOG + assign IDs — honestly flagged as whole-bundle today; optional `/plan-roadmap --add-slice`).

See SKILL §1 for what is intentionally out of scope (diff-aware doc merge, stable ID minting — both deferred).
