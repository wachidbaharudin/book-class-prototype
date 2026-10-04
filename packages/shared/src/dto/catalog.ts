import { z } from 'zod';
import { MoneyAmountSchema } from '../money';
import { IdSchema, IsoUtcSchema } from './common';

export const CLASS_STATUSES = ['draft', 'published', 'archived'] as const;
export const ClassStatusSchema = z.enum(CLASS_STATUSES);
export type ClassStatus = z.infer<typeof ClassStatusSchema>;

export const SESSION_STATUSES = ['scheduled', 'cancelled'] as const;
export const SessionStatusSchema = z.enum(SESSION_STATUSES);
export type SessionStatus = z.infer<typeof SessionStatusSchema>;

export const ClassSchema = z.object({
  id: IdSchema,
  centerId: IdSchema,
  branchId: IdSchema,
  title: z.string().min(1),
  description: z.string().nullable(),
  capacity: z.number().int().positive(),
  /** Per-session IDR price (FR-3.1). */
  basePrice: MoneyAmountSchema,
  /** Whole-series IDR price; null for per-session-only classes (FR-3.1). */
  packagePrice: MoneyAmountSchema.nullable(),
  status: ClassStatusSchema,
});
export type Class = z.infer<typeof ClassSchema>;

export const SessionSchema = z.object({
  id: IdSchema,
  centerId: IdSchema,
  classId: IdSchema,
  startsAt: IsoUtcSchema,
  endsAt: IsoUtcSchema,
  capacity: z.number().int().nonnegative(),
  status: SessionStatusSchema,
});
export type Session = z.infer<typeof SessionSchema>;
