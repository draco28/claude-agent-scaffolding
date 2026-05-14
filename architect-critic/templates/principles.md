# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Your principles

(empty — add yours here, one per line)

## Examples (commented out — uncomment to activate)

# Prefer explicit over implicit configuration
# Push validation to system boundaries; trust internal code
# Every state-change operation needs a documented rollback path
# Avoid feature flags that outlive the experiment they gate
# Tests must hit real boundaries (DB, network) — mocks only at the seam
# Don't add fallbacks for scenarios that can't happen
# A bug fix doesn't need surrounding cleanup
