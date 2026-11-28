import { getCloudflareContext } from "@opennextjs/cloudflare";
import { getCurrentUser } from "@/lib/session";

const ALLOWED: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};
const MAX_BYTES = 5 * 1024 * 1024;

// Auth-gated upload. Stores the image in R2 under cardholders/<uuid>.<ext> and
// returns the absolute serve URL (built from the request origin, correct in dev
// and prod) to persist in photo_url.
export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });
  if (user.role !== "LGU_ADMIN" && user.role !== "SUPERADMIN")
    return Response.json({ error: "Forbidden" }, { status: 403 });

  // Reject oversized bodies up front, before buffering the whole multipart into
  // the isolate's memory (the body is role-gated but the gate is a decodable cookie).
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > MAX_BYTES + 64 * 1024)
    return Response.json({ error: "Photo must be 5 MB or smaller." }, { status: 400 });

  const form = await req.formData();
  const file = form.get("photo");
  if (!(file instanceof File))
    return Response.json({ error: "A photo file is required." }, { status: 400 });

  const ext = ALLOWED[file.type];
  if (!ext)
    return Response.json(
      { error: "Photo must be a JPEG, PNG, or WebP image." },
      { status: 400 },
    );
  if (file.size > MAX_BYTES)
    return Response.json({ error: "Photo must be 5 MB or smaller." }, { status: 400 });

  const key = `cardholders/${crypto.randomUUID()}.${ext}`;
  const { env } = getCloudflareContext();
  await env.CARDHOLDER_PHOTOS.put(key, await file.arrayBuffer(), {
    httpMetadata: { contentType: file.type },
  });

  // Prefer the configured canonical origin so the persisted URL stays durable
  // regardless of which host the upload came through (preview alias, localhost…).
  const base = env.SITE_BASE_URL || new URL(req.url).origin;
  return Response.json({ url: `${base}/api/photos/${key}` }, { status: 201 });
}
