export const meta = {
  name: 'ossify-verify-work-item',
  description: 'ossify impl-check Layer 4: one reader + one refuter per semantic lens at work-item close',
  phases: [
    { title: 'Read', detail: 'one Sonnet/medium reader per lens, at most 5 findings each' },
    { title: 'Refute', detail: 'one Sonnet/low refuter per lens, survivors only' },
  ],
}

// args.lenses: [{id, text}] - the three impl-check.md §4b lenses, verbatim.
// args.inputs: {spec, report, handoff, patterns, wt} - absolute paths from the close.
// Pure orchestration: the lens texts, the paths and the verdict rule all live
// elsewhere (C1). Returns {findings, agents_run}; findings === null means the
// close falls back inline.

const schemaFor = (lensId) => ({
  type: 'object',
  required: ['findings'],
  additionalProperties: false,
  properties: {
    findings: {
      type: 'array',
      maxItems: 5,
      items: {
        type: 'object',
        required: ['lens', 'claim', 'evidence', 'declared_in_report_s7'],
        additionalProperties: false,
        properties: {
          lens: { type: 'string', enum: [lensId] },
          claim: { type: 'string' },
          evidence: {
            type: 'object',
            required: ['file', 'line'],
            additionalProperties: false,
            properties: { file: { type: 'string' }, line: { type: 'integer' } },
          },
          declared_in_report_s7: { type: 'boolean' },
        },
      },
    },
  },
})

const inputsBlock = () =>
  '- the staged diff: git -C ' + args.inputs.wt + ' diff --cached\n' +
  '- spec: ' + args.inputs.spec + '\n' +
  '- handoff: ' + args.inputs.handoff + '\n' +
  '- report (§7, Deviations from spec, decides declared_in_report_s7): ' + args.inputs.report + '\n' +
  '- documented patterns: ' + args.inputs.patterns + '\n\n' +
  'Read-only: do not write, edit, or run any mutating command.\n'

let agentsRun = 0
const counted = (prompt, opts) =>
  agent(prompt, opts).then((r) => { if (r) { agentsRun += 1 } return r })

phase('Read')
const reviewed = await pipeline(
  args.lenses,
  (lens) => counted(
    'You are the "' + lens.id + '" lens of an ossify work-item close (impl-check.md §4b).\n\n' +
    'LENS TEXT (apply exactly as written):\n' + lens.text + '\n\n' +
    'Inputs (read them yourself):\n' + inputsBlock() +
    'Return AT MOST 5 findings in the schema. Every finding cites evidence {file, line} ' +
    'in the staged diff. declared_in_report_s7 is true only when report §7 declares the ' +
    'deviation the claim describes.',
    { label: 'read:' + lens.id, phase: 'Read', model: 'sonnet', effort: 'medium', schema: schemaFor(lens.id) },
  ),
  (found, lens) => {
    if (!found) { throw new Error('reader for ' + lens.id + ' returned nothing') }
    return counted(
      'You are the refuter for the "' + lens.id + '" lens of an ossify work-item close. ' +
      'Try to knock down EACH finding below by re-reading the same inputs. ' +
      'Default to refuted=true when uncertain; a finding survives only if the evidence ' +
      'holds at the named file and line, and (for a fidelity claim) report §7 really ' +
      'does not declare the deviation.\n\nInputs:\n' + inputsBlock() +
      'Findings:\n' + JSON.stringify(found.findings, null, 2) +
      '\n\nReturn ONLY the survivors, in the same schema.',
      { label: 'refute:' + lens.id, phase: 'Refute', model: 'sonnet', effort: 'low', schema: schemaFor(lens.id) },
    )
  },
)

const results = reviewed.filter(Boolean)
if (results.length < args.lenses.length) {
  return { findings: null, agents_run: agentsRun }   // any null lens result -> inline fallback
}
return { findings: results.flatMap((r) => r.findings), agents_run: agentsRun }
