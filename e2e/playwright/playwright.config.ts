import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: false,
  workers: Number(process.env.PW_WORKERS || 1),
  retries: process.env.CI ? 1 : 0,
  reporter: [
    ['list'],
    ['junit', { outputFile: 'artifacts/playwright/junit.xml' }],
    ['html', { outputFolder: 'artifacts/playwright/html', open: 'never' }]
  ],
  use: {
    baseURL: process.env.FRONTEND_URL || 'http://127.0.0.1:4300',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  }
});
