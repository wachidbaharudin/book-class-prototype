import { z } from 'zod';

/**
 * Error codes for the API error envelope (ENG-00 §6, XD-10):
 *   { "error": { code, message, details? } }
 * Codes are stable and exported so clients never match on free-text messages.
 */
export const ERROR_CODES = {
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  UNAUTHENTICATED: 'UNAUTHENTICATED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  IDEMPOTENCY_KEY_REQUIRED: 'IDEMPOTENCY_KEY_REQUIRED',
  IDEMPOTENCY_CONFLICT: 'IDEMPOTENCY_CONFLICT',
  SEATS_UNAVAILABLE: 'SEATS_UNAVAILABLE',
  PAYMENT_EXPIRED: 'PAYMENT_EXPIRED',
  PAYMENT_ALREADY_PAID: 'PAYMENT_ALREADY_PAID',
  REFUND_REJECTED: 'REFUND_REJECTED',
  INSUFFICIENT_CREDIT: 'INSUFFICIENT_CREDIT',
  WEBHOOK_SIGNATURE_INVALID: 'WEBHOOK_SIGNATURE_INVALID',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
} as const;

export type ErrorCode = (typeof ERROR_CODES)[keyof typeof ERROR_CODES];

export const ERROR_CODE_VALUES = Object.values(ERROR_CODES) as [ErrorCode, ...ErrorCode[]];

export const ErrorCodeSchema = z.enum(ERROR_CODE_VALUES);

export const ApiErrorSchema = z.object({
  code: ErrorCodeSchema,
  message: z.string(),
  details: z.unknown().optional(),
});
export type ApiError = z.infer<typeof ApiErrorSchema>;

export const ErrorEnvelopeSchema = z.object({ error: ApiErrorSchema });
export type ErrorEnvelope = z.infer<typeof ErrorEnvelopeSchema>;
