---
scenario_id: 01-hidden-assumption
expected_severity: premise
expected_principle: ghost-notes
expected_finding: critic should surface the unstated assumption that the database supports transactions
---
# SPEC: User registration flow

## 1. Goal
Implement a registration endpoint that creates a user record and sends a welcome email.

## 2. Steps
1. Receive POST /register with email + password
2. Hash password
3. INSERT user row
4. INSERT welcome_email_job row
5. Return 201

## 3. Failure modes
- Duplicate email → return 409

(Spec ends here — note that step 3+4 assume atomicity without specifying transaction boundaries; the database type isn't mentioned anywhere.)
