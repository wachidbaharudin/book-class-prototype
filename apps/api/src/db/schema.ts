import { desc, sql } from 'drizzle-orm';
import {
  bigint,
  bigserial,
  boolean,
  char,
  check,
  date,
  index,
  integer,
  jsonb,
  pgEnum,
  pgTable,
  smallint,
  text,
  timestamp,
  unique,
  uniqueIndex,
  type AnyPgColumn,
} from 'drizzle-orm/pg-core';

/**
 * Drizzle schema mirroring `docs/schema.sql` 1:1 (ENG-00 §3, SCHEMA.md §5).
 *
 * This file doubles as the invariant inventory: CHECK constraints, partial unique
 * indexes, and ENUMs are declared here and generated into SQL migrations by
 * `pnpm --filter @bookclass/api db:generate`. Money is BIGINT IDR; timestamps are
 * `TIMESTAMPTZ` (UTC) everywhere. Every table carries `center_id` (XD-8).
 */

// -------------------------------------------------------------
// Enums
// -------------------------------------------------------------
export const userRole = pgEnum('user_role', ['admin', 'teacher', 'customer']);
export const userStatus = pgEnum('user_status', ['active', 'invited', 'suspended']);
export const classStatus = pgEnum('class_status', ['draft', 'published', 'archived']);
export const teacherRole = pgEnum('teacher_role', ['main', 'co']);
export const sessionStatus = pgEnum('session_status', ['scheduled', 'cancelled']);
export const priceRuleType = pgEnum('price_rule_type', ['date', 'dow']);
export const bookingType = pgEnum('booking_type', ['session', 'series']);
export const bookingStatus = pgEnum('booking_status', [
  'pending_payment',
  'paid',
  'cancelled',
  'partially_cancelled',
]);
export const bookingItemStatus = pgEnum('booking_item_status', [
  'pending_payment',
  'confirmed',
  'cancelled',
  'completed',
  'no_show',
]);
export const paymentMethod = pgEnum('payment_method', ['qris', 'manual', 'store_credit']);
export const paymentStatus = pgEnum('payment_status', ['pending', 'paid', 'failed', 'expired']);
export const refundMethod = pgEnum('refund_method', ['gateway', 'store_credit']);
export const refundStatus = pgEnum('refund_status', ['pending', 'succeeded', 'failed']);
export const refundReason = pgEnum('refund_reason', ['policy', 'admin_override', 'reschedule']);
export const creditEntryType = pgEnum('credit_entry_type', [
  'refund_credit',
  'payment_spend',
  'adjustment',
]);
export const attendanceStatus = pgEnum('attendance_status', ['present', 'absent']);
export const refundDestination = pgEnum('refund_destination', [
  'gateway_then_credit',
  'credit_only',
]);
export const branchStatus = pgEnum('branch_status', ['active', 'archived']);

const createdAt = () => timestamp('created_at', { withTimezone: true }).notNull().defaultNow();
const updatedAt = () => timestamp('updated_at', { withTimezone: true }).notNull().defaultNow();
const id = () => bigserial('id', { mode: 'number' }).primaryKey();
const centerId = () =>
  bigint('center_id', { mode: 'number' })
    .notNull()
    .references(() => centers.id);

// -------------------------------------------------------------
// 3.1 Identity & Tenancy
// -------------------------------------------------------------
export const centers = pgTable('centers', {
  id: id(),
  name: text('name').notNull(),
  currency: char('currency', { length: 3 }).notNull().default('IDR'),
  refundDestination: refundDestination('refund_destination')
    .notNull()
    .default('gateway_then_credit'),
  midtransMerchantId: text('midtrans_merchant_id'),
  midtransServerKeyEnc: text('midtrans_server_key_enc'),
  midtransClientKey: text('midtrans_client_key'),
  isProduction: boolean('is_production').notNull().default(false),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
  // Added by ALTER in schema.sql; classes may override it (FR-6.1).
  defaultCancellationPolicyId: bigint('default_cancellation_policy_id', {
    mode: 'number',
  }).references((): AnyPgColumn => cancellationPolicies.id),
});

export const users = pgTable(
  'users',
  {
    id: id(),
    centerId: centerId(),
    email: text('email').notNull(),
    name: text('name').notNull(),
    phone: text('phone'),
    passwordHash: text('password_hash'),
    role: userRole('role').notNull(),
    status: userStatus('status').notNull().default('active'),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [unique('ux_users_center_email').on(t.centerId, t.email)],
);

export const studentProfiles = pgTable(
  'student_profiles',
  {
    id: id(),
    centerId: centerId(),
    customerId: bigint('customer_id', { mode: 'number' })
      .notNull()
      .references(() => users.id),
    name: text('name').notNull(),
    birthDate: date('birth_date'),
    notes: text('notes'),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [index('ix_student_profiles_customer').on(t.centerId, t.customerId)],
);

// -------------------------------------------------------------
// 3.3 Cancellation policies
// -------------------------------------------------------------
export const cancellationPolicies = pgTable('cancellation_policies', {
  id: id(),
  centerId: centerId(),
  name: text('name').notNull(),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

export const cancellationPolicyRules = pgTable(
  'cancellation_policy_rules',
  {
    id: id(),
    centerId: centerId(),
    policyId: bigint('policy_id', { mode: 'number' })
      .notNull()
      .references(() => cancellationPolicies.id, { onDelete: 'cascade' }),
    hoursBefore: integer('hours_before').notNull(),
    refundPercent: smallint('refund_percent').notNull(),
  },
  (t) => [
    unique('ux_policy_rules_hours').on(t.policyId, t.hoursBefore),
    index('ix_policy_rules_center').on(t.centerId, t.policyId),
    check('cancellation_policy_rules_hours_before_check', sql`${t.hoursBefore} >= 0`),
    check(
      'cancellation_policy_rules_refund_percent_check',
      sql`${t.refundPercent} BETWEEN 0 AND 100`,
    ),
  ],
);

// -------------------------------------------------------------
// 3.2 Catalog & Scheduling
// -------------------------------------------------------------
export const branches = pgTable(
  'branches',
  {
    id: id(),
    centerId: centerId(),
    name: text('name').notNull(),
    address: text('address'),
    timezone: text('timezone').notNull(),
    status: branchStatus('status').notNull().default('active'),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [index('ix_branches_center').on(t.centerId)],
);

export const classes = pgTable(
  'classes',
  {
    id: id(),
    centerId: centerId(),
    branchId: bigint('branch_id', { mode: 'number' })
      .notNull()
      .references(() => branches.id),
    title: text('title').notNull(),
    description: text('description'),
    schedule: jsonb('schedule').notNull(),
    capacity: integer('capacity').notNull(),
    basePrice: bigint('base_price', { mode: 'number' }).notNull(),
    packagePrice: bigint('package_price', { mode: 'number' }),
    cancellationPolicyId: bigint('cancellation_policy_id', { mode: 'number' }).references(
      () => cancellationPolicies.id,
    ),
    status: classStatus('status').notNull().default('draft'),
    createdBy: bigint('created_by', { mode: 'number' }).references(() => users.id),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [
    index('ix_classes_center_status').on(t.centerId, t.status),
    index('ix_classes_center_branch').on(t.centerId, t.branchId),
    check('classes_capacity_check', sql`${t.capacity} > 0`),
    check('classes_base_price_check', sql`${t.basePrice} >= 0`),
    check('classes_package_price_check', sql`${t.packagePrice} >= 0`),
  ],
);

export const classTeachers = pgTable(
  'class_teachers',
  {
    id: id(),
    centerId: centerId(),
    classId: bigint('class_id', { mode: 'number' })
      .notNull()
      .references(() => classes.id, { onDelete: 'cascade' }),
    teacherId: bigint('teacher_id', { mode: 'number' })
      .notNull()
      .references(() => users.id),
    role: teacherRole('role').notNull(),
  },
  (t) => [
    unique('ux_class_teacher').on(t.classId, t.teacherId),
    // I-2: at most ONE main teacher per class, enforced by the database.
    uniqueIndex('ux_class_teachers_one_main')
      .on(t.classId)
      .where(sql`${t.role} = 'main'`),
    index('ix_class_teachers_teacher').on(t.centerId, t.teacherId),
  ],
);

export const sessions = pgTable(
  'sessions',
  {
    id: id(),
    centerId: centerId(),
    classId: bigint('class_id', { mode: 'number' })
      .notNull()
      .references(() => classes.id, { onDelete: 'cascade' }),
    startsAt: timestamp('starts_at', { withTimezone: true }).notNull(),
    endsAt: timestamp('ends_at', { withTimezone: true }).notNull(),
    capacity: integer('capacity').notNull(),
    status: sessionStatus('status').notNull().default('scheduled'),
    cancelledReason: text('cancelled_reason'),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [
    index('ix_sessions_class_start').on(t.centerId, t.classId, t.startsAt),
    index('ix_sessions_start').on(t.centerId, t.startsAt),
    check('ck_session_window', sql`${t.endsAt} > ${t.startsAt}`),
    check('sessions_capacity_check', sql`${t.capacity} >= 0`),
  ],
);

// -------------------------------------------------------------
// 3.3 Price rules (BR-1: exact date > day-of-week > base)
// -------------------------------------------------------------
export const priceRules = pgTable(
  'price_rules',
  {
    id: id(),
    centerId: centerId(),
    classId: bigint('class_id', { mode: 'number' })
      .notNull()
      .references(() => classes.id, { onDelete: 'cascade' }),
    ruleType: priceRuleType('rule_type').notNull(),
    appliesOn: date('applies_on'),
    dayOfWeek: smallint('day_of_week'),
    price: bigint('price', { mode: 'number' }).notNull(),
    validFrom: date('valid_from'),
    validTo: date('valid_to'),
    createdAt: createdAt(),
  },
  (t) => [
    index('ix_price_rules_class').on(t.centerId, t.classId),
    check('price_rules_day_of_week_check', sql`${t.dayOfWeek} BETWEEN 0 AND 6`),
    check('price_rules_price_check', sql`${t.price} >= 0`),
    check(
      'ck_price_rule_fields',
      sql`(${t.ruleType} = 'date' AND ${t.appliesOn} IS NOT NULL AND ${t.dayOfWeek} IS NULL) OR (${t.ruleType} = 'dow' AND ${t.dayOfWeek} IS NOT NULL AND ${t.appliesOn} IS NULL)`,
    ),
  ],
);

// -------------------------------------------------------------
// 3.4 Booking & Money
// -------------------------------------------------------------
export const bookings = pgTable(
  'bookings',
  {
    id: id(),
    centerId: centerId(),
    code: text('code').notNull(),
    customerId: bigint('customer_id', { mode: 'number' })
      .notNull()
      .references(() => users.id),
    studentProfileId: bigint('student_profile_id', { mode: 'number' })
      .notNull()
      .references(() => studentProfiles.id),
    classId: bigint('class_id', { mode: 'number' })
      .notNull()
      .references(() => classes.id),
    bookingType: bookingType('booking_type').notNull(),
    status: bookingStatus('status').notNull().default('pending_payment'),
    packagePrice: bigint('package_price', { mode: 'number' }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [
    unique('ux_bookings_code').on(t.code),
    index('ix_bookings_customer').on(t.centerId, t.customerId, desc(t.createdAt)),
    check('bookings_package_price_check', sql`${t.packagePrice} >= 0`),
  ],
);

export const bookingItems = pgTable(
  'booking_items',
  {
    id: id(),
    centerId: centerId(),
    bookingId: bigint('booking_id', { mode: 'number' })
      .notNull()
      .references(() => bookings.id, { onDelete: 'cascade' }),
    sessionId: bigint('session_id', { mode: 'number' })
      .notNull()
      .references(() => sessions.id),
    status: bookingItemStatus('status').notNull().default('pending_payment'),
    unitPrice: bigint('unit_price', { mode: 'number' }).notNull(),
    cancelledAt: timestamp('cancelled_at', { withTimezone: true }),
    cancelReason: text('cancel_reason'),
    createdAt: createdAt(),
  },
  (t) => [
    unique('ux_item_booking_session').on(t.bookingId, t.sessionId),
    index('ix_items_session_status').on(t.centerId, t.sessionId, t.status),
    check('booking_items_unit_price_check', sql`${t.unitPrice} >= 0`),
  ],
);

export const payments = pgTable(
  'payments',
  {
    id: id(),
    centerId: centerId(),
    bookingId: bigint('booking_id', { mode: 'number' })
      .notNull()
      .references(() => bookings.id),
    method: paymentMethod('method').notNull(),
    status: paymentStatus('status').notNull().default('pending'),
    amount: bigint('amount', { mode: 'number' }).notNull(),
    currency: char('currency', { length: 3 }).notNull().default('IDR'),
    gatewayOrderId: text('gateway_order_id'),
    gatewayTransactionId: text('gateway_transaction_id'),
    qrCodeUrl: text('qr_code_url'),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    paidAt: timestamp('paid_at', { withTimezone: true }),
    createdAt: createdAt(),
  },
  (t) => [
    unique('ux_payments_booking').on(t.bookingId),
    unique('ux_payments_gateway_order').on(t.gatewayOrderId),
    index('ix_payments_expiry')
      .on(t.status, t.expiresAt)
      .where(sql`${t.status} = 'pending'`),
    check('payments_amount_check', sql`${t.amount} >= 0`),
  ],
);

export const paymentEvents = pgTable(
  'payment_events',
  {
    id: id(),
    centerId: centerId(),
    paymentId: bigint('payment_id', { mode: 'number' })
      .notNull()
      .references(() => payments.id),
    gatewayEventId: text('gateway_event_id').notNull(),
    eventType: text('event_type').notNull(),
    payload: jsonb('payload').notNull(),
    receivedAt: timestamp('received_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [unique('ux_payment_events_gateway').on(t.gatewayEventId)],
);

export const refunds = pgTable(
  'refunds',
  {
    id: id(),
    centerId: centerId(),
    bookingItemId: bigint('booking_item_id', { mode: 'number' })
      .notNull()
      .references(() => bookingItems.id),
    amount: bigint('amount', { mode: 'number' }).notNull(),
    method: refundMethod('method').notNull(),
    status: refundStatus('status').notNull().default('pending'),
    reason: refundReason('reason').notNull(),
    gatewayRefundId: text('gateway_refund_id'),
    createdBy: bigint('created_by', { mode: 'number' }).references(() => users.id),
    createdAt: createdAt(),
  },
  (t) => [
    index('ix_refunds_item').on(t.centerId, t.bookingItemId),
    check('refunds_amount_check', sql`${t.amount} > 0`),
  ],
);

export const creditLedger = pgTable(
  'credit_ledger',
  {
    id: id(),
    centerId: centerId(),
    customerId: bigint('customer_id', { mode: 'number' })
      .notNull()
      .references(() => users.id),
    amount: bigint('amount', { mode: 'number' }).notNull(),
    entryType: creditEntryType('entry_type').notNull(),
    refBookingItemId: bigint('ref_booking_item_id', { mode: 'number' }).references(
      () => bookingItems.id,
    ),
    refPaymentId: bigint('ref_payment_id', { mode: 'number' }).references(() => payments.id),
    createdAt: createdAt(),
  },
  (t) => [index('ix_credit_customer').on(t.centerId, t.customerId, t.createdAt)],
);

export const settlementEntries = pgTable(
  'settlement_entries',
  {
    id: id(),
    centerId: centerId(),
    bookingItemId: bigint('booking_item_id', { mode: 'number' })
      .notNull()
      .references(() => bookingItems.id),
    amount: bigint('amount', { mode: 'number' }).notNull(),
    earnedAt: timestamp('earned_at', { withTimezone: true }),
    createdAt: createdAt(),
  },
  (t) => [
    unique('ux_settlement_item').on(t.bookingItemId),
    index('ix_settlement_unearned')
      .on(t.centerId)
      .where(sql`${t.earnedAt} IS NULL`),
    check('settlement_entries_amount_check', sql`${t.amount} >= 0`),
  ],
);

// -------------------------------------------------------------
// 3.5 Operations
// -------------------------------------------------------------
export const attendance = pgTable(
  'attendance',
  {
    id: id(),
    centerId: centerId(),
    bookingItemId: bigint('booking_item_id', { mode: 'number' })
      .notNull()
      .references(() => bookingItems.id),
    status: attendanceStatus('status').notNull(),
    markedBy: bigint('marked_by', { mode: 'number' })
      .notNull()
      .references(() => users.id),
    markedAt: timestamp('marked_at', { withTimezone: true }),
    autoResolved: boolean('auto_resolved').notNull().default(false),
    createdAt: createdAt(),
  },
  (t) => [unique('ux_attendance_item').on(t.bookingItemId)],
);

export const sessionNotes = pgTable(
  'session_notes',
  {
    id: id(),
    centerId: centerId(),
    sessionId: bigint('session_id', { mode: 'number' })
      .notNull()
      .references(() => sessions.id),
    body: text('body').notNull(),
    authorId: bigint('author_id', { mode: 'number' })
      .notNull()
      .references(() => users.id),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [unique('ux_notes_session').on(t.sessionId)],
);

export const notifications = pgTable(
  'notifications',
  {
    id: id(),
    centerId: centerId(),
    userId: bigint('user_id', { mode: 'number' })
      .notNull()
      .references(() => users.id),
    type: text('type').notNull(),
    payload: jsonb('payload')
      .notNull()
      .default(sql`'{}'::jsonb`),
    sentAt: timestamp('sent_at', { withTimezone: true }),
    createdAt: createdAt(),
  },
  (t) => [
    index('ix_notifications_queue')
      .on(t.centerId)
      .where(sql`${t.sentAt} IS NULL`),
  ],
);
