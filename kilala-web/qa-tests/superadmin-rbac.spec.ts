import { test, expect, Page } from '@playwright/test';

const WEB_BASE_URL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000';

function jwtForRole(role: 'LGU_ADMIN' | 'SUPERADMIN') {
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const payload = Buffer.from(JSON.stringify({
    id: 'test-user-id',
    email: 'test@example.gov.ph',
    role,
    exp,
  })).toString('base64url');
  return `header.${payload}.signature`;
}

async function loginWithRole(page: Page, role: 'LGU_ADMIN' | 'SUPERADMIN') {
  await page.context().addCookies([
    {
      name: process.env.AUTH_COOKIE || 'kilala_token',
      value: jwtForRole(role),
      url: WEB_BASE_URL,
    },
  ]);
}

test.describe('SUPERADMIN RBAC', () => {
  test('SUPERADMIN can access /dashboard/accounts and sees Accounts heading', async ({ page }) => {
    await loginWithRole(page, 'SUPERADMIN');
    await page.goto('/dashboard/accounts');
    await expect(page.getByRole('heading', { name: 'Accounts' })).toBeVisible();
  });

  test('LGU_ADMIN can access /dashboard and stays on dashboard', async ({ page }) => {
    await loginWithRole(page, 'LGU_ADMIN');
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/dashboard(\/)?$/);
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });
});

test.describe('Role-based nav + city picker', () => {
  test('LGU_ADMIN: no Accounts link in sidebar and no city combobox in top bar', async ({ page }) => {
    await loginWithRole(page, 'LGU_ADMIN');
    await page.goto('/dashboard');
    await expect(page.getByRole('link', { name: 'Accounts' })).not.toBeVisible();
    await expect(page.getByRole('combobox', { name: /city/i })).not.toBeVisible();
  });

  test('SUPERADMIN: Accounts link visible in sidebar and city combobox visible in top bar', async ({ page }) => {
    await loginWithRole(page, 'SUPERADMIN');
    await page.goto('/dashboard');
    await expect(page.getByRole('link', { name: 'Accounts' })).toBeVisible();
    await expect(page.getByRole('combobox', { name: /city/i })).toBeVisible();
  });
});
