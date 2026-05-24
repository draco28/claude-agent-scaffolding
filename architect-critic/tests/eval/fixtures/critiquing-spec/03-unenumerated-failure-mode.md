---
scenario_id: 03-unenumerated-failure-mode
expected_severity: gap
expected_principle: ghost-notes
expected_finding: critic should surface the missing failure mode for downstream payment-gateway timeout or unavailability — the spec lists duplicate-order and insufficient-funds but omits the clearly load-bearing network/service-availability case
---
# SPEC: Order checkout and payment processing

## 1. Goal
Implement the checkout endpoint that accepts a finalized cart, charges the customer via the
third-party payment gateway (Stripe), and records the resulting order in the database.

## 2. Context
- Payment is processed synchronously — the HTTP response to the client reflects the final payment
  outcome (success or hard failure). No async webhooks for the primary charge path.
- Stripe SDK is initialized at service start with a configured 10s read timeout (library default).
- Order records must not be created unless payment succeeds.

## 3. Request contract
```
POST /checkout
{
  "cart_id": "uuid",
  "payment_method_id": "pm_xxx",  // Stripe PaymentMethod token
  "idempotency_key": "uuid"
}
```

## 4. Steps
1. Validate `cart_id` belongs to the authenticated user and is in `PENDING` state.
2. Lock the cart row (`SELECT ... FOR UPDATE`) to prevent concurrent checkout attempts.
3. Compute total from cart line items; confirm all items still in stock.
4. Call `stripe.PaymentIntents.create(amount, currency, payment_method, confirm=True, idempotency_key)`.
5. If Stripe returns `succeeded`: create `orders` row with status `CONFIRMED`, release cart lock, return 201.
6. If Stripe returns `requires_action`: return 402 with `client_secret` for 3DS challenge (client handles).

## 5. Failure modes
- **Duplicate checkout attempt** — same `idempotency_key` re-submitted: Stripe de-dupes; our lock
  ensures only one DB write; return same 201 as original.
- **Insufficient funds / card declined** — Stripe returns `card_error`; no order created; return 402
  with user-facing decline reason from Stripe error object.

## 6. Invariants
- No order row exists without a corresponding `succeeded` PaymentIntent.
- Cart transitions: `PENDING → CONFIRMED` (success) or remains `PENDING` on decline.

## 7. Out of scope
- Partial refunds, order cancellation, and webhook reconciliation are handled by separate specs.
