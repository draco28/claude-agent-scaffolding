# Scenario: manifest and dotfile name different trackers

A repo was used with wayfinder before it joined ossify. It carries
`.wayfinder.json` with `{"tracker":"github:acme/notes"}` and two open maps on
that tracker. It has since been paired, so `.workspace/pairing.json` now exists
with `ai_workspace.git_remote` pointing at `github.com/acme/acme-ai`.

The operator runs `/ossify:wayfinder` with no argument.

**What the session must do.**
