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

**Never take the version from the cache directory's name.** #368's third
instance had five version-named directories side by side — 1.2.0 through
1.5.0 — and the one that answered was the **oldest**. "Newest directory wins" is
not the resolution rule, and an operator eyeballing the cache will guess wrong.
The manifest at the root that `command -v` actually resolved is the only
version that describes what ran.

**The loaded skill body.** This is the layer #368's first report missed, and it
is a second fact, not a restatement of the first: the command wrapper resolved a
1.2.0 `SKILL.md` while the installed record pinned 1.4.1.

**It is not derivable in Bash, and the obvious attempt fails silently.**
`${CLAUDE_PLUGIN_ROOT}` is *not exported into Bash-tool subprocesses*
(anthropics/claude-code#48230). It expands to the empty string, so a path built
from it becomes `/skills/...` and fails exactly as a missing file would — the
same trap `references/budget-check.md` documents for locating the harness.

Resolve it from the session instead. The wrapper that loaded this body Read it
from a concrete absolute path, and that path is in the session's own transcript.
Take the plugin root from that Read path and read its manifest the same way you
read the binary's. Report the path, not only the version: the path is the
operator's only way to confirm which of several cached roots answered.

**The reference.** §2.

---

## 2. Selecting the reference, and skipping when there is none

Two arms. Context decides, and the read-out says which one it used.

- **A checkout carrying ossify's own manifest.** If `ossify/.claude-plugin/plugin.json`
  resolves on the walk-up path from the working directory, that manifest is the
  reference. The operator is working *on* ossify, and the version they care
  about is the one in the tree in front of them.
- **A consumer project.** Otherwise the reference is the installed record —
  `installed_plugins.json` under the plugins directory — corroborated, where the
  marketplace checkout is present, by that checkout's own ossify manifest.

**Name the arm and name what you read.** A comparison whose basis is unstated
cannot be checked by the operator, and the two arms can legitimately disagree on
a machine that has both a checkout and an install.

**Neither resolvable is `skip:`, with the reason** — no checkout manifest on the
walk-up path and no readable installed record. Never quietly substitute the
other arm, and never infer a reference from the cache directory names (§1).
Silence here is indistinguishable from a comparison that came back clean, which
is the confusion the whole sweep is built to prevent.

---

## 3. The comparison is per ceremony

For every ceremony `SKILL.md` present under the loaded root, compare it against
the same file under the reference root and report **one line per ceremony**:
identical, or differing and in what way. A file present on one side and absent
on the other is itself a delta, not a skip.

**Why per ceremony rather than one verdict, measured rather than assumed.**
#368's third instance diffed the stale body against current for the ceremony the
session had already run. Work-item close was near-invariant from 1.2.0 to 1.5.0
— a `target_repo` read and an `ai_workspace` guard — so that completed close
stood. Spine close was where the same staleness would have caused real damage.
One "your session is stale" verdict spanning both discards exactly the
distinction that tells the operator which of their completed work to revisit.

---

## 4. What this surface does not conclude

- **It does not decide a rerun.** Report the delta and stop. Whether a completed
  ceremony has to be redone is the operator's judgment, informed by the
  per-ceremony lines, and a blanket redo instruction destroys the information
  they would judge it with.
- **It does not rule a ceremony safe.** "Byte-identical" is a fact about two
  files. That a completed close still stands is a conclusion drawn from it, and
  it is not this surface's to draw.
- **It does not update anything.** If the operator asks, name `/plugin update`;
  do not run it, and do not touch the cache. Same discipline as §4's repair
  verbs in `SKILL.md`.
- **It does not re-resolve this session's plugin table.** Nothing here can — §5.

---

## 5. The limits, and they belong in the read-out

Both of these are stated on a **clean** provenance line as readily as on a
failing one. A clean line read as a durable guarantee is this surface's own
failure mode.

- **It is opt-in.** `doctor` runs when it is asked to. A session whose operator
  never runs it gets no provenance signal at all — which is precisely #368's
  three instances. This surface narrows that window; it does not close it.
- **It describes one moment.** The session's plugin resolution table is built at
  session start. An operator who runs `/plugin update` mid-session does not
  change what this session answers with, and nothing here rebuilds the table. A
  clean line means clean **at the moment `doctor` ran**.

---

## 6. Read-out shape

Same tagged grammar as every other surface (`SKILL.md` §14). At minimum: the
binary identity line, the loaded-body identity line, the reference line naming
its arm, and the per-ceremony delta lines — or a plain statement that there are
none, because an omitted comparison and a clean one must not look alike.

A `skip:` on the reference never rolls up to `ok:` for the surface; the roll-up
says `partial` and names what did not run. And where the identities disagree,
the mismatch belongs in the read-out's findings, not only in the surface line —
a finding visible in the transcript but absent from the closing summary is the
same defect §14 names for every other surface.
