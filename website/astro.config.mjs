import { defineConfig } from "astro/config";
import { readFileSync } from "node:fs";

const project = JSON.parse(readFileSync(new URL("../project.json", import.meta.url)));
const configuredUrl = process.env.PUBLIC_SITE_URL || project.siteUrl;
const site = configuredUrl ? new URL(configuredUrl) : undefined;

export default defineConfig({
  site: site?.origin,
  base: site?.pathname ?? "/",
  trailingSlash: "always",
  devToolbar: { enabled: false },
});
