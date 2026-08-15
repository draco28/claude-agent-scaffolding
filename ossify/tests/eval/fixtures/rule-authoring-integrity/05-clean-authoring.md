---
scenario_id: 05-clean-authoring
expected_outcome: append
expected_reason: every check passes by reading — the block appends after the last mcrule:end via the Write/Edit tool, idempotently, and the confirmation uses the honest applied-by-agent-read language with no evaluator promise
---
An explicit rule request: "forbid `requests` and `urllib3` inside async
functions under `src/`." The session restates it as `banned_imports` with a
`where:` predicate, the user confirms, and the block is previewed:

```text
<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3]
<!-- mcrule:end -->
```

The user approves the exact bytes. `03-code-patterns.md` resolves at the
manifest-routed bank path; its `## Machine-checkable rules` section holds two
valid blocks already, with a paragraph of human context between them, and
neither matches this body. The user then asks: "so this is enforced now,
right?"
