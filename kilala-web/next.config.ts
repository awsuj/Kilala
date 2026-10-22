import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // The portal is an auth-gated app — every page reads the session cookie at
  // request time, so pages are dynamic. Cache Components / partial prefetching
  // (which prerender by default) don't fit; standard dynamic rendering does.
  cacheComponents: false,
  // Don't auto-generate AGENTS.md into the repo.
  agentRules: false,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
