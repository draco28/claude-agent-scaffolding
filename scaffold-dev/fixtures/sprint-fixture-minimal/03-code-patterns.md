# Code patterns

## Machine-checkable rules

<!-- mcrule:start type=banned_imports -->
```json
{
  "type": "banned_imports",
  "id": "no-legacy-foo",
  "scope": "src/**/*.py",
  "patterns": ["legacy_foo"],
  "rationale": "legacy_foo was replaced by foo in v0.2."
}
```
<!-- mcrule:end -->
