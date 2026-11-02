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
});
