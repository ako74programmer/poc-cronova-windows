import { test, expect } from '@playwright/test';

test('frontend is reachable', async ({ page }) => {
  const response = await page.goto('/');
  expect(response?.ok()).toBeTruthy();
  await expect(page.locator('body')).toBeVisible();
});
