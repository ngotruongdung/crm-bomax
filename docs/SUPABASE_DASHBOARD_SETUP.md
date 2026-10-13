# Kết nối OpsDesk với Supabase Dashboard

Tài liệu này dành cho project Supabase mới, dùng để chạy OpsDesk với dữ liệu BOMAX demo có thể đăng nhập thật.
Hai file SQL đã được đóng gói sẵn trong `supabase/manual/`:

| File | Chạy khi nào | Có thể chạy lại? |
| --- | --- | --- |
| `OPSDesk_Supabase_Schema.sql` | Một lần trên project Supabase trống | Không. File tạo toàn bộ schema/migration. |
| `OPSDesk_Supabase_Demo_Data.sql` | Sau khi tạo bốn tài khoản Auth demo | Có. Seed dùng ID cố định và upsert. |
| `OPSDesk_P11_Context_Contract_Fix.sql` | Chỉ project hosted cũ cần nâng cấp `rpc_get_context` | Có. Chỉ thay thế function, không thay đổi dữ liệu. |
| `OPSDesk_P12_Attendance_Admin_Settings.sql` | Project hosted P00–P11 muốn bật cấu hình Wi‑Fi, chấm công web và ảnh online đơn giản | Một lần. Thêm bảng setting và thay thế attendance function, không xoá dữ liệu. |

Không chạy file schema trên project có dữ liệu OpsDesk thật. Nếu project đó đã từng chạy migration, hãy dùng
Supabase CLI/migration history ở bước sau thay vì dán lại schema. Với project hosted đã có schema từ trước,
chạy riêng `supabase/manual/OPSDesk_P11_Context_Contract_Fix.sql` trong SQL Editor để cập nhật contract context
an toàn; file này không tạo hoặc xoá dữ liệu.

Để bật phần **Thiết lập chấm công** trên project đã có schema P00–P11, chạy thêm
`supabase/manual/OPSDesk_P12_Attendance_Admin_Settings.sql` đúng một lần. Sau khi chạy, đăng nhập bằng admin và
mở `/settings/attendance` để tạo văn phòng, Wi‑Fi/BSSID cho mobile, public IP/CIDR cho web, mẫu ca và gán lịch.
P12 thay luồng online cũ bằng ảnh chụp trực tiếp từ camera điện thoại được tải lên private storage; không còn bắt
mã phiên laptop.

## 1. Tạo project và cấu hình Auth

1. Tạo một project mới trong Supabase, chờ trạng thái Database sẵn sàng.
2. Trong **Authentication > URL Configuration**, đặt `Site URL` là `http://127.0.0.1:3000`.
3. Thêm Redirect URL `http://127.0.0.1:3000/auth/callback`.
   `localhost` và `127.0.0.1` là hai origin khác nhau trong trình duyệt; dùng một địa chỉ thống nhất với
   `NEXT_PUBLIC_APP_URL` để reset password và magic link quay về đúng app.
4. Trong **Authentication > Users**, tạo và xác nhận bốn tài khoản sau. Chọn mật khẩu riêng, mạnh và chỉ dùng
   ở môi trường demo/staging:

| Vai trò demo | Email |
| --- | --- |
| Admin | `admin@bomax.demo` |
| Manager | `manager@bomax.demo` |
| Employee A | `linh@bomax.demo` |
| Employee B | `huy@bomax.demo` |

Nếu màn hình Supabase của bạn chỉ hiện lựa chọn gửi lời mời, hãy dùng lời mời để xác nhận email và đặt mật khẩu;
file seed chỉ cần các user tồn tại/đã xác nhận với đúng bốn email trên. Dashboard quản lý user nằm ở
**Authentication > Users**. [Tài liệu Supabase về Users](https://supabase.com/docs/guides/auth/users)

## 2. Chạy SQL schema và dữ liệu demo

Mở **SQL Editor > New query** trong đúng project Supabase:

1. Mở file `supabase/manual/OPSDesk_Supabase_Schema.sql`, copy toàn bộ, dán và bấm **Run**. Chờ query thành công.
2. Mở file `supabase/manual/OPSDesk_Supabase_Demo_Data.sql`, copy toàn bộ, dán và bấm **Run**.
3. Chạy truy vấn kiểm tra sau trong SQL Editor:

```sql
select
  (select count(*) from public.organizations where slug = 'bomax-digital') as organizations,
  (select count(*) from public.organization_members where organization_id = '53000000-0000-0000-0000-000000000001') as members,
  (select count(*) from public.sellers where organization_id = '53000000-0000-0000-0000-000000000001') as sellers,
  (select count(*) from public.tasks where organization_id = '53000000-0000-0000-0000-000000000001') as tasks;
```

Kết quả mong đợi: `organizations = 1`, `members = 4`, `sellers = 3`, `tasks = 9`.

Script tạo organization `BOMAX Digital`, ba seller, phân quyền theo seller và chín task có trạng thái mới,
đang làm, quá hạn, blocked, chờ duyệt, hoàn thành và tương lai. Nó không tạo mật khẩu, không chèn secret và
không thêm dữ liệu attendance/selfie riêng tư.

## 3. Lấy URL/key và tạo `.env.local`

Trong Supabase Dashboard, mở **Connect** để lấy Project URL và publishable key. Có thể vào
**Settings > API Keys** nếu cần xem/tạo key cụ thể. Publishable key được phép nằm ở browser/mobile;
secret/service-role key chỉ được ở server. [Tài liệu chính thức về API keys](https://supabase.com/docs/guides/getting-started/api-keys)

Tại thư mục project, chạy:

```powershell
Copy-Item .env.example .env.local
Copy-Item .env.local apps/web/.env.local
```

Trong monorepo này, script kiểm tra môi trường đọc `.env.local` ở thư mục gốc, còn Next.js web đọc
`apps/web/.env.local`. Vì vậy, sau lệnh copy ở trên, giữ hai file này cùng giá trị `NEXT_PUBLIC_*`.
Mở chúng và thay các giá trị sau. Giữ cùng một Project URL/key cho web và Expo:

```dotenv
NEXT_PUBLIC_APP_URL=http://127.0.0.1:3000
NEXT_PUBLIC_DEMO_MODE=false

NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_YOUR_KEY

EXPO_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_YOUR_KEY
EXPO_PUBLIC_OPSDESK_WEB_URL=http://localhost:3000
```

Nếu dashboard chỉ có key kiểu cũ, legacy `anon` vẫn tương thích với hai biến `*_ANON_KEY` này. Không dán
`sb_secret_...` hoặc service-role key vào bất kỳ biến `NEXT_PUBLIC_*`/`EXPO_PUBLIC_*` nào.

Chỉ khi cần mời user, worker, export hoặc maintenance server-side, thêm server-only values sau vào `.env.local`:

```dotenv
SUPABASE_SERVICE_ROLE_KEY=sb_secret_SERVER_ONLY_KEY
AUTOMATION_SECRET=a-random-secret-at-least-32-characters
PUSH_TOKEN_ENCRYPTION_KEY=64-hex-characters-or-base64-that-decodes-to-32-bytes
ATTENDANCE_TRUSTED_INGRESS=none
```

Local demo giữ `ATTENDANCE_TRUSTED_INGRESS=none`; tính năng chấm công office sẽ fail-closed cho tới khi có
deployment đứng sau ingress đáng tin cậy.

Chấm công Wi‑Fi trên **website** không đọc SSID/BSSID từ trình duyệt. Khi deploy qua Vercel, đặt
`ATTENDANCE_TRUSTED_INGRESS=vercel`; khi deploy qua Cloudflare, đặt `ATTENDANCE_TRUSTED_INGRESS=cloudflare`.
Sau đó, admin bật “Cho phép trên web” và thêm CIDR public IP của gateway Wi‑Fi văn phòng tại
`/settings/attendance`. Localhost luôn bị khóa cho thao tác ghi công web, kể cả khi máy đang bắt đúng Wi‑Fi.

## 4. Chạy app và đăng nhập

```powershell
pnpm verify:env
pnpm dev:web
```

Mở `http://127.0.0.1:3000/login`, đăng nhập bằng `manager@bomax.demo` và mật khẩu bạn đã đặt. Tài khoản này
có quyền manager trên ba seller, vì vậy sẽ nhìn thấy workspace, Today, task demo, reports và các phần quản lý
thuộc phạm vi được cấp. `admin@bomax.demo` là owner/admin để kiểm tra phần quản trị; hai tài khoản còn lại dùng
để kiểm tra góc nhìn employee.

Nếu app vẫn hiển thị demo read-only, dừng `pnpm dev:web`, kiểm tra `.env.local` không còn placeholder rồi chạy
lại. Next.js đọc `NEXT_PUBLIC_*` khi khởi động dev server.

## 5. Khi deploy thật

- Đổi `NEXT_PUBLIC_APP_URL` sang HTTPS domain thật và thêm `/auth/callback` của domain đó vào Redirect URLs.
- Bắt buộc `NEXT_PUBLIC_DEMO_MODE=false`.
- Chạy `pnpm verify:env:production` sau khi đã cấu hình đủ server secret/worker/ingress thật.
- Không chạy demo seed ở production. Dùng quy trình owner bootstrap và data thật trong
  `docs/DEPLOYMENT_CHECKLIST.md`.

## Tái tạo file SQL khi migration thay đổi

Hai file SQL dashboard được sinh từ migration + seed source. Nếu project tiếp tục thêm migration, chạy:

```powershell
pnpm build:supabase:dashboard-sql
```

Sau đó dùng bản `OPSDesk_Supabase_Schema.sql` mới trên một project trống khác. Không dùng nó để nâng cấp
project đang chạy; khi đó cần Supabase CLI migration workflow.
