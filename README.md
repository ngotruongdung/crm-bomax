# OpsDesk

Nền tảng quản lý vận hành team thương mại điện tử, dùng chung dữ liệu Supabase cho web và mobile.

Repository đã triển khai các phase P00–P10 và đang ở P11: regression, UAT và deployment readiness.
Hosted Supabase đã có probe schema/storage cùng smoke auth/RLS/RPC tạm thời; các lifecycle nghiệp vụ,
thiết bị attendance, cron, backup/restore và UAT vẫn được theo dõi minh bạch trong
[docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md).

## Bắt đầu nhanh

```bash
corepack enable
pnpm install
pnpm check:env
pnpm secret-scan
pnpm dev:web
# In another terminal for the Expo app:
pnpm dev:mobile
```

Mở `http://localhost:3000` để dùng workspace; `/login`, `/overview`, `/today` và
`/auth/accept-invite` sử dụng access state Supabase an toàn khi cấu hình `.env.local` đầy đủ.
Mobile đã có auth/session restore dùng chung contract Supabase, với route `/today` cho employee và
`/overview` cho admin/manager sau khi context được xác minh. Các lệnh baseline được ghi trong
[docs/SETUP.md](docs/SETUP.md). Dùng `pnpm build:mobile` để kiểm tra Expo/Metro bundles cho web,
iOS và Android; `pnpm build:mobile:web` chỉ bundle web.

Khi đã có hosted Supabase, chạy `pnpm verify:env:server` rồi `pnpm test:runtime:remote` để kiểm tra
schema/storage, auth/RLS và các RPC đọc nghiệp vụ bằng tenant QA tự dọn. Hướng dẫn đầy đủ ở
[docs/SETUP.md](docs/SETUP.md).
Các alias chuẩn `pnpm build:web`, `pnpm db:reset`, `pnpm db:types`, `pnpm seed:demo` và
`pnpm verify:deployment` được mô tả trong [docs/SETUP.md](docs/SETUP.md).

## Nguyên tắc triển khai

- Supabase PostgreSQL/Auth/Storage/Realtime là backend dùng chung.
- TypeScript strict, không đưa service-role key vào client.
- Mỗi phase phải có test và checkpoint riêng; không xây feature giả để lấp giao diện.
- UI sẽ dùng tiếng Việt và design token theo đặc tả OpsDesk.
