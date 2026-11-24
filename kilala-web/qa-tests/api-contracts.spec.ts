import { test, expect } from '@playwright/test';

const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:5001';

test.describe('Sprint 1 - API smoke contracts', () => {
  test('health contract returns healthy status', async ({ request }) => {
    const response = await request.get(`${API_BASE_URL}/api/health`);
    expect(response.status()).toBe(200);
    expect(await response.json()).toEqual({
      status: 'healthy',
      system: 'Kilala Backend API',
    });
  });

  test('login rejects missing credentials with HTTP 400', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: {},
    });
    expect(response.status()).toBe(400);
    expect(await response.json()).toEqual({
      error: 'Email and password are required',
    });
  });

  test('login rejects invalid credentials with HTTP 401', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: {
        email: 'missing@example.test',
        password: 'not-the-password',
      },
    });
    expect(response.status()).toBe(401);
    expect(await response.json()).toEqual({
      error: 'Invalid email or password',
    });
  });

  test('seeded LGU login returns agreed JWT and user fields', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: {
        email: 'admin@makati.gov.ph',
        password: 'MockHashForTestingOnly123456789012',
      },
    });
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body.message).toBe('Login successful');
    expect(typeof body.token).toBe('string');
    expect(body.token.split('.')).toHaveLength(3);
    expect(body.user).toEqual({
      id: '22222222-2222-2222-2222-222222222221',
      email: 'admin@makati.gov.ph',
      role: 'LGU_ADMIN',
    });
  });

  test('business signup rejects missing required fields without creating data', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/api/auth/register-business`, {
      data: {},
    });
    expect(response.status()).toBe(400);
    expect(await response.json()).toEqual({
      error: 'Missing required business registration fields',
    });
  });

  test('cardholder verification rejects missing fields', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/api/auth/verify-record`, {
      data: {},
    });
    expect(response.status()).toBe(400);
    expect(await response.json()).toEqual({
      error: 'All fields are required for verification',
    });
  });

  test('cardholder verification returns the seeded unclaimed record', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/api/auth/verify-record`, {
      data: {
        privilege_type: 'PWD',
        card_id_number: 'MKT-PWD-2026-TEST-001',
        first_name: 'Ana',
        middle_name: 'Marie',
        last_name: 'Santos',
        date_of_birth: '1999-03-17',
      },
    });
    const body = await response.json();
    if (response.status() === 200) {
      expect(body).toEqual({
        message: 'Record verified successfully',
        profile_id: '44444444-4444-4444-4444-444444444443',
        first_name: 'Ana',
        last_name: 'Santos',
      });
    } else {
      expect(response.status()).toBe(409);
      expect(body).toEqual({
        error: 'This ID has already been claimed by an existing account.',
      });
    }
  });

  test('cardholder claim rejects missing fields', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/api/auth/claim-cardholder`, {
      data: {},
    });
    expect(response.status()).toBe(400);
    expect(await response.json()).toEqual({
      error: 'All fields are required to claim your ID',
    });
  });

  test('GET /api/lgus returns the Metro Manila cities', async ({ request }) => {
    const res = await request.get(`${API_BASE_URL}/api/lgus`);
    expect(res.status()).toBe(200);
    const names = (await res.json()).map((l: { municipality_name: string }) => l.municipality_name);
    for (const city of ['Quezon City', 'Manila', 'Taguig', 'Makati City', 'Pasig', 'Caloocan']) {
      expect(names).toContain(city);
    }
  });
});

test.describe('POST /api/lgu-admins contracts', () => {
  let token: string;

  test.beforeAll(async ({ request }) => {
    // These endpoints are SUPERADMIN-only since Task 1; log in as super admin.
    const res = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: {
        email: process.env.SUPERADMIN_EMAIL ?? 'superadmin@kilala.gov.ph',
        password: process.env.SUPERADMIN_PASSWORD ?? 'Kilala2026',
      },
    });
    const body = await res.json();
    expect(res.status()).toBe(200);
    expect(body.token).toBeTruthy();
    token = body.token;
  });

  test('POST /api/lgu-admins without a token is rejected 401', async ({ request }) => {
    const res = await request.post(`${API_BASE_URL}/api/lgu-admins`, { data: {} });
    expect(res.status()).toBe(401);
  });

  test('POST /api/lgu-admins with missing fields returns 400', async ({ request }) => {
    const res = await request.post(`${API_BASE_URL}/api/lgu-admins`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { email: 'x@y.gov.ph' },
    });
    expect(res.status()).toBe(400);
  });

  test('POST /api/lgu-admins with an unknown lgu_id returns 400', async ({ request }) => {
    const res = await request.post(`${API_BASE_URL}/api/lgu-admins`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        email: `new-${Date.now()}@qc.gov.ph`,
        password: 'pw',
        lgu_id: '00000000-0000-0000-0000-000000000000',
        first_name: 'A',
        last_name: 'B',
        department: 'OSCA',
      },
    });
    expect(res.status()).toBe(400);
  });

  test('POST /api/lgu-admins with a duplicate email returns 409', async ({ request }) => {
    const res = await request.post(`${API_BASE_URL}/api/lgu-admins`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        email: 'admin@makati.gov.ph',
        password: 'pw',
        lgu_id: '11111111-1111-1111-1111-111111111111',
        first_name: 'A',
        last_name: 'B',
        department: 'OSCA',
      },
    });
    expect(res.status()).toBe(409);
  });
});

test.describe('SUPERADMIN all-cities mode', () => {
  let saToken: string;
  let mkToken: string;

  test.beforeAll(async ({ request }) => {
    const saRes = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: {
        email: process.env.SUPERADMIN_EMAIL ?? 'superadmin@kilala.gov.ph',
        password: process.env.SUPERADMIN_PASSWORD ?? 'Kilala2026',
      },
    });
    const saBody = await saRes.json();
    expect(saRes.status()).toBe(200);
    expect(saBody.token).toBeTruthy();
    saToken = saBody.token;

    const mkRes = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: {
        email: 'admin@makati.gov.ph',
        password: 'MockHashForTestingOnly123456789012',
      },
    });
    const mkBody = await mkRes.json();
    expect(mkRes.status()).toBe(200);
    expect(mkBody.token).toBeTruthy();
    mkToken = mkBody.token;
  });

  test('SUPERADMIN GET /api/lgu/cardholders with no lgu_id returns 200 (all cities)', async ({ request }) => {
    const res = await request.get(`${API_BASE_URL}/api/lgu/cardholders`, { headers: { Authorization: `Bearer ${saToken}` } });
    expect(res.status()).toBe(200);
    expect(Array.isArray(await res.json())).toBe(true);
  });

  test('SUPERADMIN GET /api/lgu/dashboard with no lgu_id returns 200 (combined)', async ({ request }) => {
    const res = await request.get(`${API_BASE_URL}/api/lgu/dashboard`, { headers: { Authorization: `Bearer ${saToken}` } });
    expect(res.status()).toBe(200);
  });

  test('SUPERADMIN POST /api/lgu/cardholders with no city returns 400', async ({ request }) => {
    const res = await request.post(`${API_BASE_URL}/api/lgu/cardholders`, {
      headers: { Authorization: `Bearer ${saToken}` },
      data: { lgu_id_number: 'x', first_name: 'A', last_name: 'B', date_of_birth: '1950-01-01', sex: 'Male', address: 'x', privilege_type: 'SENIOR_CITIZEN' },
    });
    expect(res.status()).toBe(400);
  });

  test('LGU_ADMIN with no lgu_id still sees only its own city (count stable vs SUPERADMIN-all)', async ({ request }) => {
    const own = await request.get(`${API_BASE_URL}/api/lgu/cardholders`, { headers: { Authorization: `Bearer ${mkToken}` } });
    const all = await request.get(`${API_BASE_URL}/api/lgu/cardholders`, { headers: { Authorization: `Bearer ${saToken}` } });
    expect(own.status()).toBe(200);
    expect((await all.json()).length).toBeGreaterThanOrEqual((await own.json()).length);
  });
});

test.describe('SUPERADMIN RBAC contracts', () => {
  let token: string;

  test.beforeAll(async ({ request }) => {
    const res = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: {
        email: 'admin@makati.gov.ph',
        password: 'MockHashForTestingOnly123456789012',
      },
    });
    const body = await res.json();
    expect(res.status()).toBe(200);
    expect(body.token).toBeTruthy();
    token = body.token;
  });

  test('GET /api/lgu-admins is forbidden for an LGU_ADMIN (now SUPERADMIN-only)', async ({ request }) => {
    const res = await request.get(`${API_BASE_URL}/api/lgu-admins`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(403);
  });

  test('POST /api/lgu-admins is forbidden for an LGU_ADMIN', async ({ request }) => {
    const res = await request.post(`${API_BASE_URL}/api/lgu-admins`, { headers: { Authorization: `Bearer ${token}` }, data: {} });
    expect(res.status()).toBe(403);
  });

  test('LGU_ADMIN cannot override city via ?lgu_id (override ignored)', async ({ request }) => {
    const base = await request.get(`${API_BASE_URL}/api/lgu/cardholders`, { headers: { Authorization: `Bearer ${token}` } });
    const spoof = await request.get(`${API_BASE_URL}/api/lgu/cardholders?lgu_id=99999999-9999-9999-9999-999999999999`, { headers: { Authorization: `Bearer ${token}` } });
    expect(spoof.status()).toBe(200);
    expect(await spoof.json()).toEqual(await base.json()); // same (own-city) data, not the spoofed city
  });
});
