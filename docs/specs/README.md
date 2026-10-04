# Engineering Specs — Index

Source of truth for requirements: [PRD.md](../../PRD.md). Data model: [docs/SCHEMA.md](../SCHEMA.md) + [docs/schema.sql](../schema.sql).

Ordering = risk × core-value per the PRD (M0 payment spike first). Build prerequisite is ENG-07 (identity), but it is low-risk and specced lean.

---

## ENG-00 — High-Level Architecture (umbrella)

- Tech stack, module boundaries, deployment topology (single instance, one center).
- Cross-cutting decisions made once: UTC storage + branch-timezone rendering, BIGINT IDR money, append-only money tables, idempotency strategy, audit trail, webhook security.
- Maps modules → sub-specs → PRD FRs; states dependency order.

Full spec: [ENG-00-architecture.md](ENG-00-architecture.md)

## ENG-01 — Payments: Midtrans Core API (QRIS, GoPay acquirer) Integration

Ranked #1 for **risk**, not build order. Three deliverables in sequence:

1. **Spike (M0):** answer gateway unknowns before they contaminate ENG-02/05/06 — full/partial refunds on GoPay-acquired QRIS (PRD §10.3), refund-after-settlement / insufficient-balance behavior (BR-8), refund windows (on-us 45d / off-us 7d), QR expiry configurability, webhook retry/signature/ordering, Core API `actions[]` QR-action handling.
2. **`PaymentProvider` interface + MockAdapter:** unblocks ENG-02/03/04 against a deterministic fake.
3. **MidtransAdapter:** Core API charge (`/v2/charge`) + webhook-verified, idempotent payment state machine (FR-5); refund API with store-credit fallback (BR-8/9); sandbox → live as config-only flip (PRD SC-2).

Full spec: [ENG-01-payments.md](ENG-01-payments.md)

## ENG-02 — Booking & Seat Reservation

- Atomic seat counting — overbooking impossible (FR-4.4, I-1).
- Pending-payment seat hold with expiry/release matching QR lifetime (BR-2).
- Booking state machine; per-session vs series booking; series only before first session (FR-4.2); price snapshot at booking (I-4).

## ENG-03 — Scheduling & Session Generation

- Schedule rule → materialized sessions; one-off class = 1 session (FR-2.2).
- Cross-branch teacher conflict detection (FR-2.3); per-session reschedule/delete with BR-7 forced-refund hook.
- Branch timezones (WIB/WITA/WIT) correct in generation and rendering.

## ENG-04 — Pricing Engine

- Resolution precedence: exact date > day-of-week > base (BR-1), with valid-from/to ranges.
- Package pricing + `session_price_share` computation (feeds refund math in ENG-05).
- Admin sees resolution chain; customers see resolved price only (FR-3.4).

## ENG-05 — Cancellation & Refund Engine

- Configurable ordered-cutoff policies: global default + per-class override (FR-6.1); per-session independent evaluation (FR-6.2).
- Execution: gateway-first with automatic credit fallback (BR-8/9), manual admin override (FR-6.5), no-show = lowest cutoff (BR-6).
- Append-only audit trail on every refund (I-5).

## ENG-06 — Settlement Ledger & Revenue Reporting

- BookingItem → earned when session ends, attendance-independent (BR-5, FR-8.1).
- Dashboard: earned revenue + refund exposure, filterable per branch; full money trail per booking (FR-8.3).

## ENG-07 — Identity, Roles & Organization

- Auth + 3 roles with role-scoped home screens; center/branch setup; teacher invites.
- Customer account → N student profiles (FR-1). Prerequisite for all, low-risk — specced lean.

## ENG-08 — Attendance & Session Notes

- Roster marking window (session start → +24h); auto-absent resolution (FR-7.2).
- Free-text notes visible to admin + booking customers (FR-7.3).

## ENG-09 — Notifications (Email)

- Trigger map + templates for the 5 email types (FR-9); extensible to WhatsApp post-MVP.

---

## Dependency & sequencing notes

- **Critical risk path:** ENG-01 (spike) → ENG-02 → ENG-05. Spike findings are constraints for ENG-02 (seat-hold duration) and ENG-05 (refund fallback paths).
- **Safe to spec/build in parallel:** ENG-07, ENG-03, ENG-04 — nothing in the spike changes them.
- **Suggested spec-writing order:** 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09.
