# Rubric: doctor-provenance

Score each 1-5 (4 criteria). Pass = all ≥4. `expected_outcome` vocabulary:
`mismatch` | `clean`.

- **`mismatch`** = the answering binary, the loaded skill body and the reference
  do not all describe one plugin state, **and that includes two roots reporting
  the same version while holding different trees.** Version equality is not tree
  equality: measured in this repository, `close/SKILL.md` differs between commit
  `46f276a` and commit `fe89048` while both declare 1.5.0. A judgment that calls
  a same-version pair clean without comparing their bodies has scored the wrong
  thing, however correct its version numbers were.
- **`clean`** = the identities agree, the comparison ran, and it found nothing.
  All three of those, stated.

A mismatch visible somewhere in the transcript but absent from the provenance
line is a different, wrong outcome from one that names it.

**Every criterion is scored on every fixture.** A fixture that turns on one
mechanic is still scored on the other three — a criterion whose own condition
never arises scores whether the skill correctly stayed silent about it (or
correctly reported a clean line), the same convention `doctor-declared-repos`
and `close-per-repo` use. There is no N/A.

1. **Provenance is reported at all — as a surface of the sweep when none was
   named — the answering binary and the loaded skill body are reported as two
   separate identities each with its own path and version, and any mismatch
   reaches the closing findings.**
   On a bare `/ossify:doctor` the surface is always-on: it carries its own line
   in the sweep alongside the others, whatever they said. A read-out that omits
   it, or that reaches it only because the other surfaces came back clean, fails
   this criterion before its content is read. On a fixture that names the surface
   explicitly no placement question arises, and the criterion scores the identity
   reporting alone. #368's first report was binary-only; its second comment is
   the layer that report missed — a wrapper resolved a stale `SKILL.md` while the
   pinned version said otherwise, so a single "ossify version" line cannot
   express the state the surface exists to make visible. Both lines must name a
   concrete resolved path, not a version alone. Collapsing the two into one line,
   reporting only the binary, or naming versions with no paths, each reproduces
   the blind spot — **including when the two happen to agree.** A root that is
   not one of the two identities, such as the binary's root in a fixture where
   only the loaded body is compared, must not be reported as a comparison input.
   Finally, a `warn:` that appears in the surface line and never in the read-out's
   findings section is that requirement broken, not a presentation choice.
2. **The comparison reference is selected from context and named, and a
   reference missing either half emits `skip:` with a `partial` roll-up rather
   than a guess or silence.** A checkout carrying ossify's own manifest on the
   walk-up path is the reference; otherwise it is the installed record together
   with the root that record points at. The read-out must say which arm it used
   and what it read. A selected reference must resolve **both** an identity and a
   readable comparison root — if either is missing, the line is `skip:` naming
   which half failed and the surface rolls up `partial`. Silently dropping the
   comparison, or substituting the other arm without saying so, scores 1-2 here
   regardless of whether the version numbers were right.
3. **The comparison runs unconditionally over the union of both roots, reports
   one line per skill body including one-sided ones, states plainly when nothing
   differs, and leaves the rerun decision to the operator.** #368's third comment
   is the requirement: staleness is not uniform across bodies, so a verdict
   spanning all of them destroys the information the operator needs. The union
   matters because a body present only under the reference is never visited by an
   iteration over the loaded root, and that is the likeliest shape when one root
   is newer. Matching versions are not grounds to skip the comparison. Where
   nothing differs, saying so explicitly is required — an omitted comparison and
   a clean one must not look alike. Directing a blanket redo, declaring completed
   work void, or ruling any body safe on the skill's own authority is wrong: the
   skill reports the delta and stops.
4. **The surface states its own limits: opt-in, no mid-session re-resolution,
   and it cannot report its own absence.** A clean provenance line describes the
   moment `doctor` ran. It is not a promise that the session will notice a later
   plugin update, nothing re-resolves the plugin table, and a session that loaded
   a body older than this surface gets no provenance line at all — so the cross-
   check for that case has to come from outside the body. A read-out that
   presents its verdict as a standing guarantee, or omits the limits, scores 1-2
   — scored on a clean fixture exactly as on a mismatched one, because a clean
   line read as durable is the failure this criterion names.

## Output format
`{"scores":{"binary_and_body_separate":N,"reference_context_selected":N,"per_ceremony_deltas":N,"limits_stated":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
