import { z } from 'zod';
import { APP_NAME } from '../app';

export const HealthResponseSchema = z.object({
  status: z.literal('ok'),
  app: z.string(),
});
export type HealthResponse = z.infer<typeof HealthResponseSchema>;

export const HEALTH_FALLBACK: HealthResponse = { status: 'ok', app: APP_NAME };
