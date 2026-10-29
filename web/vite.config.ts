import { fileURLToPath } from 'node:url';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

const repo = fileURLToPath(new URL('..', import.meta.url));

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // The site reads the app's own commands.json, so the two never drift apart.
  resolve: { alias: { '@commands': `${repo}commands/commands.json` } },
  server: { fs: { allow: [repo] } },
  test: { include: ['src/**/*.test.ts'] },
});
