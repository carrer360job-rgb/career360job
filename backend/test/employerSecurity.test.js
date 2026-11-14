import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { hasTrustedApproval, signaturesMatch } from '../src/routes/employerRoutes.js';

test('employer access needs a recorded admin review', () => {
  assert.equal(hasTrustedApproval({ status: 'approved' }), false);
  assert.equal(hasTrustedApproval({ status: 'approved', reviewedBy: 'admin' }), false);
  assert.equal(hasTrustedApproval({
    status: 'approved', reviewedBy: 'admin', reviewedAt: { toMillis: () => 100 },
  }), true);
  assert.equal(hasTrustedApproval({
    status: 'pending', reviewedBy: 'admin', reviewedAt: { toMillis: () => 100 },
  }), false);
});

test('Razorpay checkout signature accepts the exact order and payment pair', () => {
  const secret = 'test-secret';
  const signature = createHmac('sha256', secret)
    .update('order_123|pay_456').digest('hex');
  assert.equal(signaturesMatch('order_123|pay_456', signature, secret), true);
  assert.equal(signaturesMatch('order_123|pay_789', signature, secret), false);
  assert.equal(signaturesMatch('order_999|pay_456', signature, secret), false);
  assert.equal(signaturesMatch('order_123|pay_456', 'bad', secret), false);
});

test('Razorpay webhook signature checks the raw request bytes', () => {
  const body = Buffer.from('{"event":"payment.captured","payload":{}}');
  const secret = 'webhook-secret';
  const signature = createHmac('sha256', secret).update(body).digest('hex');
  assert.equal(signaturesMatch(body, signature, secret), true);
  assert.equal(signaturesMatch(Buffer.from('{"payload":{},"event":"payment.captured"}'), signature, secret), false);
});
