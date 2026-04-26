#!/usr/bin/env bash
# scaffold/lib/repo.sh — repo identity, branch detection, stack/LLM signal scan.
#
# All functions are FAIL-SAFE: errors return safe defaults rather than crashing.
# No side effects beyond reading the filesystem and shelling out to git.

# ── Repo identity ───────────────────────────────────────────────────────────

# sf_repo_root — absolute path to the repo's working tree root.
# Falls back to current working directory if not inside a git repo.
sf_repo_root() {
  local root
  if root="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$root" ]]; then
    printf '%s' "$root"
  else
    pwd
  fi
}

# sf_repo_remote_url — git remote URL for origin, or empty string.
sf_repo_remote_url() {
  git -C "$(sf_repo_root)" remote get-url origin 2>/dev/null || true
}

# sf_repo_hash — deterministic 12-hex-char identifier for this repo.
# Uses git remote URL when available (survives dir moves), falls back to
# absolute path of the repo root. Cross-clone behavior: two clones of the same
# remote will share state; this is intentional per SPEC OQ-14.
sf_repo_hash() {
  local key
  key="$(sf_repo_remote_url)"
  if [[ -z "$key" ]]; then
    key="$(sf_repo_root)"
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$key" | sha256sum | cut -c1-12
  else
    printf '%s' "$key" | shasum -a 256 | cut -c1-12
  fi
}

# sf_branch — current branch name. Detached HEAD returns "_detached_<sha7>";
# unborn (fresh init, no commits) returns "_unborn"; non-git dir returns
# "_no_git".
sf_branch() {
  local b
  if ! git -C "$(sf_repo_root)" rev-parse --git-dir >/dev/null 2>&1; then
    echo "_no_git"
    return 0
  fi
  if ! b="$(git -C "$(sf_repo_root)" rev-parse --abbrev-ref HEAD 2>/dev/null)"; then
    echo "_unborn"
    return 0
  fi
  if [[ "$b" == "HEAD" ]]; then
    local sha
    sha="$(git -C "$(sf_repo_root)" rev-parse --short HEAD 2>/dev/null)" || sha="unknown"
    echo "_detached_${sha}"
  else
    echo "$b"
  fi
}

# sf_branch_safe — branch name sanitized for use as a directory name.
# Replaces forward slash (common in feature branches like feat/auth) with
# double-underscore so it round-trips visually.
sf_branch_safe() {
  sf_branch | sed 's|/|__|g'
}

# ── Stack detection ─────────────────────────────────────────────────────────

# sf_stack_detect — newline-separated list of detected stacks.
# Possible values: python, node, rust, go. Empty if none detected.
sf_stack_detect() {
  local root
  root="$(sf_repo_root)"
  local stacks=()
  [[ -f "$root/pyproject.toml" || -f "$root/requirements.txt" || -f "$root/setup.py" || -f "$root/Pipfile" ]] && stacks+=("python")
  [[ -f "$root/package.json" ]] && stacks+=("node")
  [[ -f "$root/Cargo.toml" ]] && stacks+=("rust")
  [[ -f "$root/go.mod" ]] && stacks+=("go")
  printf '%s\n' "${stacks[@]}"
}

# sf_stack_detect_json — same as sf_stack_detect but as a JSON array.
sf_stack_detect_json() {
  local stacks
  stacks="$(sf_stack_detect)"
  if [[ -z "$stacks" ]]; then
    echo '[]'
  else
    printf '%s\n' "$stacks" | jq -R . | jq -s .
  fi
}

# ── LLM-project detection ───────────────────────────────────────────────────

# sf_llm_detect — "true" or "false". Scans pyproject/requirements/package.json
# for known LLM SDK signals; checks .env* for known API keys; checks for
# directories typical of LLM projects.
sf_llm_detect() {
  local root
  root="$(sf_repo_root)"

  # Python signals
  if [[ -f "$root/pyproject.toml" || -f "$root/requirements.txt" ]]; then
    if grep -qE '(openai|anthropic|langchain|langgraph|llama-index|llama_index|transformers|^mcp[[:space:]=>]|instructor|outlines|dspy)' \
        "$root/pyproject.toml" "$root/requirements.txt" 2>/dev/null; then
      echo "true"; return 0
    fi
  fi

  # Node signals (package.json)
  if [[ -f "$root/package.json" ]] && command -v jq >/dev/null 2>&1; then
    local deps
    deps="$(jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys | .[]' "$root/package.json" 2>/dev/null)"
    if echo "$deps" | grep -qE '(@anthropic-ai/sdk|^openai$|^langchain$|^ai$|@ai-sdk/|@mistralai/mistralai)'; then
      echo "true"; return 0
    fi
  fi

  # Filesystem signals
  for d in agents prompts evals tools; do
    if [[ -d "$root/$d" || -d "$root/src/$d" ]]; then
      echo "true"; return 0
    fi
  done

  # .env signals
  for envfile in "$root/.env" "$root/.env.example" "$root/.env.local"; do
    if [[ -f "$envfile" ]] && grep -qE '(ANTHROPIC_API_KEY|OPENAI_API_KEY)' "$envfile" 2>/dev/null; then
      echo "true"; return 0
    fi
  done

  echo "false"
}

# ── Test-framework detection ────────────────────────────────────────────────

# sf_test_command — best-guess command to run the project's tests.
# Prints empty string if no framework can be inferred.
sf_test_command() {
  local root
  root="$(sf_repo_root)"

  # Python: pytest
  if [[ -f "$root/pytest.ini" ]] || \
     ([[ -f "$root/pyproject.toml" ]] && grep -q '\[tool\.pytest' "$root/pyproject.toml" 2>/dev/null) || \
     [[ -d "$root/tests" && (-f "$root/tests/conftest.py" || -n "$(find "$root/tests" -maxdepth 1 -name 'test_*.py' -print -quit 2>/dev/null)") ]]; then
    echo "pytest"; return 0
  fi

  # JS/TS: vitest, jest
  if [[ -f "$root/vitest.config.js" || -f "$root/vitest.config.ts" || -f "$root/vitest.config.mjs" ]]; then
    echo "vitest run"; return 0
  fi
  if [[ -f "$root/jest.config.js" || -f "$root/jest.config.ts" ]] || \
     ([[ -f "$root/package.json" ]] && jq -e '.jest' "$root/package.json" >/dev/null 2>&1); then
    echo "jest"; return 0
  fi

  # Rust: cargo test
  if [[ -f "$root/Cargo.toml" ]]; then
    echo "cargo test"; return 0
  fi

  # Go: go test
  if [[ -f "$root/go.mod" ]]; then
    echo "go test ./..."; return 0
  fi

  echo ""
}
