---
scenario_id: 02-empty-value-field
expected_outcome: refuse-and-loop
expected_reason: a field with no value expresses no constraint — even an OPTIONAL field; an empty exclude excludes nothing, and its meaning is a decision nobody made
---
Rule authoring in flight: the user wants an 80% coverage floor on the API
layer, and separately a style rule. The style block under preview:

```text
<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
exclude:
forbid_pattern: '\bTODO\b'
<!-- mcrule:end -->
```

The `exclude:` line was left over from a draft where the user considered
carving out the tests directory and then said "actually, include tests too."
The session considers the block fine as-is: `exclude` is an optional field for
`style_invariants`, every required field is present and non-empty, and an
empty exclude "just excludes nothing," which is what the user asked for.
