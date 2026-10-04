import { z } from 'zod';

export const IdSchema = z.coerce.number().int().positive();
export type Id = z.infer<typeof IdSchema>;

/** XD-1: instants are ISO-8601 UTC strings on the wire. */
export const IsoUtcSchema = z.string().datetime({ offset: false });
export type IsoUtc = z.infer<typeof IsoUtcSchema>;

export const TimestampsSchema = z.object({
  createdAt: IsoUtcSchema,
  updatedAt: IsoUtcSchema,
});
export type Timestamps = z.infer<typeof TimestampsSchema>;
