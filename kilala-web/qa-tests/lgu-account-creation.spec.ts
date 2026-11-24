import { test, expect, type APIRequestContext, type Page } from '@playwright/test';

const WEB_BASE_URL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000';
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:5001';

async function loginAsSuperadmin(request: APIRequestContext, page: Page) {
  const response = await request.post(`${API_BASE_URL}/api/auth/login`, {
    data: {
      email: process.env.SUPERADMIN_EMAIL ?? 'superadmin@kilala.gov.ph',
      password: process.env.SUPERADMIN_PASSWORD ?? 'Kilala2026',
    },
  });
  expect(response.status()).toBe(200);
  const { token } = await response.json();

  await page.context().addCookies([
    {
      name: process.env.AUTH_COOKIE || 'kilala_token',
      value: token,
      url: WEB_BASE_URL,
    },
  ]);
}

test.describe('LGU Account Creation', () => {
  test.beforeEach(async ({ page, request }) => {
    await loginAsSuperadmin(request, page);
  });

  test('accounts page renders the create button', async ({ page }) => {
    await page.goto('/dashboard/accounts');
    await expect(
      page.getByRole('main').getByRole('heading', { name: 'Accounts' }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: /create lgu account/i }),
    ).toBeVisible();
  });

  test('create account dialog shows the Metro Manila city dropdown', async ({ page }) => {
    await page.goto('/dashboard/accounts');
    await page.getByRole('button', { name: /create lgu account/i }).click();
    await page.getByRole('combobox', { name: /city/i }).click();
    await expect(page.getByRole('option', { name: 'Quezon City' })).toBeVisible();
  });

  test('submitting empty form shows each required-field error', async ({ page }) => {
    await page.goto('/dashboard/accounts');
    await page.getByRole('button', { name: /create lgu account/i }).click();
    await page.getByRole('button', { name: /create account/i }).click();
    for (const message of [
      'City is required.',
      'Email is required.',
      'Password is required.',
      'First name is required.',
      'Last name is required.',
      'Department is required.',
    ]) {
      await expect(page.getByRole('alert').filter({ hasText: message })).toBeVisible();
    }
  });
});
