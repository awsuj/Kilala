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

interface DashboardResponse {
  cardholderStats: {
    total_cardholders: string | number;
  };
  totalAccreditedBusinesses: string | number;
  scanStats: {
    total_scans: string | number;
    valid_scans: string | number;
    invalid_scans: string | number;
    scans_today: string | number;
  };
}

interface Business {
  id: string;
  business_name: string;
  branch_name: string | null;
  email: string;
  is_accredited: boolean;
}

interface VerificationLog {
  id: string;
  status_at_scan: string;
  is_valid: boolean;
  failure_reason: string | null;
  scanned_at: string;
  first_name: string;
  last_name: string;
  lgu_id_number: string;
  privilege_type: 'PWD' | 'SENIOR_CITIZEN';
  business_name: string;
  branch_name: string | null;
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

async function getApiData<T>(
  request: APIRequestContext,
  path: string,
  token: string,
): Promise<T> {
  const response = await request.get(`${API_BASE_URL}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(response.status()).toBe(200);
  return (await response.json()) as T;
}

const formatNumber = (value: string | number) =>
  Number(value).toLocaleString('en-US');

test.describe('LGU live backend data', () => {
  test('LGU dashboard, businesses, and logs APIs require an admin token', async ({ request }) => {
    for (const path of ['/api/lgu/dashboard', '/api/lgu/businesses', '/api/lgu/logs']) {
      const response = await request.get(`${API_BASE_URL}${path}`);
      expect(response.status(), `${path} should require authentication`).toBe(401);
    }

    const login = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD },
    });
    expect(login.status()).toBe(200);
    const { token } = (await login.json()) as LoginResponse;
    const response = await request.get(`${API_BASE_URL}/api/lgu/dashboard`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.status()).toBe(200);
  });

  test('dashboard renders live totals and identifies its remaining sample data', async ({
    page,
    request,
  }) => {
    const token = await loginAsAdmin(request, page);
    const stats = await getApiData<DashboardResponse>(
      request,
      '/api/lgu/dashboard',
      token,
    );

    await page.goto('/dashboard');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

    for (const [label, value] of [
      ['Registered Cardholders', stats.cardholderStats.total_cardholders],
      ['Accredited Businesses', stats.totalAccreditedBusinesses],
      ['Verifications', stats.scanStats.total_scans],
    ] as const) {
      const card = page.getByText(label, { exact: true }).locator('..');
      await expect(card).toContainText(formatNumber(value));
    }

    const verificationPanel = page
      .getByText('Total Verifications', { exact: true })
      .locator('../..');
    await expect(verificationPanel).toContainText(formatNumber(stats.scanStats.total_scans));
    for (const [label, value] of [
      ['Valid', stats.scanStats.valid_scans],
      ['Invalid', stats.scanStats.invalid_scans],
      ['Today', stats.scanStats.scans_today],
    ] as const) {
      await expect(verificationPanel.getByText(label, { exact: true }).locator('..'))
        .toContainText(formatNumber(value));
    }

    await expect(page.getByText('Cardholders by Barangay', { exact: true }).locator('..'))
      .toContainText('Sample data');
    await expect(page.getByText('than last month')).toHaveCount(0);
  });

  test('businesses list reflects live backend data and revoke/re-accredit updates the backend', async ({
    page,
    request,
  }) => {
    const token = await loginAsAdmin(request, page);
    const businesses = await getApiData<Business[]>(
      request,
      '/api/lgu/businesses',
      token,
    );
    const business = businesses.find((item) => item.email === 'qa.business@example.test');

    console.log('Business API data:', business);
    
    expect(business, 'The QA Test Business fixture should exist in the LGU').toBeDefined();
    if (!business) return;

    const restoreAccreditation = async () => {
      const response = await request.patch(
        `${API_BASE_URL}/api/lgu/businesses/${business.id}/accreditation`,
        {
          headers: { Authorization: `Bearer ${token}` },
          data: { is_accredited: business.is_accredited },
        },
      );
      expect(response.status()).toBe(200);
    };

    try {
      await page.goto('/dashboard/businesses');
      const row = page.getByRole('row').filter({ hasText: business.email });
      await expect(row).toContainText(business.business_name);
      await expect(row).toContainText(business.branch_name || '—');
      await expect(row).toContainText(business.is_accredited ? 'Accredited' : 'Revoked');

      const actionLabel = business.is_accredited ? 'Revoke' : 'Re-accredit';
      const nextLabel = business.is_accredited ? 'Re-accredit' : 'Revoke';
      await row.getByRole('button', { name: actionLabel }).click();
      await expect(row.getByRole('button', { name: nextLabel })).toBeVisible();

      const updatedBusinesses = await getApiData<Business[]>(
        request,
        '/api/lgu/businesses',
        token,
      );
      expect(
        updatedBusinesses.find((item) => item.id === business.id)?.is_accredited,
      ).toBe(!business.is_accredited);

      await row.getByRole('button', { name: nextLabel }).click();
      await expect(row.getByRole('button', { name: actionLabel })).toBeVisible();
    } finally {
      await restoreAccreditation();
    }
  });

  test('reports renders live verification rows and labels discount summaries as pending sample data', async ({
    page,
    request,
  }) => {
    const token = await loginAsAdmin(request, page);
    const logs = await getApiData<VerificationLog[]>(request, '/api/lgu/logs', token);

    await page.goto('/dashboard/reports');
    await expect(page.getByRole('heading', { name: 'Reports' })).toBeVisible();
    await expect(page.getByText('Total Discounts Provided', { exact: true }).locator('..'))
      .toContainText('Sample — endpoint pending');
    await expect(page.getByText('Total Sales Recorded', { exact: true }).locator('..'))
      .toContainText('Sample — endpoint pending');

    const auditCard = page.getByText('Verification audit log', { exact: true }).locator('../..');
    const auditTable = auditCard.getByRole('table');
    const rows = auditTable.getByRole('row');
    await expect(rows).toHaveCount(logs.length + 1);

    if (logs.length === 0) {
      await expect(auditCard.getByText('No verification scans recorded yet.')).toBeVisible();
      return;
    }

    const log = logs[0];
    const row = rows.filter({ hasText: log.lgu_id_number }).first();
    await expect(row).toContainText(`${log.last_name}, ${log.first_name}`);
    await expect(row).toContainText(log.privilege_type === 'SENIOR_CITIZEN' ? 'Senior' : 'PWD');
    await expect(row).toContainText(
      `${log.business_name}${log.branch_name ? ` · ${log.branch_name}` : ''}`,
    );
    await expect(row).toContainText(log.is_valid ? 'Valid' : 'Invalid');
    await expect(row).toContainText(log.failure_reason || '—');
    await expect(row.getByRole('cell').first()).not.toBeEmpty();
  });
});
