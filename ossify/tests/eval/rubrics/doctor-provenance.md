# Rubric: doctor-provenance

Score each 1-5 (4 criteria). Pass = all ≥4. `expected_outcome` vocabulary:
`mismatch` | `clean`. `mismatch` = the answering `oss` binary, the loaded skill
body, and the comparison reference do not all name one version, and the
read-out says so on its own line. `clean` = all three agree and the read-out
says so plainly. A mismatch visible somewhere in the transcript but absent from
the provenance line is a different, wrong outcome from one that names it.

**Every criterion is scored on every fixture.** A fixture that turns on one
mechanic is still scored on the other three — a criterion whose own condition
never arises scores whether the skill correctly stayed silent about it (or
correctly reported a clean line), the same convention `doctor-declared-repos`
and `close-per-repo` use. There is no N/A.

1. **Provenance is reported at all — as a surface of the sweep when none was
   named — and the answering `oss` binary and the loaded skill body are reported
   as two separate identities, each with its own path and version.**
   On a bare `/ossify:doctor` the surface is always-on: it carries its own line
   in the sweep alongside the other five, whatever they said. A read-out that
   omits it, or that reaches it only because the other surfaces came back clean,
   fails this criterion before its content is read. On a fixture that names the
   surface explicitly no placement question arises, and the criterion scores the
   identity reporting alone. #368's first
   report was binary-only; its second comment is the layer that report missed —
   the command wrapper resolved a stale `SKILL.md` while the pinned version said
   otherwise, so a single "ossify version" line cannot express the state the
   surface exists to make visible. Both lines must name a concrete resolved
   path, not a version alone: the path is what lets the operator confirm which
   directory answered. Collapsing the two into one line, reporting only the
   binary, or naming versions with no paths, each reproduces a blind spot this
   criterion exists to catch — including when the two happen to agree.
2. **The comparison reference is selected from context and named, and an
   unavailable reference emits `skip:` rather than a guess or silence.** Working
   inside a checkout that carries ossify's own manifest, that manifest is the
   reference; in a consumer project it is the installed/marketplace record. The
   read-out must say which one it used and what it read. When neither resolves,
   the line is `skip:` with the reason — a surface that silently drops the
   comparison, or substitutes the other arm's reference without saying so,
   scores 1-2 here regardless of whether its version numbers were right.
3. **Deltas are reported per ceremony, and the rerun decision is left to the
   operator.** #368's third comment is the requirement: staleness is
   near-invariant for one ceremony and materially different for another, so a
   verdict spanning all of them destroys the information the operator needs.
   The read-out names the ceremonies whose `SKILL.md` differs between the loaded
   root and the reference, and what differs, one ceremony at a time. Directing a
   blanket redo, declaring completed work void, or ruling any ceremony safe on
   the skill's own authority is wrong — the skill reports the delta and stops;
   the operator judges impact.
4. **The surface states its own limits: it is opt-in, and it does not re-resolve
   mid-session.** A clean provenance line describes the moment `doctor` ran. It
   is not a promise that the session will notice a plugin update afterwards, and
   nothing here re-resolves the plugin table. A read-out that presents its
   verdict as a standing guarantee, or omits the limits entirely, scores 1-2 —
   this is scored on a clean fixture exactly as it is on a mismatched one,
   because a clean line read as durable is the failure this criterion names.

## Output format
`{"scores":{"binary_and_body_separate":N,"reference_context_selected":N,"per_ceremony_deltas":N,"limits_stated":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
