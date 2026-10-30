import { defineCloudflareConfig } from "@opennextjs/cloudflare";

// All routes are dynamic (SSR + server actions + auth-cookie reads), so no
// incremental/ISR cache override is needed.
export default defineCloudflareConfig();
