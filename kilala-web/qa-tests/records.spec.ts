import { expect, test, type APIRequestContext, type Page } from "@playwright/test";

const WEB_BASE_URL = process.env.PLAYWRIGHT_BASE_URL || "http://localhost:3000";
const API_BASE_URL = process.env.API_BASE_URL || "http://localhost:5001";
const ADMIN_EMAIL = "admin@makati.gov.ph";
const ADMIN_PASSWORD = "MockHashForTestingOnly123456789012";

interface LoginResponse {
  token: string;
  user: { role: string };
}

interface Cardholder {
  id: string;
  lgu_id_number: string;
  first_name: string;
  middle_name: string | null;
  last_name: string;
  date_of_birth: string;
  privilege_type: "PWD" | "SENIOR_CITIZEN";
  disability_type: string | null;
  status: "ACTIVE" | "EXPIRED" | "REVOKED" | "SUSPENDED";
  issued_date: string;
  expiry_date: string | null;
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

async function getCardholders(
  request: APIRequestContext,
  token: string,
): Promise<Cardholder[]> {
  const response = await request.get(`${API_BASE_URL}/api/lgu/cardholders`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(response.status()).toBe(200);
  return (await response.json()) as Cardholder[];
}

async function updateCardholder(
  request: APIRequestContext,
  token: string,
  cardholder: Cardholder,
  updates: { status?: Cardholder["status"]; expiry_date?: string },
) {
  const response = await request.patch(
    `${API_BASE_URL}/api/lgu/cardholders/${cardholder.id}`,
    {
      headers: { Authorization: `Bearer ${token}` },
      data: updates,
    },
  );
  expect(response.status()).toBe(200);
}

function recordRow(page: Page, id: string) {
  return page.getByRole("row").filter({ hasText: id });
}

function cardholderName(cardholder: Cardholder) {
  const middleInitial = cardholder.middle_name
    ? ` ${cardholder.middle_name[0]}.`
    : "";
  return `${cardholder.last_name}, ${cardholder.first_name}${middleInitial}`;
}

function dateOnly(date: string) {
  return date.slice(0, 10);
}

function todayLocal() {
  const today = new Date();
  return [
    today.getFullYear(),
    String(today.getMonth() + 1).padStart(2, "0"),
    String(today.getDate()).padStart(2, "0"),
  ].join("-");
}

test.describe("LGU records page", () => {
  test("renders cardholders from the live API and opens their details", async ({
    page,
    request,
  }) => {
    const token = await loginAsAdmin(request, page);
    const cardholders = await getCardholders(request, token);

    await page.goto("/dashboard/records");
    if (cardholders.length === 0) {
      await expect(page.getByText("No records yet.")).toBeVisible();
      return;
    }

    const expectedCount = Math.min(cardholders.length, 25);
    await expect(
      page.getByText(`Showing 1 to ${expectedCount} of ${cardholders.length}`),
    ).toBeVisible();

    const cardholder = cardholders[0];
    const row = recordRow(page, cardholder.lgu_id_number);
    await page.getByRole("searchbox", { name: "Search by ID or name" })
      .fill(cardholder.lgu_id_number.replace(/-/g, ""));
    await expect(row).toBeVisible();
    await expect(row).toContainText(cardholderName(cardholder));
    await expect(row).toContainText(
      cardholder.privilege_type === "SENIOR_CITIZEN" ? "Senior" : "PWD",
    );
    await row.click();

    const details = page.getByRole("dialog");
    await expect(details).toBeVisible();
    await expect(details.getByText(cardholder.lgu_id_number)).toBeVisible();
    await expect(details.getByText(
      [cardholder.first_name, cardholder.middle_name, cardholder.last_name]
        .filter(Boolean)
        .join(" "),
    )).toBeVisible();
    await expect(details.getByText(
      cardholder.privilege_type === "SENIOR_CITIZEN"
        ? "Senior Citizen Card"
        : "PWD Privilege Card",
    )).toBeVisible();
  });

  test("searches live records by name and ID, filters by type, and sorts columns", async ({
    page,
    request,
  }) => {
    const token = await loginAsAdmin(request, page);
    const cardholders = await getCardholders(request, token);
    test.skip(cardholders.length === 0, "The LGU API has no cardholders to search.");
    if (cardholders.length === 0) return;

    const cardholder = cardholders[0];
    await page.goto("/dashboard/records");
    const search = page.getByRole("searchbox", { name: "Search by ID or name" });

    await search.fill(cardholder.first_name.toLocaleLowerCase());
    await expect(recordRow(page, cardholder.lgu_id_number)).toBeVisible();
    await expect(page).toHaveURL(new RegExp(`q=${cardholder.first_name}`, "i"));

    await search.fill(cardholder.lgu_id_number.replace(/-/g, ""));
    await expect(recordRow(page, cardholder.lgu_id_number)).toBeVisible();
    await expect(page).toHaveURL(
      new RegExp(`q=${cardholder.lgu_id_number.replace(/-/g, "")}`),
    );

    await page.getByLabel("Filter by type").selectOption(
      cardholder.privilege_type === "SENIOR_CITIZEN" ? "Senior" : "PWD",
    );
    await expect(page).toHaveURL(
      new RegExp(`type=${cardholder.privilege_type === "SENIOR_CITIZEN" ? "Senior" : "PWD"}`),
    );
    await expect(recordRow(page, cardholder.lgu_id_number)).toBeVisible();

    const nameHeader = page.getByRole("columnheader", { name: "Name" });
    await nameHeader.getByRole("button", { name: "Name" }).click();
    await expect(nameHeader).toHaveAttribute("aria-sort", "ascending");
    await expect(page).toHaveURL(/sort=name/);
    await expect(page).toHaveURL(/dir=asc/);
  });

  test("paginates the live record set and keeps the selected page in the URL", async ({
    page,
    request,
  }) => {
    const token = await loginAsAdmin(request, page);
    const cardholders = await getCardholders(request, token);
    await page.goto("/dashboard/records");

    if (cardholders.length <= 25) {
      if (cardholders.length === 0) {
        await expect(page.getByText("No records")).toBeVisible();
      } else {
        await expect(
          page.getByText(`Showing 1 to ${cardholders.length} of ${cardholders.length}`),
        ).toBeVisible();
      }
      await expect(page.getByRole("button", { name: "Next", exact: true })).toHaveCount(0);
      return;
    }

    await expect(page.getByText(`Showing 1 to 25 of ${cardholders.length}`)).toBeVisible();
    await page.getByRole("button", { name: "Next", exact: true }).click();
    const pageTwoEnd = Math.min(50, cardholders.length);
    const totalPages = Math.ceil(cardholders.length / 25);
    await expect(page.getByText(`Showing 26 to ${pageTwoEnd} of ${cardholders.length}`))
      .toBeVisible();
    await expect(page.getByText(`Page 2 of ${totalPages}`)).toBeVisible();
    await expect(page).toHaveURL(/page=2/);

    await page.getByRole("button", { name: "Previous", exact: true }).click();
    await expect(page.getByText(`Showing 1 to 25 of ${cardholders.length}`)).toBeVisible();
    await expect(page).not.toHaveURL(/page=2/);
  });

  test("validates duplicate card numbers against live records without creating a row", async ({
    page,
    request,
  }) => {
    const token = await loginAsAdmin(request, page);
    const cardholders = await getCardholders(request, token);
    test.skip(cardholders.length === 0, "A live cardholder is needed for duplicate validation.");
    if (cardholders.length === 0) return;

    await page.goto("/dashboard/records");
    await page.getByRole("button", { name: "+ Add Record" }).click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Card number*").fill(cardholders[0].lgu_id_number);
    await dialog.getByRole("button", { name: "Add record" }).click();
    await expect(dialog.getByText("This card number already exists.")).toBeVisible();
    await expect(dialog).toBeVisible();
  });

  test("suspends, reinstates, and renews a live card with backend state restored", async ({
    page,
    request,
  }) => {
    const token = await loginAsAdmin(request, page);
    const cardholders = await getCardholders(request, token);
    const cardholder = cardholders.find(
      (row) =>
        row.status === "ACTIVE" &&
        row.privilege_type === "PWD" &&
        row.expiry_date !== null &&
        dateOnly(row.issued_date) <= todayLocal(),
    );
    test.skip(
      !cardholder,
      "Requires an active PWD card with an expiry date to exercise renewal.",
    );
    if (!cardholder) return;

    const originalExpiry = dateOnly(cardholder.expiry_date!);
    const originalStatus = cardholder.status;
    try {
      await updateCardholder(request, token, cardholder, {
        expiry_date: "2000-01-01",
      });
      await page.goto("/dashboard/records");
      await page.getByRole("button", { name: /^Expired/ }).click();
      const expiredRow = recordRow(page, cardholder.lgu_id_number);
      await expect(expiredRow).toBeVisible();
      await expiredRow.getByRole("button", { name: "Renew" }).click();

      const renewalDialog = page.getByRole("dialog");
      const issuingDate = todayLocal();
      await renewalDialog.getByLabel("New issuing date*").fill(issuingDate);
      const expiryPreview = renewalDialog.getByText(/^New expiry: /);
      await expect(expiryPreview).toBeVisible();
      const previewText = await expiryPreview.textContent();
      const expectedExpiry = previewText?.match(/\d{4}-\d{2}-\d{2}$/)?.[0];
      expect(expectedExpiry, "The renewal dialog should show a calculated expiry").toBeTruthy();
      await renewalDialog.getByRole("button", { name: "Renew card", exact: true }).click();

      await page.getByRole("button", { name: /^Active/ }).click();
      const renewedRow = recordRow(page, cardholder.lgu_id_number);
      await expect(renewedRow).toBeVisible();
      await expect.poll(async () => {
        const updated = await getCardholders(request, token);
        const expiry = updated.find((row) => row.id === cardholder.id)?.expiry_date;
        return expiry ? Date.parse(expiry) : Number.NaN;
      }).toBeGreaterThan(Date.now());

      await renewedRow.click();
      await page.getByRole("button", { name: "Suspend" }).click();
      const suspendDialog = page.getByRole("dialog");
      await suspendDialog.getByRole("button", { name: "Suspend card" }).click();
      await expect(suspendDialog.getByText("Please enter a reason.")).toBeVisible();
      await suspendDialog.getByLabel("Reason*").fill("QA status transition");
      await suspendDialog.getByRole("button", { name: "Suspend card" }).click();

      await expect.poll(async () => {
        const updated = await getCardholders(request, token);
        return updated.find((row) => row.id === cardholder.id)?.status;
      }).toBe("SUSPENDED");

      await page.getByRole("button", { name: /^Suspended/ }).click();
      const suspendedRow = recordRow(page, cardholder.lgu_id_number);
      await expect(suspendedRow).toBeVisible();
      await suspendedRow.getByRole("button", { name: "Reinstate" }).click();
      await expect.poll(async () => {
        const updated = await getCardholders(request, token);
        return updated.find((row) => row.id === cardholder.id)?.status;
      }).toBe("ACTIVE");
    } finally {
      await updateCardholder(request, token, cardholder, {
        status: originalStatus,
        expiry_date: originalExpiry,
      });
    }
  });
});
