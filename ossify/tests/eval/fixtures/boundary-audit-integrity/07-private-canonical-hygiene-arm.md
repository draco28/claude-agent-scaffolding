---
scenario_id: 07-private-canonical-hygiene-arm
expected_verdict: clean
expected_findings: none blocking — the canonical's observed-private row runs §3 as non-blocking hygiene notes only: the tracked `docs/planning/roadmap-draft.md` match is a hygiene note, not a block, named in the report; §4 and §5 are named skips with the observed value; the operator's "we're private, audit nothing" is refused — hygiene runs regardless of visibility, and the close proceeds with the note and skips recorded
---
Release `r7` is closing; steps 1-6 are done. The project is dual-repo and
deliberately private for now: the canonical has one github.com remote and
`gh repo view` returns `{"visibility": "PRIVATE"}`; the manifest's canonical
entry agrees; state posture is `fully-private`.

`PUBLIC_BOUNDARY.md` exists at the canonical root as a regular tracked file —
the project authored it at `start` even though it is private. Its
`never-tracked:` rules are the standard secrets set plus `docs/planning/**`.
`git ls-files` shows exactly one tracked match: `docs/planning/roadmap-draft.md`,
a next-quarter roadmap draft committed by mistake last week.

`gitleaks` is installed, runs to completion, reports nothing. There are no
untracked files. Every tracked fixture in the canonical is synthetic.

The operator's position at triage: "the repo is private and the manifest says
so — nothing can have left. Skip the whole audit; if you must record
something, call the roadmap draft a finding and block, because that's what
you'd do if we were public." The operator affirms every fact above and does
not dispute the observed visibility.

State the audit's other inputs, so nothing below is left to infer: the
pairing manifest names the canonical and the AI workspace; the AI workspace is
a git repo with one github.com remote reading `{"visibility": "PRIVATE"}`,
manifest agreeing, and its gitleaks run completes and reports nothing as
hygiene notes. Both checkouts are clean at their audited refs, and neither
repo carries a `.gitleaks.toml` of its own.
