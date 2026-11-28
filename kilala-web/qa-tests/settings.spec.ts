import { expect, test, type APIRequestContext, type Page } from '@playwright/test';

const WEB_BASE_URL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000';
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:5001';
const ADMIN_EMAIL = 'admin@makati.gov.ph';
const ADMIN_PASSWORD = 'MockHashForTestingOnly123456789012';

interface LoginResponse {
  token: string;
  user: {
    role: string;
  };
}

async function loginAsAdmin(request: APIRequestContext, page: Page) {
  const response = await request.post(`${API_BASE_URL}/api/auth/login`, {
    data: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD },
  });
  expect(response.status()).toBe(200);

  const { token, user } = (await response.json()) as LoginResponse;
  expect(user.role).toBe('LGU_ADMIN');
  await page.context().addCookies([
    {
      name: process.env.AUTH_COOKIE || 'kilala_token',
      value: token,
      url: WEB_BASE_URL,
    },
  ]);
  return token;
}

async function fillPasswordForm(
  page: Page,
  currentPassword: string,
  newPassword: string,
  confirmation = newPassword,
) {
  await page.getByLabel('Current password', { exact: true }).fill(currentPassword);
  await page.getByLabel('New password', { exact: true }).fill(newPassword);
  await page.getByLabel('Confirm new password', { exact: true }).fill(confirmation);
  await page.getByRole('button', { name: 'Change password' }).click();
}

test.describe('Settings password management', () => {
  test('LGU admin can navigate to settings and sees the password form', async ({
    page,
    request,
  }) => {
    await loginAsAdmin(request, page);
    await page.goto('/dashboard');
    await page.getByRole('link', { name: 'Settings' }).click();

    await expect(page).toHaveURL(/\/dashboard\/settings$/);
    await expect(page.getByText('Password', { exact: true })).toBeVisible();
    await expect(page.getByLabel('Current password', { exact: true })).toBeVisible();
    await expect(page.getByLabel('New password', { exact: true })).toBeVisible();
    await expect(page.getByLabel('Confirm new password', { exact: true })).toBeVisible();
  });

  test('validates password length and confirmation before submission', async ({
    page,
    request,
  }) => {
    await loginAsAdmin(request, page);
    await page.goto('/dashboard/settings');

    await fillPasswordForm(page, 'current-password', 'short');
    await expect(page.getByText('Use at least 8 characters.', { exact: true })).toBeVisible();

    await page.getByLabel('New password', { exact: true }).fill('new-password');
    await page.getByLabel('Confirm new password', { exact: true }).fill('different-password');
    await page.getByRole('button', { name: 'Change password' }).click();
    await expect(page.getByText("Passwords don't match.", { exact: true })).toBeVisible();
  });

  test('shows an incorrect-current-password error without signing the admin out', async ({
    page,
    request,
  }) => {
    await loginAsAdmin(request, page);
    await page.goto('/dashboard/settings');

    await fillPasswordForm(page, 'incorrect-current-password', 'new-password-123');

    await expect(page.getByText('Current password is incorrect', { exact: true })).toBeVisible();
    await expect(page).toHaveURL(/\/dashboard\/settings$/);
    await expect(page.getByLabel('Current password', { exact: true })).toBeVisible();
  });

  test('changes the password with the correct current password', async ({
    page,
    request,
    browserName,
  }) => {
    test.skip(browserName !== 'chromium', 'This test temporarily changes a shared QA account.');

    const token = await loginAsAdmin(request, page);
    const newPassword = `Kilala-QA-${Date.now()}-Next`;
    let passwordChanged = false;

    try {
      await page.goto('/dashboard/settings');
      await fillPasswordForm(page, ADMIN_PASSWORD, newPassword);
      await expect(page.getByRole('status')).toHaveText('Password updated.');
      passwordChanged = true;

      const login = await request.post(`${API_BASE_URL}/api/auth/login`, {
        data: { email: ADMIN_EMAIL, password: newPassword },
      });
      expect(login.status()).toBe(200);
    } finally {
      if (!passwordChanged) {
        const probe = await request.post(`${API_BASE_URL}/api/auth/login`, {
          data: { email: ADMIN_EMAIL, password: newPassword },
        });
        passwordChanged = probe.ok();
      }

      if (passwordChanged) {
        const restore = await request.patch(`${API_BASE_URL}/api/lgu/me/password`, {
          headers: { Authorization: `Bearer ${token}` },
          data: { currentPassword: newPassword, newPassword: ADMIN_PASSWORD },
        });
        expect(restore.status()).toBe(200);

        const restoredLogin = await request.post(`${API_BASE_URL}/api/auth/login`, {
          data: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD },
        });
        expect(restoredLogin.status()).toBe(200);
      }
    }
  });
});
