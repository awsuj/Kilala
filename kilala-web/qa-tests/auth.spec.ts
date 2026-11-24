import { test, expect, Page } from '@playwright/test';

const WEB_BASE_URL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000';

function encodeJwtPayload(payload: Record<string, unknown>) {
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `header.${body}.signature`;
}

async function addSession(page: Page, payload: Record<string, unknown>) {
  await page.context().addCookies([
    {
      name: process.env.AUTH_COOKIE || 'kilala_token',
      value: encodeJwtPayload(payload),
      url: WEB_BASE_URL,
    },
  ]);
}

test.describe('Sprint 1 - login and authorization UI', () => {
  test('root redirects unauthenticated users to login', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByText('LGU Portal. Sign in to manage records.')).toBeVisible();
  });

  test('login form validates required fields before calling the API', async ({ page }) => {
    await page.goto('/login');
    await page.getByRole('button', { name: 'Log In' }).click();

    await expect(page.getByText('Please enter your email and password.', { exact: true })).toBeVisible();
    await expect(page.getByLabel('Email')).toHaveValue('');
  });

  test('dashboard rejects an unauthenticated visitor', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login$/);
  });

  test('dashboard rejects an expired token', async ({ page }) => {
    await addSession(page, {
      id: 'admin-id',
      email: 'admin@makati.gov.ph',
      role: 'LGU_ADMIN',
      exp: Math.floor(Date.now() / 1000) - 60,
    });
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login$/);
  });

  test('dashboard accepts a valid LGU_ADMIN JWT and supports logout', async ({ page }) => {
    await addSession(page, {
      id: 'admin-id',
      email: 'admin@makati.gov.ph',
      role: 'LGU_ADMIN',
      exp: Math.floor(Date.now() / 1000) + 3600,
    });

    await page.goto('/dashboard');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    await expect(page.getByText('LGU Admin')).toBeVisible();
    await expect(page.getByText('admin@makati.gov.ph')).toBeVisible();

    await page.getByRole('button', { name: 'Log out' }).click();
    await expect(page).toHaveURL(/\/login$/);
  });

  test('non-admin JWT is not allowed into the dashboard', async ({ page }) => {
    await addSession(page, {
      id: 'cardholder-id',
      email: 'juan.pwd@email.com',
      role: 'CARDHOLDER',
      exp: Math.floor(Date.now() / 1000) + 3600,
    });
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login$/);
  });

  test('seeded LGU admin can sign in through the real login API', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill('admin@makati.gov.ph');
    await page.getByLabel('Password').fill('MockHashForTestingOnly123456789012');
    await page.getByRole('button', { name: 'Log In' }).click();

    await expect(page).toHaveURL(/\/dashboard$/, { timeout: 15_000 });
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });
});
