import { test, expect, type APIRequestContext } from "@playwright/test";

const API_BASE_URL = process.env.API_BASE_URL || "http://localhost:5001";

const ADMIN_EMAIL = "admin@makati.gov.ph";
const ADMIN_PASSWORD = "MockHashForTestingOnly123456789012";
const SUPERADMIN_EMAIL = "superadmin@kilala.gov.ph";
const SUPERADMIN_PASSWORD = "Kilala2026";

async function login(
  request: APIRequestContext,
  email: string,
  password: string,
): Promise<string> {
  const res = await request.post(`${API_BASE_URL}/api/auth/login`, {
    data: { email, password },
  });
  expect(res.status(), "login should succeed").toBe(200);
  return (await res.json()).token as string;
}

const uniquePermit = () => `QA-BP-${Date.now()}-${Math.floor(Math.random() * 1e6)}`;

test.describe("LGU Add Business — POST /api/lgu/businesses", () => {
  test("creates an unclaimed accredited business (201) with a locked placeholder account", async ({
    request,
  }) => {
    const token = await login(request, ADMIN_EMAIL, ADMIN_PASSWORD);
    const res = await request.post(`${API_BASE_URL}/api/lgu/businesses`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        business_name: "QA Mart",
        business_permit_no: uniquePermit(),
        tin_number: "000-1-2-3",
      },
    });
    expect(res.status()).toBe(201);
    const body = await res.json();
    expect(body.business_name).toBe("QA Mart");
    expect(body.is_accredited).toBe(true);
    expect(typeof body.lgu_name).toBe("string");
    expect(body.is_active).toBe(false);
  });

  test("rejects missing required fields with 400", async ({ request }) => {
    const token = await login(request, ADMIN_EMAIL, ADMIN_PASSWORD);
    const res = await request.post(`${API_BASE_URL}/api/lgu/businesses`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {},
    });
    expect(res.status()).toBe(400);
  });

  test("rejects a SUPERADMIN with no city selected with 400", async ({
    request,
  }) => {
    const token = await login(request, SUPERADMIN_EMAIL, SUPERADMIN_PASSWORD);
    const res = await request.post(`${API_BASE_URL}/api/lgu/businesses`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        business_name: "QA No City",
        business_permit_no: uniquePermit(),
        tin_number: "000-1-2-3",
      },
    });
    expect(res.status()).toBe(400);
    expect((await res.json()).error).toBe(
      "Select a city before registering a business",
    );
  });

  test("rejects a duplicate business permit with 409", async ({ request }) => {
    const token = await login(request, ADMIN_EMAIL, ADMIN_PASSWORD);
    const permit = uniquePermit();
    const data = {
      business_name: "QA Dup",
      business_permit_no: permit,
      tin_number: "000-1-2-3",
    };
    const first = await request.post(`${API_BASE_URL}/api/lgu/businesses`, {
      headers: { Authorization: `Bearer ${token}` },
      data,
    });
    expect(first.status()).toBe(201);
    const second = await request.post(`${API_BASE_URL}/api/lgu/businesses`, {
      headers: { Authorization: `Bearer ${token}` },
      data,
    });
    expect(second.status()).toBe(409);
  });

  test("the placeholder account cannot log in", async ({ request }) => {
    const token = await login(request, ADMIN_EMAIL, ADMIN_PASSWORD);
    const permit = uniquePermit();
    const created = await request.post(`${API_BASE_URL}/api/lgu/businesses`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        business_name: "QA Locked",
        business_permit_no: permit,
        tin_number: "000-1-2-3",
      },
    });
    expect(created.status()).toBe(201);

    // Pull the real placeholder email from the list (don't assume its format),
    // confirm it's unclaimed, then prove that account cannot log in.
    const list = await request.get(`${API_BASE_URL}/api/lgu/businesses`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const row = (await list.json()).find(
      (b: { business_permit_no: string }) => b.business_permit_no === permit,
    );
    expect(row.is_active).toBe(false);
    const res = await request.post(`${API_BASE_URL}/api/auth/login`, {
      data: { email: row.email, password: "anything" },
    });
    expect(res.status()).not.toBe(200);
  });

  test("does not falsely reject distinct permits that slug-collide", async ({
    request,
  }) => {
    const token = await login(request, ADMIN_EMAIL, ADMIN_PASSWORD);
    const base = `${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
    const mk = (permit: string) =>
      request.post(`${API_BASE_URL}/api/lgu/businesses`, {
        headers: { Authorization: `Bearer ${token}` },
        data: {
          business_name: "QA Collide",
          business_permit_no: permit,
          tin_number: "000-1-2-3",
        },
      });
    // `AA.<base>` and `AA-<base>` are distinct permits that slug to the same
    // string — they must both be accepted, not rejected as a false duplicate.
    expect((await mk(`AA.${base}`)).status()).toBe(201);
    expect((await mk(`AA-${base}`)).status()).toBe(201);
  });

  test("GET /api/lgu/businesses includes is_active for each row", async ({
    request,
  }) => {
    const token = await login(request, ADMIN_EMAIL, ADMIN_PASSWORD);
    const res = await request.get(`${API_BASE_URL}/api/lgu/businesses`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status()).toBe(200);
    const rows = await res.json();
    for (const row of rows) {
      expect(typeof row.is_active).toBe("boolean");
    }
  });
});
