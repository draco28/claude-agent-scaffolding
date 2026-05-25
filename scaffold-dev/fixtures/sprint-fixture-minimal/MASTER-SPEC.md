# sprint-fixture-minimal — Master Specification

**Spec version:** 1.0

## Executive Summary

Minimal sprint fixture used by scaffold-dev's tests/test-e2e.sh to exercise the
lib-API layer end-to-end. Models a tiny project with 1 sprint × 1 vertical
slice × 2 work items.

<!-- master-spec:phase id=1 name=foundation -->
## Phase 1: Foundation

### 1.3 Project class & MVP
**Project class:** CLI tool

<!-- master-spec:phase id=2 name=strategy -->
## Phase 2: Strategy

Single-user CLI; 1 sprint demo.

<!-- master-spec:phase id=3 name=domain -->
## Phase 3: Domain & Data Model

Models: Item(id, label). One entity, no relations.
