export const meta = {
  name: 'ossify-verify-work-item',
  description: 'ossify impl-check Layer 4: one reader + one refuter per semantic lens at work-item close',
  phases: [
    { title: 'Read', detail: 'one Sonnet/medium reader per lens, at most 5 findings each' },
    { title: 'Refute', detail: 'one Sonnet/low refuter per lens, full-coverage verdicts only' },
  ],
}

// args.lenses: [{id, text}] - the three impl-check.md §4b lenses, verbatim.
// args.inputs: {spec, report, handoff, patterns, wt} - absolute paths from the close.
// Pure orchestration: the lens texts, the paths and the verdict rule all live
// elsewhere (C1). Returns {findings, agents_run}; findings === null means the
// close falls back inline.

const readerSchemaFor = (lensId) => ({
  type: 'object',
  required: ['findings'],
  additionalProperties: false,
  properties: {
    findings: {
      type: 'array',
      maxItems: 5,
      items: {
        type: 'object',
        required: ['id', 'lens', 'claim', 'evidence', 'declared_in_report_s7'],
        additionalProperties: false,
        properties: {
          id: { type: 'string' },
          lens: { type: 'string', enum: [lensId] },
          claim: { type: 'string' },
          // `line` is required for `fidelity` and `pattern` - both point at a
          // hunk that exists in the staged diff - but NOT for `absence`: that
          // lens is about something the diff never contains at all, so there
          // is no line to cite. A prompt instruction alone is not enforcement
          // (a reader can drift), so the schema itself gates it per lens
          // rather than trusting every agent to have read the prompt closely.
          // `file` is required for every lens - it can always name where the
          // artifact should exist, even when the artifact itself is not.
          evidence: {
            type: 'object',
            required: lensId === 'absence' ? ['file'] : ['file', 'line'],
            additionalProperties: false,
            properties: { file: { type: 'string', minLength: 1 }, line: { type: 'integer', minimum: 1 } },
          },
          declared_in_report_s7: { type: 'boolean' },
        },
      },
    },
  },
})

// The refuter returns a VERDICT PER FINDING ID, never a finding object - this
// is the integrity boundary. Three properties fall out of "one verdict per
// input id, always":
//   - retain/discard is explicit per id, so an incomplete or truncated
//     response is DETECTABLE (missing or extra ids fail coverage) instead of
//     silently reading as "everything not mentioned was refuted".
//   - declared_in_report_s7 is the refuter's OWN re-verified value, so a
//     refuter that catches the reader mis-tagging that field can correct it
//     without having to discard an otherwise-real finding to do so.
//   - claim/evidence/lens never appear in this schema at all, so there is no
//     channel for the refuter to rewrite or invent finding content - the
//     script assembles the final object from the READER's own data, with
//     only declared_in_report_s7 overwritten by the refuter's verdict.
const refuterSchema = {
  type: 'object',
  required: ['verdicts'],
  additionalProperties: false,
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'retain', 'declared_in_report_s7'],
        additionalProperties: false,
        properties: {
          id: { type: 'string' },
          retain: { type: 'boolean' },
          declared_in_report_s7: { type: 'boolean' },
        },
      },
    },
  },
}

// POSIX single-quote escaping: wrap in single quotes, and any embedded single
// quote becomes '"'"' (close the quote, emit an escaped single quote via
// double quotes, reopen). Double-quoting alone (the previous form) still lets
// $, `, and $() through if the path happens to contain them; single-quoting
// disables all shell interpretation except the quote character itself, which
// this handles explicitly.
const shellQuote = (s) => "'" + String(s).split("'").join("'\"'\"'") + "'"

const inputsBlock = () =>
  '- the staged diff: git -C ' + shellQuote(args.inputs.wt) + ' diff --cached\n' +
  '- spec: ' + args.inputs.spec + '\n' +
  '- handoff: ' + args.inputs.handoff + '\n' +
  '- report (§7, Deviations from spec, decides declared_in_report_s7): ' + args.inputs.report + '\n' +
  '- documented patterns: ' + args.inputs.patterns + '\n\n' +
  'Read-only: do not write, edit, or run any mutating command.\n'

const patternExtra = (lensId) =>
  lensId === 'pattern'
    ? 'This lens is about conventions the repo follows IN FACT, not just what ' +
      '03-code-patterns.md documents - the inputs above are a floor, not a ' +
      'ceiling. Read the relevant neighbouring files in the worktree yourself ' +
      'before judging; the fixed input list alone cannot establish an ' +
      'undocumented convention.\n\n'
    : ''

let agentsRun = 0
const counted = (prompt, opts) =>
  agent(prompt, opts).then((r) => { if (r) { agentsRun += 1 } return r })

phase('Read')
const reviewed = await pipeline(
  args.lenses,
  (lens) => counted(
    'You are the "' + lens.id + '" lens of an ossify work-item close (impl-check.md §4b).\n\n' +
    'LENS TEXT (apply exactly as written):\n' + lens.text + '\n\n' +
    'Inputs (read them yourself):\n' + inputsBlock() + patternExtra(lens.id) +
    'Return AT MOST 5 findings in the schema. Assign each a SHORT, UNIQUE id ' +
    '(e.g. "f1", "f2" - never reuse one within this response) - the refuter pass ' +
    'will refer to findings by this id only. Every finding cites evidence.file. For ' +
    'fidelity and pattern findings, also cite evidence.line in the staged diff. For an ' +
    'absence finding - something the spec requires that the diff does not contain at all ' +
    '- evidence.file names where it should exist and evidence.line may be omitted; never ' +
    'invent a line number to satisfy the schema. declared_in_report_s7 is true only when ' +
    'report §7 declares the deviation the claim describes. An absence-shaped gap (the diff ' +
    'never attempted something the spec required) is never a fidelity finding, even ' +
    'if it could also read as "fails to do something asked for" - that belongs to ' +
    'the absence lens.',
    { label: 'read:' + lens.id, phase: 'Read', model: 'sonnet', effort: 'medium', schema: readerSchemaFor(lens.id) },
  ).then((found) => {
    if (!found) { return null }
    const ids = found.findings.map((f) => f.id)
    // Duplicate ids from the reader are ambiguous input no downstream check
    // can safely resolve (which of two same-id findings does a verdict
    // apply to?) - treat exactly like a reader that returned nothing.
    if (new Set(ids).size !== ids.length) { return null }
    return found
  }),
  (found, lens) => {
    if (!found) { throw new Error('reader for ' + lens.id + ' returned nothing, or duplicate ids') }
    return counted(
      'You are the refuter for the "' + lens.id + '" lens of an ossify work-item close ' +
      '(impl-check.md §4b).\n\nLENS TEXT (the reader was held to this; check scope against ' +
      'it too, not just evidence):\n' + lens.text + '\n\n' +
      'Try to knock down EACH finding below by re-reading the same inputs. This gate must ' +
      'not fail open: retain (retain=true) a finding UNLESS you find concrete evidence that ' +
      'refutes it - never discard one merely because you are uncertain. Refute (retain=false) ' +
      'only when it is actually out of this lens\'s scope, or the evidence does not hold at the ' +
      'named file (and line, when one is given - an absence finding may have none). If your only ' +
      'disagreement is the declared_in_report_s7 value, do NOT refute the finding for that alone - ' +
      'retain it and correct the value instead; that field is exactly what you are re-verifying ' +
      'against report §7\'s own text, and a wrong label is not the same as a false claim.\n\n' +
      'Inputs:\n' + inputsBlock() + patternExtra(lens.id) +
      'Findings (each already has an id):\n' + JSON.stringify(found.findings, null, 2) +
      '\n\nReturn ONE verdict per finding id above, no more and no fewer - every id must appear ' +
      'exactly once in verdicts, each with your own retain decision and your own re-verified ' +
      'declared_in_report_s7. Do not return finding objects, claims, or evidence - ids and your ' +
      'two judgments on each, nothing else.',
      { label: 'refute:' + lens.id, phase: 'Refute', model: 'sonnet', effort: 'low', schema: refuterSchema },
    ).then((verdict) => {
      // T3-ANCHOR-START (tests/test-workflows.sh extracts and executes this
      // exact block against fixtures - keep it self-contained: `found` and
      // `verdict` are its only free variables, and it must end in `return`.)
      if (!verdict) { return null }
      const readerIds = found.findings.map((f) => f.id)
      const readerIdSet = new Set(readerIds)
      const entries = verdict.verdicts || []
      const verdictIds = entries.map((v) => v.id)
      // Coverage must be EXACT: same count, same set, no id repeated. Partial
      // or padded coverage is untrustworthy - null this lens (-> inline
      // fallback) rather than silently treat a missing id as "refuted" or an
      // extra one as ignorable.
      const coversExactly =
        readerIds.length === entries.length &&
        new Set(verdictIds).size === verdictIds.length &&
        readerIds.every((id) => new Set(verdictIds).has(id)) &&
        verdictIds.every((id) => readerIdSet.has(id))
      if (!coversExactly) { return null }
      const byId = new Map(entries.map((v) => [v.id, v]))
      return {
        findings: found.findings
          .filter((f) => byId.get(f.id).retain)
          .map((f) => ({ ...f, declared_in_report_s7: byId.get(f.id).declared_in_report_s7 })),
      }
      // T3-ANCHOR-END
    })
  },
)

const results = reviewed.filter(Boolean)
if (results.length < args.lenses.length) {
  return { findings: null, agents_run: agentsRun }   // any null lens result -> inline fallback
}
return { findings: results.flatMap((r) => r.findings), agents_run: agentsRun }
