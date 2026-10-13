# OPSDESK — IMPLEMENTATION PLAN THEO PHASE

> **Mục đích của file này**  
> Đây là **kế hoạch thực thi bắt buộc** để một AI lập trình triển khai project OpsDesk theo từng giai đoạn nhỏ, có kiểm thử và có cổng nghiệm thu rõ ràng.  
> AI **không được code toàn bộ project trong một lần**. Mỗi phiên làm việc chỉ được xử lý **một phase** trong file này, hoàn tất test, cập nhật tài liệu trạng thái, rồi **dừng lại**. Chỉ được chuyển sang phase tiếp theo ở một phiên làm việc sau khi phase hiện tại đạt điều kiện PASS.

---

## 0. TÀI LIỆU NGUỒN VÀ THỨ TỰ ƯU TIÊN

AI phải đọc các file theo thứ tự sau trước khi code:

1. `DAC_TA_OPSDESK_APP_WEB_SUPABASE.md` — **nguồn yêu cầu sản phẩm và kỹ thuật chính**.
2. `PLAN_XAY_DUNG_OPSDESK_THEO_PHASE.md` — **nguồn quy trình thực thi và cổng kiểm thử**.
3. `UI_REFERENCE.png` — giao diện tham chiếu về layout, độ thoáng, sidebar, bảng, card, màu sắc, typography.
4. `docs/IMPLEMENTATION_STATUS.md` — trạng thái thực tế của repository ở thời điểm hiện tại.
5. `docs/TEST_REPORT.md` — kết quả kiểm thử đã chạy ở các phase trước.
6. `docs/DECISIONS.md` — thay đổi yêu cầu/kiến trúc đã được chấp thuận sau khi đặc tả ban đầu được viết.

### 0.1. Khi hai tài liệu có vẻ mâu thuẫn

- `DAC_TA_OPSDESK_APP_WEB_SUPABASE.md` quyết định **sản phẩm phải làm gì**.
- File plan này quyết định **làm theo thứ tự nào và khi nào được coi là hoàn thành**.
- Nếu `docs/DECISIONS.md` có quyết định mới hơn và ghi rõ ngày, lý do, người yêu cầu thì quyết định mới được ưu tiên cho phần đã thay đổi.
- AI không được tự sửa yêu cầu để làm cho việc code dễ hơn.

### 0.2. Mapping với G0–G9 trong đặc tả

Plan này chia nhỏ G0–G9 để một AI không cần xử lý phạm vi quá lớn trong một lần:

| Plan phase | Mapping đặc tả |
|---|---|
| P00 | G0 |
| P01A, P01B | G1 |
| P02 | G2 |
| P03A, P03B, P03C | G3 |
| P04 | G4 |
| P05 | G5 |
| P06 | G6 |
| P07 | G7 |
| P08, P09 | G8 |
| P10, P11 | G9 |

Không được hiểu việc chia nhỏ này là thay đổi scope. Đây chỉ là chia nhỏ thứ tự thực hiện.

---

# 1. QUY TẮC TỐI CAO: MỖI PHASE = MỘT PHIÊN TRIỂN KHAI

## 1.1. AI không được làm phase tiếp theo trong cùng một lần chạy

Ví dụ:

- Phiên 1: chỉ làm P00.
- Sau khi P00 PASS: dừng, báo kết quả.
- Phiên sau: đọc lại tài liệu và làm P01A.
- P01A PASS: dừng.
- Phiên sau mới làm P01B.

Ngay cả khi còn nhiều thời gian/context/token, AI vẫn **không được tự tiện tiếp tục phase kế tiếp**.

Mục tiêu là:

- Giảm lỗi dây chuyền.
- Dễ review từng lớp.
- Khi có bug thì biết bug xuất hiện từ phase nào.
- Tránh tình trạng giao diện nhìn hoàn chỉnh nhưng database/RLS/backend bên dưới sai.
- Cho phép đổi yêu cầu sớm mà không phải đập lại cả hệ thống.

## 1.2. Trước khi bắt đầu mỗi phase

AI bắt buộc thực hiện đủ 8 bước:

1. Đọc lại mục của phase trong file này.
2. Đọc các mục liên quan trong `DAC_TA_OPSDESK_APP_WEB_SUPABASE.md`.
3. Đọc `docs/IMPLEMENTATION_STATUS.md`.
4. Đọc phần mới nhất của `docs/TEST_REPORT.md`.
5. Kiểm tra working tree/repository hiện tại, không giả định chat cũ còn đúng.
6. Liệt kê các file/migration/module dự kiến thay đổi.
7. Nêu rõ test nào sẽ phải chạy ở cuối phase.
8. Chỉ sau đó mới bắt đầu code.

## 1.3. Sau khi hoàn thành code của phase

AI phải:

1. Chạy migration/reset database phù hợp.
2. Chạy lint.
3. Chạy typecheck.
4. Chạy unit tests của phần vừa làm.
5. Chạy database/RLS tests nếu phase chạm database.
6. Chạy integration tests nếu phase có RPC/server function.
7. Chạy E2E/manual validation cho UI liên quan.
8. Kiểm tra negative path và permission path, không chỉ happy path.
9. Cập nhật `docs/TEST_REPORT.md`.
10. Cập nhật `docs/IMPLEMENTATION_STATUS.md`.
11. Nếu có quyết định mới, cập nhật `docs/DECISIONS.md`.
12. Ghi commit/checkpoint nếu repository dùng Git.
13. **Dừng lại, không code phase sau.**

---

# 2. TRẠNG THÁI PHASE VÀ QUY TẮC GATE

Mỗi phase chỉ được có một trong các trạng thái sau:

| Trạng thái | Ý nghĩa |
|---|---|
| `NOT_STARTED` | Chưa bắt đầu |
| `IN_PROGRESS` | Đang triển khai |
| `FAIL` | Có lỗi chức năng/test/permission chưa giải quyết |
| `BLOCKED_EXTERNAL_SETUP` | Code đã đủ nhưng không thể xác minh phần phụ thuộc thiết bị/chứng chỉ/IP/tài khoản bên ngoài |
| `PASS` | Toàn bộ điều kiện bắt buộc của phase đã đạt |

## 2.1. Chỉ được chuyển phase khi nào?

### Bình thường
Chỉ chuyển khi phase hiện tại = `PASS`.

### Ngoại lệ rất hạn chế: `BLOCKED_EXTERNAL_SETUP`

Chỉ được dùng khi toàn bộ các điều kiện sau cùng đúng:

- Logic code đã triển khai thật.
- Unit/integration/database tests có thể chạy đã PASS.
- Chỉ còn phần phụ thuộc bên ngoài không có trong môi trường code, ví dụ:
  - điện thoại thật để kiểm tra BSSID iOS/Android;
  - AP Wi-Fi thật của công ty;
  - APNs/Expo push credential;
  - IP public văn phòng;
  - SMTP/API key thật.
- AI đã tạo checklist setup và mô tả chính xác cách xác minh khi có điều kiện.
- Không dùng mock để giả thành PASS.

Khi phase là `BLOCKED_EXTERNAL_SETUP`, AI có thể triển khai phase không phụ thuộc trực tiếp nếu chủ dự án yêu cầu, nhưng **không được gọi project là hoàn tất** trước khi external verification được thực hiện.

## 2.2. Những trường hợp tuyệt đối không được chuyển phase

- Migration lỗi.
- RLS có lỗ hổng.
- Cross-organization test fail.
- Nút UI chưa nối backend thật.
- Dùng mock/localStorage thay Supabase cho logic production.
- API trả thành công giả khi dữ liệu chưa ghi.
- Idempotency chưa xử lý ở thao tác có retry/double-click.
- Một test bắt buộc đang `FAIL`.
- Có lỗi TypeScript/build.
- Có secret trong client bundle/repo.
- Có bug làm sai số công, sai quyền, sai lịch lặp, sai cutoff báo cáo 18:00.

---

# 3. CÁC FILE TRẠNG THÁI AI PHẢI DUY TRÌ

AI phải tạo các file sau ngay từ P00 nếu chưa có.

## 3.1. `docs/IMPLEMENTATION_STATUS.md`

Cấu trúc tối thiểu:

```md
# Implementation Status

CURRENT_PHASE: P00
CURRENT_PHASE_STATUS: IN_PROGRESS
LAST_UPDATED: 2026-10-04

## Phase summary
| Phase | Status | Commit | Notes |
|---|---|---|---|
| P00 | PASS | abc123 | Repo/bootstrap done |
| P01A | NOT_STARTED | - | - |
...

## Feature status
| Feature | Status | Source spec | Notes |
|---|---|---|---|
| Supabase Auth | NOT_STARTED | §29–31 | |
| Seller scope | NOT_STARTED | §16 | |
| Task core | NOT_STARTED | §4, §12–13 | |
...

## External blockers
- None

## Next allowed phase
P01A
```

## 3.2. `docs/TEST_REPORT.md`

Không được chỉ viết “all tests passed”. Phải có bằng chứng có cấu trúc:

```md
# Test Report

## P03B — Task core
Date: ...
Commit: ...
Status: PASS

### Automated
| Test/command | Result | Evidence |
|---|---|---|
| pnpm lint | PASS | 0 errors |
| pnpm typecheck | PASS | 0 errors |
| supabase test db | PASS | AUTH/TASK tests |
| pnpm test | PASS | 83 tests |
| pnpm test:e2e -- task | PASS | 12 specs |

### Spec test IDs
| ID | Result | Evidence/notes |
|---|---|---|
| TASK-01 | PASS | integration create_task.spec.ts |
| TASK-02 | PASS | idempotency test |
...

### Manual checks
- [x] Create task web
- [x] Employee sees assigned task
- [x] Other organization cannot see task
...

### Open failures
None
```

## 3.3. `docs/DECISIONS.md`

Dùng cho những quyết định mới, không dùng để che bug.

Ví dụ:

```md
## ADR-005 — Attendance office requires native mobile
Date: ...
Status: Accepted
Reason: Browser cannot reliably prove Wi-Fi SSID/BSSID.
Impact: Web shows diagnostic/help only; native app performs strict office check-in.
```

## 3.4. `docs/PHASE_CHECKLIST.md`

Có thể tạo một checklist ngắn để AI nhìn thấy ngay phase hiện tại:

```md
## P03B
- [ ] DB schema complete
- [ ] RPC complete
- [ ] RLS complete
- [ ] Web UI complete
- [ ] Mobile shared contract complete
- [ ] Unit tests pass
- [ ] DB tests pass
- [ ] E2E pass
- [ ] Manual happy path pass
- [ ] Manual permission negative path pass
- [ ] Docs updated
```

---

# 4. CẤU TRÚC KIỂM THỬ CHUNG

## 4.1. Test pyramid bắt buộc

### Database / RLS
Dùng Supabase local + pgTAP hoặc cách tương đương để test:

- constraints;
- unique keys;
- foreign keys;
- RLS;
- grant/execute;
- organization isolation;
- seller scope;
- HR privacy.

### Domain unit tests
Dùng cho:

- task status transition;
- recurrence date generation;
- working-day calculation;
- attendance interval arithmetic;
- timesheet minutes;
- report cohort calculation;
- reminder eligibility;
- timezone conversion.

### Integration tests
Dùng cho command/RPC/Edge Function:

- create task;
- bulk create;
- submit task;
- approve request;
- attendance finalize;
- recurring generator;
- report snapshot;
- outbox dispatch.

### Web E2E
Dùng Playwright hoặc tương đương cho các luồng chính.

### Native test
- emulator/simulator cho logic UI có thể mô phỏng;
- thiết bị thật cho Wi-Fi/BSSID/camera/challenge nếu cần;
- không coi mock native module là test production.

## 4.2. Test data chuẩn

Seed phải có ít nhất:

### Organization A
- `owner_a`
- `manager_ab_a` — quản lý Seller A/B
- `manager_c_a` — quản lý Seller C
- `employee_a1`
- `employee_a2`
- `hr_a`

Seller:
- Seller A — Shopee
- Seller B — TikTok Shop
- Seller C — Shopee

### Organization B
- `owner_b`
- `employee_b1`
- Seller X

### Mục đích
Bộ seed này phải đủ để test:

- cross-organization leak;
- manager scope;
- employee scope;
- HR-only evidence;
- seller assignment;
- task reassignment;
- report recipient scope.

## 4.3. Kiểm thử visual chung

Ở các phase có UI, tối thiểu kiểm tra:

- 1440px desktop;
- 1280px desktop;
- 1024px;
- 768px tablet;
- 390px mobile.

UI phải bám `UI_REFERENCE.png` và mục Design System trong đặc tả:

- nền xám rất nhạt;
- main surface trắng;
- sidebar sáng, gọn;
- viền mảnh;
- card bo nhẹ, không bóng nặng;
- CTA chính gần đen;
- typography sạch;
- không avatar/initial circle;
- khoảng trắng rộng;
- nội dung ưu tiên bảng/list rõ ràng hơn dashboard đầy màu sắc.

---

# 5. QUY TẮC DATABASE/MIGRATION CHO MỌI PHASE

1. Mọi thay đổi schema phải qua migration trong `supabase/migrations/`.
2. Không chỉnh database production bằng tay rồi quên migration.
3. Sau một phase đã PASS, không sửa ngược migration đã áp dụng; tạo migration mới.
4. Mọi table nghiệp vụ private phải có RLS trước khi phase PASS.
5. Không dùng `service_role` ở client/web browser/mobile.
6. Admin client chỉ nằm server-only/Edge Function đáng tin cậy.
7. Function đặc quyền phải giới hạn `EXECUTE`.
8. Function security definer phải kiểm soát `search_path` và authorization bên trong.
9. Sau schema change, generate lại DB types.
10. Gate bắt buộc:

```bash
supabase db reset
supabase test db
```

Hoặc command tương đương trong repo.

Nếu clean reset không dựng được database từ zero thì phase không PASS.

---

# 6. QUY TẮC FRONTEND CHO MỌI PHASE

1. Không tạo UI giả rồi để TODO backend.
2. Nếu backend chưa tồn tại, component chưa được đánh dấu completed.
3. PermissionGate chỉ là UX; authorization thật ở server/RLS.
4. Loading, empty, error phải có state thật.
5. Không hardcode số lượng task/báo cáo giả trên dashboard production.
6. Query key phải chứa organization và phạm vi phù hợp.
7. Mutation quan trọng không optimistic thành công nếu có rủi ro sai dữ liệu.
8. Retry thao tác create/update dùng idempotency/expected version theo đặc tả.
9. Form validation phải giữ dữ liệu khi lỗi.
10. Deep link phải hoạt động sau refresh.
11. Logout phải clear cache nhạy cảm.

---

# 7. QUY TRÌNH CHUẨN TRONG MỖI PHASE

Mỗi phase phải đi theo đúng thứ tự sau:

### Bước A — Recon
- đọc spec;
- kiểm repo;
- chạy baseline tests;
- ghi scope.

### Bước B — Contract/data model
- enum/type/schema;
- migration;
- constraints/index;
- RLS/policy;
- generated types.

### Bước C — Backend command/query
- RPC/Edge Function/server route;
- authorization;
- transaction;
- idempotency/versioning;
- audit/outbox nếu liên quan.

### Bước D — Frontend/native
- query/mutation hooks;
- UI states;
- permission UX;
- responsive;
- accessibility cơ bản.

### Bước E — Automated test
- unit;
- DB/RLS;
- integration;
- E2E.

### Bước F — Manual scenario
Chạy luồng bằng tài khoản seed khác nhau.

### Bước G — Gate review
- có test fail không?
- có fake success không?
- có leak scope không?
- có TODO critical không?
- docs đã cập nhật chưa?

### Bước H — Stop
Ngay khi phase PASS/FAIL/BLOCKED được ghi, AI dừng.

---

# 8. PHASE P00 — REPO AUDIT, BOOTSTRAP, CI VÀ QUY ƯỚC

## 8.1. Mục tiêu

Tạo nền móng kỹ thuật để các phase sau không code tùy tiện.

**P00 không triển khai feature nghiệp vụ hoàn chỉnh.**

## 8.2. Việc phải làm

### Repo audit
- Xác định repo mới hay repo đã tồn tại.
- Nếu đã có code: liệt kê stack, version, vấn đề tương thích.
- Không rewrite stack đang tốt chỉ vì plan đề xuất mặc định khác.

### Monorepo/package structure
Nếu repo mới, theo cấu trúc trong đặc tả:

- `apps/web`
- `apps/mobile`
- `packages/contracts`
- `packages/domain`
- `packages/design-tokens`
- `packages/api-client`
- `supabase/`
- `docs/`

### Tooling
Thiết lập:

- TypeScript strict;
- lint;
- format;
- unit test runner;
- Playwright;
- Supabase CLI;
- test DB;
- environment validation.

### Script chuẩn
Tạo script tương đương:

```json
{
  "lint": "...",
  "typecheck": "...",
  "test": "...",
  "test:db": "...",
  "test:e2e": "...",
  "build": "..."
}
```

### Environment
Tạo `.env.example` không chứa secret thật.

Phân tách rõ:

- browser-safe env;
- server-only env;
- mobile public config;
- Supabase service role server-only;
- external provider keys.

### Docs
Tạo:

- `docs/IMPLEMENTATION_STATUS.md`
- `docs/TEST_REPORT.md`
- `docs/DECISIONS.md`
- `docs/SETUP.md`
- `docs/PHASE_CHECKLIST.md`

## 8.3. Không được làm trong P00

- Không dựng 20 màn hình giả.
- Không tạo dashboard số liệu mock rồi gọi là MVP.
- Không code chấm công.
- Không code daily task.
- Không code report 18:00.

## 8.4. Test bắt buộc

- clean install thành công;
- lint chạy;
- typecheck chạy;
- test runner chạy được dù chưa nhiều tests;
- web dev/build khởi động;
- mobile project compile/bootstrap cơ bản;
- Supabase local start/reset chạy;
- secret scan cơ bản không phát hiện secret thật.

## 8.5. Gate PASS

P00 chỉ PASS khi:

- repo cấu trúc rõ;
- mọi script baseline chạy được;
- Supabase local hoạt động;
- docs trạng thái tồn tại;
- `.env.example` đầy đủ tên biến nhưng không có secret;
- không có lỗi build/typecheck blocker.

## 8.6. Output cuối phase

AI báo:

- stack/version thực tế;
- cây repo;
- commands đã chạy;
- test baseline;
- external setup còn thiếu;
- commit/checkpoint;
- **dừng**.

---

# 9. PHASE P01A — SUPABASE CORE SCHEMA, ORGANIZATION, MEMBERSHIP, AUTH FOUNDATION

## 9.1. Mục tiêu

Tạo multi-tenant foundation đúng ngay từ đầu.

## 9.2. Scope

Triển khai phần nền liên quan:

- organizations;
- profiles/user mapping cần thiết;
- memberships;
- roles/capabilities;
- invitations foundation;
- timestamps/version fields;
- audit foundation;
- generic idempotency storage nếu đặc tả dùng chung;
- helper functions phục vụ RLS.

Đối chiếu kỹ mục database/RLS trong đặc tả.

## 9.3. Thứ tự code

1. Enum/domain contracts.
2. Migration table + constraints.
3. Index cần thiết.
4. RLS enable.
5. Membership helpers.
6. Auth server helper.
7. Seed org A/org B.
8. Generated types.
9. DB tests.

## 9.4. RLS phải chứng minh được

- Anonymous không đọc dữ liệu private.
- User organization A không đọc B.
- Membership inactive bị chặn dù auth session còn hợp lệ.
- Client tự nhét role vào metadata không thay quyền.
- Employee không tự nâng role.

## 9.5. Test bắt buộc

Tối thiểu:

- AUTH-01
- AUTH-02
- AUTH-03
- AUTH-04 nền tảng tenant
- AUTH-11
- SEC-11 nếu worker/admin foundation đã tạo
- SEC-12
- SEC-14

Ngoài ra:

- `supabase db reset` PASS;
- generated types không lỗi;
- lint/typecheck PASS.

## 9.6. Manual check

- login seed account A;
- query membership A;
- thử query organization B;
- revoke membership rồi refresh request;
- xác minh bị chặn.

## 9.7. Gate PASS

Không được sang P01B nếu tenant isolation chưa PASS.

---

# 10. PHASE P01B — INVITE, ROLE/CAPABILITY, SELLER SCOPE FOUNDATION VÀ PERMISSION MATRIX

## 10.1. Mục tiêu

Hoàn thiện cơ chế cấp quyền thực tế trước khi có task.

## 10.2. Scope

- invite flow;
- activate membership;
- role owner/admin/manager/employee theo đặc tả;
- capability HR riêng;
- seller master table foundation;
- seller membership/scope;
- manager scope;
- permission helper/query.

## 10.3. Backend trước UI

Phải có server command thật cho:

- create invite;
- accept invite;
- list members theo scope;
- update role/capability có authorization;
- create seller;
- assign seller scope.

Invite phải idempotent/retriable và không tạo duplicate/orphan quyền.

## 10.4. Test bắt buộc

- AUTH-04
- AUTH-05
- AUTH-06
- AUTH-07
- AUTH-08
- AUTH-09
- AUTH-10
- AUTH-12
- SEC-01 nền HR file nếu chưa có file có thể defer evidence content nhưng permission model phải test

## 10.5. Manual check

- Owner mời employee.
- Invite sai email không accept được.
- Manager A/B chỉ thấy scope phù hợp.
- Manager seller không tự có HR capability.
- Disable member làm session mất quyền ở request kế tiếp.

## 10.6. Gate PASS

P01B PASS khi permission matrix thực tế khớp spec và cross-scope tests PASS.

---

# 11. PHASE P02 — DESIGN SYSTEM, AUTH UX VÀ APP SHELL

## 11.1. Mục tiêu

Tạo giao diện khung chuẩn theo ảnh tham chiếu trước khi nhân bản nhiều trang.

## 11.2. Không làm feature giả

P02 chỉ tạo shell và primitives. Không điền số liệu dashboard giả để làm đẹp.

## 11.3. Design tokens

Tạo shared tokens cho:

- background;
- surface;
- border;
- text primary/secondary/muted;
- CTA dark;
- radius;
- spacing;
- typography;
- icon sizing;
- row height;
- table density;
- sidebar width;
- mobile spacing.

## 11.4. UI reference bắt buộc

Từ `UI_REFERENCE.png`:

- Sidebar trái chiếm chiều rộng cố định desktop, nền sáng.
- Main content đặt trong surface trắng, tách bằng border mảnh.
- Header/breadcrumb tối giản.
- Các mục navigation có icon nét mảnh.
- Active item nền xám rất nhạt/trắng, border/shadow cực nhẹ.
- Không dùng gradient nổi bật toàn hệ thống.
- Không dùng card nhiều màu.
- Không dùng avatar cho danh sách người.
- Bảng dữ liệu đơn sắc, dễ scan.

## 11.5. Component phải có

Tối thiểu:

- AppShell
- Sidebar
- MobileBottomNavigation hoặc mobile navigation theo spec
- PageHeader
- Breadcrumb
- Button variants
- Input
- Select/Combobox
- Checkbox thường
- DailyTaskCheckbox khác style/semantics với checklist
- Dialog/Drawer
- Sheet
- Table
- StatusBadge
- PriorityBadge
- EmptyState
- ErrorState
- Skeleton
- Toast
- ConfirmDialog
- PersonLabel dạng text

## 11.6. Auth pages

Code thật:

- login;
- accept invite;
- invalid/expired invite;
- unauthorized/no membership;
- logout.

## 11.7. Test bắt buộc

- UI-01
- UI-02
- UI-03
- UI-04
- UI-05 cơ bản auth/deep link
- UI-07
- UI-08
- UI-09
- UI-11

## 11.8. Visual gate

Chụp/kiểm tra ít nhất:

- login desktop;
- app shell desktop 1440;
- app shell 1024;
- mobile 390.

So với reference ở mức hệ thống thiết kế, không cần pixel-perfect từng nội dung vì reference là app khác.

## 11.9. Gate PASS

Không chuyển sang task UI nếu shell chưa responsive hoặc còn avatar/visual sai định hướng.

---

# 12. PHASE P03A — SELLER + TEAM MANAGEMENT UI, MASTER DATA END-TO-END

## 12.1. Mục tiêu

Có dữ liệu thật để task dựa vào.

## 12.2. Trang liên quan

- P14–P15 Seller và phân công.
- P16–P17 Nhân sự.
- Các phần settings liên quan role/capability.

## 12.3. Luồng phải chạy end-to-end

### Seller
- list seller;
- create seller;
- edit seller;
- deactivate seller;
- assign manager/member;
- xem ai phụ trách.

### Team
- list member;
- invite;
- xem role/scope;
- đổi role nếu có quyền;
- activate/deactivate;
- assign seller scope.

## 12.4. Backend

- Không insert/update trực tiếp từ client cho thao tác đặc quyền nếu RPC/server command cần audit.
- Tất cả thay đổi role/scope có audit event.
- Không xóa cứng lịch sử member đã từng làm task.

## 12.5. Test bắt buộc

Reuse toàn bộ AUTH liên quan scope và thêm E2E:

- owner tạo seller;
- manager không đủ quyền không tạo role admin;
- member inactive biến mất khỏi lựa chọn assignee mới;
- employee không xem team ngoài phạm vi được phép;
- seller C không lộ cho manager chỉ A/B nếu spec giới hạn.

## 12.6. Gate PASS

Sau P03A, hệ thống phải có thể cấu hình team 5–10 người và seller thật mà không đụng SQL/dashboard thủ công.

---

# 13. PHASE P03B — TASK CORE: CREATE, ASSIGN, ACK, START, CHECKLIST, SUBMIT, REVIEW

## 13.1. Mục tiêu

Hoàn thành transaction/task engine trước dashboard mở rộng.

## 13.2. Scope backend

Phải có logic thật cho:

- create task;
- quick create;
- assign one responsible member;
- collaborators nếu spec có;
- reviewer;
- checklist;
- ack;
- start;
- update details;
- submit result;
- attach evidence nếu task cần;
- approve/reject/return;
- blocker;
- reassignment;
- deadline change;
- cancel/waive;
- reopen;
- audit/event history;
- outbox event foundation.

## 13.3. Quy tắc transaction

Create task phải đảm bảo các phần liên quan nằm trong transaction hợp lý:

- task;
- checklist;
- assignments;
- event;
- audit;
- outbox.

Nếu lỗi giữa chừng không để task mồ côi.

## 13.4. Idempotency/version

Bắt buộc:

- double-click create không tạo 2 task;
- retry same key/same payload trả kết quả cũ;
- same key/different payload báo lỗi;
- concurrent update dùng version/expected_version;
- không last-write-wins âm thầm.

## 13.5. Frontend phạm vi

Trang:

- P09 create/quick task, phần non-daily trước;
- P10 task detail;
- drawer/detail actions;
- submit/review dialogs.

Chưa cần calendar/daily generator ở phase này.

## 13.6. Test bắt buộc

- TASK-01 đến TASK-16
- TASK-18 đến TASK-20
- UI-05
- UI-06
- UI-12

TASK-17 có thể hoàn tất ở P03C khi Today projection tồn tại.

## 13.7. Manual E2E

Luồng 1:
1. Manager tạo task cho employee.
2. Employee nhận notification/inbox record nền nếu outbox chưa dispatch thì ít nhất event tồn tại.
3. Employee ack.
4. Start.
5. Hoàn checklist.
6. Submit.
7. Reviewer approve.
8. Task done.

Luồng 2:
1. Submit thiếu checklist required.
2. Server reject.
3. UI giữ draft.

Luồng 3:
1. Manager reassignment.
2. Người cũ không còn là assignee.
3. Lịch sử còn nguyên.

## 13.8. Gate PASS

Task engine phải đúng trước khi xây Today/dashboard. Nếu UI đẹp nhưng TASK-13/version conflict fail thì phase FAIL.

---

# 14. PHASE P03C — TODAY, MY TASKS, ALL TASKS, OVERVIEW VÀ FILTERS

## 14.1. Mục tiêu

Cho nhân viên mở app/web là biết ngay hôm nay phải làm gì.

## 14.2. Trang phải hoàn chỉnh

- P05 Today
- P06 My Tasks
- P07 All Tasks
- P08 Overview

## 14.3. Today phải phân nhóm đúng

Tối thiểu:

- Việc mới cần nhận.
- Cần xử lý hôm nay.
- Quá hạn.
- Đang chờ/bị vướng.
- Chờ duyệt nếu user là reviewer/manager.

Không gom tất cả thành một list không ưu tiên.

## 14.4. Quy tắc hiển thị

Task planned hôm nay nhưng due ngày mai vẫn xuất hiện.

Hiển thị rõ:

- task title;
- seller;
- deadline;
- priority;
- status;
- checklist progress;
- blocker nếu có;
- action ngắn phù hợp state.

## 14.5. Filter/search

- seller;
- assignee;
- status;
- due date;
- priority;
- overdue;
- reviewer;
- text search.

Filter quan trọng phải sync URL state ở web.

## 14.6. Mobile

Mobile Today phải ưu tiên:

- check-in card placeholder/integration hook nếu attendance chưa làm;
- Today task list;
- quick task actions;
- notification entry.

Không được fake chấm công thành hoạt động nếu P06 chưa làm.

## 14.7. Test bắt buộc

- TASK-17
- UI-01
- UI-05
- UI-07
- UI-10
- UI-11
- Realtime fallback behavior nền tảng nếu đã enable.

## 14.8. Gate PASS

Một employee seed phải có thể đăng nhập và biết chính xác:

- task nào cần nhận;
- task nào làm hôm nay;
- task nào quá hạn;
- task nào đang blocked/review;

mà không cần vào nhiều trang.

---

# 15. PHASE P04 — DAILY TASK, RECURRENCE ENGINE, TEMPLATE VÀ CALENDAR

## 15.1. Mục tiêu

Triển khai đúng yêu cầu checkbox Daily và lịch lặp mà không reset lịch sử.

## 15.2. UI create task

Trong P09:

- có checkbox `Daily task — Tự động lặp lại`;
- khi tick mới mở recurrence settings;
- mặc định theo working days nếu phù hợp;
- có preview ngày chạy;
- không trộn Daily checkbox với checklist item checkbox.

## 15.3. Trang recurring

P11–P12:

- list templates;
- create/edit;
- active/paused;
- targets/seller/member;
- start date;
- end date optional;
- recurrence type;
- due time;
- preview occurrences;
- version history cơ bản.

## 15.4. Calendar

P13:

- actual task instances hiển thị như task thật;
- future virtual occurrences hiển thị phân biệt, ví dụ nét đứt;
- virtual occurrence không có nút complete;
- click virtual mở template/preview, không giả là task đã tạo.

## 15.5. Generator backend

Phải chạy phía server/cron, không chạy bằng timer browser.

Yêu cầu:

- deterministic;
- idempotent;
- unique template target + work date;
- retry không duplicate;
- catch-up có metadata;
- pause/resume;
- version effective date;
- inactive assignee tạo issue/needs_assignment.

## 15.6. Leave/coverage interaction

P04 chưa có full leave engine nếu P05 chưa làm, nhưng data model phải sẵn cho:

- fixed working days;
- coverage needed;
- later approved leave suppression.

Không hardcode logic khiến P05 phải phá schema.

## 15.7. Test bắt buộc

Toàn bộ:

- DAILY-01 đến DAILY-14

Thêm:

- cron/generator rerun 2–3 lần;
- timezone Asia/Ho_Chi_Minh;
- DST không phải vấn đề VN nhưng code không dùng local browser time như authority;
- Sunday/Monday ISO weekday.

## 15.8. Manual scenario

1. Tạo daily task Seller A cho employee A.
2. Preview đúng 5 ngày làm việc.
3. Generator tạo hôm nay.
4. Hoàn thành hôm nay.
5. Chạy generator ngày kế tiếp fixture/fake clock.
6. Task mới vẫn todo.
7. Task hôm qua overdue vẫn tồn tại nếu chưa done.

## 15.9. Gate PASS

Không được sang HR nếu occurrence/history chưa chắc chắn, vì leave/attendance sẽ phụ thuộc calendar/work date.

---

# 16. PHASE P05 — SHIFT, WORK SCHEDULE, LEAVE TYPES, REQUESTS VÀ APPROVALS

## 16.1. Mục tiêu

Tạo nền HR/tổ chức thời gian trước chấm công.

## 16.2. Scope

- shift definitions;
- breaks;
- employee schedules;
- work dates;
- leave types;
- paid/unpaid treatment;
- full-day/partial leave;
- early leave;
- late arrival request nếu dùng;
- remote work request;
- attendance correction request foundation;
- approval flow;
- HR capability.

## 16.3. Trang

- P21 Requests của nhân viên.
- P22 Approvals.
- phần P23 lịch ca/schedule cần cho attendance.

## 16.4. Privacy

Manager chỉ cần availability không được mặc định xem:

- reason_private;
- evidence file;
- attendance selfie.

HR/admin đúng capability mới xem phần nhạy cảm.

## 16.5. Approved leave và task

Khi approve:

- không xóa task;
- tạo/đánh dấu need coverage nếu cần;
- suppress reminder trong khoảng approved;
- vẫn giữ history;
- daily Every Day phải có quyết định coverage/waive chứ không ép employee nghỉ làm task.

## 16.6. Test bắt buộc

Toàn bộ:

- REQ-01 đến REQ-13

Regression:

- DAILY-06
- DAILY-07
- AUTH-07

## 16.7. Manual scenario

- employee xin nghỉ nửa ngày;
- HR approve;
- calendar availability thay đổi;
- task liên quan tạo coverage issue;
- manager không HR không đọc lý do private.

## 16.8. Gate PASS

Request approval và leave treatment phải chính xác trước khi code tính công.

---

# 17. PHASE P06 — ATTENDANCE NATIVE: OFFICE WIFI + REMOTE SELFIE

## 17.1. Mục tiêu

Triển khai chấm công đúng yêu cầu đã chốt:

- tại văn phòng: phải xác thực mạng công ty;
- online: phải có quyền/lịch remote hợp lệ và selfie cùng máy tính;
- không false success.

## 17.2. Nguyên tắc kỹ thuật

### Office
Web browser không được coi là nguồn xác thực Wi-Fi strict.

Native app:

- đọc SSID/BSSID theo quyền hệ điều hành;
- server kiểm BSSID allowlist;
- server kiểm trusted public IP/gateway adapter;
- server kiểm shift/work schedule;
- challenge chống replay;
- timestamp chính thức từ server/DB.

### Remote
- phải có approved remote permission/schedule;
- camera capture trực tiếp;
- không gallery picker trong luồng chính;
- upload private storage;
- challenge/session metadata;
- không tự động nhận diện khuôn mặt ở V1 nếu spec không yêu cầu.

## 17.3. Check-in/out

- check-in tạo/open session;
- check-out đóng session;
- double request idempotent;
- hai thiết bị không tạo 2 session mở;
- chưa check-in mà check-out thì không tự bịa giờ;
- còn task chưa xong vẫn cho check-out.

## 17.4. Trang

- P18 office attendance
- P19 remote attendance
- P20 attendance status/history/diagnostic

## 17.5. Diagnostic UX

Phân biệt rõ:

- permission missing;
- SSID unavailable;
- wrong BSSID;
- wrong public IP;
- no scheduled shift;
- remote not approved;
- challenge expired;
- upload failed;
- server unavailable.

Không trả một thông báo chung “Chấm công thất bại”.

## 17.6. Test bắt buộc

Toàn bộ:

- ATT-01 đến ATT-22

Nhưng phân loại:

### Có thể tự động local/integration
- ATT-03/04/05/09/10/11/12/13/15/17/18/19/20/21/22 phần server.

### Bắt buộc thiết bị thật/external verify
- ATT-01/02/07/08/14/16 tùy platform.

Nếu không có thiết bị thật, ghi `BLOCKED_EXTERNAL_SETUP`, không giả PASS.

## 17.7. Security review

- service_role không có trong app;
- signed upload/finalize flow;
- file path không tin client;
- evidence private;
- no cross-user file access;
- client IP lấy từ trusted server adapter.

## 17.8. Gate

Nếu không có thiết bị thật, có thể kết thúc `BLOCKED_EXTERNAL_SETUP` nếu server/integration tests pass và checklist test thiết bị rõ ràng. Khi có thiết bị, phải quay lại đổi phase thành PASS.

---

# 18. PHASE P07 — TIMESHEET, CÔNG THÁNG, RECONCILIATION, CLOSE/REOPEN

## 18.1. Mục tiêu

Tính công chính xác từ dữ liệu lịch, attendance và approved absence.

## 18.2. Không được nhầm

- công thực làm != nghỉ hưởng lương;
- online != nghỉ;
- về sớm 2 giờ != mất cả ngày;
- một ca != mặc định 1 công;
- tháng != mặc định 26 công;
- thiếu checkout != tự tính 0 công;
- overtime không tự coi là payable OT nếu chưa có policy.

## 18.3. Engine

Thứ tự xử lý đề xuất:

1. Load historical schedule snapshot.
2. Xác định scheduled working intervals trừ break.
3. Load attendance raw events/sessions.
4. Apply corrections append-only.
5. Intersect worked intervals với schedule.
6. Apply paid/unpaid approved absences.
7. Detect overlaps/exceptions.
8. Sum seconds/minutes trước khi convert work units.
9. Build day summary.
10. Build month summary.

## 18.4. Trang

- P23 schedule/shift view hoàn chỉnh.
- P24 monthly timesheet.
- P25 reconciliation/close/export.

## 18.5. Close/reopen

Close chỉ khi:

- không còn blocking exception;
- snapshot lưu immutable;
- user có quyền.

Reopen:

- phải có lý do;
- audit;
- tạo revision mới;
- không sửa snapshot cũ âm thầm.

## 18.6. Test bắt buộc

Toàn bộ:

- TIME-01 đến TIME-14

Regression:

- REQ-02/03/07/08/12
- ATT-12/17/19

## 18.7. Manual sample calculation

Ca 09:00–18:00, break 12–13:

- scheduled = 480 min.
- check-in 09:00, checkout 16:00.
- approved unpaid 16:00–18:00.
- actual worked = 360 min = 0.75 standard day if standard=480.
- unpaid = 120 min = 0.25.

Bảng phải hiện hai thành phần, không double subtract.

## 18.8. Gate PASS

Không chuyển automation/report nếu công tháng còn sai số hoặc snapshot close chưa immutable.

---

# 19. PHASE P08 — OUTBOX, NOTIFICATION INBOX, PUSH VÀ REMINDER ENGINE

## 19.1. Mục tiêu

Tách event nghiệp vụ khỏi delivery để reminder/report không phụ thuộc browser mở.

## 19.2. Architecture

- transaction tạo domain event + outbox record;
- worker claim outbox với lease;
- dispatch inbox/push;
- receipt/status;
- retry;
- dedupe;
- dead-letter/manual inspect nếu vượt retry.

Không claim “exactly once push”. Mục tiêu là idempotent/deduplicated business delivery.

## 19.3. Trang

- P28 notification inbox.

## 19.4. Reminder rules

Theo đặc tả:

- assigned;
- unack trong working time;
- sắp đến hạn;
- overdue;
- blocked;
- reviewer reminder;
- approved leave suppression;
- personalized stricter reminder có rule minh bạch;
- snooze không đổi deadline;
- daily push limit/digest.

## 19.5. Test bắt buộc

Toàn bộ:

- NOTIFY-01 đến NOTIFY-11

Security:

- SEC-13
- token lifecycle/revocation.

## 19.6. Manual scenario

- Assign task khi employee offline.
- Đóng web/mobile.
- Worker dispatch.
- Mở lại app.
- Inbox vẫn có notification.
- Đọc notification không tự ack task.

## 19.7. Gate PASS

Nếu notification chỉ hoạt động khi tab web mở thì FAIL.

---

# 20. PHASE P09 — REPORT 18:00 SNAPSHOT, MANAGER SCOPE VÀ DELIVERY

## 20.1. Mục tiêu

Tạo bản chốt công việc tự động mỗi ngày lúc 18:00 giờ Việt Nam, không phụ thuộc client.

## 20.2. Scheduler

- server scheduler/Supabase Cron;
- timezone xử lý rõ `Asia/Ho_Chi_Minh`;
- không timer browser;
- run_id/version;
- idempotent retry.

## 20.3. Snapshot as-of cutoff

Report phải phản ánh trạng thái **tại 18:00**, không phải trạng thái khi job retry lúc 18:20.

Phải lưu facts/snapshot đủ để:

- task done 18:10 không sửa report 18:00;
- report reopen/revision có version;
- manager scope tại thời điểm phù hợp;
- audit.

## 20.4. Nội dung report

Từng nhân sự:

- due cohort;
- done;
- in review;
- open;
- blocked subset;
- overdue theo cutoff;
- kết quả nổi bật;
- việc cần hỗ trợ;
- attendance trạng thái tạm tính nếu còn trong ca;
- không tự check-out lúc 18:00.

Manager chỉ thấy seller/team scope được cấp.

## 20.5. AI summary optional

AI chỉ diễn giải facts đã tính.

Nếu AI timeout:

- report facts/table vẫn ready;
- không block report;
- không để AI tự tính totals.

## 20.6. Trang

- P26 report list/summary.
- P27 report detail theo người/seller.

## 20.7. Test bắt buộc

Toàn bộ:

- REPORT-01 đến REPORT-14

Regression:

- AUTH-12
- NOTIFY-08
- TIME snapshot liên quan.

## 20.8. Gate PASS

Phải chứng minh report được tạo khi tất cả client đóng.

Cron retry không duplicate run/delivery logic.

---

# 21. PHASE P10 — FILE SECURITY, PRIVACY, RETENTION, EXPORT, AUDIT, BACKUP

## 21.1. Mục tiêu

Hardening dữ liệu nhạy cảm trước khi gọi hệ thống sẵn sàng dùng nội bộ rộng.

## 21.2. Storage

- private buckets;
- signed URL ngắn hạn;
- authorized gateway/server command;
- file metadata DB;
- MIME/size checks;
- orphan cleanup;
- attendance selfie privacy.

## 21.3. Export

- task/timesheet report export theo scope;
- chống CSV formula injection;
- không leak totals ngoài quyền;
- audit export.

## 21.4. Retention

- policy cho attendance selfie;
- policy cho task evidence;
- legal hold nếu spec có;
- cleanup worker;
- không xóa file đang hold.

## 21.5. Audit

Audit các thao tác nhạy cảm:

- role/scope;
- leave approval;
- attendance evidence access;
- timesheet close/reopen;
- export;
- report revision;
- task deadline/reassignment nếu spec yêu cầu.

Không log raw selfie/private reason vào application log.

## 21.6. Backup/restore

- DB backup plan;
- Storage backup/restore plan;
- staging restore drill;
- verify links/data after restore.

## 21.7. Test bắt buộc

Toàn bộ:

- SEC-01 đến SEC-15

## 21.8. Gate PASS

P10 không PASS nếu mới backup DB nhưng bỏ Storage hoặc restore chưa từng thử trên staging/local equivalent.

---

# 22. PHASE P11 — FULL REGRESSION, UAT, PERFORMANCE CƠ BẢN VÀ DEPLOYMENT READINESS

## 22.1. Mục tiêu

Không code thêm feature mới. Phase này chỉ:

- sửa lỗi;
- regression;
- UAT;
- config production;
- deployment checklist;
- monitoring;
- documentation.

## 22.2. Full test suite

Chạy toàn bộ test IDs trong mục 41 của đặc tả:

- AUTH-01..12
- TASK-01..20
- DAILY-01..14
- ATT-01..22
- REQ-01..13
- TIME-01..14
- REPORT-01..14
- NOTIFY-01..11
- UI-01..12
- SEC-01..15

Không được chọn subset rồi gọi là regression hoàn chỉnh.

## 22.3. Cross-feature UAT scenarios

### UAT-01 — Ngày làm việc bình thường
1. Employee office check-in.
2. Daily tasks xuất hiện.
3. Employee ack/start/complete.
4. Reviewer duyệt.
5. Employee check-out.
6. 18:00 report phản ánh đúng.
7. Timesheet đúng.

### UAT-02 — Nghỉ nửa ngày
1. Employee gửi yêu cầu.
2. HR approve.
3. Task cần coverage được highlight.
4. Reminder bị suppress trong khoảng nghỉ.
5. Attendance/timesheet không double count.
6. Report không gán miss sai.

### UAT-03 — Làm online
1. Remote request approved.
2. Selfie check-in.
3. Daily tasks vẫn xuất hiện.
4. Check-out.
5. Công online tính hợp lệ.

### UAT-04 — Task bị miss
1. Task assigned.
2. Không ack trong working time.
3. Reminder đúng rule.
4. Quá hạn.
5. 18:00 report ghi open/overdue đúng.
6. Không gửi spam ngoài rule.

### UAT-05 — Manager scope
1. Manager A/B xem dashboard/report.
2. Không lộ Seller C.
3. Không lộ HR evidence.
4. Export cũng không lộ.

### UAT-06 — Multi-organization isolation
1. User A thay URL/id bằng B.
2. REST/RPC/file/report đều deny.

### UAT-07 — Retry/network instability
1. Double-click create task.
2. Refresh giữa submit.
3. Worker retry.
4. Cron retry.
5. Không duplicate business records.

## 22.4. Performance baseline

Không cần tối ưu cực đoan cho team 5–10 người, nhưng phải tránh thiết kế tệ.

Kiểm tra:

- Today query không N+1 rõ rệt;
- task list pagination/filter;
- indexes phục vụ due/status/seller/assignee/work_date;
- report generation không scan toàn DB vô điều kiện;
- notification worker batch;
- signed file access không tải file thừa;
- web route quan trọng có loading hợp lý.

## 22.5. Deployment checklist

Phải có:

- Supabase production project config;
- migrations applied;
- auth redirect URLs;
- RLS verified;
- Storage buckets/policies;
- Cron jobs;
- Edge Function secrets;
- push credentials;
- trusted office network config;
- retention config;
- monitoring/logging;
- owner bootstrap;
- seed demo không chạy production;
- backup confirmed;
- restore procedure documented.

## 22.6. Gate final

Project chỉ được đánh dấu `READY_FOR_INTERNAL_PRODUCTION` khi:

- full suite PASS;
- external device tests PASS hoặc còn blocker được chủ dự án chấp nhận rõ;
- no critical/high security issue;
- no fake/demo data production;
- no `service_role` leak;
- deployment checklist complete;
- UAT owner/admin/employee flows pass.

---

# 23. BẢNG TÓM TẮT PHASE VÀ GATE

| Phase | Trọng tâm | Test gate chính | Không được sang phase sau nếu |
|---|---|---|---|
| P00 | Repo/tooling | build/lint/typecheck/local Supabase | repo không dựng được |
| P01A | Tenant/Auth core | AUTH core + SEC schema | cross-org/RLS fail |
| P01B | Invite/role/seller scope | AUTH full | scope leak |
| P02 | Design system/shell | UI shell | responsive/visual foundation sai |
| P03A | Team/Seller UI | permission E2E | master data chưa quản lý bằng UI |
| P03B | Task engine | TASK core | transaction/idempotency/version fail |
| P03C | Today/lists | TASK-17 + UI | Today không phản ánh đúng công việc |
| P04 | Daily recurrence | DAILY-01..14 | duplicate/reset history |
| P05 | HR requests | REQ-01..13 | leave treatment/privacy sai |
| P06 | Attendance | ATT-01..22 | false success/network validation sai |
| P07 | Timesheet | TIME-01..14 | số công sai/snapshot mutable |
| P08 | Notification | NOTIFY-01..11 | phụ thuộc client mở |
| P09 | Report 18:00 | REPORT-01..14 | cutoff/scope/retry sai |
| P10 | Security/ops | SEC-01..15 | file/export/backup leak |
| P11 | Full regression | toàn bộ | critical failure/UAT fail |

---

# 24. CHECKLIST CHUẨN ĐỂ AI TỰ NGHIỆM THU MỖI PHASE

AI copy checklist này vào report phase và tick trung thực:

```md
## Gate checklist

### Scope
- [ ] Chỉ code phạm vi của phase hiện tại
- [ ] Không tự triển khai phase sau
- [ ] Không bỏ requirement khó

### Database
- [ ] Migrations tồn tại và clean reset được
- [ ] Constraints/indexes hợp lý
- [ ] RLS đã bật cho private tables
- [ ] Grants/function permissions đúng
- [ ] Generated types cập nhật

### Backend
- [ ] Authorization server-side
- [ ] Transaction đúng
- [ ] Idempotency/retry đúng nếu cần
- [ ] Audit/outbox đúng nếu cần
- [ ] Không false success

### Frontend/mobile
- [ ] Nối backend thật
- [ ] Loading state
- [ ] Empty state
- [ ] Error state
- [ ] Responsive
- [ ] Permission UX đúng nhưng không thay server auth
- [ ] Không avatar nếu không phải evidence selfie

### Tests
- [ ] lint PASS
- [ ] typecheck PASS
- [ ] unit PASS
- [ ] DB/RLS PASS nếu áp dụng
- [ ] integration PASS nếu áp dụng
- [ ] E2E PASS nếu áp dụng
- [ ] manual happy path PASS
- [ ] manual negative permission path PASS
- [ ] regression phần phụ thuộc PASS

### Documentation
- [ ] IMPLEMENTATION_STATUS updated
- [ ] TEST_REPORT updated
- [ ] DECISIONS updated nếu có
- [ ] external blocker documented nếu có

### Gate
FINAL_PHASE_RESULT: PASS | FAIL | BLOCKED_EXTERNAL_SETUP
```

---

# 25. CÁCH AI XỬ LÝ KHI TEST FAIL

Khi có test fail:

1. Không đổi expected result để test pass nếu expected bám spec.
2. Không skip test.
3. Không comment test.
4. Không gắn `.only` rồi bỏ các test khác.
5. Không tắt RLS để unblock.
6. Không dùng service role trong client để vượt permission.
7. Không đổi task/attendance/report semantics để code dễ hơn.
8. Phân loại nguyên nhân:
   - logic bug;
   - data model bug;
   - permission bug;
   - race/idempotency;
   - timezone;
   - UI integration;
   - external setup.
9. Sửa nguyên nhân gốc.
10. Chạy lại test fail.
11. Chạy regression nhóm liên quan.
12. Chỉ khi tất cả pass mới đổi phase thành PASS.

---

# 26. CÁCH AI XỬ LÝ REQUIREMENT THAY ĐỔI GIỮA DỰ ÁN

Nếu chủ dự án bổ sung yêu cầu:

1. Không âm thầm code ngay vào nơi gần nhất.
2. Ghi `ADR/CHANGE` vào `docs/DECISIONS.md`:
   - yêu cầu mới;
   - tác động database;
   - tác động backend;
   - tác động UI;
   - phase nào phải reopen;
   - regression tests cần chạy lại.
3. Nếu yêu cầu ảnh hưởng phase đã PASS, đổi phase liên quan thành `IN_REVIEW_CHANGE` hoặc ghi rõ cần regression.
4. Tạo migration mới, không sửa lịch sử production migration.
5. Sau thay đổi, chạy lại test suite phụ thuộc.

Ví dụ:

Nếu sau này thêm “task weekly”:

- tác động P04 recurrence engine;
- cần test recurrence weekly;
- cần regression DAILY;
- không chỉ thêm một dropdown UI rồi xong.

---

# 27. QUY TẮC STOP/RESUME ĐỂ AI KHÁC CÓ THỂ TIẾP QUẢN

Mỗi phase kết thúc phải để repository ở trạng thái AI khác đọc được mà không cần lịch sử chat.

## 27.1. Cuối phiên AI phải ghi

Trong `IMPLEMENTATION_STATUS.md`:

- phase vừa làm;
- trạng thái;
- commit/hash;
- files chính;
- schema migrations;
- test results;
- blockers;
- next allowed phase.

## 27.2. Khi AI mới vào project

AI mới phải:

1. đọc spec;
2. đọc plan;
3. đọc status;
4. đọc test report;
5. kiểm git diff/current branch;
6. xác minh phase trước thật sự pass bằng lệnh tối thiểu;
7. chỉ làm `NEXT_ALLOWED_PHASE`.

Không hỏi người dùng kể lại toàn bộ cuộc trò chuyện.

---

# 28. TEMPLATE BÁO CÁO CUỐI MỖI PHASE

AI phải trả về đúng dạng dễ review:

```md
# Phase PXX Result

Status: PASS / FAIL / BLOCKED_EXTERNAL_SETUP
Commit: <hash>

## 1. Đã triển khai
- ...

## 2. Database/migrations
- ...

## 3. Backend/RPC
- ...

## 4. Frontend/mobile
- ...

## 5. Tests đã chạy
| Command/Test IDs | Result |
|---|---|
| ... | PASS |

## 6. Manual validation
- ...

## 7. Lỗi/blocker còn lại
- None / ...

## 8. Tài liệu đã cập nhật
- IMPLEMENTATION_STATUS.md
- TEST_REPORT.md
- DECISIONS.md nếu có

## 9. Next allowed phase
PXX

STOP: Do not implement the next phase in this session.
```

---

# 29. PROMPT KHỞI ĐỘNG PROJECT LẦN ĐẦU

Chủ dự án có thể gửi prompt này cùng `DAC_TA_OPSDESK_APP_WEB_SUPABASE.md`, file plan và ảnh UI:

```text
Đọc kỹ ba nguồn:
1) DAC_TA_OPSDESK_APP_WEB_SUPABASE.md
2) PLAN_XAY_DUNG_OPSDESK_THEO_PHASE.md
3) UI_REFERENCE.png

Đặc tả quyết định sản phẩm phải làm gì. Plan quyết định thứ tự triển khai.
Database bắt buộc dùng Supabase.

Không code toàn bộ project trong một lần.
Mỗi phiên chỉ được làm đúng MỘT phase theo PLAN.
Bắt đầu từ phase đầu tiên chưa PASS trong docs/IMPLEMENTATION_STATUS.md.
Nếu file trạng thái chưa tồn tại thì bắt đầu P00.

Trước khi code, hãy báo:
- phase đang làm;
- mục tiêu phase;
- file/module/migration dự kiến thay đổi;
- tests sẽ chạy ở cuối phase.

Sau đó code thật end-to-end trong phạm vi phase đó.
Không dùng mock/localStorage thay backend production.
Không tắt RLS.
Không đưa service_role vào client.
Không giả PASS cho Wi-Fi/device/external setup.

Cuối phase:
- chạy toàn bộ gate test;
- cập nhật IMPLEMENTATION_STATUS.md;
- cập nhật TEST_REPORT.md;
- ghi PASS/FAIL/BLOCKED trung thực;
- DỪNG LẠI.

Dù phase PASS, không được code phase tiếp theo trong cùng phiên.
```

---

# 30. PROMPT TIẾP TỤC Ở PHIÊN SAU

```text
Đọc lại:
- DAC_TA_OPSDESK_APP_WEB_SUPABASE.md
- PLAN_XAY_DUNG_OPSDESK_THEO_PHASE.md
- docs/IMPLEMENTATION_STATUS.md
- docs/TEST_REPORT.md
- docs/DECISIONS.md

Kiểm tra repository hiện tại và xác minh phase trước đúng là PASS.
Sau đó chỉ triển khai NEXT_ALLOWED_PHASE được ghi trong IMPLEMENTATION_STATUS.md.

Không code phase kế tiếp sau phase này trong cùng phiên.
Kết thúc bằng gate test, cập nhật docs và dừng.
```

---

# 31. PROMPT REVIEW MỘT PHASE VỪA LÀM XONG

Nếu chủ dự án muốn một AI khác review trước khi cho đi tiếp:

```text
Bạn đang ở vai trò reviewer, không phải feature developer.

Đọc DAC_TA_OPSDESK_APP_WEB_SUPABASE.md và PLAN_XAY_DUNG_OPSDESK_THEO_PHASE.md.
Xem phase hiện tại trong IMPLEMENTATION_STATUS.md.

Hãy kiểm tra source thực tế, migration, RLS, RPC/API, frontend/mobile và tests của phase đó.
Không tin tuyên bố PASS nếu không có bằng chứng.

Thực hiện:
1. chạy gate commands;
2. đối chiếu các test ID bắt buộc;
3. thử ít nhất một happy path;
4. thử ít nhất một permission/negative path;
5. kiểm tra không có code/mock của phase sau che lỗi phase hiện tại.

Trả kết luận:
- PASS_REVIEWED nếu đủ;
- FAIL_REVIEW với danh sách lỗi cụ thể nếu chưa đủ;
- BLOCKED_EXTERNAL_SETUP nếu chỉ còn phụ thuộc bên ngoài.

Không triển khai phase tiếp theo.
```

---

# 32. PROMPT FIX KHI PHASE FAIL

```text
Phase hiện tại đang FAIL.
Không được triển khai phase khác.

Đọc TEST_REPORT.md và các failure của phase hiện tại.
Ưu tiên sửa nguyên nhân gốc theo thứ tự:
1. security/RLS/cross-tenant;
2. data correctness;
3. transaction/idempotency/race;
4. backend authorization;
5. UI integration;
6. visual polish.

Sau mỗi nhóm sửa, chạy lại test fail và regression liên quan.
Chỉ khi toàn bộ gate đạt mới đổi phase thành PASS.
Sau đó cập nhật docs và dừng.
```

---

# 33. DEFINITION OF DONE CẤP PROJECT

Project **không được gọi là hoàn chỉnh** chỉ vì nhìn thấy đủ màn hình.

Toàn bộ project chỉ đạt Done khi:

- [ ] P00 PASS
- [ ] P01A PASS
- [ ] P01B PASS
- [ ] P02 PASS
- [ ] P03A PASS
- [ ] P03B PASS
- [ ] P03C PASS
- [ ] P04 PASS
- [ ] P05 PASS
- [ ] P06 PASS hoặc external verification đã được thực hiện và chuyển PASS trước release thật
- [ ] P07 PASS
- [ ] P08 PASS
- [ ] P09 PASS
- [ ] P10 PASS
- [ ] P11 PASS
- [ ] Full AUTH suite PASS
- [ ] Full TASK suite PASS
- [ ] Full DAILY suite PASS
- [ ] Full ATT suite PASS
- [ ] Full REQ suite PASS
- [ ] Full TIME suite PASS
- [ ] Full REPORT suite PASS
- [ ] Full NOTIFY suite PASS
- [ ] Full UI suite PASS
- [ ] Full SEC suite PASS
- [ ] UAT end-to-end PASS
- [ ] Backup/restore verified
- [ ] Production secrets/config documented
- [ ] No demo/mock production logic
- [ ] No secret/service_role exposed
- [ ] No known critical/high security defect

---

# 34. NGUYÊN TẮC CUỐI CÙNG CHO AI

1. **Làm ít hơn nhưng hoàn chỉnh từng phase tốt hơn làm nhiều nhưng nửa vời.**
2. **Database và permission đúng quan trọng hơn giao diện đẹp.**
3. **Một nút chưa nối backend thì được coi là chưa làm.**
4. **Một test chưa chạy thì không được coi là PASS.**
5. **Một mock native module không chứng minh Wi-Fi thật hoạt động.**
6. **Một cron chạy trong browser không phải automation server.**
7. **Một report tính từ state hiện tại không phải snapshot 18:00.**
8. **Một task recurring reset trạng thái cũ là sai thiết kế.**
9. **Một đơn nghỉ được duyệt không đồng nghĩa mọi loại nghỉ đều mất công.**
10. **Một manager quản lý seller không tự động có quyền xem dữ liệu HR nhạy cảm.**
11. **Không được bỏ qua scope/race/timezone vì team hiện chỉ 5–10 người.**
12. **Cuối mỗi phase phải dừng.**

---

# 35. CHECKPOINT KHỞI ĐẦU DỰ KIẾN

Nếu đây là repository mới, thứ tự làm việc lý tưởng là:

```text
Session 01 -> P00  -> STOP
Session 02 -> P01A -> STOP
Session 03 -> P01B -> STOP
Session 04 -> P02  -> STOP
Session 05 -> P03A -> STOP
Session 06 -> P03B -> STOP
Session 07 -> P03C -> STOP
Session 08 -> P04  -> STOP
Session 09 -> P05  -> STOP
Session 10 -> P06  -> STOP
Session 11 -> P07  -> STOP
Session 12 -> P08  -> STOP
Session 13 -> P09  -> STOP
Session 14 -> P10  -> STOP
Session 15 -> P11  -> STOP
```

Nếu một phase FAIL, phiên tiếp theo vẫn ở phase đó cho tới khi PASS.

Không được “để lỗi đó sau sửa” nếu lỗi nằm trong gate của phase.

---

**Kết luận:**  
File này là quy trình thi công. AI phải dùng nó như một pipeline có cổng kiểm tra, không phải checklist tham khảo. Mục tiêu không phải viết thật nhiều code trong một lần, mà là đưa từng lớp của OpsDesk từ `NOT_STARTED` → `IN_PROGRESS` → `PASS` với bằng chứng có thể kiểm tra lại.
