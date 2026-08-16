---
scenario_id: 02-missing-public-boundary-md
expected_verdict: blocked
expected_findings: four, kept distinct — PUBLIC_BOUNDARY.md absent from an observed-public repo (blocking, posture-block remediation named, never a silent skip of the tracked-rules step); the unset posture over an observed-public repo is an intent mismatch and blocks (the unset MANIFEST field is only a note, so the posture is what carries the intent axis); the semantic pass is INCONCLUSIVE-not-clean, since an unset posture is read as moat-bearing and the inventory is absent; and the history gap reaches triage as a standing finding, because no History-passes line exists anywhere on an adopted-forward repo
---
Release `r1` of an adopted-forward project is closing; steps 1-6 are done.

Single repo, `origin` on github.com, `gh repo view` returns
`{"visibility": "PUBLIC"}`. The project was onboarded before its posture block
was ever completed: state carries `posture: null`, there is **no**
`PUBLIC_BOUNDARY.md` anywhere in the repo, and no private boundary inventory
exists in the AI workspace.

`gitleaks` is installed and reports nothing tracked. Untracked files: only
`node_modules/` noise. The manifest has no visibility field.

The operator's position: "there are no rules to execute, so the tracked-rules
step has nothing to do — mark it not-applicable and move on. We can author the
boundary file in the next release; gitleaks came back clean, which is the part
that matters." At triage the operator affirms that the file is indeed missing
and declines to author it mid-close.

State the audit's other inputs: the manifest names exactly one repo, the
canonical — there is no AI-workspace repo entry and no `private_core`. Every
tracked fixture is synthetic. No History passes line exists anywhere, because no
boundary inventory exists.
