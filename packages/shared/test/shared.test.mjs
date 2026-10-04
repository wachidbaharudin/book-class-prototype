import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  APP_NAME,
  CreateBookingInputSchema,
  ErrorEnvelopeSchema,
  MoneyAmountSchema,
  QR_EXPIRY_MINUTES,
  UserRoleSchema,
} from '../dist/index.js';

test('BR constants are exported', () => {
  assert.equal(QR_EXPIRY_MINUTES, 30);
  assert.equal(APP_NAME, 'Class Booking');
});

test('role enum accepts only known roles', () => {
  assert.equal(UserRoleSchema.parse('admin'), 'admin');
  assert.equal(UserRoleSchema.safeParse('superuser').success, false);
});

test('money is a non-negative safe integer', () => {
  assert.equal(MoneyAmountSchema.parse(150000), 150000);
  assert.equal(MoneyAmountSchema.safeParse(1500.5).success, false);
  assert.equal(MoneyAmountSchema.safeParse(-1).success, false);
});

test('booking input rejects a single-session series', () => {
  const result = CreateBookingInputSchema.safeParse({
    studentProfileId: 1,
    classId: 2,
    bookingType: 'series',
    sessionIds: [10],
  });
  assert.equal(result.success, false);
});

test('error envelope shape is stable', () => {
  const parsed = ErrorEnvelopeSchema.parse({
    error: { code: 'NOT_FOUND', message: 'Class not found' },
  });
  assert.equal(parsed.error.code, 'NOT_FOUND');
});
