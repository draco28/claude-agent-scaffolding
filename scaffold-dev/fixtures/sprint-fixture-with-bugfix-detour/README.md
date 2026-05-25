# sprint-fixture-with-bugfix-detour

Fixture used by scaffold-dev's tests/test-e2e.sh T7.2 to exercise the handoff
chain (forward bug-fix handoff → return handoff → sprint cleanup with
carry-forward preservation).

The fixture's MASTER-SPEC and ROADMAP are reused from sprint-fixture-minimal;
this fixture adds:

- A sample carry-forward sprint-handoff that must SURVIVE sprint-close cleanup.
- An expected sequence of bug-fix forward + return handoffs that are
  composed and cleaned up by the test.
