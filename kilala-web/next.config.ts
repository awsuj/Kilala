import type { NextConfig } from "next";
import { initOpenNextCloudflareForDev } from "@opennextjs/cloudflare";

// Makes getCloudflareContext() bindings (R2, etc.) available under `next dev`
// via Miniflare, matching the deployed Worker.
initOpenNextCloudflareForDev();

const nextConfig: NextConfig = {
  // The portal is an auth-gated app — every page reads the session cookie at
  // request time, so pages are dynamic. Cache Components / partial prefetching
  // (which prerender by default) don't fit; standard dynamic rendering does.
  cacheComponents: false,
  // Don't auto-generate AGENTS.md into the repo.
  agentRules: false,
  turbopack: {
    root: process.cwd(),
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
