import { z } from 'zod';
import { DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from './constants';

/** XD-10: cursor pagination on list endpoints (`?cursor=`). */
export const PaginationQuerySchema = z.object({
  cursor: z.string().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE),
});
export type PaginationQuery = z.infer<typeof PaginationQuerySchema>;

export const PageMetaSchema = z.object({
  nextCursor: z.string().nullable(),
});
export type PageMeta = z.infer<typeof PageMetaSchema>;
