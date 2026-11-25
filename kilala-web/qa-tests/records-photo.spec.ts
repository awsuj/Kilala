import { expect, test, type APIRequestContext, type Page } from "@playwright/test";

const WEB = process.env.PLAYWRIGHT_BASE_URL || "http://localhost:3000";
const API = process.env.API_BASE_URL || "http://localhost:5001";
const ADMIN_EMAIL = "admin@makati.gov.ph";
const ADMIN_PASSWORD = "MockHashForTestingOnly123456789012";

// Camera path needs a fake media device in the browser.
test.use({
  launchOptions: {
    args: ["--use-fake-device-for-media-stream", "--use-fake-ui-for-media-stream"],
  },
});

// A real, decodable 4×4 PNG (createImageBitmap in the downscale step needs valid pixels).
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAEAQMAAACTPww9AAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGUExURQ5bSv///yS5uC4AAAABYktHRAH/Ai3eAAAAB3RJTUUH6gsZBywXnmdDrAAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAyNi0xMS0yNVQwNzo0NDoyMyswMDowMNUBAv0AAAAldEVYdGRhdGU6bW9kaWZ5ADIwMjYtMTEtMjVUMDc6NDQ6MjMrMDA6MDCkXLpBAAAAKHRFWHRkYXRlOnRpbWVzdGFtcAAyMDI2LTExLTI1VDA3OjQ0OjIzKzAwOjAw80mbngAAAAtJREFUCNdjYIAAAAAIAAEvIN0xAAAAAElFTkSuQmCC",
  "base64",
);

async function loginAsAdmin(request: APIRequestContext, page: Page) {
  const res = await request.post(`${API}/api/auth/login`, {
    data: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD },
  });
  expect(res.status()).toBe(200);
  const { token } = await res.json();
  await page.context().addCookies([
    { name: process.env.AUTH_COOKIE || "kilala_token", value: token, url: WEB },
  ]);
}

async function openAddRecord(page: Page) {
  await page.goto("/dashboard/records");
  await page.getByRole("button", { name: "+ Add Record" }).click();
  return page.getByRole("dialog");
}

async function setPhoto(dialog: ReturnType<Page["getByRole"]>) {
  await dialog.locator('input[type="file"]').setInputFiles({
    name: "face.png",
    mimeType: "image/png",
    buffer: PNG,
  });
  await expect(
    dialog.locator('img[src*="/api/photos/cardholders/"]'),
  ).toBeVisible();
}

test.describe("Add Record — cardholder photo", () => {
  test("shows a Photo field with Upload and Camera options", async ({ page, request }) => {
    await loginAsAdmin(request, page);
    const dialog = await openAddRecord(page);
    await expect(dialog.locator('label[for="photo"]')).toContainText("Photo");
    await expect(dialog.getByRole("button", { name: /Upload photo/i })).toBeVisible();
    await expect(dialog.getByRole("button", { name: /Use camera/i })).toBeVisible();
  });

  test("uploading a photo shows a thumbnail backed by /api/photos", async ({ page, request }) => {
    await loginAsAdmin(request, page);
    const dialog = await openAddRecord(page);
    await setPhoto(dialog);
  });

  test("adds a Senior record with a photo and shows it in details", async ({ page, request }) => {
    await loginAsAdmin(request, page);
    const dialog = await openAddRecord(page);
    const card = `MKT-QA-PHOTO-${Date.now()}`;

    await dialog.getByLabel("First name*").fill("Foto");
    await dialog.getByLabel("Last name*").fill("Tester");
    await dialog.getByLabel("Birthday*").fill("1950-01-01");
    await dialog.getByLabel("Sex*").selectOption("Male");
    await dialog.getByLabel("Address*").fill("123 QA St, Makati");
    await dialog.getByLabel("Card number*").fill(card);
    await dialog.getByRole("combobox", { name: /Issuing LGU/i }).click();
    await page.getByRole("option", { name: "Quezon City" }).click();
    await dialog.getByLabel("Issuing date*").fill("2025-01-01");
    await dialog.getByText("Senior Citizen", { exact: true }).click();
    await setPhoto(dialog);

    await dialog.getByRole("button", { name: "Add record" }).click();
    await expect(dialog).not.toBeVisible();

    // Open the new record's details and confirm the photo renders.
    await page.getByText(card).click();
    await expect(
      page.getByRole("dialog").locator('img[src*="/api/photos/"]'),
    ).toBeVisible();
  });

  test("adds a record with no photo (photo stays optional)", async ({ page, request }) => {
    await loginAsAdmin(request, page);
    const dialog = await openAddRecord(page);
    const card = `MKT-QA-NOPHOTO-${Date.now()}`;

    await dialog.getByLabel("First name*").fill("Nophoto");
    await dialog.getByLabel("Last name*").fill("Tester");
    await dialog.getByLabel("Birthday*").fill("1950-01-01");
    await dialog.getByLabel("Sex*").selectOption("Female");
    await dialog.getByLabel("Address*").fill("456 QA St, Makati");
    await dialog.getByLabel("Card number*").fill(card);
    await dialog.getByRole("combobox", { name: /Issuing LGU/i }).click();
    await page.getByRole("option", { name: "Quezon City" }).click();
    await dialog.getByLabel("Issuing date*").fill("2025-01-01");
    await dialog.getByText("Senior Citizen", { exact: true }).click();

    await dialog.getByRole("button", { name: "Add record" }).click();
    await expect(dialog).not.toBeVisible();
    await expect(page.getByText(card)).toBeVisible();
  });
});
