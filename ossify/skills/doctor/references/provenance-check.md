# Provenance check

Depth for `doctor/SKILL.md` §9. The surface answers one question — **which
ossify actually answered this session** — and it exists because that question
went unanswered for three separate sessions (#368), each time for a whole
session, each time invisibly.

This file is prose end to end. There is no verb for any of it and there should
not be: every step is reading a file and saying what it found.

---

## 1. Three identities, resolved independently

They are three because they can disagree, and #368 is the record of them doing
it. Reporting one number for "the ossify version" cannot express the state the
surface exists to make visible.

**The answering binary.** `command -v oss` prints the `oss` actually on `$PATH`
in this session. Its plugin root is the parent of the `bin/` that holds it; read
`.claude-plugin/plugin.json` there for the version.

**Resolve symlinks before deriving that root.** A symlink on `$PATH` answers
`command -v` with its own location, and the parent of *that* `bin/` is not the
plugin root — it is whatever directory the link sits in. Follow the link to its
target first, and derive the root from where the real file lives.

**A regular wrapper is a different case, and it fails safe.** Where `command -v`
resolves an ordinary file that is not itself a plugin-root binary — a launcher
that execs the real `oss` from somewhere else — there is no link to follow and
the plugin root cannot be derived from its location. The binary identity is then
`skip:` naming that reason, unless the real target can be established some other
way. Do not fall back to the loaded body's root, and do not read a version out of
a cache directory name. Wrapper support for the OpenCode bundle specifically is
deferred rather than solved here.

**Never take the version from the cache directory's name.** #368's third
instance had five version-named directories side by side and the one that
answered was the **oldest**. "Newest directory wins" is not the resolution rule,
and an operator eyeballing the cache will guess wrong. The manifest at the root
that resolution actually reached is the only version that describes what ran.

**The loaded skill body.** This is the layer #368's first report missed, and it
is a second fact, not a restatement of the first: the command wrapper resolved a
1.2.0 `SKILL.md` while the installed record pinned 1.4.1.

**It is not derivable in Bash, and the obvious attempt fails silently.**
`${CLAUDE_PLUGIN_ROOT}` is *not exported into Bash-tool subprocesses*
(anthropics/claude-code#48230). It expands to the empty string, so a path built
from it becomes `/skills/...` and fails exactly as a missing file would — the
same trap `references/budget-check.md` documents for locating the harness.

Resolve it from the session instead: **the path this body was loaded from,
whatever loaded it.** A slash-command wrapper Reads it from a concrete absolute
path that is in the transcript. A description-match invocation has no wrapper and
may leave no such path — and when the transcript holds none, **the loaded-body
identity is `skip:` with that reason**. Do not substitute the binary's root for
it: they are the two facts this surface exists to separate, and assuming they
agree is the defect, not the shortcut. Report the path, not only the version:
the path is the operator's only way to confirm which of several roots answered.

**The reference.** §2.

---

## 2. Selecting the reference, and one rule for everything that can go wrong

Two arms. Context decides, and the read-out says which one it used.

- **A checkout carrying ossify's own manifest.** If `ossify/.claude-plugin/plugin.json`
  resolves on the walk-up path from the working directory, that checkout is the
  reference. The operator is working *on* ossify, and the version they care
  about is the one in the tree in front of them.
- **A consumer project.** Otherwise the reference is the installed record —
  `installed_plugins.json` under the plugins directory — together with the
  checkout or cache root that record points at.

**One rule covers every way this fails, and it is deliberately not a matrix of
arms.** A selected reference must resolve **both** halves: an identity (which
version it claims) **and** a readable comparison root (a tree whose skill bodies
can actually be read). If either half is missing, emit `skip:` naming which half
failed, and the surface rolls up `partial` rather than `ok:`.

That single rule covers the cases an arm matrix would enumerate one by one: a
readable installed record with no ossify entry; a record naming a root that is
not on this machine; a marketplace checkout present with no installed record to
select it; and both arms unresolvable. **Never quietly substitute the other
arm**, and never infer a reference from cache directory names (§1). Silence is
indistinguishable from a comparison that came back clean, which is the confusion
the whole sweep is built to prevent.

---

## 3. The comparison is over the union of skill bodies, and it always runs

Build the **union** of skill-body names present under the loaded root and under
the reference root, then report **one line per body**: identical, differing and
in what way, or present under one root only. A body on one side and not the
other is a delta, not a skip — and it is the likeliest shape when one root is
newer, which is exactly when this surface is being read.

**Iterating the loaded root alone is the bug this paragraph replaces.** A body
that exists only in the reference is never visited, so a newly added skill goes
unreported while the read-out claims a complete comparison.

**"Skill bodies", not "ceremonies".** `doctor` is an entry skill and explicitly
*not* a ceremony (`SKILL.md` §1), so a comparison scoped to ceremonies would
exclude the very body running the comparison. Every `skills/<name>/SKILL.md`
under either root is in scope.

**The comparison runs whether or not the identities agree, and it says so when
nothing differs.** Two roots can report the same version and still hold
different trees — measured in this repository's own history, where `close/SKILL.md`
differs between commit `46f276a` and commit `fe89048` while both declare version
1.5.0. Version equality is therefore not evidence of tree equality, and skipping
the comparison because the numbers matched would miss precisely that case. An
omitted comparison and a comparison that found nothing must not look alike.

**Why per body rather than one verdict.** #368's third comment is the
requirement: the operator diffed the stale body against current for the ceremony
they had already run, and what they needed was per-ceremony impact rather than a
blanket redo. Staleness is not uniform — one body can be untouched across
several versions while another changed materially — and a single "your session
is stale" verdict discards the distinction that tells the operator which of
their completed work to revisit.

**The limit, stated rather than implied: this compares `SKILL.md` bodies only.**
Files under `references/` are not read, and a good deal of ceremony prose lives
there — `close/references/work-item-close.md` and `references/work-pr/loop.md`
among them. So a differing `close/SKILL.md` is reported as one delta and cannot
be resolved further here, and staleness confined to a reference file produces no
delta at all. Say this when reporting; do not let a clean body comparison read
as a clean plugin.

---

## 4. What this surface does not conclude

- **It does not decide a rerun.** Report the delta and stop. Whether a completed
  ceremony has to be redone is the operator's judgment, informed by the per-body
  lines, and a blanket redo instruction destroys the information they would
  judge it with.
- **It does not rule a ceremony safe.** "Byte-identical" is a fact about two
  files. That a completed close still stands is a conclusion drawn from it, and
  it is not this surface's to draw — the more so given the `references/` gap
  above.
- **It does not update anything.** If the operator asks, name `/plugin update`;
  do not run it, and do not touch the cache. Same discipline as §1's rule in
  `SKILL.md` — surface the line, name the verb, let the user run it.
- **It does not re-resolve this session's plugin table.** Nothing here can — §5.

---

## 5. The limits, and they belong in the read-out

All three are stated on a **clean** provenance line as readily as on a failing
one. A clean line read as a durable guarantee is this surface's own failure mode.

- **It is opt-in.** `doctor` runs when it is asked to. A session whose operator
  never runs it gets no provenance signal at all — which is precisely #368's
  three instances. This surface narrows that window; it does not close it.
- **It describes one moment.** The session's plugin resolution table is built at
  session start. An operator who runs `/plugin update` mid-session does not
  change what this session answers with, and nothing here rebuilds the table. A
  clean line means clean **at the moment `doctor` ran**.
- **It cannot report its own absence.** This surface ships in the skill body it
  diagnoses. A session that loaded a body older than 1.7.0 has no provenance
  surface: a bare `doctor` reports the five older surfaces, and the `provenance`
  token is unrecognised and runs the sweep. So the very staleness most worth
  catching is the case where nothing here runs at all. The cross-check has to
  come from outside the body — read the plugin manifest at the resolved root
  directly, or run `/plugin update` and start a fresh session. Bootstrapping it
  inside the plugin was considered and rejected: a wrapper loads from the same
  versioned root and is stale identically, and a mechanical verb that reads two
  manifests and reports is exactly what `docs/conventions/skill-first.md` puts on
  the prose side.

---

## 6. Read-out shape and tag grammar

Same tagged grammar as every other surface (`SKILL.md` §14). At minimum: the
binary identity line, the loaded-body identity line, the reference line naming
its arm, the per-body comparison lines — or a plain statement that nothing
differs — **and all three of §5's limits.**

All three are required every time; omitting any one leaves that limit's failure
mode unreported.

The grammar, and nothing here is a gate:

- **No identity mismatch and no deltas → `ok:`.**
- **An identity mismatch, or any body delta → `warn:`, plus a finding.**
- **An unresolved identity, reference, or comparison root → `skip:` naming what
  did not resolve, and the surface rolls up `partial`.**

A `skip:` never rolls up to `ok:`. And where anything came back `warn:`, it
belongs in the read-out's findings section, not only in the surface line —
`SKILL.md` §14 requires findings to be carried there worst-first, so a `warn:`
visible in the transcript and absent from the findings is that requirement
broken.
