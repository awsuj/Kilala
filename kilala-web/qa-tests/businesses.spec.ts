import { expect, test, type APIRequestContext, type Page } from "@playwright/test";

const WEB_BASE_URL = process.env.PLAYWRIGHT_BASE_URL || "http://localhost:3000";
const API_BASE_URL = process.env.API_BASE_URL || "http://localhost:5001";
const ADMIN_EMAIL = "admin@makati.gov.ph";
const ADMIN_PASSWORD = "MockHashForTestingOnly123456789012";
const SUPERADMIN_EMAIL = "superadmin@kilala.gov.ph";
const SUPERADMIN_PASSWORD = "Kilala2026";

interface LoginResponse {
  token: string;
  user: { role: string };
}

interface Business {
  id: string;
  business_name: string;
  business_permit_no: string;
  is_active: boolean;
}

async function loginAsAdmin(request: APIRequestContext, page: Page) {
  const response = await request.post(`${API_BASE_URL}/api/auth/login`, {
    data: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD },
  });
  expect(response.status()).toBe(200);
  const { token, user } = (await response.json()) as LoginResponse;
  expect(user.role).toBe("LGU_ADMIN");
  await page.context().addCookies([
    {
      name: process.env.AUTH_COOKIE || "kilala_token",
      value: token,
      url: WEB_BASE_URL,
    },
  ]);
  return token;
}

async function getBusinesses(
  request: APIRequestContext,
  token: string,
): Promise<Business[]> {
  const response = await request.get(`${API_BASE_URL}/api/lgu/businesses`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(response.status()).toBe(200);
  return (await response.json()) as Business[];
}

test.describe("LGU Add Business — web", () => {
  test("+ Add Business opens a dialog whose Issuing LGU field lists Metro Manila cities", async ({
    page,
    request,
  }) => {
    await loginAsAdmin(request, page);
    await page.goto("/dashboard/businesses");

    await page.getByRole("button", { name: "+ Add Business" }).click();
    const dialog = page.getByRole("dialog");

    const lguTrigger = dialog.getByRole("combobox", { name: /Issuing LGU/i });
    await expect(lguTrigger).toBeVisible();

    await lguTrigger.click();
    await expect(
      page.getByRole("option", { name: "Quezon City" }),
    ).toBeVisible();
  });

  test("validates duplicate business permits against live rows without creating one", async ({
    page,
    request,
  }) => {
    const token = await loginAsAdmin(request, page);
    const businesses = await getBusinesses(request, token);
    test.skip(
      businesses.length === 0,
      "A live business is needed for duplicate validation.",
    );

    await page.goto("/dashboard/businesses");
    await page.getByRole("button", { name: "+ Add Business" }).click();
    const dialog = page.getByRole("dialog");

    await dialog.getByLabel("Business name*").fill("Dup Co");
    await dialog
      .getByLabel("Business permit number*")
      .fill(businesses[0].business_permit_no);
    await dialog.getByLabel("TIN number*").fill("000-1-2-3");
    await dialog.getByRole("button", { name: "Add Business" }).click();

    await expect(
      dialog.getByText("This business permit already exists."),
    ).toBeVisible();
    await expect(dialog).toBeVisible();
  });

  test("a server-side error keeps the dialog open with the typed input preserved", async ({
    page,
    request,
  }) => {
    // A SUPERADMIN with no city selected is rejected server-side. The dialog must
    // stay open, show the error, and keep what the admin typed — not vanish.
    const res = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: { email: SUPERADMIN_EMAIL, password: SUPERADMIN_PASSWORD },
    });
    expect(res.status()).toBe(200);
    const { token } = (await res.json()) as LoginResponse;
    await page.context().addCookies([
      {
        name: process.env.AUTH_COOKIE || "kilala_token",
        value: token,
        url: WEB_BASE_URL,
      },
    ]);

    await page.goto("/dashboard/businesses");
    await page.getByRole("button", { name: "+ Add Business" }).click();
    const dialog = page.getByRole("dialog");

    await dialog.getByLabel("Business name*").fill("Keep Me Co");
    await dialog.getByRole("combobox", { name: /Issuing LGU/i }).click();
    await page.getByRole("option", { name: "Quezon City" }).click();
    await dialog
      .getByLabel("Business permit number*")
      .fill(`QA-SA-${Date.now()}`);
    await dialog.getByLabel("TIN number*").fill("000-1-2-3");
    await dialog.getByRole("button", { name: "Add Business" }).click();

    await expect(
      dialog.getByText("Select a city from the top bar before adding a business."),
    ).toBeVisible();
    await expect(dialog).toBeVisible();
    await expect(dialog.getByLabel("Business name*")).toHaveValue("Keep Me Co");
  });
});
