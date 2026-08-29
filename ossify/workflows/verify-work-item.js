export const meta = {
  name: 'ossify-verify-work-item',
  description: 'ossify impl-check Layer 4: one reader + one refuter per semantic lens at work-item close',
  phases: [
    { title: 'Read', detail: 'one Sonnet/medium reader per lens, at most 5 findings each' },
    { title: 'Refute', detail: 'one Sonnet/low refuter per lens, id-membership only' },
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
            properties: { file: { type: 'string' }, line: { type: 'integer', minimum: 1 } },
          },
          declared_in_report_s7: { type: 'boolean' },
        },
      },
    },
  },
})

// The refuter NEVER returns a finding object - only which ids survive. This
// is the integrity boundary: a refuter that could re-emit full findings could
// rewrite a claim's text or invent a finding the reader never made, and a
// schema-valid result would sail through with no way to tell it apart from a
// real survivor. Restricting the refuter's own output to an id list, and
// having the SCRIPT (not the refuter) filter the reader's original objects by
// that list, makes fabrication structurally impossible rather than merely
// discouraged by prompt text.
const refuterSchema = {
  type: 'object',
  required: ['survivor_ids'],
  additionalProperties: false,
  properties: {
    survivor_ids: { type: 'array', items: { type: 'string' } },
  },
}

const inputsBlock = () =>
  '- the staged diff: git -C "' + args.inputs.wt + '" diff --cached (quote the' +
  ' path yourself if you run this - it may contain spaces)\n' +
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
    'Return AT MOST 5 findings in the schema. Assign each a short unique id ' +
    '(e.g. "f1", "f2") - the refuter pass will refer to findings by this id only. ' +
    'Every finding cites evidence.file. For fidelity and pattern findings, also ' +
    'cite evidence.line in the staged diff. For an absence finding - something ' +
    'the spec requires that the diff does not contain at all - evidence.file names ' +
    'where it should exist and evidence.line may be omitted; never invent a line ' +
    'number to satisfy the schema. declared_in_report_s7 is true only when report ' +
    '§7 declares the deviation the claim describes. An absence-shaped gap (the diff ' +
    'never attempted something the spec required) is never a fidelity finding, even ' +
    'if it could also read as "fails to do something asked for" - that belongs to ' +
    'the absence lens.',
    { label: 'read:' + lens.id, phase: 'Read', model: 'sonnet', effort: 'medium', schema: readerSchemaFor(lens.id) },
  ),
  (found, lens) => {
    if (!found) { throw new Error('reader for ' + lens.id + ' returned nothing') }
    return counted(
      'You are the refuter for the "' + lens.id + '" lens of an ossify work-item close ' +
      '(impl-check.md §4b).\n\nLENS TEXT (the reader was held to this; check scope against ' +
      'it too, not just evidence):\n' + lens.text + '\n\n' +
      'Try to knock down EACH finding below by re-reading the same inputs. This gate must ' +
      'not fail open: retain a finding UNLESS you find concrete evidence that refutes it - ' +
      'never discard one merely because you are uncertain. A finding is refuted only when ' +
      'it is actually out of this lens\'s scope, the evidence does not hold at the named ' +
      'file (and line, when one is given - an absence finding may have none), or the ' +
      'declared_in_report_s7 value is actually wrong against report §7\'s own text.\n\n' +
      'Inputs:\n' + inputsBlock() + patternExtra(lens.id) +
      'Findings (each already has an id):\n' + JSON.stringify(found.findings, null, 2) +
      '\n\nReturn ONLY the ids of the findings that survive, as survivor_ids. Do not return ' +
      'finding objects, rewritten claims, or new findings - an id from this list, or nothing.',
      { label: 'refute:' + lens.id, phase: 'Refute', model: 'sonnet', effort: 'low', schema: refuterSchema },
    ).then((verdict) => {
      if (!verdict) { return null }
      // The integrity boundary itself: only ids that were actually in the
      // reader's own output can survive, and the finding CONTENT that reaches
      // the caller is always the reader's object, never anything the refuter
      // returned. A refuter hallucinating an id, or trying to smuggle content
      // through some other channel, has no path to affect the result.
      // T3-ANCHOR-START (tests/test-workflows.sh extracts and executes this
      // exact block against fixtures - keep it self-contained: `found` and
      // `verdict` are its only free variables, and it must end in `return`.)
      const validIds = new Set(found.findings.map((f) => f.id))
      const survivorIds = new Set(
        (verdict.survivor_ids || []).filter((id) => validIds.has(id)),
      )
      return { findings: found.findings.filter((f) => survivorIds.has(f.id)) }
      // T3-ANCHOR-END
    })
  },
)

const results = reviewed.filter(Boolean)
if (results.length < args.lenses.length) {
  return { findings: null, agents_run: agentsRun }   // any null lens result -> inline fallback
}
return { findings: results.flatMap((r) => r.findings), agents_run: agentsRun }
