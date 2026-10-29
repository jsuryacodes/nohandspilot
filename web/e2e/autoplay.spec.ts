import { expect, test } from '@playwright/test';

test('a first visit to /try plays "open Chrome, new tab, search for Docker networking" by itself, within 5 s', async ({
  page,
}) => {
  await page.goto('/try');
  const chrome = page.getByRole('region', { name: 'Google Chrome window' });
  const results = chrome.getByText(
    'Stand-in results. On your Mac, Pilot opens the real Google search in Chrome.',
  );
  await expect(results).toBeVisible({ timeout: 5000 });
  // two tabs: the one Chrome opened with, and the search in the new one
  await expect(chrome.getByRole('button', { name: 'New Tab', exact: true })).toBeVisible();
  await expect(
    chrome.getByRole('button', { name: 'Docker networking - Google Search', exact: true }),
  ).toHaveAttribute('aria-current', 'page');
  // the HUD, in Pilot's words, every step ticked
  for (const step of ['Opened Google Chrome', 'New tab', 'Searching Docker networking']) {
    await expect(page.getByText(new RegExp(`^${step}`))).toBeVisible();
  }
});

test('the visitor takes over: a chip runs, and auto-play never comes back', async ({ page }) => {
  await page.goto('/try');
  await page.getByRole('button', { name: 'play lofi beats on YouTube' }).click({ timeout: 8000 });
  await expect(
    page
      .getByRole('region', { name: 'Google Chrome window' })
      .getByRole('button', { name: 'lofi beats - YouTube', exact: true }),
  ).toBeVisible();
});
