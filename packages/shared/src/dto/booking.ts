import { z } from 'zod';
import { MoneyAmountSchema } from '../money';
import { IdSchema } from './common';

export const BOOKING_TYPES = ['session', 'series'] as const;
export const BookingTypeSchema = z.enum(BOOKING_TYPES);
export type BookingType = z.infer<typeof BookingTypeSchema>;

export const BOOKING_STATUSES = [
  'pending_payment',
  'paid',
  'cancelled',
  'partially_cancelled',
] as const;
export const BookingStatusSchema = z.enum(BOOKING_STATUSES);
export type BookingStatus = z.infer<typeof BookingStatusSchema>;

export const BOOKING_ITEM_STATUSES = [
  'pending_payment',
  'confirmed',
  'cancelled',
  'completed',
  'no_show',
] as const;
export const BookingItemStatusSchema = z.enum(BOOKING_ITEM_STATUSES);
export type BookingItemStatus = z.infer<typeof BookingItemStatusSchema>;

/** Request body for `POST /api/v1/bookings`. The idempotency key travels in a header (XD-4). */
export const CreateBookingInputSchema = z
  .object({
    studentProfileId: IdSchema,
    classId: IdSchema,
    bookingType: BookingTypeSchema,
    sessionIds: z.array(IdSchema).min(1),
  })
  .refine((value) => value.bookingType !== 'series' || value.sessionIds.length > 1, {
    message: 'series bookings must include more than one session',
    path: ['sessionIds'],
  });
export type CreateBookingInput = z.infer<typeof CreateBookingInputSchema>;

export const BookingItemSchema = z.object({
  id: IdSchema,
  bookingId: IdSchema,
  sessionId: IdSchema,
  status: BookingItemStatusSchema,
  /** I-4: price snapshot, the series share for package bookings (XD-2). */
  unitPrice: MoneyAmountSchema,
});
export type BookingItem = z.infer<typeof BookingItemSchema>;

export const BookingSchema = z.object({
  id: IdSchema,
  centerId: IdSchema,
  code: z.string().min(1),
  customerId: IdSchema,
  studentProfileId: IdSchema,
  classId: IdSchema,
  bookingType: BookingTypeSchema,
  status: BookingStatusSchema,
  packagePrice: MoneyAmountSchema.nullable(),
  items: z.array(BookingItemSchema),
});
export type Booking = z.infer<typeof BookingSchema>;
