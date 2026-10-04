import { z } from 'zod';

/** Roles are the authorization primitive owned by ENG-07. */
export const USER_ROLES = ['admin', 'teacher', 'customer'] as const;
export const UserRoleSchema = z.enum(USER_ROLES);
export type UserRole = z.infer<typeof UserRoleSchema>;

export const USER_STATUSES = ['active', 'invited', 'suspended'] as const;
export const UserStatusSchema = z.enum(USER_STATUSES);
export type UserStatus = z.infer<typeof UserStatusSchema>;
