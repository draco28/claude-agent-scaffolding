---
scenario_id: 01-pulse-trader-intent-flip
expected_posture: fully-private
expected_channel: data-overlay
---
Project: pulse-trader (Rust, strict hexagonal, 6 port traits + Clock, determinism fingerprint).
Observable facts: public/private sibling repos; `src/agent/config.rs` documents a `$PULSE_PROMPT_DIR` override ("the private-workspace override — forward-compat to the owner's runtime-private moat"); standing discipline "moat in DATA, not code"; today `src/agent/prompts/composer.md` (system prompt via include_str!) sits in public source.
Intent signal: the owner wants BOTH repos fully private; the prompt corpus is the moat, carried at runtime via the declared override seam. Revenue intent: none.
(Facts alone read `source-available`; the intent signal is what decides it.)
