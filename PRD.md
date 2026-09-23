# PRD — Class Booking App for Learning Centers

**Status:** Draft v1 (refined) — 3 open decisions remain (see §10)
**Goal:** Ready-to-deploy booking app with tightly scoped functionality, used as a showcase to attract development clients.

---

## 1. Vision & Success Criteria

A learning center (tutoring, courses, workshops) can publish bookable classes with teachers, schedules, and pricing; parents/students book and pay online; the center receives money only after a class actually runs; cancellations and refunds follow center-configured rules; teachers confirm attendance and leave session notes.

**Success criteria (what "done" means):**
1. A complete money-and-booking loop runnable end-to-end in one 10-minute demo (see §8).
2. Deployable as a single instance for one learning center, using a real payment gateway in **sandbox mode** that can switch to live keys by config change only.
3. Every business rule (pricing overrides, cancellation, refund handling) is *configurable by the admin*, not hardcoded — this is the core selling point of the showcase.
4. Customer-facing flows are mobile-first (parents book from phones); admin/teacher flows are desktop-first.

---

## 2. Personas & Roles

| Role | Description |
|---|---|
| **Center Admin** | Owns the center and its branches: manages teachers, classes, pricing rules, cancellation policies, bookings, payments, revenue reports — all organization-wide, filterable per branch. |
| **Teacher** | Assigned to classes. Views own schedule & roster, marks attendance, writes session notes. One teacher per class is designated **main teacher**; others are co-teachers. |
| **Customer** | A parent or an adult student. Holds an account and manages one or more **student profiles** (children). Books and pays on behalf of a profile. |

*Note: "student or parent can book" is modeled as one Customer account type with N student profiles. An adult student has a profile linked to their own account. No separate student login — children don't manage bookings.*

---

## 3. Domain Model

```
Center = one organization, one or more Branches (multi-tenant-ready schema)
 ├── Branches (name, address, timezone)
 ├── Users (admin | teacher | customer) — organization-wide
 ├── Students (profiles owned by a Customer) — organization-wide
 ├── Classes ←── the bookable item, belongs to a Branch
 │    ├── title, description, capacity, teachers (1 main + N co)
 │    ├── schedule rule → generates Sessions
 │    ├── base price + optional package price
 │    └── cancellation policy (defaults to center-wide policy)
 ├── Sessions (concrete instance: date, start/end time, status)
 ├── PriceRules (override per date or day-of-week)
 ├── Bookings (single-session or full-series "package")
 │    └── BookingItems (one per session reserved)
 ├── Payments (one per booking; Midtrans Snap QRIS, sandbox)
 ├── Refunds (per cancelled session, per rule; via gateway refund API or credit)
 ├── Attendance (per BookingItem: present | absent)
 ├── SessionNotes (free text, per session)
 └── SettlementLedger (per-session settlement → earned-revenue report + refund exposure)
```

**Key unification:** a "one-off class" is just a Class whose schedule generates exactly **1 session**. Single-session booking and series booking share the same machinery. No separate entity types.

---

## 4. Functional Requirements

### FR-1 — Center & Account Setup
- FR-1.1 Admin registers center (name, currency, default cancellation policy) and creates one or more **branches** (name, address, timezone — WIB/WITA/WIT).
- FR-1.2 Admin invites teachers; teacher logs in and sees only their own schedule, rosters, and note-taking.
- FR-1.3 Customer registers, creates student profiles (name, age), books for any of their profiles.
- AC: each role's home screen shows only data relevant to that role.

### FR-2 — Class Management (Admin)
- FR-2.1 Create a Class at a chosen branch: title, description, capacity, schedule rule (weekly on day(s) at time, from date, for N weeks — or a single date/time), teachers (1 main, optional co-teachers), base price per session, optional package price for the full series.
- FR-2.2 Creating a class generates its Sessions automatically; admin can individually delete/reschedule a Session (bookings on it require handling — cancel-with-full-refund if rescheduled).
- FR-2.3 Conflict prevention: saving a class fails with a clear error if any assigned teacher already has a session overlapping in time — checked across **all branches** (teachers are organization-wide).
- FR-2.4 Capacity is enforced per session (see FR-4.4). No waitlist in v1.
- AC: one-off class = class with 1 generated session, bookable immediately.

### FR-3 — Pricing (Admin)
- FR-3.1 Every Class has a base price (per session) and optional package price (whole series, typically discounted).
- FR-3.2 Admin attaches **PriceRules** to a Class: override price for a specific **date** or a **day-of-week** (e.g., Saturday surcharge, holiday pricing), optionally with a valid-from/to range.
- FR-3.3 Precedence when resolving a session's price: **exact date rule > day-of-week rule > base price**.
- FR-3.4 Prices shown to customers are always the resolved price; admin sees the resolution (base → rule applied) in the class detail view.
- AC: adding a "Saturdays +50% on weekends" style rule changes the displayed price on affected sessions only.

### FR-4 — Booking (Customer)
- FR-4.1 Browse classes: filter by branch, teacher, date; each session shows resolved price, available seats, and refund policy summary.
- FR-4.2 Book **per session** (one session of a series or a one-off class) or **per series** ("package": all sessions at package price). Series bookings are only open **before the first session starts** (Decision §10.4) — no mid-series prorating in v1.
- FR-4.3 Booking requires a selected student profile; booking creates a pending payment; seats are reserved until payment succeeds or the QR code expires (default 30 min, matching Midtrans QRIS expiry).
- FR-4.4 Seat counting is atomic — overbooking is impossible.
- FR-4.5 Customer sees upcoming bookings, history, payment and refund status.

### FR-5 — Payment (Midtrans QRIS)
- FR-5.1 Payment via **Midtrans Snap, QRIS channel**, in sandbox mode; live by config/key change only. Customer taps "Bayar" → QR code shown with countdown → pays from any e-wallet/banking app → Midtrans webhook confirms (webhook is the source of truth; app also polls status while the QR is displayed).
- FR-5.2 No gateway-held escrow: QRIS funds settle directly to the **center's own Midtrans merchant account** (T+1). The app's SettlementLedger tracks per-session settlement for revenue reporting and refund exposure (FR-8) — it does not gate money.
- FR-5.3 Optional second channel: **Virtual Account bank transfer** via the same Snap integration (one config toggle). Recommended fallback — VA refunds are the most battle-tested channel in Midtrans.
- FR-5.4 Manual bank transfer (offline confirmation) remains available for centers without a gateway account.
- AC: paying a booking moves it pending → paid; payment is visible in admin ledger immediately, tagged per session.

### FR-6 — Cancellation & Refund
- FR-6.1 Admin defines **CancellationPolicy** as an ordered list of `{hours_before_session_start → refund %}` (e.g., ≥24h → 100%, ≥2h → 50%, <2h → 0%). Global default, overridable per Class.
- FR-6.2 Customer can cancel any booking or any remaining sessions of a series booking. Each cancelled session is evaluated independently: `refund = session_price_share × refund_%`.
  - `session_price_share` = package price ÷ series length for packages; per-session price otherwise.
- FR-6.3 Admin chooses refund destination per center: **back to original payment (Midtrans refund API)** or **store credit** (v1-simple ledger, reusable on future bookings).
- FR-6.4 Refunds execute via the Midtrans refund API when feasible — inside the gateway's refund window and with sufficient merchant balance (BR-8). Partial refunds fall back to store credit automatically if the channel rejects them (BR-9); full cancellations always attempt the gateway first.
- FR-6.5 Admin can always manually override a refund (support/dispute case) from the booking detail.
- FR-6.6 No-show is treated as "cancelled at <lowest cutoff>" → typically 0% refund; money is still released to the center (class was held).
- AC: cancelling 3 days before a class with a ≥24h→100% rule produces a 100% gateway refund; cancelling 1 hour before produces 0% (or per configured rule).

### FR-7 — Attendance & Notes (Teacher)
- FR-7.1 Any assigned teacher sees the session roster and marks each booked student **present/absent** from session start until 24h after it ends.
- FR-7.2 Unmarked rosters auto-resolve to "absent" 24h after session end (so revenue reporting is never blocked).
- FR-7.3 Teacher submits a free-text note per session (e.g., the topic taught). Visible to admin and to the booking customers. Structured curriculum is **out of scope**.
- AC: attendance status is visible to admin in real time.

### FR-8 — Settlement Tracking & Revenue Reporting
- FR-8.1 A BookingItem becomes **settled (earned)** when the session end time has passed (attendance need not be marked — money is owed because the class ran).
- FR-8.2 Money is **not gated**: QRIS funds settle directly to the center's bank via Midtrans (T+1). "Admin gets money after class passes" is deliberately satisfied as *reporting* — the app recognizes revenue only when the session ends.
- FR-8.3 Admin dashboard shows: **earned revenue** per class/session — filterable per branch — **refund exposure** (paid revenue whose class has not yet ended), and the full money trail per booking: payment → session → settlement → refunds.
- AC: after a demo class passes, its revenue appears in the earned-revenue report and refund exposure drops.

### FR-9 — Notifications (minimal, email)
- Booking confirmation, payment receipt, reminder 24h before session, cancellation/refund notice, revenue summary. (WhatsApp = post-MVP.)

---

## 5. Business Rules Summary

| # | Rule |
|---|---|
| BR-1 | Price resolution: exact date > day-of-week > base price. |
| BR-2 | Seats are reserved while payment is pending; released when the QR code expires (default 30 min, matches Midtrans QRIS expiry config) or payment fails. |
| BR-3 | Refund % determined solely by time-before-start at cancellation, per class policy (global default fallback). |
| BR-4 | Package refunds are per-remaining-session using session_price_share. |
| BR-5 | Revenue is marked earned when the session ends, regardless of attendance. The money itself settles to the center's bank T+1, ungated — earning is a reporting metric. |
| BR-6 | No-show = lowest-cutoff cancellation (typically 0% refund, center keeps money). |
| BR-7 | Rescheduling a booked session forces full-refund cancellation of affected bookings. |
| BR-8 | Gateway refund executes only if within the gateway's refund window and merchant balance covers it; otherwise the refund issues as store credit and the admin is notified. |
| BR-9 | Partial refunds attempt the gateway first; if the channel rejects, the partial amount falls back to store credit (full-cancellation refunds always attempt the gateway). |

---

### 5.1 Settlement Model — money is not gated (deliberate decision)

"Admin gets money after class passes" is soft, so v1 does **not** gate money. QRIS settles to the center's bank T+1 regardless; there is no withdrawal ceremony. The requirement is satisfied as **reporting** (FR-8): revenue is recognized only when a session ends, and the dashboard shows earned revenue + refund exposure — which is what center owners actually ask for ("how much have I truly earned, and how much could still be refunded").

The ledger schema stays mode-agnostic so a future **platform escrow** model (your merchant account + Midtrans Iris disbursements) remains a config + integration, not a rewrite — relevant only if multi-center SaaS ever becomes a goal.

## 6. Non-Functional (brief)

- Single currency (IDR) and single language (Bahasa Indonesia) per deployment.
- Timezone is a property of each branch (Indonesia spans WIB/WITA/WIT); sessions render in their branch's timezone.
- Responsive web app: customer = mobile-first; admin/teacher = desktop.
- Payments idempotent & webhook-verified; no double-charge, no lost payment.
- Overbooking impossible (transactional seat counting).
- Audit trail on refunds.

---

## 7. Scope

**In scope (v1):**
- Admin: branches, classes, sessions, pricing rules, cancellation policies, teachers, bookings, revenue reports (filterable per branch).
- Customer: profiles, browse, book per-session or series, pay, cancel/refund.
- Teacher: schedule, roster, attendance, free-text notes.
- Settlement tracking → earned-revenue report + refund exposure.
- Email notifications.

**Out of scope (v1):**
- Class topics / curriculum management (structured). *Free-text session notes remain in scope — this is the only concession to your original "teacher notes" requirement.*
- Waitlists; recurring subscriptions/memberships; credit wallet beyond refund storage.
- Rooms/resources scheduling; full SaaS multi-tenancy (separate businesses on one platform — schema is tenant-ready, auth/provisioning UI is not); branch-scoped admin roles (one admin manages all branches in v1).
- Automated bank payouts; real-time chat; reviews/ratings; analytics beyond basic dashboard; multi-currency; WhatsApp notifications.

---

## 8. Demo Script (10 minutes — the actual product pitch)

1. **Admin setup (2 min):** set cancellation policy (≥24h→100%, <24h→0%), create two branches (Kemang, BSD), create a class "Piano Beginner — Saturday 4pm, 8 sessions" at Kemang with main teacher + co-teacher, add a Saturday price rule. Show generated sessions + branch filter.
2. **Book & pay (3 min):** as parent, add child profile, book a single session and the full series, pay via Midtrans sandbox QRIS (scan the QR from any wallet app / sandbox simulator). Show the pending-payment lock and QR expiry.
3. **Teacher (2 min):** teacher sees roster, marks attendance, writes "Today's topic: C-major scales" note.
4. **Money & reporting (2 min):** session passes → its revenue appears in the earned-revenue report and refund exposure drops. Show the full money trail.
5. **Cancel & refund (1 min):** parent cancels another booking 3 days out → 100% gateway refund via Midtrans refund API (and cancels one 1h out → 0% per rule).

This single flow exercises every requirement and every selling point (configurable rules, refund handling, attendance-driven completeness).

---

## 9. Milestones

| M | Deliverable | Proves |
|---|---|---|
| 0 | **Payment spike:** Midtrans sandbox — QRIS + VA charges, webhook confirm, full & partial refunds, refund-after-settlement (insufficient balance behavior), refund window limits, QR expiry | De-risks FR-5/FR-6/FR-8 before anything depends on them |
| 1 | Auth + roles + center config + student profiles | Role isolation |
| 2 | Classes, sessions, price rules, policies, teacher assignment | Config-over-code selling point |
| 3 | Booking + sandbox payment + settlement ledger | The core loop |
| 4 | Attendance, notes, settlement tracking, revenue report | Money story |
| 5 | Cancellation/refund engine + notifications + polish | Completeness |

---

## 10. Decisions

**Resolved:**
1. **Market & payment:** Indonesia, IDR, QRIS via **Midtrans Snap** (recommended over Xendit: more mature QRIS sandbox + refund API). Manual bank-transfer confirmation remains an optional fallback.
2. **Refund handling:** the gateway refunds on our request via the refund API — your assumption works. One correction: the gateway does **not** hold money in escrow; QRIS funds settle to the center's bank T+1. "Money after class passes" is therefore satisfied as earned-revenue reporting (FR-8), not a gateway feature. Refund destination: admin-selectable (gateway refund or store credit), with automatic credit fallback if partial QRIS refunds prove unsupported.
3. **Attendance:** any assigned teacher may mark attendance.
4. **Series booking window:** series ("package") bookings are only allowed before the first session starts. No mid-series prorating in v1 — one validation rule, no pricing controversy. Revisit prorating if a real center asks for it.
5. **Multi-branch:** one organization owns N branches — classes belong to a branch; teachers, customers, students, and gateway keys are organization-wide; revenue reports filter per branch. Full SaaS multi-tenancy stays out of scope for v1.

**Remaining items to confirm (non-blocking):**
1. Midtrans merchant account ownership: center registers its own account and enters keys in admin settings (recommended for v1) vs platform-owned merchant account (marketplace mode, post-MVP).
2. UI language assumed Bahasa Indonesia — confirm.
3. Partial QRIS refund support — verify in Milestone 0 spike (FR-6.4).
4. Settlement: money settles directly to the center's bank (no gating), with earned-revenue reporting (§5.1). Platform escrow + Iris disbursements only if multi-center SaaS ever becomes a goal.
