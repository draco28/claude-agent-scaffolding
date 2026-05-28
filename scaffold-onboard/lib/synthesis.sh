#!/usr/bin/env bash
# scaffold-onboard/lib/synthesis.sh
# Synthesis layer — aggregates state into cross-cutting derived values.
# Task 2 fills in the synthesis functions; this is a minimal placeholder
# so that test-synthesis.sh can source this file during Task 1 TDD.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Resolve synthesize-vs-deterministic. Callers set SF_SYNTH_FAST=1 for --fast.
# Echoes "fast" or "synthesize".
sf_synth_mode() {
  if [[ "${SF_SYNTH_FAST:-0}" == "1" ]]; then
    echo "fast"
  else
    echo "synthesize"
  fi
}
