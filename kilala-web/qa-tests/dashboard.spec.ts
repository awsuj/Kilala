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

test.describe('Sprint 1 - dashboard foundation', () => {
  test.beforeEach(async ({ page }) => {
    await loginForDashboard(page);
  });

  // The dashboard now renders live data from GET /api/lgu/dashboard instead of
  // the old mock "Cardholders by Barangay" table (which has no backing schema
  // column), so this asserts the backend-independent shell rather than seeded
  // rows. Live-data content is covered by the Sprint 2 integration suite.
  test('dashboard shell renders with heading and search', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    await expect(page.getByRole('searchbox', { name: 'Search records' })).toBeVisible();
  });

  test('navigation links open their Sprint 1 portal pages', async ({ page }) => {
    await page.goto('/dashboard');

    await page.getByRole('link', { name: 'Records' }).click();
    await expect(page).toHaveURL(/\/dashboard\/records$/);
    await expect(page.getByRole('heading', { name: 'Records' })).toBeVisible();

    await page.getByRole('link', { name: 'Businesses' }).click();
    await expect(page).toHaveURL(/\/dashboard\/businesses$/);
    await expect(page.getByRole('heading', { name: 'Businesses' })).toBeVisible();

    await page.getByRole('link', { name: 'Reports' }).click();
    await expect(page).toHaveURL(/\/dashboard\/reports$/);
    await expect(page.getByRole('heading', { name: 'Reports' })).toBeVisible();
  });

  test('navigation can retract and restore the sidebar', async ({ page }) => {
    await page.goto('/dashboard');
    await page.getByRole('button', { name: 'Retract navigation' }).click();
    await expect(page.getByRole('button', { name: 'Open navigation' })).toBeVisible();
    await page.getByRole('button', { name: 'Open navigation' }).click();
    await expect(page.getByRole('navigation')).toBeVisible();
  });
});
