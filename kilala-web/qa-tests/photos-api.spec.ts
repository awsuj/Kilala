import { test, expect } from "@playwright/test";

const WEB = process.env.PLAYWRIGHT_BASE_URL || "http://localhost:3000";

// The upload route gates on the session cookie, which the portal only *decodes*
// (never verifies — the backend is the authority), so a fake admin JWT suffices.
function adminCookie(): string {
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const payload = Buffer.from(
    JSON.stringify({ id: "admin-id", email: "admin@makati.gov.ph", role: "LGU_ADMIN", exp }),
  ).toString("base64url");
  return `kilala_token=header.${payload}.sig`;
}

// 1×1 PNG
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

test.describe("Cardholder photo upload/serve — /api/photos", () => {
  test("POST /api/photos without a session is rejected 401", async ({ request }) => {
    const res = await request.post(`${WEB}/api/photos`, {
      multipart: { photo: { name: "x.png", mimeType: "image/png", buffer: PNG } },
    });
    expect(res.status()).toBe(401);
  });

  test("POST /api/photos with a non-image is rejected 400", async ({ request }) => {
    const res = await request.post(`${WEB}/api/photos`, {
      headers: { Cookie: adminCookie() },
      multipart: {
        photo: { name: "x.txt", mimeType: "text/plain", buffer: Buffer.from("not an image") },
      },
    });
    expect(res.status()).toBe(400);
  });

  test("POST /api/photos over 5 MB is rejected 400", async ({ request }) => {
    const big = Buffer.alloc(5 * 1024 * 1024 + 1);
    const res = await request.post(`${WEB}/api/photos`, {
      headers: { Cookie: adminCookie() },
      multipart: { photo: { name: "big.png", mimeType: "image/png", buffer: big } },
    });
    expect(res.status()).toBe(400);
  });

  test("POST /api/photos stores an image and serves it back", async ({ request }) => {
    const res = await request.post(`${WEB}/api/photos`, {
      headers: { Cookie: adminCookie() },
      multipart: { photo: { name: "x.png", mimeType: "image/png", buffer: PNG } },
    });
    expect(res.status()).toBe(201);
    const { url } = await res.json();
    expect(url).toMatch(/\/api\/photos\/cardholders\/.+\.png$/);

    const got = await request.get(url);
    expect(got.status()).toBe(200);
    expect(got.headers()["content-type"]).toMatch(/^image\//);
  });

  test("GET /api/photos for a missing key returns 404", async ({ request }) => {
    const res = await request.get(`${WEB}/api/photos/cardholders/does-not-exist.png`);
    expect(res.status()).toBe(404);
  });

  test("served photos carry X-Content-Type-Options: nosniff", async ({ request }) => {
    const up = await request.post(`${WEB}/api/photos`, {
      headers: { Cookie: adminCookie() },
      multipart: { photo: { name: "x.png", mimeType: "image/png", buffer: PNG } },
    });
    const { url } = await up.json();
    const got = await request.get(url);
    expect(got.headers()["x-content-type-options"]).toBe("nosniff");
  });
});
