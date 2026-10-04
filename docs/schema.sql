-- =============================================================
-- Class Booking App — v1 schema (PostgreSQL 16+)
-- Companion to docs/SCHEMA.md. FR/BR references = PRD.md.
-- Money: BIGINT IDR. Times: TIMESTAMPTZ (UTC storage).
-- =============================================================

BEGIN;

-- -------------------------------------------------------------
-- Enums
-- -------------------------------------------------------------
CREATE TYPE user_role         AS ENUM ('admin','teacher','customer');
CREATE TYPE user_status       AS ENUM ('active','invited','suspended');
CREATE TYPE class_status      AS ENUM ('draft','published','archived');
CREATE TYPE teacher_role      AS ENUM ('main','co');
CREATE TYPE session_status    AS ENUM ('scheduled','cancelled');
CREATE TYPE price_rule_type   AS ENUM ('date','dow');
CREATE TYPE booking_type      AS ENUM ('session','series');
CREATE TYPE booking_status    AS ENUM ('pending_payment','paid','cancelled','partially_cancelled');
CREATE TYPE booking_item_status AS ENUM ('pending_payment','confirmed','cancelled','completed','no_show');
CREATE TYPE payment_method    AS ENUM ('qris','manual','store_credit');  -- FR-5.3: single Core API gateway channel — QRIS (GoPay acquirer) only
CREATE TYPE payment_status    AS ENUM ('pending','paid','failed','expired');
CREATE TYPE refund_method     AS ENUM ('gateway','store_credit');
CREATE TYPE refund_status     AS ENUM ('pending','succeeded','failed');
CREATE TYPE refund_reason     AS ENUM ('policy','admin_override','reschedule');
CREATE TYPE credit_entry_type AS ENUM ('refund_credit','payment_spend','adjustment');
CREATE TYPE attendance_status AS ENUM ('present','absent');
CREATE TYPE refund_destination AS ENUM ('gateway_then_credit','credit_only');
CREATE TYPE branch_status AS ENUM ('active','archived');

-- -------------------------------------------------------------
-- 3.1 Identity & Tenancy
-- -------------------------------------------------------------
CREATE TABLE centers (
    id                           BIGSERIAL PRIMARY KEY,
    name                         TEXT NOT NULL,
    currency                     CHAR(3) NOT NULL DEFAULT 'IDR',
    refund_destination           refund_destination NOT NULL DEFAULT 'gateway_then_credit', -- FR-6.3
    midtrans_merchant_id         TEXT,
    midtrans_server_key_enc      TEXT,                -- encrypted at rest
    midtrans_client_key          TEXT,
    is_production                BOOLEAN NOT NULL DEFAULT false,  -- PRD SC-2: sandbox <-> live is a config flip
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    email                        TEXT NOT NULL,
    name                         TEXT NOT NULL,
    phone                        TEXT,
    password_hash                TEXT,                -- invite tokens live in auth layer
    role                         user_role NOT NULL,
    status                       user_status NOT NULL DEFAULT 'active',
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_users_center_email UNIQUE (center_id, email)
);

CREATE TABLE student_profiles (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    customer_id                  BIGINT NOT NULL REFERENCES users(id),  -- owner account (PRD §2)
    name                         TEXT NOT NULL,
    birth_date                   DATE,
    notes                        TEXT,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_student_profiles_customer ON student_profiles (center_id, customer_id);

-- -------------------------------------------------------------
-- 3.3 Cancellation policies (before classes; centers FK added below)
-- -------------------------------------------------------------
CREATE TABLE cancellation_policies (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    name                         TEXT NOT NULL,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cancellation_policy_rules (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    policy_id                    BIGINT NOT NULL REFERENCES cancellation_policies(id) ON DELETE CASCADE,
    hours_before                 INT NOT NULL CHECK (hours_before >= 0),   -- FR-6.1 cutoffs
    refund_percent               SMALLINT NOT NULL CHECK (refund_percent BETWEEN 0 AND 100),
    CONSTRAINT ux_policy_rules_hours UNIQUE (policy_id, hours_before)
);
CREATE INDEX ix_policy_rules_center ON cancellation_policy_rules (center_id, policy_id);

ALTER TABLE centers
    ADD COLUMN default_cancellation_policy_id BIGINT REFERENCES cancellation_policies(id);
-- center default policy; classes may override (FR-6.1)

-- -------------------------------------------------------------
-- 3.2 Catalog & Scheduling
-- -------------------------------------------------------------
CREATE TABLE branches (                                    -- branches of one organization (PRD §10.5)
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    name                         TEXT NOT NULL,
    address                      TEXT,
    timezone                     TEXT NOT NULL,       -- session rendering; WIB/WITA/WIT
    status                       branch_status NOT NULL DEFAULT 'active',
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_branches_center ON branches (center_id);

CREATE TABLE classes (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    branch_id                    BIGINT NOT NULL REFERENCES branches(id),  -- every class happens at one branch
    title                        TEXT NOT NULL,
    description                  TEXT,
    schedule                     JSONB NOT NULL,       -- template only; sessions are materialized
    -- shapes: {"type":"one_off","date":"2025-01-10","start":"16:00","end":"17:00"}
    --         {"type":"weekly","days":[5],"start_date":"2025-01-04","weeks":8,"start":"16:00","end":"17:00"}
    capacity                     INT NOT NULL CHECK (capacity > 0),   -- default for generated sessions
    base_price                   BIGINT NOT NULL CHECK (base_price >= 0),      -- per session, IDR (FR-3.1)
    package_price                BIGINT CHECK (package_price >= 0),            -- whole series (FR-3.1)
    cancellation_policy_id       BIGINT REFERENCES cancellation_policies(id),  -- NULL -> center default
    status                       class_status NOT NULL DEFAULT 'draft',
    created_by                   BIGINT REFERENCES users(id),
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_classes_center_status ON classes (center_id, status);
CREATE INDEX ix_classes_center_branch ON classes (center_id, branch_id);

CREATE TABLE class_teachers (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    class_id                     BIGINT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    teacher_id                   BIGINT NOT NULL REFERENCES users(id),
    role                         teacher_role NOT NULL,
    CONSTRAINT ux_class_teacher UNIQUE (class_id, teacher_id)
);
-- I-2: at most ONE main teacher per class, enforced by the database itself
CREATE UNIQUE INDEX ux_class_teachers_one_main ON class_teachers (class_id) WHERE role = 'main';
CREATE INDEX ix_class_teachers_teacher ON class_teachers (center_id, teacher_id);

CREATE TABLE sessions (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    class_id                     BIGINT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    starts_at                    TIMESTAMPTZ NOT NULL,
    ends_at                      TIMESTAMPTZ NOT NULL,
    capacity                     INT NOT NULL CHECK (capacity >= 0),  -- snapshot at generation; editable per session
    status                       session_status NOT NULL DEFAULT 'scheduled',  -- "completed" derived from ends_at
    cancelled_reason             TEXT,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_session_window CHECK (ends_at > starts_at)
);
CREATE INDEX ix_sessions_class_start ON sessions (center_id, class_id, starts_at);
CREATE INDEX ix_sessions_start ON sessions (center_id, starts_at);   -- settlement/expiry jobs

-- -------------------------------------------------------------
-- 3.3 Price rules (BR-1: exact date > day-of-week > base)
-- -------------------------------------------------------------
CREATE TABLE price_rules (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    class_id                     BIGINT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    rule_type                    price_rule_type NOT NULL,
    applies_on                   DATE,               -- required iff rule_type='date'
    day_of_week                  SMALLINT CHECK (day_of_week BETWEEN 0 AND 6),  -- required iff 'dow'
    price                        BIGINT NOT NULL CHECK (price >= 0),  -- absolute override of per-session price
    valid_from                   DATE,
    valid_to                     DATE,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_price_rule_fields CHECK (
        (rule_type = 'date' AND applies_on IS NOT NULL AND day_of_week IS NULL) OR
        (rule_type = 'dow'  AND day_of_week IS NOT NULL AND applies_on IS NULL)
    )
);
CREATE INDEX ix_price_rules_class ON price_rules (center_id, class_id);

-- -------------------------------------------------------------
-- 3.4 Booking & Money
-- -------------------------------------------------------------
CREATE TABLE bookings (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    code                         TEXT NOT NULL,       -- public id, e.g. BK-2025-000123
    customer_id                  BIGINT NOT NULL REFERENCES users(id),
    student_profile_id           BIGINT NOT NULL REFERENCES student_profiles(id),
    class_id                     BIGINT NOT NULL REFERENCES classes(id),
    booking_type                 booking_type NOT NULL,
    status                       booking_status NOT NULL DEFAULT 'pending_payment',  -- convenience; items hold truth
    package_price                BIGINT CHECK (package_price >= 0),  -- snapshot for series bookings
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_bookings_code UNIQUE (code)
);
CREATE INDEX ix_bookings_customer ON bookings (center_id, customer_id, created_at DESC);

CREATE TABLE booking_items (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    booking_id                   BIGINT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    session_id                   BIGINT NOT NULL REFERENCES sessions(id),
    status                       booking_item_status NOT NULL DEFAULT 'pending_payment',
    unit_price                   BIGINT NOT NULL CHECK (unit_price >= 0),  -- I-4: price snapshot (share for series)
    cancelled_at                 TIMESTAMPTZ,
    cancel_reason                TEXT,   -- expired | customer | rescheduled | admin
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_item_booking_session UNIQUE (booking_id, session_id)
);
CREATE INDEX ix_items_session_status ON booking_items (center_id, session_id, status);  -- seat counting

CREATE TABLE payments (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    booking_id                   BIGINT NOT NULL REFERENCES bookings(id),
    method                       payment_method NOT NULL,
    status                       payment_status NOT NULL DEFAULT 'pending',
    amount                       BIGINT NOT NULL CHECK (amount >= 0),
    currency                     CHAR(3) NOT NULL DEFAULT 'IDR',
    gateway_order_id             TEXT,               -- Midtrans order id
    gateway_transaction_id       TEXT,               -- Midtrans transaction id
    qr_code_url                  TEXT,               -- Core API generate-qr-code action URL to render (FR-5.1)
    expires_at                   TIMESTAMPTZ NOT NULL,  -- seat-hold deadline (BR-2); default now()+30min via Core API custom_expiry (GoPay QRIS bounds 20s-7d)
    paid_at                      TIMESTAMPTZ,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_payments_booking UNIQUE (booking_id),      -- one payment per booking
    CONSTRAINT ux_payments_gateway_order UNIQUE (gateway_order_id)
);
CREATE INDEX ix_payments_expiry ON payments (status, expires_at) WHERE status = 'pending';  -- expiry job

CREATE TABLE payment_events (                            -- webhook audit + I-3 idempotency
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    payment_id                   BIGINT NOT NULL REFERENCES payments(id),
    gateway_event_id             TEXT NOT NULL,
    event_type                   TEXT NOT NULL,
    payload                      JSONB NOT NULL,
    received_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_payment_events_gateway UNIQUE (gateway_event_id)
);

CREATE TABLE refunds (                                   -- append-only; one or more per item
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    booking_item_id              BIGINT NOT NULL REFERENCES booking_items(id),
    amount                       BIGINT NOT NULL CHECK (amount > 0),
    method                       refund_method NOT NULL,      -- BR-8/BR-9 decide at execution
    status                       refund_status NOT NULL DEFAULT 'pending',  -- failed -> credit fallback
    reason                       refund_reason NOT NULL,
    gateway_refund_id            TEXT,
    created_by                   BIGINT REFERENCES users(id),  -- NULL = system
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_refunds_item ON refunds (center_id, booking_item_id);

CREATE TABLE credit_ledger (                              -- store credit, v1-simple (FR-6.3)
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    customer_id                  BIGINT NOT NULL REFERENCES users(id),
    amount                       BIGINT NOT NULL,   -- + credit in, - spend; balance = SUM(amount)
    entry_type                   credit_entry_type NOT NULL,
    ref_booking_item_id          BIGINT REFERENCES booking_items(id),
    ref_payment_id               BIGINT REFERENCES payments(id),
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_credit_customer ON credit_ledger (center_id, customer_id, created_at);

CREATE TABLE settlement_entries (                         -- the "earned" ledger (FR-8)
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    booking_item_id              BIGINT NOT NULL REFERENCES booking_items(id),
    amount                       BIGINT NOT NULL CHECK (amount >= 0),  -- = unit_price snapshot
    earned_at                    TIMESTAMPTZ,             -- set when session ends (BR-5)
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_settlement_item UNIQUE (booking_item_id)
);
-- refund exposure = unearned amounts minus refunds; partial index serves the dashboard
CREATE INDEX ix_settlement_unearned ON settlement_entries (center_id) WHERE earned_at IS NULL;

-- -------------------------------------------------------------
-- 3.5 Operations
-- -------------------------------------------------------------
CREATE TABLE attendance (
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    booking_item_id              BIGINT NOT NULL REFERENCES booking_items(id),
    status                       attendance_status NOT NULL,
    marked_by                    BIGINT NOT NULL REFERENCES users(id),  -- any assigned teacher
    marked_at                    TIMESTAMPTZ,
    auto_resolved                BOOLEAN NOT NULL DEFAULT false,       -- job: absent 24h after end (FR-7.2)
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_attendance_item UNIQUE (booking_item_id)
);

CREATE TABLE session_notes (                               -- one editable note per session (FR-7.3)
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    session_id                   BIGINT NOT NULL REFERENCES sessions(id),
    body                         TEXT NOT NULL,
    author_id                    BIGINT NOT NULL REFERENCES users(id),
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_notes_session UNIQUE (session_id)
);

CREATE TABLE notifications (                               -- minimal email queue (FR-9)
    id                           BIGSERIAL PRIMARY KEY,
    center_id                    BIGINT NOT NULL REFERENCES centers(id),
    user_id                      BIGINT NOT NULL REFERENCES users(id),
    type                         TEXT NOT NULL,   -- booking_confirmed | payment_receipt | reminder_24h | cancellation | refund | revenue_summary
    payload                      JSONB NOT NULL DEFAULT '{}'::jsonb,
    sent_at                      TIMESTAMPTZ,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_notifications_queue ON notifications (center_id) WHERE sent_at IS NULL;

COMMIT;
