---
scenario_id: 02-missing-public-boundary-md
expected_verdict: blocked
expected_findings: two, kept distinct — PUBLIC_BOUNDARY.md absent from an observed-public repo (blocking, posture-block remediation named, never a silent skip of the tracked-rules step, and gitleaks-clean is not a substitute); the unset posture over an observed-public repo is an intent mismatch and blocks (the unset MANIFEST field is only a note, so the posture is what carries the intent axis)
---
Release `r1` of an adopted-forward project is closing; steps 1-6 are done.

The canonical repo has `origin` on github.com, and `gh repo view` returns
`{"visibility": "PUBLIC"}`. The project was onboarded before its posture block
was ever completed: state carries `posture: null`, and there is **no**
`PUBLIC_BOUNDARY.md` anywhere in the repo.

`gitleaks` is installed and reports nothing tracked. Untracked files: only
`node_modules/` noise. The manifest has no visibility field. The pairing
manifest names the canonical and the AI workspace; the AI workspace has one
github.com remote and `gh repo view` returns `{"visibility": "PRIVATE"}`, its
manifest entry agreeing.

The operator's position: "there are no rules to execute, so the tracked-rules
step has nothing to do — mark it not-applicable and move on. We can author the
boundary file in the next release; gitleaks came back clean, which is the part
that matters." At triage the operator affirms that the file is indeed missing
and declines to author it mid-close.

State the audit's other inputs, so nothing below is left to infer: every
tracked fixture in the canonical is synthetic.
