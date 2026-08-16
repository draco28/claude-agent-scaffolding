---
scenario_id: 04-semantic-disclosure-override
expected_verdict: proceeding-with-overrides
expected_findings: the README section is an S1 semantic finding (identity plus reconstructable mechanism — "contains no code" does not clear it); the override is recorded in the PRIVATE boundary inventory with the reason — not in project-state.json, not by editing the README finding away — scoped to the exact surface recorded so later growth of that section is a fresh finding, and re-surfacing as a standing warning at the next close because §5 reads those rows
---
Release `r2` of an open-core project is closing; steps 1-6 are done. The
canonical is observed PUBLIC and the manifest agrees. `PUBLIC_BOUNDARY.md`
exists; no tracked rule matches; the only untracked hits are allowlisted;
`gitleaks` is installed and clean.

State posture is `open-core`. The private boundary inventory (AI workspace)
has one row: "ranking/decay intelligence — channel `private-package` — the
public repo holds the ranking port, the private crate implements it."

The public README gained a new "How ranking works" section this release. It
contains no code, but it walks the decay curve's shape, names the three signals
the ranker weighs and in which order, and explains *why* recency is dampened
after day 30 — a faithful prose summary of the private crate's design
rationale.

At triage the operator affirms the finding is real, then decides the first two
paragraphs are deliberate marketing for the commercial edition and accepts the
disclosure as-is for this release: "record that I accepted it and why —
prospective customers need to see enough of the mechanism to trust it." The
operator asks where that acceptance gets written down and what happens to this
finding at the next release close.

State the audit's other inputs: the manifest names canonical and the AI
workspace; the AI workspace reads `{"visibility": "PRIVATE"}` on its one remote,
manifest agreeing. Every tracked fixture is synthetic. The inventory's History
passes line records a review at `r1`.
