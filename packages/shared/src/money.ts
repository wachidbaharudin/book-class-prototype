import { z } from 'zod';
import { DEFAULT_CURRENCY } from './constants';

/**
 * Money at every boundary is a plain integer in the center currency (XD-2).
 * In app code it is a Dinero.js v2 object; at the DB and JSON edges it is this
 * value. No float ever crosses a boundary.
 */
export const MoneyAmountSchema = z.number().int().nonnegative().safe();
export type MoneyAmount = z.infer<typeof MoneyAmountSchema>;

export const CurrencySchema = z.literal(DEFAULT_CURRENCY);
export type Currency = z.infer<typeof CurrencySchema>;
