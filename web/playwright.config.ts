import { defineConfig } from '@playwright/test';

// npm run e2e: builds, serves the build, and runs e2e/ in the installed Chromium
export default defineConfig({
  testDir: 'e2e',
  webServer: { command: 'npx vite preview --port 4174 --strictPort', port: 4174 },
  use: { baseURL: 'http://localhost:4174' },
});
