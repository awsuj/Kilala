import { expect, test, type Page } from '@playwright/test';

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

async function loginAsAdmin(page: Page) {
  await page.context().addCookies([
    {
      name: process.env.AUTH_COOKIE || 'kilala_token',
      value: adminJwt(),
      url: WEB_BASE_URL,
    },
  ]);
}

function recordRow(page: Page, id: string) {
  return page.getByRole('row').filter({ hasText: id });
}

test.describe('Records page', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto('/dashboard/records');
  });

  test('opens full cardholder details from a table row', async ({ page }) => {
    await recordRow(page, '13-7404-000-0000845').click();

    const details = page.getByRole('dialog');
    await expect(details).toBeVisible();
    await expect(details.getByText('Castillo, Ramon V.')).toBeVisible();
    await expect(details.getByText('PWD Privilege Card')).toBeVisible();
    await expect(details.getByText('Expired on Mar 14, 2024')).toBeVisible();
    await expect(details.getByText('Personal')).toBeVisible();
    await expect(details.getByText('Ramon Villar Castillo')).toBeVisible();
    await expect(details.getByText('Card', { exact: true })).toBeVisible();
    await expect(details.getByRole('heading', { name: 'Disability' })).toBeVisible();
    await expect(details.getByText('Orthopedic')).toBeVisible();
    await expect(details.getByText('History')).toBeVisible();
    await expect(details.getByRole('button', { name: 'Renew card' })).toBeVisible();
  });

  test('searches names without case or accent sensitivity and IDs without dashes', async ({ page }) => {
    const search = page.getByRole('searchbox', { name: 'Search by ID or name' });

    await search.fill('JOSÉ');
    await expect(recordRow(page, '13-7403-000-0004102')).toBeVisible();
    await expect(page.getByText('Garcia, Jose R.')).toBeVisible();

    await search.fill('1374040000001874');
    await expect(recordRow(page, '13-7404-000-0001874')).toBeVisible();
    await expect(page.getByText('Reyes, Ana M.')).toBeVisible();
    await expect(page.getByText('No records match your filters.')).toHaveCount(0);
    await expect(page).toHaveURL(/q=1374040000001874/);
  });

  test('filters by status and type, syncs them to the URL, and sorts columns', async ({ page }) => {
    await page.getByRole('button', { name: /^Active/ }).click();
    await page.getByLabel('Filter by type').selectOption('Senior');

    await expect(page).toHaveURL(/status=active/);
    await expect(page).toHaveURL(/type=Senior/);
    await expect(recordRow(page, 'QC-SC-2021-004512')).toBeVisible();
    await expect(recordRow(page, '13-7405-000-0000231')).toHaveCount(0);

    const nameHeader = page.getByRole('columnheader', { name: 'Name' });
    await nameHeader.getByRole('button', { name: 'Name' }).click();
    await expect(nameHeader).toHaveAttribute('aria-sort', 'ascending');
    await expect(page).toHaveURL(/sort=name/);
    await expect(page).toHaveURL(/dir=asc/);
  });

  test('paginates records and keeps the current page in the URL', async ({ page }) => {
    await expect(page.getByText('Showing 1 to 25 of 30')).toBeVisible();
    await page.getByRole('button', { name: 'Next', exact: true }).click();

    await expect(page.getByText('Showing 26 to 30 of 30')).toBeVisible();
    await expect(page.getByText('Page 2 of 2')).toBeVisible();
    await expect(page).toHaveURL(/page=2/);

    await page.getByRole('button', { name: 'Previous', exact: true }).click();
    await expect(page.getByText('Showing 1 to 25 of 30')).toBeVisible();
    await expect(page).not.toHaveURL(/page=2/);
  });

  test('suspends only after a reason is entered and supports undo', async ({ page }) => {
    await recordRow(page, 'QC-SC-2021-004512').click();
    await page.getByRole('button', { name: 'Suspend' }).click();

    const suspendDialog = page.getByRole('dialog');
    await expect(suspendDialog.getByText('Suspend card?')).toBeVisible();
    await suspendDialog.getByRole('button', { name: 'Suspend card' }).click();
    await expect(suspendDialog.getByText('Please enter a reason.')).toBeVisible();

    await suspendDialog.getByLabel('Reason*').fill('Reported lost card');
    await suspendDialog.getByRole('button', { name: 'Suspend card' }).click();
    await expect(page.getByRole('status')).toContainText('Dela Cruz, Maria S. suspended');

    await page.getByRole('button', { name: /^Suspended/ }).click();
    const suspendedRow = recordRow(page, 'QC-SC-2021-004512');
    await expect(suspendedRow).toBeVisible();
    await expect(suspendedRow.getByText('Suspended', { exact: true })).toBeVisible();

    await page.getByRole('button', { name: 'Undo' }).click();
    await page.getByRole('button', { name: /^Active/ }).click();
    await expect(recordRow(page, 'QC-SC-2021-004512')).toBeVisible();
  });

  test('renews an expired card with a live expiry preview and supports undo', async ({ page }) => {
    const expiredRow = recordRow(page, '13-7404-000-0000845');
    await expiredRow.getByRole('button', { name: 'Renew' }).click();

    const renewDialog = page.getByRole('dialog');
    await renewDialog.getByLabel('New issuing date*').fill('2025-01-02');
    await expect(renewDialog.getByText('New expiry: 2030-01-02')).toBeVisible();
    await renewDialog.getByRole('button', { name: 'Renew card', exact: true }).click();

    await expect(page.getByRole('status')).toContainText('renewed until Jan 2, 2030');
    await page.getByRole('button', { name: /^Active/ }).click();
    await expect(recordRow(page, '13-7404-000-0000845')).toBeVisible();

    await page.getByRole('button', { name: 'Undo' }).click();
    await page.getByRole('button', { name: /^Expired/ }).click();
    await expect(recordRow(page, '13-7404-000-0000845')).toBeVisible();
  });

  test('reinstates a suspended card in one click and supports undo', async ({ page }) => {
    await page.getByRole('button', { name: /^Suspended/ }).click();
    const suspendedRow = recordRow(page, '13-7404-000-0006001');
    await expect(suspendedRow).toBeVisible();
    await suspendedRow.getByRole('button', { name: 'Reinstate' }).click();

    await expect(page.getByRole('status')).toContainText('Torres, Jasmine R. reinstated');
    await page.getByRole('button', { name: /^Active/ }).click();
    await expect(recordRow(page, '13-7404-000-0006001')).toBeVisible();

    await page.getByRole('button', { name: 'Undo' }).click();
    await page.getByRole('button', { name: /^Suspended/ }).click();
    await expect(recordRow(page, '13-7404-000-0006001')).toBeVisible();
  });

  test('edits name and birthday while keeping card fields locked', async ({ page }) => {
    await recordRow(page, 'QC-SC-2021-004512').click();
    await page.getByRole('button', { name: 'Edit details' }).click();

    const editDialog = page.getByRole('dialog');
    await expect(editDialog.getByText('Locked fields')).toBeVisible();
    await expect(editDialog.getByText('QC-SC-2021-004512', { exact: true })).toBeVisible();
    await expect(editDialog.getByLabel('Card number')).toHaveCount(0);
    await expect(editDialog.getByLabel('Type')).toHaveCount(0);

    await editDialog.getByLabel('First name*').fill('Maria Elena');
    await editDialog.getByLabel('Birthday*').fill('1950-08-20');
    await editDialog.getByRole('button', { name: 'Save changes' }).click();

    await expect(page.getByRole('status')).toContainText('Saved changes to Dela Cruz, Maria Elena S.');
    await expect(page.getByRole('button', { name: 'Dela Cruz, Maria Elena S.' })).toBeVisible();
    await recordRow(page, 'QC-SC-2021-004512').click();
    const updatedDetails = page.getByRole('dialog');
    await expect(updatedDetails.getByText('Maria Elena Santos Dela Cruz')).toBeVisible();
    await expect(updatedDetails.getByText('Aug 20, 1950', { exact: false })).toBeVisible();
    await page.keyboard.press('Escape');

    await page.getByRole('button', { name: 'Undo' }).click();
    await expect(page.getByRole('button', { name: 'Dela Cruz, Maria S.' })).toBeVisible();
    await recordRow(page, 'QC-SC-2021-004512').click();
    const restoredDetails = page.getByRole('dialog');
    await expect(restoredDetails.getByText('Maria Santos Dela Cruz')).toBeVisible();
    await expect(restoredDetails.getByText('Aug 19, 1950', { exact: false })).toBeVisible();
  });
});
