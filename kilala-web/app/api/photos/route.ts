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

  const origin = new URL(req.url).origin;
  return Response.json({ url: `${origin}/api/photos/${key}` }, { status: 201 });
}
