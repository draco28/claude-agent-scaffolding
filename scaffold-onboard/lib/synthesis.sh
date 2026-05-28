#!/usr/bin/env bash
# scaffold-onboard/lib/synthesis.sh
# Synthesis layer — aggregates state into cross-cutting derived values.
# Task 2 fills in the synthesis functions; this is a minimal placeholder
# so that test-synthesis.sh can source this file during Task 1 TDD.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"
