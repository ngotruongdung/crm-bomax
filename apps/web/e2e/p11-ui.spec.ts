import { expect, test } from '@playwright/test';

const viewports = [
  { width: 1440, height: 900 },
  { width: 1280, height: 800 },
  { width: 1024, height: 768 },
  { width: 768, height: 1024 },
  { width: 390, height: 844 },
];

for (const viewport of viewports) {
  test(`UI-01 tasks stay usable at ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await page.goto('/tasks');

    await expect(page.getByRole('heading', { name: 'Tất cả công việc' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Giao việc' })).toBeVisible();

    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);
  });
}

for (const viewport of [
  { width: 1440, height: 900 },
  { width: 390, height: 844 },
]) {
  test(`UI-01B Today and My Tasks stay usable at ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport);

    await page.goto('/today');
    await expect(page.getByRole('heading', { name: 'Hôm nay', exact: true })).toBeVisible();
    await expect(page.locator('.today-summary-strip')).toBeVisible();
    let overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);

    await page.goto('/my-tasks');
    await expect(
      page.getByRole('heading', { name: 'Công việc của tôi', exact: true }),
    ).toBeVisible();
    await expect(page.locator('.my-tasks-summary-strip')).toBeVisible();
    overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);
  });
}

for (const viewport of [
  { width: 1440, height: 900 },
  { width: 390, height: 844 },
]) {
  test(`FE-R6 Today and action inbox stay focused at ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport);

    await page.goto('/today');
    await expect(page.locator('.today-focus-header')).toBeVisible();
    await expect(page.getByRole('link', { name: 'Chấm công' })).toBeVisible();
    let overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);

    await page.goto('/notifications?tab=tasks');
    await expect(page.getByText('Action inbox', { exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: /Công việc/ })).toHaveAttribute(
      'aria-pressed',
      'true',
    );
    await expect(page.getByText('Bạn còn thông báo mới')).toHaveCount(0);

    await page.getByRole('button', { name: /Chưa đọc/ }).click();
    await expect(page).toHaveURL(/tab=unread/);
    await page.reload();
    await expect(page.getByRole('button', { name: /Chưa đọc/ })).toHaveAttribute(
      'aria-pressed',
      'true',
    );
    overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);
  });

  test(`UI-12 HR and attendance surfaces stay compact at ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport);

    await page.goto('/requests');
    await expect(page.getByRole('heading', { name: 'Yêu cầu của tôi' })).toBeVisible();
    await expect(page.locator('.hr-request-type-tabs')).toBeVisible();
    await expect(page.getByRole('button', { name: '+ Tạo yêu cầu' })).toBeDisabled();
    let overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);

    await page.goto('/approvals');
    await expect(page.getByRole('heading', { name: 'Phê duyệt' })).toBeVisible();
    const approvalRow = page.locator('.hr-approval-row-button').first();
    await expect(approvalRow).toBeVisible();
    await approvalRow.click();
    const approvalDrawer = page.getByRole('dialog');
    await expect(approvalDrawer).toBeVisible();
    await expect(approvalDrawer.getByRole('button', { name: 'Duyệt' })).toBeDisabled();
    await expect(approvalDrawer.getByRole('button', { name: 'Từ chối' })).toBeDisabled();
    overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);

    await page.goto('/attendance');
    await expect(page.getByRole('heading', { name: 'Chấm công', exact: true })).toBeVisible();
    await expect(page.locator('.attendance-today-card')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Chấm công văn phòng' })).toBeDisabled();
    overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);

    await page.goto('/attendance/monitor');
    await expect(page.getByRole('heading', { name: 'Theo dõi chấm công' })).toBeVisible();
    await expect(page.locator('.attendance-monitor-table')).toBeVisible();
    overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);

    await expect(page.locator('[class*="avatar" i]')).toHaveCount(0);
  });

  test(`UI-13 timesheets stay usable at ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport);

    await page.goto('/timesheet/me');
    await expect(page.getByRole('heading', { name: 'Công tháng của tôi' })).toBeVisible();
    await expect(page.locator('.timesheet-summary-grid')).toBeVisible();
    let overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);

    await page.goto('/timesheets');
    await expect(page.getByRole('heading', { name: 'Bảng công tháng' })).toBeVisible();
    await expect(page.locator('.timesheet-people-card')).toBeVisible();
    overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);
  });
}

test('UI-02 workspace keeps the Synapse-like light surface hierarchy', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/tasks');

  const sidebar = page.locator('.workspace-sidebar');
  const header = page.locator('.workspace-header');
  const primaryAction = page.getByRole('button', { name: 'Giao việc' });

  await expect(sidebar).toHaveCSS('background-color', 'rgb(245, 246, 248)');
  await expect(sidebar).toHaveCSS('border-right-width', '1px');
  await expect(header).toHaveCSS('background-color', 'rgb(255, 255, 255)');
  await expect(primaryAction).toHaveCSS('background-color', 'rgb(32, 33, 36)');
});

test('UI-03 rendered workspace surfaces do not introduce avatar UI', async ({ page }) => {
  for (const route of ['/overview', '/tasks', '/team']) {
    await page.goto(route);
    await expect(page.locator('[class*="avatar" i]')).toHaveCount(0);
  }
});

test('UI-04 row selection, checklist required state and Daily toggle stay independent', async ({
  page,
}) => {
  await page.goto('/tasks');

  const rowSelection = page.getByRole('checkbox', { name: 'Chọn TASK-1028' });
  await rowSelection.check();
  await expect(page.getByText('Đã chọn 1 công việc.')).toBeVisible();

  await page.getByRole('button', { name: 'Giao việc' }).click();
  const drawer = page.getByRole('dialog', { name: 'Giao công việc' });
  await drawer.getByRole('button', { name: 'Thêm tùy chọn' }).click();
  await drawer.getByRole('button', { name: '+ Thêm bước' }).click();

  const required = drawer.getByRole('checkbox', { name: 'Bắt buộc' });
  const daily = drawer.getByRole('checkbox', { name: /Daily task/i });
  await expect(required).toBeChecked();
  await expect(daily).not.toBeChecked();

  await daily.check();
  await expect(required).toBeChecked();
  await required.uncheck();
  await expect(daily).toBeChecked();
  await expect(rowSelection).toBeChecked();
});

test('UI-05 direct task deep link and refresh keep the same task', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/tasks/83000000-0000-0000-0000-000000000001');
  let drawer = page.getByRole('dialog', { name: 'Chi tiết TASK-1028' });
  await expect(drawer).toBeVisible();
  await expect(drawer.getByText('TASK-1028', { exact: true })).toBeVisible();

  let box = await drawer.boundingBox();
  expect(box?.width).toBeGreaterThanOrEqual(515);
  expect(box?.width).toBeLessThanOrEqual(525);

  await page.reload();
  drawer = page.getByRole('dialog', { name: 'Chi tiết TASK-1028' });
  await expect(drawer).toBeVisible();
  await expect(page.getByText('Chế độ demo · chỉ đọc')).toBeVisible();

  await drawer.getByRole('button', { name: 'Mở rộng chi tiết công việc' }).click();
  await expect
    .poll(async () => (await drawer.boundingBox())?.width ?? 0)
    .toBeGreaterThanOrEqual(715);
  box = await drawer.boundingBox();
  expect(box?.width).toBeLessThanOrEqual(725);

  await drawer.getByRole('button', { name: 'Đóng chi tiết công việc' }).click();
  await expect(page).toHaveURL(/\/tasks$/);
});

test('UI-07 task pages expose real empty and error states', async ({ page }) => {
  await page.goto('/tasks?q=__no_matching_task__');
  await expect(page.getByRole('heading', { name: 'Không có công việc phù hợp' })).toBeVisible();

  await page.goto('/tasks/83000000-0000-0000-0000-999999999999');
  await expect(page.getByRole('heading', { name: 'Không thể tải công việc' })).toBeVisible();
  await expect(page.getByText('Công việc demo không tồn tại.')).toBeVisible();
});

test('UI-10 task filters survive reload and browser back through URL state', async ({ page }) => {
  await page.goto('/tasks?q=flash&priority=normal');

  const search = page.getByRole('textbox', { name: 'Tìm công việc' });
  const priority = page.getByRole('combobox', { name: 'Lọc ưu tiên' });
  await expect(search).toHaveValue('flash');
  await expect(priority).toHaveValue('normal');

  await page.reload();
  await expect(search).toHaveValue('flash');
  await expect(priority).toHaveValue('normal');

  await page.getByRole('link', { name: /TASK-1027/i }).click();
  await expect(page.getByRole('dialog', { name: 'Chi tiết TASK-1027' })).toBeVisible();
  await page.goBack();
  await expect(page).toHaveURL(/q=flash/);
  await expect(page).toHaveURL(/priority=normal/);
  await expect(search).toHaveValue('flash');
});

for (const viewport of [
  { width: 1440, height: 900 },
  { width: 390, height: 844 },
]) {
  test(`UI-11 seller and team workspaces stay compact at ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport);

    await page.goto('/sellers');
    await expect(page.locator('.seller-workspace-layout')).toBeVisible();
    await expect(page.locator('.seller-summary-strip')).toBeVisible();
    let overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);

    await page.goto('/team');
    await expect(page.getByRole('textbox', { name: 'Tìm nhân sự' })).toBeVisible();
    const firstMemberRow = page.locator('.team-row-main').first();
    await expect(firstMemberRow).toBeVisible();
    await firstMemberRow.click();
    await expect(page.getByRole('dialog')).toBeVisible();
    await expect(page.locator('[class*="avatar" i]')).toHaveCount(0);
    overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);
  });
}
