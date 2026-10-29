import { fileURLToPath } from 'node:url';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

const repo = fileURLToPath(new URL('..', import.meta.url));
// Link previews need an absolute address: SITE_URL if set, else Vercel's production domain, else relative.
const vercel = process.env.VERCEL_PROJECT_PRODUCTION_URL;
const site = process.env.SITE_URL ?? (vercel ? `https://${vercel}` : '');

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    { name: 'site-url', transformIndexHtml: (html) => html.replaceAll('%SITE%', site) },
  ],
  // The site reads the app's own commands.json, so the two never drift apart.
  resolve: { alias: { '@commands': `${repo}commands/commands.json` } },
  server: { fs: { allow: [repo] } },
  test: { include: ['src/**/*.test.ts'] },
});
