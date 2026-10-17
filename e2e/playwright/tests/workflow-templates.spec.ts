import { expect, test, type Page } from '@playwright/test';

type BuiltDag = {
  dag_id: string;
  schedule: string;
  tasks: Array<{ id: string; deps: string[] }>;
};

async function mockConsole(page: Page, built: BuiltDag[]) {
  await page.addInitScript(() => {
    localStorage.setItem('cnv_mode', 'expert');
    localStorage.setItem('cnv_lang', 'pl');
  });

  await page.route('**/api/me', async (route) => {
    await route.fulfill({ json: { username: 'e2e', role: 'admin', auth: false } });
  });
  await page.route('**/api/info', async (route) => {
    await route.fulfill({ json: { version: 'e2e', executor: 'in-process', tick: '2s', tz: 'UTC' } });
  });
  await page.route('**/api/overview', async (route) => {
    await route.fulfill({ json: { stats: { total_dags: 0 }, dags: [] } });
  });
  await page.route('**/api/dags', async (route) => {
    if (route.request().method() === 'GET') {
      await route.fulfill({ json: [] });
      return;
    }
    await route.fallback();
  });
  await page.route('**/api/dags/**', async (route) => {
    const request = route.request();
    if (request.method() === 'POST' && request.url().endsWith('/api/dags/build')) {
      built.push(request.postDataJSON() as BuiltDag);
      await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
      return;
    }
    if (request.method() === 'GET' && request.url().includes('/runs')) {
      await route.fulfill({ json: [] });
      return;
    }
    if (request.method() === 'GET') {
      await route.fulfill({ json: { dag_id: 'mock', schedule: '', tasks: [] } });
      return;
    }
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
  });
}

async function openExpertNewWorkflow(page: Page, built: BuiltDag[]) {
  await mockConsole(page, built);
  await page.goto('/');
  await expect(page.locator('#newdag')).toBeVisible();
  await page.locator('#newdag').click();
  await expect(page.locator('#modal-root .tpl-card')).toHaveCount(6);
}

function taskGraph(dag: BuiltDag) {
  return Object.fromEntries(dag.tasks.map((task) => [task.id, task.deps || []]));
}

test('expert new-workflow modal groups all starters into two categories', async ({ page }) => {
  const built: BuiltDag[] = [];
  await openExpertNewWorkflow(page, built);

  await expect(page.getByText('Automatyzacja ogólna', { exact: true })).toBeVisible();
  await expect(page.getByText('Dostarczanie oprogramowania', { exact: true })).toBeVisible();
  await expect(page.locator('.tpl-card[data-tpl="build"] .tpl-name')).toHaveText('Budowanie, testy i pakowanie');
  await expect(page.locator('.tpl-card[data-tpl="quality_gate"] .tpl-name')).toHaveText('Brama jakości');
  await expect(page.locator('.tpl-card[data-tpl="fanout"]')).toBeVisible();
});

test('Build, test & package creates a linear SDLC graph', async ({ page }) => {
  const built: BuiltDag[] = [];
  await openExpertNewWorkflow(page, built);

  await page.locator('.tpl-card[data-tpl="build"]').click();
  await page.locator('#nd-id').fill('e2e_build_test_package');
  await page.locator('#nd-create').click();

  await expect.poll(() => built.length).toBe(1);
  expect(taskGraph(built[0])).toEqual({
    build: [],
    test: ['build'],
    package: ['test'],
  });
  expect(built[0].schedule).toBe('');
});

test('Quality gate creates three parallel checks and a join', async ({ page }) => {
  const built: BuiltDag[] = [];
  await openExpertNewWorkflow(page, built);

  await page.locator('.tpl-card[data-tpl="quality_gate"]').click();
  await page.locator('#nd-id').fill('e2e_quality_gate');
  await page.locator('#nd-create').click();

  await expect.poll(() => built.length).toBe(1);
  expect(taskGraph(built[0])).toEqual({
    lint: [],
    unit_tests: [],
    security_scan: [],
    quality_gate: ['lint', 'unit_tests', 'security_scan'],
  });
  expect(built[0].schedule).toBe('');
});
