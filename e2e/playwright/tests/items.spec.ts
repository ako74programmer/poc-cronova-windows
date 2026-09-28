import { expect, test } from '@playwright/test';

const apiBaseUrl = (process.env.API_URL || '').replace(/\/$/, '');

function isApiResponse(response: { url(): string; request(): { method(): string } }, method: string, suffix: string): boolean {
  return response.request().method() === method && response.url() === `${apiBaseUrl}${suffix}`;
}

test('Angular UI performs the Item API CRUD flow', async ({ page, request }) => {
  expect(apiBaseUrl, 'playwright.api_url must be configured').not.toBe('');

  const initialListResponse = page.waitForResponse((response) => isApiResponse(response, 'GET', '/items'));
  const home = await page.goto('/');
  expect(home?.ok()).toBeTruthy();
  await expect(page.getByRole('heading', { name: 'Item Portal' })).toBeVisible();
  expect((await initialListResponse).status()).toBe(200);

  const invalidCreate = await request.post(`${apiBaseUrl}/items`, { data: { name: '' } });
  expect(invalidCreate.status()).toBe(400);

  const itemName = `E2E item ${Date.now()}`;
  const createResponsePromise = page.waitForResponse((response) => isApiResponse(response, 'POST', '/items'));
  await page.getByLabel('Item name').fill(itemName);
  await page.getByRole('button', { name: 'Create item' }).click();
  const createResponse = await createResponsePromise;
  expect(createResponse.status()).toBe(201);
  const created = (await createResponse.json()) as { id: number; name: string };
  expect(created.name).toBe(itemName);
  const itemRow = page.getByRole('listitem').filter({ hasText: itemName });
  await expect(itemRow).toBeVisible();

  const getItemResponsePromise = page.waitForResponse((response) =>
    isApiResponse(response, 'GET', `/items/${created.id}`),
  );
  await page.getByRole('button', { name: `View ${itemName}` }).click();
  expect((await getItemResponsePromise).status()).toBe(200);
  await expect(page.getByTestId('selected-item-id')).toHaveText(String(created.id));
  await expect(page.getByTestId('selected-item-name')).toHaveText(itemName);

  const updatedName = `${itemName} updated`;
  await page.getByRole('button', { name: `Edit ${itemName}` }).click();
  await page.getByLabel('Updated item name').fill(updatedName);
  const updateResponsePromise = page.waitForResponse((response) =>
    isApiResponse(response, 'PUT', `/items/${created.id}`),
  );
  await page.getByRole('button', { name: 'Update item' }).click();
  const updateResponse = await updateResponsePromise;
  expect(updateResponse.status()).toBe(200);
  expect((await updateResponse.json()).name).toBe(updatedName);
  await expect(page.getByTestId('selected-item-name')).toHaveText(updatedName);
  await expect(page.getByRole('listitem').filter({ hasText: updatedName })).toBeVisible();

  const persistedUpdate = await request.get(`${apiBaseUrl}/items/${created.id}`);
  expect(persistedUpdate.status()).toBe(200);
  expect((await persistedUpdate.json()).name).toBe(updatedName);

  const deleteResponsePromise = page.waitForResponse((response) =>
    isApiResponse(response, 'DELETE', `/items/${created.id}`),
  );
  await page.getByRole('button', { name: `Delete ${updatedName}` }).click();
  expect((await deleteResponsePromise).status()).toBe(204);
  await expect(page.getByRole('listitem').filter({ hasText: updatedName })).toHaveCount(0);
  const deletedItem = await request.get(`${apiBaseUrl}/items/${created.id}`);
  expect(deletedItem.status()).toBe(404);
});
