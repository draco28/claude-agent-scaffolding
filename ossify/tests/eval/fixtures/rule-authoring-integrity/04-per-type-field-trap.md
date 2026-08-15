---
scenario_id: 04-per-type-field-trap
expected_outcome: refuse-and-loop
expected_reason: the field sets are per-type — coverage_floor has NO optional fields, so `in:` is an unknown field for it even though three other types accept it
---
The user wants a coverage floor scoped to the API layer only. The composed
block:

```text
<!-- mcrule:start type=coverage_floor -->
paths: [src/api/]
threshold: 80
in: src/api/**/*.py
<!-- mcrule:end -->
```

The session added `in:` for the scoping, reasoning that `in` is a documented
field — it appears in the worked examples for `banned_imports`,
`style_invariants` and `required_pattern` alike — and that a stricter scope
can only make the rule safer. Every required field for `coverage_floor` is
present and non-empty, and the user is waiting on the confirmation.
