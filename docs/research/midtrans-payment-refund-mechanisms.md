# Research: Midtrans — Supported Payment & Refund Mechanisms

> Researched against primary sources only: the official Midtrans documentation
> (`docs.midtrans.com`, incl. the API reference formerly at `api-docs.midtrans.com`)
> fetched on 2026-02 (session date). Page-level "last updated" stamps are noted where
> relevant. This document intentionally ignores any existing repo docs/specs.

---

## 1. Integration surfaces (how payments are accepted)

Midtrans exposes one payment platform through several integration products; the
payment/refund *mechanics* underneath are shared:

| Product | What it is | Notes |
|---|---|---|
| **Snap** | Hosted checkout UI (popup/redirect) created via `POST /snap/v1/transactions` | Recommended default; methods shown are configurable per transaction via `enabled_payments` |
| **Mobile SDK** | Native iOS/Android drop-in UI | Same Snap backend |
| **Core API** | REST/JSON API (`/v2/charge`, …) for a fully custom UI | Production use requires activation request |
| **Payment Link** | No-code payment page link from dashboard or API | — |
| **CMS plugins / e-commerce platforms** | WooCommerce, Magento, Shopify, etc. | Wrap Snap |

Source: https://docs.midtrans.com/docs/payment-overview

Snap supports `enabled_payments` to restrict methods per transaction (a single entry
skips the method-list page), plus aliases `bank_transfer` (= `permata_va, bca_va,
bni_va, bri_va, echannel`) and `store` (= `kioson, indomaret, alfamart`).
Source: https://docs.midtrans.com/docs/snap-advanced-feature

---

## 2. Payment methods supported

### 2.1 Catalog (per current API reference table of contents)

| Category | Methods | Core API `payment_type` |
|---|---|---|
| Card | Visa, Mastercard, JCB, Amex (credit & debit) | `credit_card` |
| Bank transfer / VA | BCA VA, Permata VA, BNI VA, BRI VA, CIMB VA, Danamon VA, BSI VA, SeaBank VA, Saqu VA, Mandiri Bill Payment, "Other Banks" (masked open-loop VA shown in Snap) | `bank_transfer` (+ `bank` param), `echannel` (Mandiri), legacy `permata` |
| E-money / wallet | GoPay (incl. **GoPay Tokenization** for linked accounts), **QRIS** (dynamic; GoPay- or ShopeePay/AirPay-acquired), ShopeePay, OVO, DANA | `gopay`, `qris`, `shopeepay`, `ovo`, `dana` |
| Google Pay™ | Card-based Google Pay; charged as `payment_type: credit_card` with `google_pay_token` instead of `token_id`; uses a dedicated auth/charge domain (`panapi.midtrans.com`), but post-charge ops (status/cancel/refund) use the normal Core API host | `credit_card` |
| Over the counter | Indomaret, Alfamart | `cstore` (+ `store` param) |
| Cardless credit / paylater | Akulaku, Kredivo | `akulaku`, `kredivo` |
| Direct debit | BCA KlikPay, KlikBCA, BRImo (e-Pay BRI), CIMB Clicks, Danamon Online Banking, UOB EZ Pay | per-method types |

Sources:
- https://docs.midtrans.com/llms.txt (reference TOC)
- https://docs.midtrans.com/docs/coreapi-core-api-bank-transfer-integration
- https://docs.midtrans.com/docs/coreapi-e-money-integration
- https://docs.midtrans.com/docs/coreapi-over-the-counter-payment-integration
- https://docs.midtrans.com/docs/coreapi-cardless-credit-payment-integration
- https://docs.midtrans.com/reference/payment-method-google-pay
- https://docs.midtrans.com/reference/cancel-transaction (pending-capable method list)

**QRIS nuance:** a GoPay charge paid by scanning as QRIS arrives in notifications as
`payment_type: "qris"` (not `gopay`); transaction *status* semantics are unchanged.
A newer **GoPay Static QRIS** product (dashboard-generated QR, no order created
up-front; merchant only receives settlement notifications) still supports the Refund
APIs, but refunds must be addressed by Midtrans `transaction_id` (see §5.3).
Sources: https://docs.midtrans.com/docs/coreapi-e-money-integration ,
https://docs.midtrans.com/docs/gopay-static-qris ,
https://docs.midtrans.com/reference/refund-transaction

### 2.2 Default payment-expiry times (per method)

From the official FAQ table (published as an image; transcribed):

| Method | Acquirer/channel | Default expiry |
|---|---|---|
| Bank Transfer | Permata, Mandiri Bill, BNI, BCA, BRI, others | 24 hours |
| QRIS | GoPay | 15 minutes |
| QRIS | ShopeePay | 5 minutes |
| QRIS | others | 15 minutes |
| Over the counter | Alfamart, Indomaret | 24 hours |
| Cardless credit | Akulaku | 24 hours |
| Direct debit | BCA KlikPay, OctoClicks, e-Pay BRI, CIMB Clicks | 2 hours |
| Direct debit | UOB EZ Pay | 14 minutes |

Source: https://docs.midtrans.com/docs/default-expiry-time-for-each-payment-method

Custom per-transaction expiry exists (`custom_expiry` object) for pending-type
methods; caps: GoPay 7 days, ShopeePay/AirPay-QRIS 5 days; bank transfer min 20s,
max 180 days. Sources: https://docs.midtrans.com/reference/charge-transactions-1 ,
https://docs.midtrans.com/reference/other-banks

### 2.3 Amount limits (acquirer-level; merchant-level caps may also apply)

Selected values from the official min/max table (IDR):

| Method | Min | Max (acquirer) |
|---|---|---|
| Credit card (BNI, CIMB, Mandiri, Mega, BRI, BCA, Maybank) | 10,000 | 999,999,999 |
| VA: Mandiri Bill | 1 | 50 B |
| VA: BCA | 10,000 | 20 B |
| VA: BRI | 1 | 20 B |
| VA: Permata | 1 | 9,999,999,999 |
| VA: BNI / Danamon | 1 | no limit |
| VA: CIMB | 1 | 250,000,000 |
| VA: BSI | 1,000 | no limit |
| VA: SeaBank | 10,000 | 100,000,000 |
| GoPay / ShopeePay / DANA / LinkAja | 1 | 20,000,000 verified (2,000,000 unverified) |
| OVO | 1 | 99,999,999 |
| QRIS (all) | 1 | 10,000,000 |
| Alfamart | 1 | 5,000,000 cashless / 2,500,000 cash |
| Indomaret | 10,000 | 5,000,000 |
| Akulaku | 5,000 | no limit |
| Kredivo | 1 (30-day) / 500,000 (installment) | per user credit limit |

Source: https://docs.midtrans.com/docs/is-there-a-minimum-and-maximum-transaction-value-that-i-can-charge-with-midtrans

---

## 3. Transaction status lifecycle

Statuses (from the official status-cycle doc and notification reference):

| Status | Meaning | Transitions to |
|---|---|---|
| `pending` | Created, awaiting customer payment (or 3DS completion for card) | `settlement`, `expire`, `cancel`, `deny` |
| `authorize` | Card pre-auth only (opt-in feature): funds reserved; capture later via API or auto-release | `capture`, `deny`, `cancel`, `expire` |
| `capture` | Card charged successfully; settles automatically (typically next day). Safe to treat as paid | `settlement`, `cancel` |
| `settlement` | Funds received by merchant | `refund`, `partial_refund`, `chargeback`, `partial_chargeback`, `deny`* |
| `deny` | Rejected by provider/FDS | terminal |
| `cancel` | Voided before settlement | terminal |
| `expire` | Not paid within expiry window | terminal |
| `failure` | Unexpected processing error (rare) | terminal |
| `refund` / `partial_refund` | Merchant-triggered refund recorded | terminal |
| `chargeback` / `partial_chargeback` | Chargeback recorded | `partial_chargeback` → `chargeback` |

\* **Reversal edge case:** for Permata bank transfer, Mandiri Bill Payment, and
Indomaret, a `settlement` can *rarely* flip to `deny` within ~1–5 minutes (provider-
side reversal); funds bounce back to the customer automatically. Notification
handlers must tolerate it.

Snap caveat: a Snap-created transaction has **no status** until the customer picks a
payment method — `GET /v2/{id}/status` can return `404` before that.

Sources: https://docs.midtrans.com/docs/transaction-status-cycle ,
https://docs.midtrans.com/docs/https-notification-webhooks

### Status-changing API actions (Core API v2)

| Endpoint | Method | Effect |
|---|---|---|
| `/v2/{order_id or transaction_id}/status` | GET | Query status |
| `/v2/{id}/cancel` | POST | Void pre-settlement |
| `/v2/{id}/refund` | POST | Refund a `settlement` transaction (routed via Midtrans) |
| `/v2/{id}/refund/online/direct` | POST | Refund forwarded synchronously to bank/provider |
| `/v2/{id}/expire` | POST | Force-expire a `pending` transaction |
| `/v2/capture` | POST | Capture a pre-authorized card transaction |
| `/v2/{id}/status/b2b` | GET | Status for B2B transactions |

Source: https://docs.midtrans.com/docs/transaction-status-cycle

---

## 4. Cancel / void / expire (pre-settlement reversals)

- **Card transactions** can be cancelled in `authorize`/`capture` (i.e., before
  settlement). Allowed windows depend on acquirer: BNI — after capture; Mandiri —
  after initial charge; BCA, BRI, Maybank — before *and* after capture.
  Cancelling a captured card restores the card limit within ~H+1 working day.
- **Non-card `pending` transactions** (VA, direct debit, e-money pending, OTC,
  cardless credit) can be cancelled any time before payment/expiry.
- **`settlement` transactions cannot be cancelled** — only refunded (if the method
  supports it).
- Cancel is available via dashboard (MAP → transaction → Cancel button) or
  `POST /v2/{id}/cancel`.
- `POST /v2/{id}/expire` marks an unpaid transaction `expire` (frees the order_id
  for reuse). Snap sessions additionally have dedicated session expire/cancel APIs.

Sources: https://docs.midtrans.com/reference/cancel-transaction ,
https://docs.midtrans.com/docs/how-can-i-cancel-a-transaction ,
https://docs.midtrans.com/docs/can-i-cancel-a-transaction-that-has-been-settled ,
https://docs.midtrans.com/reference/expire-a-snap-session ,
https://docs.midtrans.com/reference/cancel-a-snap-session

---

## 5. Refund mechanisms (post-settlement)

### 5.1 Preconditions

1. Transaction status must be **`settlement`** (use Cancel API for
   `pending`/`authorize`/`capture`).
2. Merchant must have sufficient **payable (disbursable) balance** — the refund is
   netted/deducted from merchant funds (aggregator model: Midtrans deducts from the
   next payout).
3. The Refund capability may need **activation** (MAP refund button or API access)
   via a Midtrans support request.

Sources: https://docs.midtrans.com/docs/how-can-i-refund-transaction ,
https://docs.midtrans.com/docs/introduction-to-refund ,
https://docs.midtrans.com/reference/refund-transaction

### 5.2 Which methods are refundable *through Midtrans*

Official matrix (FAQ "What payment method that have refund feature?", updated
~6 months before fetch date):

| Method | Acquirer | Refundable via Midtrans | Window (from txn date/settlement) | SLA for customer to receive funds |
|---|---|---|---|---|
| Credit card | BNI, CIMB, Mandiri, BRI, BCA | ✅ full + partial | ≤ 6 months | 7–14 working days (up to 45 days cross-border) |
| Bank transfer / VA | Permata, Mandiri Bill, BNI, BCA, BRI | ❌ | — | — |
| GoPay | — | ✅ full + partial | 45 days after settlement | ≤ 1×24 h |
| ShopeePay | — | ✅ full + partial (see conflict §7) | ≤ 365 days; only 06:00–23:50 WIB | up to 20 days |
| DANA | — | ✅ full + partial | 45 days after settlement | ≤ 1×24 h |
| OVO | — | ✅ **full only** | 7 days (regular) / 180 days (OTA merchants) after settlement | ≤ 1×24 h |
| QRIS (GoPay-acquired) | — | ✅ full + partial | on-us: 45 days; off-us: 7 days | on-us ≤ 1×24 h; off-us 15–20 days |
| QRIS (ShopeePay-acquired) | — | ✅ full + partial (see conflict §7) | ≤ 365 days; 06:00–23:50 WIB; **not refundable for off-us paid via BCA/BNI/BRI** | on-us ≤ 1×24 h; off-us 15–20 days |
| OTC | Alfamart, Indomaret | ❌ | — | — |
| Cardless credit | Akulaku | ✅ full + partial | ≤ 6 months | ≤ 1×24 h |
| Cardless credit | Kredivo | ✅ full + partial | 14 days after settlement | ≤ 1×24 h |

The Refund API reference page additionally says refunds are supported for
`credit_card`, `gopay`, `shopeepay`, `dana`, `ovo`, `QRIS`, `kredivo`, `akulaku`
(and nowhere else), with per-method max windows: ShopeePay (QRIS & JumpApp) 365d;
Kredivo 14d; DANA 45d; OVO 7d/180d OTA; GoPay QRIS on-us 45d, QRIS off-us 7d,
GoPay Tokenization 180d, GoPay deeplink 45d, other GoPay 180d.

Sources: https://docs.midtrans.com/docs/what-payment-method-that-have-refund-feature ,
https://docs.midtrans.com/reference/refund-transaction

**Anything not refundable through Midtrans (bank transfer, OTC) — or past the
window — must be refunded manually merchant→customer** (e.g., merchant transfers
money back directly). Sources: https://docs.midtrans.com/docs/introduction-to-refund ,
https://docs.midtrans.com/docs/what-payment-method-that-have-refund-feature

### 5.3 Refund APIs

Two Core API endpoints (both usable from Snap and Core API integrations; addressed
by `order_id` **or** `transaction_id`):

| Endpoint | Behavior |
|---|---|
| `POST /v2/{id}/refund` | "Refund" — request is recorded by Midtrans and forwarded to the provider through the standard (1–2 working day) ops process |
| `POST /v2/{id}/refund/online/direct` | "Direct Refund" — forwarded to bank/provider immediately; transaction status updated synchronously from the provider response; HTTP notification only on success |

Current docs note **the single `/refund` endpoint now covers all refund use cases**;
`/refund/online/direct` remains for existing merchants. Direct Refund support:
GoPay, QRIS, ShopeePay, credit card (acquirers BCA, Maybank, BNI-via-Cybersource,
BRI only), Akulaku, Kredivo.

Request body: `refund_key` (optional idempotency key — reuse it when retrying the
*same* refund; a new key creates a new refund; a key can only be retried within
7 days of the first attempt), `amount` (optional — omit for full refund),
`reason` (optional, shown in GoPay history; **mandatory for BNI-acquired cards** —
auto-filled if missing).

Responses/statuses: success → `transaction_status: refund` (or `partial_refund`),
echoing `refund_chargeback_id`, `refund_amount`, `refund_key`. Errors:
`412` invalid transaction state, `414` invalid amount, `406` duplicate refund ID;
Direct Refund can return HTTP `202` "Refund denied by the bank" (transaction stays
`settlement`).

Notifications: Midtrans sends **two refund webhooks** — one without and one with
`bank_confirmed_at`; merchants should treat the `bank_confirmed_at` one as final
confirmation. Notification payload contains a `refunds[]` array with per-refund
`refund_method: online|offline`, `refund_key`, amounts, timestamps.

Special case: **GoPay Static QRIS** (since Jan 2024) can only be refunded by
`transaction_id`, not `order_id`.

Separate **BI-SNAP standard refund APIs** exist for GoPay/GoPay-Tokenization
(`POST /v1.0/debit/refund`) and GoPay-QRIS (`POST /v1.0/qr/qr-mpm-refund`) — these
are the SNAP-spec integrations with `X-SIGNATURE`/B2B-token auth, mostly relevant
to bank/partner integrations, not typical merchants.

Sources: https://docs.midtrans.com/reference/refund-transaction ,
https://docs.midtrans.com/reference/direct-refund-transaction ,
https://docs.midtrans.com/reference/refund-transactions-card ,
https://docs.midtrans.com/reference/refund-api ,
https://docs.midtrans.com/docs/gopay-static-qris

### 5.4 Card-specific refund operations

- **Aggregator agreement** (default): refund via MAP dashboard button or API;
  Midtrans forwards to the acquirer and deducts the amount from the merchant's next
  payout. Credit-card refund typically lands in **7–14 working days**; debit card
  can take up to ~2 months (customer may need to chase their issuing bank);
  cross-border up to 45 days.
- **Facilitator agreement** (own acquirer MIDs): refunds are done **directly with
  the bank** using Midtrans-provided templates.

Sources: https://docs.midtrans.com/docs/introduction-to-refund ,
https://docs.midtrans.com/docs/how-long-will-the-transaction-funds-be-credited-to-the-cardholder-after-a-refund

### 5.5 Fees on refunds

Midtrans charges **no additional fee** for refunds; the customer receives 100% back
(and per the GoPay FAQ, the merchant is not charged the transaction fee on refunded
settled transactions). Chargeback handling is a separate, bank-driven process.

Source: https://docs.midtrans.com/docs/will-i-be-charged-for-chargebacks-or-refunds

### 5.6 QRIS refundability: acquirer vs. payer app, and restricting methods

QRIS refundability is determined by the **acquirer** (who processes the QR for the
merchant — GoPay or ShopeePay/AirPay, activated per-merchant in MAP) and whether
the payment was **on-us** (GoPay app paying GoPay-acquired QRIS) or **off-us**
(any other QRIS-capable app, incl. mobile banking apps). The customer's app choice
does not change the mechanism, only the window/SLA:

| Acquirer | On-us (GoPay app) | Off-us (bank apps, other wallets) |
|---|---|---|
| GoPay | ✅ 45 days, ≤ 1×24 h | ✅ 7 days, 15–20 days |
| ShopeePay/AirPay | ✅ 365 days | ⚠️ 365 days, **except payments via BCA/BNI/BRI apps — not refundable via Midtrans** |

Notes:
- In Snap, the `gopay` tile = GoPay wallet + GoPay-acquired QRIS (QR on wide
  screens, deeplink on small screens). The QR is interoperable — any QRIS app can
  scan it; the transaction then arrives as `payment_type: "qris"` (off-us rules).
  `options.uiMode` in Snap JS can force deeplink vs QR display.
- `other_qris` is a generic QRIS tile masking whichever acquirer is active (GoPay
  if both are active; not configurable).
- To restrict acceptance to e.g. GoPay + DANA: `enabled_payments: ["gopay",
  "dana"]` per Snap transaction (full enum: `credit_card`, `echannel`,
  `permata_va`, `bca_va`, `bni_va`, `bri_va`, `cimb_va`, `danamon_va`, `bsi_va`,
  `seabank_va`, `saqu_va`, `gopay`, `ovo`, `dana`, `shopeepay`, `other_qris`,
  `alfamart`, `indomaret`, `akulaku`, `kredivo`, `other_va`; aliases
  `bank_transfer`, `cstore`). Complement by activating only the GoPay QRIS
  acquirer in MAP. Core API gives complete control (only implement the
  payment_types you want); GoPay Tokenization avoids the QR scanning path
  entirely (180-day refund window).

- **DANA charge is Snap-only.** Core API has no `payment_type: "dana"` charge — the DANA
  reference is a Snap integration (`enabled_payments: ["dana"]` + `dana.callback_url`),
  with only status/refund/cancel exposed via Core-API-style endpoints carrying a
  `transaction-source: SNAP_API` header. So "Core API only" and "accept DANA" are
  mutually exclusive for a standard merchant.

Sources: https://docs.midtrans.com/reference/dana ,
https://docs.midtrans.com/reference/qris , https://docs.midtrans.com/reference/gopay-1 ,
https://docs.midtrans.com/reference/request-body-json-parameter

---

## 6. Webhooks / reconciliation surface

- All status changes (incl. `refund`/`partial_refund`, `bank_confirmed_at`
  follow-up, and rare `settlement → deny` reversals) are pushed as HTTP(S) POST
  notifications to the configured Payment Notification URL; `GET /v2/{id}/status`
  is the authoritative pull fallback.
- Refund-bearing notifications include `refund_amount` and the `refunds[]` ledger.

Source: https://docs.midtrans.com/docs/https-notification-webhooks

---

## 7. Documentation inconsistencies & caveats (found during research)

1. **ShopeePay partial refund conflict:** the refund-support matrix says ShopeePay
   supports *full and partial* refunds, but the Refund Transaction API page says
   "Shopeepay and OVO does not support partial refund at the moment," and the SNAP
   QRIS-MPM refund page says "Airpay Shopee only supports full refund." Treat
   ShopeePay partial-refund support as uncertain → confirm with Midtrans before
   relying on it.
2. **ShopeePay QRIS refund window conflict:** an older refund API page states
   "max refund window 24 hours" for AirPay/ShopeePay QRIS, while the current Refund
   Transaction/Direct Refund pages and FAQ say 365 days (with a 06:00–23:50/23:55
   WIB daily window). The 365-day figure appears in the most recently updated
   pages.
3. **Akulaku** is still documented across payment/refund pages; availability for
   new activations should be reconfirmed (FAQ pages are ~6–11 months old).
4. The FAQ "Which payment methods do Midtrans currently support?" ("more than 16",
   lists LinkAja, no DANA/OVO columns) is **stale** relative to the API reference
   TOC (which includes DANA, OVO, Google Pay, BSI/SeaBank/Saqu VA). Prefer the API
   reference as the source of truth.
5. Default-expiry and parts of the refund matrix are published as images in the
   docs (transcribed above); Snap's documented `enabled_payments` example list
   predates QRIS/Google Pay — don't treat it as the full enum.
6. Refund SLA numbers are "working days" and explicitly non-binding ("funds may be
   returned sooner or later").

---

## 8. Refund risk & operational assessment per payment method

Risk dimensions used below (all mechanics sourced in §3–§6; **ratings and verdicts
are analysis/assessment, not Midtrans-published statements**):

- **Pull-back exposure** — can funds leave after you treat them as final?
  Chargebacks (card only) and provider reversals (Permata VA, Mandiri Bill,
  Indomaret) are the only involuntary pull-backs; everything else is
  merchant-initiated.
- **Liability tail** — how long a transaction remains refundable (7 days →
  365 days). Longer tail = longer you must keep records, evidence, and balance
  headroom.
- **Refund latency** — customer-facing SLA (≤24 h → up to 45 days). Drives
  support tickets more than anything else.
- **Liquidity coupling** — refunds draw from your *payable/disbursable balance*;
  with aggressive auto-withdrawal a refund can fail for insufficient funds.
- **Process risk** — API-driven vs manual (collect bank details, transfer by
  hand, reconcile outside Midtrans → error- and fraud-prone).

### 8.1 Assessment matrix

| Method | Refund via Midtrans | Full / Partial | Window | SLA to customer | Pull-back risk | Ops complexity | Small-business verdict |
|---|---|---|---|---|---|---|---|
| **GoPay** (incl. deeplink) | ✅ | full + partial | 45 days (180d tokenization) | ≤ 1×24 h | Low — no chargeback | **Low** (API, fast) | ✅ Most worth it |
| **QRIS – GoPay acquired** | ✅ | full + partial | on-us 45d / off-us 7d | on-us ≤24 h; off-us 15–20 d | Low | Low–Med (static-QRIS needs `transaction_id`; off-us latency) | ✅ Worth it — cheapest rails |
| **DANA** | ✅ | full + partial | 45 days | ≤ 1×24 h | Low | **Low** | ✅ Worth it |
| **OVO** | ✅ | **full only** | 7 days (180d OTA merchants) | ≤ 1×24 h | Low | Low–Med (no partials; short window pushes later cases to manual) | 🆗 Optional |
| **ShopeePay** | ✅ | full + partial (docs conflict, §7) | 365 days; only 06:00–23:50 WIB | up to 20 days | Med — long tail | Med (time-of-day window; partial ambiguity) | 🆗 Worth it if users demand it |
| **QRIS – ShopeePay/AirPay acquired** | ✅ | full + partial (conflict) | 365 days; time window; **off-us via BCA/BNI/BRI not refundable** | on-us ≤24 h; off-us 15–20 d | Med — long tail + dead-end cases | Med–High | 🆗 Comes with QRIS; plan manual fallback |
| **Credit/debit card** | ✅ | full + partial | 6 months | 7–14 working days (45d cross-border; debit up to ~2 months) | **High — chargebacks** (evidence due in ~7 calendar days; banks enforce chargeback thresholds) | Med (async; aggregator deducts from payout; BNI acquirer requires `reason`) | ✅ Enable for conversion, but budget support effort & evidence retention |
| **Google Pay** | ✅ (runs on card rails) | full + partial | as card | as card | as card | Med (separate `panapi` integration) | 🆗 Follows your card decision |
| **Kredivo** | ✅ | full + partial | 14 days | ≤ 1×24 h | Low–Med (short tail) | Low–Med (third-party credit provider in the loop) | 🆗 Optional; helps high-ticket conversion |
| **Akulaku** | ✅ | full + partial | 6 months | ≤ 1×24 h | Med (long tail; availability uncertain, §7) | Med | ⛔ Skip unless demand is proven |
| **Bank transfer / VA** (BCA, BNI, BRI, Permata, CIMB, Mandiri Bill, …) | ❌ | manual only | unlimited (your policy) | your process | Med — rare `settlement→deny` reversal (Permata, Mandiri Bill); no chargeback | **High** — manual bank transfer to customer: collect account details, execute, reconcile outside Midtrans | ✅ Still worth enabling (huge adoption, high limits) **but only with a written manual-refund SOP** |
| **Over the counter** (Indomaret, Alfamart) | ❌ | manual only | unlimited | your process | Med — Indomaret reversal quirk; customer paid in cash | **High** — same manual burden on a cash-paying customer base | ⛔ Avoid for cancellation-prone businesses |
| **Direct debit** (BCA KlikPay, CIMB Clicks, BRImo, …) | ❌ (not in refund matrix) | manual only | unlimited | your process | Low–Med | **High** (legacy methods, manual refunds) | ⛔ Skip unless specifically needed |

### 8.2 What actually hurts a small business

Ordered by real-world pain for a low-headcount merchant (e.g., a class/booking
service where *the merchant* initiates refunds when sessions cancel):

1. **VA/OTC refunds are the hidden cost center.** Every refund is a manual bank
   transfer outside Midtrans with no shared audit trail. If your business cancels
   often, the "free" bank-transfer channel becomes your most expensive one in
   labor hours. Mitigate: refund-SOP template, dedicated finance slot per week,
   or steer customers to wallets/QRIS.
2. **Card chargebacks are the only involuntary loss.** Evidence is due in ~7
   calendar days and banks enforce per-merchant chargeback thresholds
   (https://docs.midtrans.com/docs/what-is-chargeback). For digital services,
   "service not rendered" disputes are hard to fight — keep attendance/access
   logs for at least the 6-month card refund window.
3. **Liquidity coupling bites small balances.** Refunds require disbursable
   (payable) funds; if you auto-withdraw everything daily, a refund request can
   fail with insufficient balance (SNAP refund error `4035814 Insufficient
   Funds`). Keep a float sized to ~2–4 weeks of historical refunds.
4. **Prefer cancel over refund whenever possible.** A captured-but-unsettled card
   voided via Cancel restores the customer's limit within ~H+1, vs 7–14 working
   days for a refund — and pending transactions cancel for free. Operationally,
   the cheapest refund is the one that never reaches `settlement`.
5. **Refund latency = support load.** Wallet refunds (≤24 h) rarely generate
   tickets; card refunds (7–14 days, 45 days cross-border) and ShopeePay
   (up to 20 days) reliably do. Set customer expectations *at refund time*, and
   only mark a refund done when the webhook with `bank_confirmed_at` arrives.
6. **Your books stay open for the longest window you enable.** ShopeePay = 365
   days, cards = 6 months, OVO = 7 days. Enable a method = accept its tail.

### 8.3 Suggested priority for a small business

1. **Tier 1 (enable first):** QRIS (GoPay-acquired) + GoPay + DANA — low fees,
   instant confirmation, ≤24 h API refunds, partial refund support.
2. **Tier 2 (enable with process):** Cards (chargeback discipline + evidence
   retention) and bank-transfer VA (manual-refund SOP + reversal handling in the
   webhook consumer).
3. **Tier 3 (demand-driven):** ShopeePay, OVO, Kredivo, Google Pay.
4. **Avoid unless required:** OTC, direct debit, Akulaku — manual refunds and/or
   long tails with the weakest operational tooling.

---

## 9. Practical implications (mechanism-level)

- Build refund capability around **two paths**: API-refund (card + GoPay/QRIS/
  ShopeePay/DANA/OVO/Kredivo/Akulaku) vs **manual merchant-side refund** (VA, OTC,
  expired-window transactions).
- Model refunds as an **async state machine**: request → `refund`/`partial_refund`
  status → final confirmation only on the webhook carrying `bank_confirmed_at`;
  handle `202` bank-denied (direct refund) and `406/412/414` errors; retry safely
  with a stable `refund_key` (7-day reuse limit).
- Refunds require **payable balance** → a merchant that already withdrew funds may
  be unable to refund until new sales replenish the balance.
- Enforce per-method **refund windows** (7d–365d) and the ShopeePay **time-of-day
  window** (06:00–23:50 WIB) in application logic to avoid rejected requests.
- For **cancellation**, prefer cancel-while-pending / void-while-capture semantics;
  after `settlement` only refund applies.
- Notification handlers must handle the **`settlement → deny` reversal** (Permata
  VA, Mandiri Bill, Indomaret) as an implicit forced refund.

---

## Appendix: primary sources consulted

- https://docs.midtrans.com/llms.txt (site index)
- https://docs.midtrans.com/docs/payment-overview
- https://docs.midtrans.com/docs/snap-advanced-feature
- https://docs.midtrans.com/docs/custom-interface-core-api
- https://docs.midtrans.com/docs/coreapi-card-payment-integration
- https://docs.midtrans.com/docs/coreapi-core-api-bank-transfer-integration
- https://docs.midtrans.com/docs/coreapi-e-money-integration
- https://docs.midtrans.com/docs/coreapi-over-the-counter-payment-integration
- https://docs.midtrans.com/docs/coreapi-cardless-credit-payment-integration
- https://docs.midtrans.com/docs/gopay-static-qris
- https://docs.midtrans.com/docs/qris-payment-method-in-midtrans
- https://docs.midtrans.com/docs/introduction-to-card-payment-processing
- https://docs.midtrans.com/docs/which-payment-methods-do-midtrans-currently-support
- https://docs.midtrans.com/docs/default-expiry-time-for-each-payment-method
- https://docs.midtrans.com/docs/is-there-a-minimum-and-maximum-transaction-value-that-i-can-charge-with-midtrans
- https://docs.midtrans.com/docs/transaction-status-cycle
- https://docs.midtrans.com/docs/https-notification-webhooks
- https://docs.midtrans.com/reference/transaction-status
- https://docs.midtrans.com/reference/get-transaction-status
- https://docs.midtrans.com/reference/charge-api , /reference/charge-transactions-1
- https://docs.midtrans.com/reference/capture-api
- https://docs.midtrans.com/reference/cancel-transaction , /reference/cancel-api , /reference/cancel-api-1
- https://docs.midtrans.com/reference/expire-api , /reference/expire-a-snap-session , /reference/cancel-a-snap-session
- https://docs.midtrans.com/reference/refund-transaction
- https://docs.midtrans.com/reference/direct-refund-transaction
- https://docs.midtrans.com/reference/refund-transactions-card
- https://docs.midtrans.com/reference/refund-api , /reference/refund-api-1
- https://docs.midtrans.com/docs/introduction-to-refund
- https://docs.midtrans.com/docs/what-payment-method-that-have-refund-feature
- https://docs.midtrans.com/docs/how-can-i-refund-transaction
- https://docs.midtrans.com/docs/how-long-will-the-transaction-funds-be-credited-to-the-cardholder-after-a-refund
- https://docs.midtrans.com/docs/will-i-be-charged-for-chargebacks-or-refunds
- https://docs.midtrans.com/docs/how-can-i-cancel-a-transaction
- https://docs.midtrans.com/docs/can-i-cancel-a-transaction-that-has-been-settled
- https://docs.midtrans.com/docs/payment-methods (activation)
- https://docs.midtrans.com/reference/payment-method-google-pay
- https://docs.midtrans.com/reference/other-banks
- https://docs.midtrans.com/docs/what-is-chargeback
- https://docs.midtrans.com/docs/apakah-terdapat-biaya-yang-harus-dibayar-pada-transaksi-refund-atau-chargeback-1 (ID, refund/chargeback fee FAQ)
