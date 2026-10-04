import { z } from 'zod';
import { CurrencySchema, MoneyAmountSchema } from '../money';
import { IdSchema, IsoUtcSchema } from './common';

export const PAYMENT_METHODS = ['qris', 'manual', 'store_credit'] as const;
export const PaymentMethodSchema = z.enum(PAYMENT_METHODS);
export type PaymentMethod = z.infer<typeof PaymentMethodSchema>;

export const PAYMENT_STATUSES = ['pending', 'paid', 'failed', 'expired'] as const;
export const PaymentStatusSchema = z.enum(PAYMENT_STATUSES);
export type PaymentStatus = z.infer<typeof PaymentStatusSchema>;

export const PaymentSchema = z.object({
  id: IdSchema,
  centerId: IdSchema,
  bookingId: IdSchema,
  method: PaymentMethodSchema,
  status: PaymentStatusSchema,
  amount: MoneyAmountSchema,
  currency: CurrencySchema,
  /** Core API `generate-qr-code` action URL to render (FR-5.1). */
  qrCodeUrl: z.string().url().nullable(),
  /** BR-2 seat-hold deadline. */
  expiresAt: IsoUtcSchema,
  paidAt: IsoUtcSchema.nullable(),
});
export type Payment = z.infer<typeof PaymentSchema>;
