# Workspace interop check

The depth behind `doctor/SKILL.md` §7. Absorbed from `scaffold-onboard`'s
`checking-workspace-interoperability` (spec §8.1), so the unified plugin owns
the question and `workspace-init` stays unchanged.

**Check only.** Spec §9.1 allocates `doctor` an *interop check*; the additive
repair half was scaffold-onboard's own extension and is not shipped here. This
surface reports and names the fix. It does not edit the manifest and does not
touch `AGENTS.md`.

---

## 1. The question

*Can this workspace be driven by Claude Code and by Codex, interchangeably,
mid-project, without either one silently working from different assumptions?*

Everything below is a way that question comes out **no**.

```bash
oss interop_check
```

Same line grammar as `oss doctor` — `ok:` / `fail:`, one line per check, rc 1
if anything failed — because a single read-out should not carry two
vocabularies.

---

## 2. What was absorbed: the question, not the checklist

The scaffold-onboard original requires ten `.routing.*` keys including
`roadmap`, `sprint_specs` and `implementation_handoffs`, plus a
`.workspace/locks` directory.

**Every one of those is an artifact this stack retired.** `ROADMAP.md` is
replaced by the feature map plus `RELEASE.md`; sprint specs by spine specs;
`PROJECT_PLAN.md` outright. ossify's lock is a `<state>.lock` directory beside
the state file, not a workspace-wide one.

Porting that key set would make `doctor` report a correctly-configured ossify
project as broken for not having the previous stack's furniture — a check whose
failures are all false is worse than no check, because someone will eventually
"fix" a healthy project to satisfy it.

**If you are ever tempted to add a key here, the test is: does an ossify
ceremony read it?** If nothing reads it, its absence is not a finding.

---

## 3. The four checks

### `manifest`

The workspace-init pairing manifest, discovered by walking up from `$PWD`.

Absent → **`fail:`, and the check returns immediately.** Every later check reads
the manifest, so continuing would emit four derived failures for one root cause
and bury the only thing that has to be fixed first. Remedy: `/init-workspace`
(new workspace) or `/pair-workspace` (existing canonical repo) — name those
tokens literally, do not paraphrase them.

### `canonical` and `ai_workspace`

Both roots must resolve to real directories. Resolution goes through the same
resolver every other ossify verb uses, which substitutes `${...}` tokens and
refuses a path that only *looks* absolute — reading the raw JSON value instead
would pass a manifest that every real call then fails on.

Two distinct failures, deliberately worded apart:

| Line | Means |
|---|---|
| `is absent, holds an unresolved ${...} token, or is not absolute` | the manifest is wrong |
| `resolved root is not a directory: <path>` | the manifest is right and the directory moved |

The second is the one that happens to real projects, usually after a repo is
renamed or moved.

### `state_path`

The state file's path must resolve. It does **not** have to be routed.

`.well_known_paths.project_state` is honoured when present; when absent, the
path derives as `<ai_workspace.root>/.ossify/project-state.json`. **Both forms
are manifest-absolute**, so both resolve identically from any directory, and an
unrouted manifest is therefore **not** an interop risk and is not reported as
one.

What *is* a risk is a path that does not resolve at all — an unresolved
`${...}` token resolves differently depending on which variables a given
session's environment happens to carry, which is precisely two agents driving
two different files.

### `agents_md`

The check that is actually about Codex.

`AGENTS.md` in the AI workspace must exist **and name ossify**. `AGENTS.md` is
the only file Codex reads for project instructions: a workspace whose
`AGENTS.md` never mentions ossify has a Codex session driving the project with
none of its ceremonies — no spine planning, no close gates, no demo ledger —
while the state file goes on recording a lifecycle nobody is following.

The match is case-insensitive, so a `## Ossify` heading satisfies it.

Two failures:

| Line | Remedy |
|---|---|
| `no AGENTS.md at <path>` | author one; it is the Codex-side entry point |
| `never mentions ossify` | add a section routing Codex to the ossify ceremonies |

**Do not write or edit `AGENTS.md` yourself.** It holds user-authored content,
and this surface has no managed-section contract to merge into — that machinery
belongs to the repair half that is deliberately not shipped here. Report the
line, name the fix, stop.

---

## 4. What this check cannot tell you

Stated so a green result is not over-read:

- **Whether a Codex session will actually behave.** The check is four
  presence-and-resolution facts. `AGENTS.md` mentioning ossify is not the same
  as `AGENTS.md` describing it correctly.
- **Whether the two agents agree on anything else** — model config, tool
  availability, or which branch is checked out.
- **Anything about `.codex` memory.** There is no Codex memory mirror and there
  should not be one: the shared source of truth is the pairing manifest, the
  lean spec, the memory bank and `project-state.json`. If you find a `.codex`
  memory tree, that is drift worth reporting in the read-out, not a thing to
  create.
