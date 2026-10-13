import { expect, test } from '@playwright/test';

test('bootstrap page renders in Vietnamese', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { name: /Nền tảng đã sẵn sàng/i })).toBeVisible();
  await expect(page.getByText('Supabase', { exact: true })).toBeVisible();
  await expect(page.getByRole('link', { name: /Mở workspace demo/i })).toBeVisible();
});

test('auth pages render without exposing a fake success state', async ({ page }) => {
  await page.goto('/login');
  await expect(page.getByRole('heading', { name: 'Đăng nhập workspace' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Đăng nhập' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Quên mật khẩu?' })).toHaveAttribute(
    'href',
    '/forgot-password',
  );
  await expect(page.getByRole('link', { name: /Mở workspace demo/i })).toHaveAttribute(
    'href',
    '/overview',
  );

  await page.goto('/forgot-password');
  await expect(page.getByRole('heading', { name: 'Đặt lại mật khẩu' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Gửi hướng dẫn' })).toBeVisible();
});

test('demo workspace routes render without requiring Supabase runtime', async ({ page }) => {
  await page.goto('/overview');
  await expect(page.getByRole('heading', { name: 'Tổng quan vận hành' })).toBeVisible();

  await page.goto('/today');
  await expect(page.getByRole('heading', { name: 'Hôm nay', exact: true })).toBeVisible();

  await page.goto('/sellers');
  await expect(page.getByRole('heading', { name: 'Seller', exact: true })).toBeVisible();

  await page.goto('/team');
  await expect(page.getByRole('heading', { name: 'Nhân sự', exact: true })).toBeVisible();

  await page.goto('/tasks');
  await expect(page.getByRole('heading', { name: 'Tất cả công việc' })).toBeVisible();

  await page.goto('/tasks/new');
  await expect(page.getByRole('heading', { name: 'Giao công việc' })).toBeVisible();

  await page.goto('/tasks/83000000-0000-0000-0000-000000000001');
  await expect(page.getByRole('dialog', { name: 'Chi tiết TASK-1028' })).toBeVisible();
  await expect(page.getByText('TASK-1028', { exact: true })).toBeVisible();
  await expect(page.getByText('Chế độ demo · chỉ đọc')).toBeVisible();
});

test('invite entry never trusts organization details from the URL', async ({ page }) => {
  await page.goto('/auth/accept-invite');
  await expect(page.getByRole('heading', { name: 'Liên kết lời mời không hợp lệ' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Về trang đăng nhập' })).toHaveAttribute(
    'href',
    '/login',
  );

  await page.goto('/auth/accept-invite?token=opaque-token&organization_name=not-trusted');
  await expect(page.getByRole('heading', { name: 'Không thể xác thực lời mời' })).toBeVisible();
  await expect(page.getByText('not-trusted')).toHaveCount(0);
  await expect(page.getByText(/Membership không được tạo từ URL/i)).toBeVisible();
  await expect(page.getByRole('link', { name: 'Về trang đăng nhập' })).toHaveAttribute(
    'href',
    '/login',
  );
});

test('UI-08 design system preview supports keyboard and focus-safe overlay interactions', async ({
  page,
}) => {
  await page.goto('/design-system');
  await expect(page.getByRole('heading', { name: 'Design system' })).toBeVisible();
  await expect(page.getByRole('combobox', { name: 'Combobox' })).toBeVisible();
  await expect(page.getByText('Daily task checkbox')).toBeVisible();
  const dialogTrigger = page.getByRole('button', { name: 'Dialog' });
  await expect(dialogTrigger).toBeVisible();

  await dialogTrigger.click();
  const dialog = page.getByRole('dialog', { name: 'Dialog primitive' });
  const dialogCloseButton = page.getByRole('button', { name: 'Đóng hộp thoại' });
  await expect(dialog).toBeVisible();
  await expect(dialogCloseButton).toBeFocused();

  await page.keyboard.press('Tab');
  await expect(dialogCloseButton).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).toBeHidden();
  await expect(dialogTrigger).toBeFocused();

  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole('button', { name: 'Drawer' }).click();
  const drawer = page.getByRole('dialog', { name: 'Drawer primitive' });
  await expect(drawer).toBeVisible();
  await expect(drawer).toHaveCSS('border-radius', '0px');
  const drawerBounds = await drawer.boundingBox();
  expect(drawerBounds).toMatchObject({ height: 844, width: 390, x: 0, y: 0 });
});
