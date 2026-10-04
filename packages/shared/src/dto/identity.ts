import { z } from 'zod';
import { UserRoleSchema, UserStatusSchema } from '../roles';
import { CurrencySchema } from '../money';
import { IdSchema, IsoUtcSchema } from './common';

export const BRANCH_STATUSES = ['active', 'archived'] as const;
export const BranchStatusSchema = z.enum(BRANCH_STATUSES);
export type BranchStatus = z.infer<typeof BranchStatusSchema>;

export const CenterSchema = z.object({
  id: IdSchema,
  name: z.string().min(1),
  currency: CurrencySchema,
  isProduction: z.boolean(),
  createdAt: IsoUtcSchema,
});
export type Center = z.infer<typeof CenterSchema>;

export const UserSchema = z.object({
  id: IdSchema,
  centerId: IdSchema,
  email: z.string().email(),
  name: z.string().min(1),
  phone: z.string().nullable(),
  role: UserRoleSchema,
  status: UserStatusSchema,
  createdAt: IsoUtcSchema,
});
export type User = z.infer<typeof UserSchema>;

export const BranchSchema = z.object({
  id: IdSchema,
  centerId: IdSchema,
  name: z.string().min(1),
  address: z.string().nullable(),
  /** IANA timezone used to render session times (XD-1), e.g. Asia/Jakarta. */
  timezone: z.string().min(1),
  status: BranchStatusSchema,
});
export type Branch = z.infer<typeof BranchSchema>;

export const StudentProfileSchema = z.object({
  id: IdSchema,
  centerId: IdSchema,
  customerId: IdSchema,
  name: z.string().min(1),
  birthDate: z.string().date().nullable(),
  notes: z.string().nullable(),
});
export type StudentProfile = z.infer<typeof StudentProfileSchema>;
