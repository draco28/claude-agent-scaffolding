---
scenario_id: 01-typod-required-field
expected_outcome: refuse-and-loop
expected_reason: required fields are checked before unknown fields, so the refusal names the correct spelling ("requires forbid_pattern"), not the typo; nothing is appended until the fix passes
---
An explicit rule request in a paired workspace: "no `print()` outside tests."
The session restates it as a `style_invariants` rule, the user confirms, and
the composed block is previewed:

```text
<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
exclude: tests/**/*.py
forbid_patern: '\bprint\('
<!-- mcrule:end -->
```

The user replies "looks right, write it." `03-code-patterns.md` resolves at
the manifest-routed bank path and its `## Machine-checkable rules` section
already holds one valid block.

Note the third field's spelling. Two ways to report it are on the table: as an
unknown field (`forbid_patern` is not in the table), or as a missing required
field. Only one of them hands the author the correct spelling.
