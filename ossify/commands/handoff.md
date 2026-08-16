---
description: Compose a session handoff — judge where it lives from repo evidence, write the six-section core, state the read-out first; never refuses
argument-hint: "[topic]"
allowed-tools: Bash(git:*), Read, Write, Edit, Glob, Grep
---

Topic, if one was given: $ARGUMENTS

Read `${CLAUDE_PLUGIN_ROOT}/references/handoff/compose.md` end to end and follow
it. It owns the whole ceremony: the location judgment, the tracked-vs-ignored
decision, the six-section core (whose template and adaptation guidance live in
`${CLAUDE_PLUGIN_ROOT}/references/handoff/sections.md`), the read-out, the
commit decision, and the failure behaviour.

Two rails survive any adaptation:

- **Never refuse for structural reasons.** No pairing manifest, no docs tree,
  not even a git repo — every one of those changes *where* the handoff goes,
  never *whether* it is written. Degrade and report, one line each.
- **No topic given is not a gap.** Derive one from the work in front of you and
  say so in the read-out.

This is a generic utility: it belongs to no ossify ceremony and no lifecycle
stage, and it works in any repository, ossify-initialised or not. The other
half is `/ossify:handoff-resume`, which re-verifies a handoff's claims against
the live repo before a fresh session acts on it.
