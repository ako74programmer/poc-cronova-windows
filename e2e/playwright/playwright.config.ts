import { defineConfig } from '@playwright/test';
import { join } from 'node:path';

const reportDir = process.env.PW_REPORT_DIR || 'artifacts/playwright';
const browserName = process.env.PW_BROWSER || 'chromium';

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: false,
  workers: Number(process.env.PW_WORKERS || 1),
  retries: Number(process.env.PW_RETRIES || 0),
  projects: [{ name: browserName, use: { browserName: browserName as 'chromium' | 'firefox' | 'webkit' } }],
  reporter: [
    ['list'],
    ['junit', { outputFile: join(reportDir, 'junit.xml') }],
    ['html', { outputFolder: join(reportDir, 'html'), open: 'never' }]
  ],
  use: {
    baseURL: process.env.FRONTEND_URL || 'http://127.0.0.1:4300',
    trace: (process.env.PW_TRACE || 'retain-on-failure') as 'on' | 'off' | 'retain-on-failure' | 'on-first-retry',
    screenshot: (process.env.PW_SCREENSHOT || 'only-on-failure') as 'on' | 'off' | 'only-on-failure',
    video: (process.env.PW_VIDEO || 'retain-on-failure') as 'on' | 'off' | 'retain-on-failure'
  }
});
