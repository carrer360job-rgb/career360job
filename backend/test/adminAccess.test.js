import test from 'node:test';
import assert from 'node:assert/strict';
import { requireAdmin } from '../src/middlewares/adminMiddleware.js';
import { mapSupabaseIdentity } from '../src/middlewares/authMiddleware.js';

function authorize(user) {
  let status = 200;
  let body;
  let passed = false;
  const response = {
    status(code) { status = code; return this; },
    json(value) { body = value; return this; },
  };
  requireAdmin({ user }, response, () => { passed = true; });
  return { status, body, passed };
}

test('admin access requires both verified email and trusted claim', () => {
  assert.equal(authorize({ email_verified: true, admin: true }).passed, true);
  for (const user of [
    undefined,
    { email_verified: true, admin: false },
    { email_verified: false, admin: true },
    { email_verified: true, admin: 'true' },
  ]) {
    assert.equal(authorize(user).status, 403);
  }
});

test('Supabase admin role comes only from trusted app metadata', () => {
  const identity = mapSupabaseIdentity({
    id: 'test-user', email: 'person@example.invalid', email_confirmed_at: new Date().toISOString(),
    user_metadata: { role: 'ADMIN' }, app_metadata: {},
  }, { role: 'CANDIDATE' });
  assert.equal(authorize(identity).status, 403);
  assert.equal(identity.admin, false);

  const admin = mapSupabaseIdentity({
    id: 'trusted-admin', email: 'admin@example.invalid',
    email_confirmed_at: new Date().toISOString(), app_metadata: { role: 'admin' },
  }, { role: 'ADMIN' });
  assert.equal(authorize(admin).passed, true);
});

test('admin endpoint rejects missing tokens and does not allow arbitrary browser origins', async (t) => {
  process.env.VERCEL = '1';
  process.env.NODE_ENV = 'test';
  process.env.CLIENT_URL_ADMIN = 'http://localhost:5173';
  const { default: app } = await import('../src/index.js');
  const server = app.listen(0);
  t.after(() => server.close());
  await new Promise((resolve) => server.once('listening', resolve));
  const url = `http://127.0.0.1:${server.address().port}/api/admin/me`;

  const missingToken = await fetch(url);
  assert.equal(missingToken.status, 401);

  const missingAuthToken = await fetch(url.replace('/api/admin/me', '/api/auth/me'));
  assert.equal(missingAuthToken.status, 401);
  const missingEmployerToken = await fetch(url.replace('/api/admin/me', '/api/employer/me'));
  assert.equal(missingEmployerToken.status, 401);

  const allowed = await fetch(url, { headers: { Origin: 'http://localhost:5173' } });
  assert.equal(allowed.headers.get('access-control-allow-origin'), 'http://localhost:5173');

  const preflight = await fetch(url, {
    method: 'OPTIONS',
    headers: {
      Origin: 'http://localhost:5173',
      'Access-Control-Request-Method': 'GET',
      'Access-Control-Request-Headers': 'authorization',
    },
  });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), 'http://localhost:5173');
  assert.match(preflight.headers.get('access-control-allow-headers') ?? '', /authorization/i);

  const rejected = await fetch(url, { headers: { Origin: 'https://untrusted.example' } });
  assert.equal(rejected.headers.get('access-control-allow-origin'), null);
});
