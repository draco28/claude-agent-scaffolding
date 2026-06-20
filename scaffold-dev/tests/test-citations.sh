#!/usr/bin/env bash
# tests/test-citations.sh — 22 tests for lib/citations.sh mechanical citation legs
# (#7 file/signature; #48 C/D doc-anchor + ADR-id resolution)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SD_BIN="$HERE/../bin/sd"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/citations.sh"

# 1. sd_citations_check_file on an existing file → returns 0
test_check_file_exists() {
  echo "test_check_file_exists:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/real.py"
  echo "# content" > "$f"
  set +e
  sd_citations_check_file "$f" >/dev/null 2>&1
  local rc=$?
  assert_eq "existing file returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 2. sd_citations_check_file on a missing file → returns 1
test_check_file_missing() {
  echo "test_check_file_missing:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/no-such-file.py"
  set +e
  sd_citations_check_file "$f" >/dev/null 2>&1
  local rc=$?
  assert_eq "missing file returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 3. sd_citations_check_signature where file contains the exact signature → returns 0
test_check_signature_exact_match() {
  echo "test_check_signature_exact_match:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/module.py"
  printf 'def foo(a, b):\n    pass\n' > "$f"
  set +e
  sd_citations_check_signature "$f" "def foo(a, b):" >/dev/null 2>&1
  local rc=$?
  assert_eq "exact signature found returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 4. sd_citations_check_signature where file has a DRIFTED signature → returns 1
test_check_signature_drifted() {
  echo "test_check_signature_drifted:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/module.py"
  # File now has an extra parameter — signature has drifted from the cited form
  printf 'def foo(a, b, c=False):\n    pass\n' > "$f"
  set +e
  sd_citations_check_signature "$f" "def foo(a, b):" >/dev/null 2>&1
  local rc=$?
  assert_eq "drifted signature returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 5. sd_citations_check_file returns status only; stdout is not a signal.
test_check_file_no_stdout() {
  echo "test_check_file_no_stdout:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/real.py"
  echo "# content" > "$f"
  local out
  set +e
  out="$(sd_citations_check_file "$f" 2>/dev/null)"
  local rc=$?
  assert_eq "existing file returns 0" "0" "$rc"
  assert_eq "existing file stdout is empty" "" "$out"
  rm -rf "$TMP_DIR"
}

# --- #48 Part C: doc-anchor resolution leg (sd_citations_check_anchor) ---

# 6. anchor present as a numbered heading → returns 0
test_check_anchor_numeric_present() {
  echo "test_check_anchor_numeric_present:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '# Spec\n\n## 5.2 Token Lifecycle\n\nbody\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "5.2" >/dev/null 2>&1
  local rc=$?
  assert_eq "numeric heading anchor returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 7. anchor present as a heading TITLE fragment → returns 0
test_check_anchor_title_present() {
  echo "test_check_anchor_title_present:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/SRS.md"
  printf '# SRS\n\n### FR-5 Authentication\n\nbody\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "FR-5" >/dev/null 2>&1
  local rc=$?
  assert_eq "title/id heading anchor returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 8. anchor absent from all headings → returns 1
test_check_anchor_missing() {
  echo "test_check_anchor_missing:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '# Spec\n\n## 5.2 Token Lifecycle\n\nbody\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "9.9" >/dev/null 2>&1
  local rc=$?
  assert_eq "missing anchor returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 9. anchor token appears only in body prose, NOT in a heading → returns 1
test_check_anchor_body_only_not_heading() {
  echo "test_check_anchor_body_only_not_heading:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '# Spec\n\n## Overview\n\nsee section 5.2 for details\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "5.2" >/dev/null 2>&1
  local rc=$?
  assert_eq "anchor only in prose (no heading) returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 10. anchor host doc missing → returns 1
test_check_anchor_doc_missing() {
  echo "test_check_anchor_doc_missing:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  set +e
  sd_citations_check_anchor "$TMP_DIR/no-such-doc.md" "5.2" >/dev/null 2>&1
  local rc=$?
  assert_eq "missing host doc returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 11. anchor check returns status only; stdout is not a signal
test_check_anchor_no_stdout() {
  echo "test_check_anchor_no_stdout:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '## 5.2 Token Lifecycle\n' > "$f"
  local out
  set +e
  out="$(sd_citations_check_anchor "$f" "5.2" 2>/dev/null)"
  local rc=$?
  assert_eq "anchor present returns 0" "0" "$rc"
  assert_eq "anchor present stdout is empty" "" "$out"
  rm -rf "$TMP_DIR"
}

# 12. empty anchor tokens are malformed and MUST NOT match every heading
test_check_anchor_empty_malformed() {
  echo "test_check_anchor_empty_malformed:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '## 5.2 Token Lifecycle\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "" >/dev/null 2>&1
  local rc=$?
  assert_eq "empty anchor returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 13. numeric/id anchors require token boundaries, not substring false positives
test_check_anchor_structured_boundaries() {
  echo "test_check_anchor_structured_boundaries:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/SRS.md"
  printf '# SRS\n\n## 15.20 Monitoring\n\n### FR-50 Extended Auth\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "5.2" >/dev/null 2>&1
  local numeric_rc=$?
  sd_citations_check_anchor "$f" "FR-5" >/dev/null 2>&1
  local id_rc=$?
  assert_eq "5.2 does not match 15.20" "1" "$numeric_rc"
  assert_eq "FR-5 does not match FR-50" "1" "$id_rc"
  rm -rf "$TMP_DIR"
}

# 14. quoted title anchors resolve against unquoted Markdown headings
test_check_anchor_quoted_title_present() {
  echo "test_check_anchor_quoted_title_present:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '# Spec\n\n## Token Lifecycle\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" '"Token Lifecycle"' >/dev/null 2>&1
  local rc=$?
  assert_eq "quoted title heading anchor returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 15. dispatcher path stays pipefail-safe on large heading files with an early match
test_check_anchor_dispatcher_large_heading_file() {
  echo "test_check_anchor_dispatcher_large_heading_file:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '## 5.2 Token Lifecycle\n' > "$f"
  local i=0
  while [[ "$i" -lt 20000 ]]; do
    printf '## filler-%s\n' "$i" >> "$f"
    i=$((i+1))
  done
  set +e
  bash "$SD_BIN" citations_check_anchor "$f" "5.2" >/dev/null 2>&1
  local rc=$?
  assert_eq "dispatcher large heading file returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# --- #48 Part D: ADR-id resolution leg (sd_citations_check_adr) ---

# 16. ADR id resolves in the (first) product dir → returns 0
test_check_adr_product_dir() {
  echo "test_check_adr_product_dir:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product" "$TMP_DIR/process"
  echo "# adr" > "$TMP_DIR/product/adr-0003-use-redis.md"
  set +e
  sd_citations_check_adr "ADR-0003" "$TMP_DIR/product" "$TMP_DIR/process" >/dev/null 2>&1
  local rc=$?
  assert_eq "ADR in product dir returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 17. ADR id resolves in the SECOND (process) dir → returns 0
test_check_adr_process_dir() {
  echo "test_check_adr_process_dir:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product" "$TMP_DIR/process"
  echo "# adr" > "$TMP_DIR/process/adr-0002-switch-backend.md"
  set +e
  sd_citations_check_adr "ADR-0002" "$TMP_DIR/product" "$TMP_DIR/process" >/dev/null 2>&1
  local rc=$?
  assert_eq "ADR in process dir returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 18. ADR id absent from all dirs → returns 1
test_check_adr_missing() {
  echo "test_check_adr_missing:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product" "$TMP_DIR/process"
  echo "# adr" > "$TMP_DIR/product/adr-0003-use-redis.md"
  set +e
  sd_citations_check_adr "ADR-0099" "$TMP_DIR/product" "$TMP_DIR/process" >/dev/null 2>&1
  local rc=$?
  assert_eq "missing ADR returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 19. unpadded citation (ADR-3) resolves a 4-digit file (adr-0003-*) → returns 0
test_check_adr_zero_pad_tolerant() {
  echo "test_check_adr_zero_pad_tolerant:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product"
  echo "# adr" > "$TMP_DIR/product/adr-0003-use-redis.md"
  set +e
  sd_citations_check_adr "ADR-3" "$TMP_DIR/product" >/dev/null 2>&1
  local rc=$?
  assert_eq "unpadded ADR-3 resolves adr-0003 returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 20. malformed ADR id (no digits) → returns 1
test_check_adr_malformed() {
  echo "test_check_adr_malformed:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product"
  set +e
  sd_citations_check_adr "ADR-foo" "$TMP_DIR/product" >/dev/null 2>&1
  local rc=$?
  assert_eq "malformed ADR id returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 21. scaffold-onboard's seed ADR filename form (0001-*) resolves too
test_check_adr_unprefixed_seed_filename() {
  echo "test_check_adr_unprefixed_seed_filename:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product"
  echo "# adr" > "$TMP_DIR/product/0001-record-architecture-decisions.md"
  set +e
  sd_citations_check_adr "ADR-0001" "$TMP_DIR/product" >/dev/null 2>&1
  local rc=$?
  assert_eq "ADR-0001 resolves unprefixed 0001 seed filename" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 22. dispatcher path preserves the malformed-id warning under set -euo pipefail
test_check_adr_dispatcher_malformed_warns() {
  echo "test_check_adr_dispatcher_malformed_warns:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product"
  local out rc
  set +e
  out="$(bash "$SD_BIN" citations_check_adr "ADR-foo" "$TMP_DIR/product" 2>&1)"
  rc=$?
  assert_eq "dispatcher malformed ADR id returns 1" "1" "$rc"
  assert_contains "dispatcher malformed ADR id warns" "malformed ADR id" "$out"
  rm -rf "$TMP_DIR"
}

test_check_file_exists
test_check_file_missing
test_check_signature_exact_match
test_check_signature_drifted
test_check_file_no_stdout
test_check_anchor_numeric_present
test_check_anchor_title_present
test_check_anchor_missing
test_check_anchor_body_only_not_heading
test_check_anchor_doc_missing
test_check_anchor_no_stdout
test_check_anchor_empty_malformed
test_check_anchor_structured_boundaries
test_check_anchor_quoted_title_present
test_check_anchor_dispatcher_large_heading_file
test_check_adr_product_dir
test_check_adr_process_dir
test_check_adr_missing
test_check_adr_zero_pad_tolerant
test_check_adr_malformed
test_check_adr_unprefixed_seed_filename
test_check_adr_dispatcher_malformed_warns

sd_test_summary
