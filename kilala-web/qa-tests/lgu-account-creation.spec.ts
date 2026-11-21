import { test, expect, Page } from '@playwright/test';

const WEB_BASE_URL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000';

function adminJwt() {
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const payload = Buffer.from(JSON.stringify({
    id: 'admin-id',
    email: 'admin@makati.gov.ph',
    role: 'LGU_ADMIN',
    exp,
  })).toString('base64url');
  return `header.${payload}.signature`;
}

async function loginForDashboard(page: Page) {
  await page.context().addCookies([
    {
      name: process.env.AUTH_COOKIE || 'kilala_token',
      value: adminJwt(),
      url: WEB_BASE_URL,
    },
  ]);
}

test.describe('LGU Account Creation', () => {
  test.beforeEach(async ({ page }) => {
    await loginForDashboard(page);
  });

  test('accounts page renders the create button', async ({ page }) => {
    await page.goto('/dashboard/accounts');
    await expect(page.getByRole('heading', { name: 'Accounts' })).toBeVisible();
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

  test('submitting empty form shows required-field errors', async ({ page }) => {
    await page.goto('/dashboard/accounts');
    await page.getByRole('button', { name: /create lgu account/i }).click();
    await page.getByRole('button', { name: /create account/i }).click();
    await expect(page.getByRole('alert').first()).toBeVisible();
  });
});
