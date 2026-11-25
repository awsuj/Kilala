import { getCloudflareContext } from "@opennextjs/cloudflare";

// Public serve route for cardholder photos, backed by the R2 binding. No auth,
// no expiry — the stored photo_url points here; works in dev (Miniflare) and prod.
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ key: string[] }> },
) {
  const { key } = await params;
  const objectKey = key.join("/");
  const { env } = getCloudflareContext();
  const obj = await env.CARDHOLDER_PHOTOS.get(objectKey);
  if (!obj) return new Response(null, { status: 404 });
  return new Response(obj.body, {
    headers: {
      "Content-Type": obj.httpMetadata?.contentType ?? "application/octet-stream",
      "Cache-Control": "public, max-age=31536000, immutable",
    },
  });
}
