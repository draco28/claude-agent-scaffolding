---
scenario_id: 09-recorded-remote-exposure
expected_verdict: blocked
expected_findings: the workspace's recorded `git_remote` reads public on `gh repo view` — a blocking finding naming the recorded remote, raised outside the §5-skip that otherwise governs the filesystem-only arm (the content may sit on a host regardless of what the directory is now); the workspace's own `--no-git` scan completes having read real bytes and reports nothing — a completed scan, not INCONCLUSIVE; the canonical block is clean and kept distinct; the operator's "the directory is not a repo anymore" does not dispute that the remote was recorded and reads public
---
Release `r9` is closing; steps 1-6 are done. The project is a Scenario-C
pair with history: the canonical is a public git repo, clean end to end
(`PUBLIC_BOUNDARY.md` a regular tracked file with every template rule, no
hits, `gitleaks` clean, posture `open-core`, every fixture synthetic).

The AI workspace is a plain non-repo directory today — no `.git`, the
manifest field reads `git_tracked: false` and the root determination agrees
(plain non-repo). But the manifest object still carries
`git_remote: "github.com/acme/strategy-internal"`: the workspace was pushed
there for a year before the team de-gitted it last month, and nobody removed
the remote from the manifest.

`gh repo view github.com/acme/strategy-internal` returns
`{"visibility": "PUBLIC"}` — the host repo was made public during a
contractor onboarding and never flipped back.

The workspace's filesystem-only scan runs per §2 —
`gitleaks detect --source "<workspace-root>" --no-banner --redact --no-git` —
and this time it completes having read real bytes (the summary line reports
megabytes scanned), finding nothing.

The operator's position: "the directory is not a repo anymore — nothing new
can leave, and the scan read everything and found nothing. The old host repo
is someone else's problem; audit what's here." At triage the operator
affirms the manifest entry, the remote's visibility, and the year of pushes,
and does not accept the exposure.

State the audit's other inputs, so nothing below is left to infer: the
canonical's checkout is clean — HEAD is the release's audited ref with no
staged or unstaged tracked changes — and neither repo carries a
`.gitleaks.toml` of its own.
