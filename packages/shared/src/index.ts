/**
 * `@bookclass/shared` — framework-free types, schemas, and constants shared by
 * `apps/api` and `apps/web`. Must never import NestJS or Next.js; enforced by
 * `scripts/check-framework-free.mjs` (run before every build).
 */
export * from './app';
export * from './constants';
export * from './errors';
export * from './money';
export * from './pagination';
export * from './roles';

export * from './dto/booking';
export * from './dto/catalog';
export * from './dto/common';
export * from './dto/health';
export * from './dto/identity';
export * from './dto/payment';
