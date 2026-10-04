/**
 * Business-rule constants shared by api, web, and CI. Values reference the
 * business rules in PRD §5 and the cross-cutting decisions in ENG-00 §6.
 */

/** BR-2: default seat-hold / QR expiry (GoPay QRIS accepts 20s–7d via custom_expiry). */
export const QR_EXPIRY_MINUTES = 30;

/** FR-7.2: teachers may mark attendance from session start until this window closes. */
export const ATTENDANCE_WINDOW_HOURS = 24;

/** Refund windows: on-us (GoPay-acquired) vs off-us QRIS. See docs/research/midtrans-payment-refund-mechanisms.md. */
export const REFUND_WINDOW_ON_US_DAYS = 45;
export const REFUND_WINDOW_OFF_US_DAYS = 7;

/** SCHEMA §1: all money is BIGINT IDR. */
export const DEFAULT_CURRENCY = 'IDR';
export const CURRENCY_CODE_LENGTH = 3;

/** Public booking identifier prefix, e.g. BK-2025-000123. */
export const BOOKING_CODE_PREFIX = 'BK';

/** XD-10: default and maximum page sizes for cursor pagination. */
export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;
