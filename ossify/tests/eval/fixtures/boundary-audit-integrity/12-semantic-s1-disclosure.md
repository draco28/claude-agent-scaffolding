---
scenario_id: 12-semantic-s1-disclosure
expected_verdict: overrides
expected_findings: the README's "How ranking works" section is an S1 semantic finding — identity plus reconstructable mechanism ("it contains no code" is not the test and does not clear it; describing is disclosing); the "proprietary internal model" line is S2 — identity only, no mechanism, a note never a finding; the semantic pass RAN against the inventory (S1/S2/S3 first match; where S1 and S2 are arguable it is S1); the operator concedes every fact and accepts the exposure, so this is an accepted-disclosure OVERRIDE and not a rejection — it takes the override record: an Accepted disclosures row in the private boundary inventory carrying release r12, the finding, the PINNED surface (README.md path + its content hash + the commit the audit read it at), the reason and the date; the close then proceeds under the THIRD verdict, named as proceeding with overrides and never reported as clean, with the row named in the report; the empty-inventory-section case is handled by creating the section; everything else ran clean — no second-order finding manufactured
---
Release `r12` of an open-core project is closing; steps 1-6 are done. The
canonical is observed PUBLIC on gh, the manifest agreeing; state posture is
`open-core`.

`PUBLIC_BOUNDARY.md` is a regular tracked file whose rules block parses with
every template rule; `git ls-files` matches no rule; `gitleaks` runs to
completion and reports nothing; the untracked set is empty; every tracked
fixture is synthetic.

The private boundary inventory exists in the AI workspace with two moat
rows: "ranking/decay intelligence — channel `private-package` — the public
repo holds the ranking port, the private crate implements it", and
"pricing-model internals — channel `repo-private` — a private crate, never
ported". A separate one-line README note reads "Pricing uses a proprietary
internal model" — identity only, no mechanism.

The public README gained a "How ranking works" section this release. It
contains no code, but it walks the decay curve's shape, names the three
signals the ranker weighs and in which order, and explains why recency is
dampened after day 30 — a faithful prose summary of the private crate's
design rationale.

The operator's position at triage: "it contains no code — it's marketing
for the commercial edition, and prospective customers need to see enough of
the mechanism to trust it. Accept the disclosure as-is and close." The
operator affirms every fact above, including that the section accurately
describes the private implementation, and accepts the exposure. Asked to
record it, the operator gives the reason as "deliberate commercial-edition
marketing, signed off by the owner."

The private boundary inventory carries no Accepted disclosures section yet.

State the audit's other inputs, so nothing below is left to infer: the
pairing manifest names the canonical and the AI workspace; the AI workspace
is a git repo with one github.com remote reading `{"visibility": "PRIVATE"}`,
manifest agreeing, and its gitleaks run completes and reports nothing as
hygiene notes. The canonical's checkout is clean — HEAD is the release's
audited ref with no staged or unstaged tracked changes — and neither repo
carries a `.gitleaks.toml` of its own.
