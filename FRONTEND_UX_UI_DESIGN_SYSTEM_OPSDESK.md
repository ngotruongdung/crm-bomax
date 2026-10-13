# OPSDESK — FRONT-END, UX/UI & DESIGN SYSTEM SPECIFICATION

**Phiên bản:** 1.0 — 04/10/2026  
**Mục đích:** tài liệu chuyên biệt cho AI/front-end developer triển khai giao diện OpsDesk chính xác, đồng nhất và có thể kiểm thử.  
**Tài liệu liên quan bắt buộc:**
1. `DAC_TA_OPSDESK_APP_WEB_SUPABASE.md` — nghiệp vụ, quyền, backend, Supabase và route.
2. `PLAN_XAY_DUNG_OPSDESK_THEO_PHASE.md` — thứ tự code và gate kiểm thử.
3. `UI_REFERENCE.png` — ảnh tham chiếu thẩm mỹ.
4. File này — nguồn chi tiết nhất về **front-end, UX/UI, spacing, typography, component, responsive và visual acceptance**.

> Nếu file này mâu thuẫn với đặc tả nghiệp vụ thì đặc tả nghiệp vụ quyết định **hệ thống phải làm gì**; file này quyết định **giao diện phải thể hiện việc đó như thế nào**.  
> Không được tự đổi UX chỉ vì thư viện UI mặc định có component khác. Nếu dùng thư viện, phải theme/override để đạt đúng design system dưới đây.

---

# 0. CHỈ THỊ BẮT BUỘC CHO AI FRONT-END

AI code giao diện phải tuân thủ các nguyên tắc sau:

1. **Không code toàn bộ frontend một lần.** Chỉ triển khai UI theo phase trong `PLAN_XAY_DUNG_OPSDESK_THEO_PHASE.md`.
2. Trước mỗi phase phải đọc phần route/màn hình tương ứng trong file này và đặc tả chính.
3. Không tạo dashboard đẹp nhưng dùng số giả, button không chạy, form không nối API thật.
4. Không dùng màu, spacing, radius, shadow tùy ý trong từng page. Tất cả phải đi qua token.
5. Không dùng avatar, initials circle hoặc ảnh đại diện cho nhân sự. Chỉ dùng `PersonLabel` dạng chữ.
6. Không dùng emoji làm icon UI.
7. Không dùng gradient đậm, glassmorphism, sidebar tối, card màu sặc sỡ, biểu đồ trang trí không có giá trị vận hành.
8. Không dùng quá nhiều pill. Badge chỉ dùng cho status/metadata cần nhận diện nhanh.
9. Không dùng checkbox đầu dòng task như nút hoàn thành task. Checkbox đầu dòng chỉ để chọn hàng loạt.
10. Một trạng thái loading/empty/error/permission/disabled phải được thiết kế thật; không bỏ trống.
11. Desktop phải tối ưu cho quản lý thao tác nhiều dữ liệu. Mobile phải tối ưu cho nhân viên xem việc hôm nay, cập nhật task, chấm công.
12. Frontend không được tự suy luận quyền, công tháng hoặc trạng thái nghiệp vụ quan trọng nếu backend đã cung cấp projection.
13. Mọi button destructive phải có wording rõ hậu quả, không dùng nút chung chung như `OK`.
14. Mọi giá trị thời gian hiển thị theo `vi-VN`, định dạng `dd/MM/yyyy`, giờ `HH:mm`.
15. Tất cả màn hình phải dùng tiếng Việt ở V1.
16. Không đưa secret Supabase, service-role key hoặc dữ liệu bằng chứng chấm công vào client bundle.
17. Khi một component mới xuất hiện từ 2 nơi trở lên, phải đưa về shared component thay vì copy/paste.
18. Visual acceptance chỉ PASS nếu đạt responsive, keyboard/focus, loading/error/empty và đúng token; không chỉ nhìn giống screenshot ở một kích thước.

---

# 1. NGÔN NGỮ THỊ GIÁC TỪ `UI_REFERENCE.png`

Ảnh tham chiếu mang cảm giác một ứng dụng productivity cao cấp, rất sáng, sạch và có nhiều khoảng thở. OpsDesk phải lấy **ngôn ngữ thị giác**, không sao chép nội dung của ảnh.

## 1.1. Những gì phải giữ

- Canvas bên ngoài xám lạnh rất nhạt.
- App surface trắng, bo lớn ở desktop.
- Sidebar màu trắng-xám nhạt hơn canvas, ít tương phản.
- Active sidebar là một block trắng bo nhẹ, không tô màu thương hiệu đậm.
- Main content gần như trắng hoàn toàn.
- Phân cấp bằng **spacing + typography + border**, không bằng nhiều màu.
- Divider rất mảnh.
- Data table sạch, header xám rất nhạt, row cao vừa.
- Checkbox vuông bo nhẹ; khi checked dùng nền gần đen và tick trắng.
- Icon nhỏ, nét mảnh, cùng family.
- Card chỉ có shadow cực nhẹ khi thực sự cần nâng lớp.
- Text chính gần đen, metadata xám.
- Accent tím-xanh chỉ là điểm nhấn nhỏ: focus, link, daily indicator, một số active states.

## 1.2. Những gì không được sao chép

- Không dùng tên `Synapse`.
- Không dùng folder 3D màu xanh như motif chung.
- Không dùng avatar trong table.
- Không giữ khoảng trống mockup 90px quanh ứng dụng trên laptop thật.
- Không biến mọi module thành folder/file manager.
- Không cố tạo hiệu ứng 3D hoặc glossy.

## 1.3. Từ khóa thiết kế

`quiet` · `structured` · `light` · `professional` · `operational` · `dense enough for work` · `not enterprise-bloated`.

Mục tiêu cảm giác: người dùng mở app lên phải thấy **rõ hôm nay cần làm gì**, không bị choáng bởi dashboard nhiều biểu đồ.

---

# 2. FRONT-END ARCHITECTURE VÀ DESIGN TOKEN LAYER

## 2.1. Nguồn token duy nhất

Repo mới dùng:

```text
packages/design-tokens/
  src/
    colors.ts
    spacing.ts
    typography.ts
    radii.ts
    shadows.ts
    motion.ts
    breakpoints.ts
    zIndex.ts
    index.ts
```

Web map token sang CSS variables. Mobile import token TS trực tiếp. Không tạo hai bộ giá trị khác nhau.

## 2.2. CSS variables chuẩn cho web

```css
:root {
  /* Canvas & surfaces */
  --canvas: #edeef1;
  --sidebar: #f7f7fa;
  --surface: #ffffff;
  --surface-muted: #f8f8fa;
  --surface-subtle: #fbfbfc;
  --surface-hover: #f3f4f6;
  --surface-pressed: #eceef2;

  /* Borders */
  --border: #e9eaee;
  --border-strong: #d8dae1;
  --border-input: #e1e3e8;

  /* Text */
  --text-primary: #18191c;
  --text-secondary: #656a76;
  --text-muted: #777d89;
  --text-placeholder: #9aa0aa;
  --text-disabled: #aeb3bd;

  /* Brand / actions */
  --primary: #1c1d21;
  --primary-hover: #303238;
  --primary-pressed: #111215;
  --primary-foreground: #ffffff;
  --accent: #5b5ce2;
  --accent-hover: #4d4ed3;
  --accent-soft: #efefff;
  --focus-ring: #7778ed;

  /* Semantic */
  --success: #23764b;
  --success-soft: #edf7f0;
  --warning: #8a5b12;
  --warning-soft: #fff7e7;
  --danger: #b93838;
  --danger-soft: #fff0f0;
  --info: #365f9d;
  --info-soft: #edf4ff;

  /* Overlay & skeleton */
  --overlay: rgba(24, 25, 28, 0.28);
  --skeleton: #eff0f3;
  --skeleton-highlight: #f7f7f9;

  /* Radius */
  --radius-xs: 4px;
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-lg: 14px;
  --radius-xl: 20px;
  --radius-full: 999px;

  /* Shadow */
  --shadow-xs: 0 1px 2px rgba(22, 25, 40, 0.04);
  --shadow-card: 0 4px 18px rgba(22, 25, 40, 0.04);
  --shadow-overlay: 0 16px 48px rgba(22, 25, 40, 0.12);

  /* Motion */
  --duration-fast: 120ms;
  --duration-normal: 180ms;
  --duration-slow: 240ms;
  --ease-standard: cubic-bezier(0.2, 0, 0, 1);
}
```

### Quy tắc màu

- 80–90% giao diện chỉ dùng neutral.
- `accent` không được dùng làm nền lớn của sidebar/page.
- `danger` chỉ dùng cho lỗi/destructive/overdue thật.
- `success` chỉ dùng khi hoàn tất/đã duyệt/đã chấm hợp lệ.
- Không truyền trạng thái chỉ bằng màu; luôn có text/icon.
- Không hardcode `#...` trong page/component; nếu cần màu mới, thêm semantic token có lý do.

---

# 3. SPACING SYSTEM — KHOẢNG CÁCH CHUẨN

OpsDesk dùng lưới cơ sở **4px**. Chỉ dùng các giá trị dưới đây trừ trường hợp icon optical alignment.

| Token | px | Dùng cho |
|---|---:|---|
| `space-0.5` | 2 | optical micro gap hiếm dùng |
| `space-1` | 4 | label → help/error, icon nội bộ nhỏ |
| `space-1.5` | 6 | label → input |
| `space-2` | 8 | icon-text gap, compact controls |
| `space-2.5` | 10 | input horizontal compact |
| `space-3` | 12 | row internal gap, button padding nhỏ |
| `space-4` | 16 | field-to-field nhỏ, card mobile padding |
| `space-5` | 20 | card desktop padding, toolbar gap |
| `space-6` | 24 | section vertical gap chuẩn |
| `space-7` | 28 | page padding desktop |
| `space-8` | 32 | nhóm lớn |
| `space-10` | 40 | block lớn |
| `space-12` | 48 | hero/login separation |
| `space-14` | 56 | rare layout gap |
| `space-16` | 64 | header/nav height reference |

## 3.1. Khoảng cách mặc định theo cấu trúc

```text
Page edge -> content:        28px desktop / 20px tablet / 16px mobile
PageHeader -> first block:   24px
Section -> Section:          32px
Section title -> content:    12px
Card padding:                20px desktop / 16px mobile
Card item gap:               16px
Form field -> field:         16px
Label -> control:             6px
Control -> help text:         4px
Help text -> error:           4px (nếu cùng xuất hiện)
Button icon -> text:          8px
Table cell x padding:        16px
Table row vertical padding:  12px, min-height theo row token
Toolbar control gap:          8px hoặc 12px
Modal title -> description:   8px
Modal body -> footer:        24px
```

## 3.2. Cấm dùng spacing tùy hứng

Sai:

```tsx
<div className="mt-[19px] px-[23px] gap-[13px]">
```

Đúng:

```tsx
<div className="mt-5 px-6 gap-3">
```

Nếu thiết kế thực sự cần một giá trị mới, thêm token và dùng thống nhất; không tạo một magic number chỉ cho một page.

---

# 4. TYPOGRAPHY — FONT, SIZE, WEIGHT, LINE HEIGHT

## 4.1. Font family

Ưu tiên:

```css
font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
```

- Phải hỗ trợ tiếng Việt đầy đủ.
- Nếu `Inter` chưa bundle/local trong project, dùng system font trước; không để app phụ thuộc CDN font bên thứ ba.
- Không dùng nhiều hơn một font UI ở V1.
- Không dùng font display trang trí.

## 4.2. Font weights được phép

- `400` Regular: body, metadata.
- `500` Medium: label, table header, button, navigation.
- `600` Semibold: page title, section title, important values.
- Không dùng `700` tràn lan; chỉ cho trường hợp thương hiệu/logo hoặc cảnh báo đặc biệt nếu thật sự cần.

## 4.3. Type scale

| Style | Size | Weight | Line-height | Letter spacing | Dùng cho |
|---|---:|---:|---:|---:|---|
| `display-sm` | 30 | 600 | 38 | -0.02em | Auth hero hiếm dùng |
| `page-title` | 24 | 600 | 32 | -0.015em | Tiêu đề trang |
| `panel-title` | 20 | 600 | 28 | -0.01em | Drawer/modal lớn |
| `card-title` | 18 | 600 | 26 | -0.01em | Card quan trọng |
| `section-title` | 16 | 600 | 24 | 0 | Tên section |
| `body-lg` | 15 | 400 | 23 | 0 | Mobile body |
| `body` | 14 | 400 | 22 | 0 | Desktop body |
| `body-medium` | 14 | 500 | 22 | 0 | Row title/label nổi bật |
| `label` | 13 | 500 | 20 | 0 | Form label, compact nav |
| `meta` | 12 | 400 | 18 | 0 | Metadata |
| `meta-medium` | 12 | 500 | 18 | Table header/status small |
| `caption` | 11 | 500 | 16 | Group label/sidebar section |
| `kpi` | 26 | 600 | 32 | -0.02em | KPI number, tabular nums |

## 4.4. Quy tắc text

- Page title: một dòng nếu có thể; mobile cho phép tối đa 2 dòng.
- Subtitle page: tối đa 2 dòng, `text-secondary`.
- Task title trong list: tối đa 2 dòng; desktop thường 1 dòng + ellipsis khi table.
- Person name: không rút thành initials.
- Dữ liệu số dùng `font-variant-numeric: tabular-nums` khi so sánh theo cột.
- Không viết toàn bộ câu bằng uppercase. Chỉ group label navigation có thể uppercase.
- Placeholder không được chứa thông tin quan trọng thay cho label.

---

# 5. ICONOGRAPHY

## 5.1. Family

- Dùng một icon set line thống nhất, mặc định đề xuất `Lucide` nếu repo mới.
- Stroke: khoảng `1.75px` ở icon 18–20px.
- Không trộn icon filled, emoji và line icon tùy ý.

## 5.2. Kích thước

| Ngữ cảnh | Size |
|---|---:|
| Inline metadata | 14px |
| Input icon | 16px |
| Sidebar | 18px |
| Button | 16px |
| Empty state | 24–32px |
| Mobile tab | 22px |

## 5.3. Icon-only button

- Desktop clickable box: `32x32` hoặc `36x36`.
- Mobile: tối thiểu `44x44` hit target.
- Bắt buộc `aria-label`/accessibilityLabel.
- Tooltip desktop xuất hiện sau 400–600ms.

---

# 6. LAYOUT SYSTEM

## 6.1. Breakpoints

```text
xs:  < 480
sm:  480–767
md:  768–1023
lg:  1024–1279
xl:  1280–1439
2xl: >= 1440
```

Các breakpoint này dùng cho layout, không dùng để tạo phiên bản UI hoàn toàn khác nhau nếu không cần.

## 6.2. Desktop app shell

### >= 1440px

```text
body/canvas padding: 20px
app shell: min-height calc(100dvh - 40px)
app radius: 20px
sidebar: 252px
main: flex 1; min-width 0
main topbar: 64px
page horizontal padding: 28px
page bottom padding: 40px
```

### 1280–1439px

```text
canvas padding: 16px
sidebar: 240px
page padding: 24px
```

### 1024–1279px

```text
canvas padding: 12px
sidebar: 224px hoặc user-controlled collapsed rail 72px
page padding: 20px
```

### 768–1023px

```text
canvas padding: 0–8px
sidebar default rail: 72px
full sidebar opens as overlay sheet 280px
page padding: 20px
```

### < 768px

```text
canvas padding: 0
app radius: 0
left sidebar: none
mobile topbar: 56px
bottom nav: 64px + safe-area-bottom
page padding: 16px
```

## 6.3. Scroll behavior

- Desktop: app shell `height: calc(100dvh - outer padding*2)`.
- Sidebar và main content có thể scroll độc lập.
- Topbar của main sticky trong main scroll container.
- DataTable có `overflow-x: auto` ở container riêng, không làm body scroll ngang.
- Drawer body scroll riêng, footer sticky.
- Modal nhỏ không scroll header/footer trừ khi viewport quá thấp.

## 6.4. Content width

- Data-heavy page: dùng toàn bộ main width.
- Form page: content chính `max-width: 720px`.
- Settings page: form `max-width: 760px`, navigation settings riêng nếu cần.
- Report detail: readable column `max-width: 960px`, bảng con có thể full.
- Auth card: `400px` desktop, `100%` mobile.

---

# 7. SURFACE, BORDER, RADIUS, SHADOW

## 7.1. Surface hierarchy

1. `canvas`: nền ngoài cùng.
2. `sidebar`: vùng nav.
3. `surface`: main app/page/card.
4. `surface-muted`: header table, segmented background, secondary blocks.
5. `surface-hover`: hover row/button ghost.

Không tạo 5 lớp card lồng nhau. Một page thông thường chỉ nên có surface page + một lớp card/table.

## 7.2. Border

- Standard: `1px solid var(--border)`.
- Strong: chỉ cho input focus-adjacent hoặc divider quan trọng.
- Không dùng border 2px cho card thường.
- Divider section: 1px.

## 7.3. Radius

| Component | Radius |
|---|---:|
| App shell desktop | 20px |
| Main card / panel | 14px |
| Input/button | 10px |
| Badge | 6px |
| Checkbox | 5px |
| Tooltip | 6px |
| Modal | 14px |
| Drawer left edge | 16px |

## 7.4. Shadow

- Card bình thường: không shadow hoặc `shadow-xs`.
- Hover card có thể `shadow-card`.
- Dropdown/popover/modal/drawer: `shadow-overlay`.
- Không dùng shadow đen đậm quanh mọi component.

---

# 8. BUTTON SYSTEM

## 8.1. Sizes

| Size | Height desktop | Padding X | Icon | Font |
|---|---:|---:|---:|---|
| `sm` | 32px | 12px | 14px | 13/500 |
| `md` | 36px | 14px | 16px | 13/500 |
| `lg` | 40px | 16px | 16px | 14/500 |
| `mobile` | min 44px | 16px | 18px | 14/500 |

Gap icon/text: `8px`.

## 8.2. Variants

### Primary
- Background `primary`.
- Text white.
- Hover `primary-hover`.
- Pressed `primary-pressed`.
- Dùng tối đa 1 CTA primary nổi bật trong một khu vực hành động.

### Secondary
- Background white.
- Border `border-input`.
- Text primary.
- Hover `surface-hover`.

### Ghost
- Background transparent.
- Hover `surface-hover`.
- Không có border.

### Danger
- Background `danger`.
- Text white.
- Chỉ destructive confirmed action.

### Danger subtle
- Background `danger-soft`.
- Text `danger`.
- Dùng cho secondary destructive.

## 8.3. Loading button

- Giữ nguyên width để layout không nhảy.
- Spinner 14–16px bên trái text.
- Text đổi thành động từ đang thực hiện: `Đang lưu...`, `Đang giao...`.
- Disabled trong khi mutation gửi.

## 8.4. Button wording

Đúng: `Giao việc`, `Lưu thay đổi`, `Duyệt yêu cầu`, `Từ chối`, `Chấm vào`, `Chấm ra`.  
Sai: `OK`, `Submit`, `Confirm` nếu có thể dùng động từ nghiệp vụ rõ hơn.

---

# 9. FORM FIELD SYSTEM

Mọi field dùng cấu trúc chung:

```text
Label [required]
Control
Help text / hint
Error text
```

## 9.1. Field wrapper

```text
field vertical gap: 6px giữa label và control
control -> help: 4px
help/error: 12px hoặc 13px tùy mật độ
field -> field: 16px
```

Label: `13px / 500 / 20px`, text-primary.  
Required indicator: `*` danger, kèm accessible text `Bắt buộc`; không chỉ dựa màu.

## 9.2. Text Input

```text
height desktop: 40px
height mobile: 44px
padding x: 12px
border: 1px solid var(--border-input)
radius: 10px
font: 14px/400
background: white
placeholder: text-placeholder
```

States:

- Default: border input.
- Hover: border strong.
- Focus: border `focus-ring`; `box-shadow: 0 0 0 3px rgba(91,92,226,.12)`.
- Error: border danger + error text; focus ring danger-soft.
- Disabled: surface-muted + text-disabled; cursor not-allowed.
- Readonly: surface-subtle; text-primary; vẫn copy được.

## 9.3. Input có icon

- Left icon container 16px, left padding 12px.
- Gap icon-text 8px.
- Clear button bên phải hit target 32px desktop, 40px mobile.
- Không dùng icon nếu label đã đủ rõ và icon không tăng hiểu biết.

## 9.4. Search Input

- Height 36–40 desktop, 44 mobile.
- Search icon trái 16px.
- Placeholder: `Tìm công việc...`, `Tìm nhân sự...` theo context.
- Debounce 250–350ms cho local/API search.
- `Esc` clear khi focus; `Ctrl/Cmd+K` mở global search.

## 9.5. Password Input

- Có nút hiện/ẩn.
- Không trim password.
- `autocomplete` đúng.
- Error auth chung, không leak tồn tại email.

## 9.6. Textarea

- Min height 96px.
- Task description: min 120px.
- Resize vertical desktop; mobile auto-grow đến khoảng 240px rồi scroll.
- Padding 12px.
- Counter khi có max length > 500, đặt góc dưới phải hoặc dưới field.

## 9.7. Number Input

- Dùng cho phút ước lượng, không dùng để nhập dữ liệu không phải số.
- Có min/max rõ.
- Không cho scientific notation nếu nghiệp vụ không cần.
- Số hiển thị tabular nums.

## 9.8. Select đơn

- Height như input.
- Trigger có chevron 16px.
- Dropdown padding 4px.
- Item min height 36px desktop / 44 mobile.
- Selected item có check 16px, không tô full accent đậm.
- Dropdown max-height 320px, scroll.
- Nếu > 8 lựa chọn, dùng searchable combobox.

## 9.9. Combobox / Person / Seller picker

- Input search ở đầu popover.
- Person row: `Tên nhân sự` + dòng phụ `Chuyên môn · Mã NV`; **không avatar**.
- Seller row: `Tên seller` + metadata `Shopee/TikTok Shop`.
- Người không hợp lệ do scope: render disabled + text lý do nếu admin đang cần hiểu; không im lặng mất khỏi list trong form quản trị.
- Multi-select hiển thị selected items dạng compact tags, tối đa 2 hàng rồi `+N`.

## 9.10. Date Picker

- Web: popover calendar.
- Locale `vi-VN`.
- Tuần hiển thị T2–CN.
- Display field `dd/MM/yyyy`.
- Không parse chuỗi mơ hồ bằng client.
- Mobile native: ưu tiên native date picker.

## 9.11. Time Picker

- 24-hour `HH:mm`.
- Step mặc định 5 phút; nếu ca cần chính xác phút, cho nhập trực tiếp.
- Mobile dùng native time picker.

## 9.12. DateTime field

Web layout desktop: date 60% + time 40% trong một row; mobile stack nếu hẹp.  
Label vẫn chỉ một label nghiệp vụ như `Hạn hoàn thành`.

## 9.13. Checkbox

Visual box `18x18px`, radius 5px. Hit target tối thiểu 36px desktop / 44px mobile.

```text
Unchecked: white, border-input
Hover: border-strong
Checked: primary background, primary border, white check
Indeterminate: primary background, white minus
Disabled: surface-muted, border, text-disabled
```

Ba mục đích phải tách component props/semantics:

1. `RowSelectionCheckbox` — chọn record.
2. `ChecklistCheckbox` — hoàn thành bước checklist.
3. `DailyTaskCheckbox` — bật lịch lặp.

## 9.14. Radio

- Circle 18px.
- Group gap 10–12px.
- Dùng khi 2–5 lựa chọn loại trừ nhau và nên nhìn thấy cùng lúc.

## 9.15. Switch

- Track 36x20px desktop, 40x22 mobile.
- Dùng cho setting on/off, không dùng thay checkbox xác nhận một hành động.
- Label bên trái hoặc phải nhưng phải click được toàn row.

## 9.16. Segmented control

Dùng cho lựa chọn nhanh như `Danh sách / Lưới` nếu thực sự có hai view, hoặc trạng thái filter nhỏ.

```text
container height: 36px
background: surface-muted
padding: 3px
radius: 10px
item active: white + shadow-xs
item padding x: 12px
```

Không dùng segmented cho hơn 4 option.

## 9.17. File Upload

- Vùng upload border dashed rất nhẹ hoặc button `Đính kèm tệp`.
- Hiển thị tên file, size, trạng thái upload.
- Có progress.
- Không tự public URL.
- Lỗi file giữ các field form khác.
- Ảnh selfie chấm công **không dùng generic upload từ gallery** trong normal flow; phải đi qua camera flow.

---

# 10. NAVIGATION COMPONENTS

## 10.1. Desktop Sidebar

```text
width: 252px @ >=1440
padding top: 20px
padding x: 16px
logo/header block height: 52px
section top gap: 24px
section label bottom gap: 8px
item height: 40px
item radius: 10px
item padding x: 12px
icon: 18px
icon-text gap: 10px
counter: 12px, right aligned
```

### Sidebar active

```text
background: #fff
border: 1px solid var(--border)
shadow: var(--shadow-xs)
text: primary, weight 500
icon: primary
```

Inactive: transparent, text-secondary.  
Hover: surface-hover.  
Không có thanh accent dày ở mép trái.

### Section label

- 11px/500/16px.
- `text-muted`.
- Uppercase `CÁ NHÂN`, `VẬN HÀNH`, `NHÂN SỰ`, `HỆ THỐNG` với letter-spacing khoảng `.06em`.

### Workspace header

- Logo/mark nhỏ 24–28px nếu có brand thật.
- Tên workspace 14/600.
- Không dùng ảnh người.

### Footer profile

- 1 dòng tên 13/500.
- Role/chuyên môn 12/400 secondary.
- Account/logout trong menu text; không avatar.

## 10.2. Collapsed Sidebar / Rail

- Width 72px.
- Icon centered.
- Tooltip khi hover.
- Counter dạng small dot/count chỉ khi cần.
- Không hiện first-letter avatar.

## 10.3. Topbar

```text
height: 64px desktop
padding x: 28px desktop
border-bottom: 1px solid border
background: rgba(255,255,255,.96)
```

Left: breadcrumb.  
Right: global search, `Giao việc` nếu có quyền, bell, account menu.

Breadcrumb:
- 13px.
- Parent secondary.
- Current primary.
- Separator 12px muted.

## 10.4. Mobile Topbar

- Height 56px.
- Back button 44x44 khi ở detail.
- Page title 16/600.
- Right actions icon-only max 2; phần còn lại vào overflow.

## 10.5. Bottom Navigation

Tabs cố định:

1. Hôm nay
2. Công việc
3. Chấm công
4. Thông báo
5. Thêm

```text
height: 64px + safe-area-bottom
icon: 22px
label: 11px/500
active: text-primary
inactive: text-muted
```

Không dùng nền accent full tab. Có thể dùng một indicator nhỏ hoặc tăng weight.

---

# 11. PAGE HEADER, TOOLBAR, FILTER BAR

## 11.1. PageHeader

Desktop:

```text
breadcrumb optional
row: title/subtitle left, actions right
page title 24/600
subtitle 14/400 text-secondary, max 2 lines
header bottom margin 24px
```

Nếu page không cần subtitle, không chừa khoảng giả.

Mobile:
- Breadcrumb ẩn nếu topbar/back đã đủ context.
- Title 22/600 hoặc 20/600 tùy chiều dài.
- Action chính full-width hoặc sticky bottom khi form.

## 11.2. Toolbar

- Height không bắt buộc cố định nhưng target 40px controls.
- Filter left, search right hoặc theo ưu tiên.
- Gap 8px.
- Khi hẹp, filter chuyển vào `Bộ lọc` sheet.

## 11.3. Filter chips

- Chỉ hiển thị filter đang áp dụng.
- Height 28–30px.
- Background surface-muted.
- Radius 6–8px, không pill quá tròn.
- Có `x` clear.
- Có `Xóa bộ lọc` khi >1 filter.

---

# 12. BADGE, CHIP, STATUS

## 12.1. StatusBadge

```text
height: 24px
padding x: 8px
radius: 6px
font: 12/500
icon optional: 12–14px
```

Mapping đề xuất:

| Nghiệp vụ | Text | Foreground | Background |
|---|---|---|---|
| Chưa nhận | `Chưa nhận` | text-secondary | surface-muted |
| Chưa bắt đầu | `Chưa bắt đầu` | text-secondary | surface-muted |
| Đang làm | `Đang làm` | info | info-soft |
| Bị vướng | `Bị vướng` | warning | warning-soft |
| Chờ duyệt | `Chờ duyệt` | accent | accent-soft |
| Hoàn thành | `Hoàn thành` | success | success-soft |
| Quá hạn | `Quá hạn` | danger | danger-soft |
| Đã từ chối | `Đã từ chối` | danger | danger-soft |

`Quá hạn` có thể là derived visual state đi cùng base status, không nhất thiết là enum status database.

## 12.2. PriorityBadge

- Thấp: neutral muted.
- Bình thường: neutral.
- Cao: warning soft.
- Khẩn: danger soft.

Không dùng 4 màu neon.

## 12.3. SellerChip

- Height 26–28px.
- Text 12/500.
- Tên seller có thể ellipsis.
- Nền tảng ở metadata hoặc small icon text; không phủ màu Shopee/TikTok toàn chip.

## 12.4. DailyIndicator

- Icon repeat 14px + `Hằng ngày`.
- Accent text trên accent-soft hoặc neutral với icon accent.
- Tooltip: lịch lặp thực tế.

---

# 13. CARD SYSTEM

## 13.1. Standard Card

```text
background: white
border: 1px solid border
radius: 14px
padding: 20px desktop / 16px mobile
shadow: none hoặc shadow-xs
```

## 13.2. KPI Card

Không làm kiểu dashboard màu sắc. Cấu trúc:

```text
Label 12/500 secondary
Value 26/600 tabular
Context 12/400 muted
optional small status indicator
```

Min height 104px. Không icon lớn trang trí.

## 13.3. Action Card

Dùng cho chấm công/việc cần xử lý. Có border + title + status + action bên phải. Khi cần chú ý có border semantic rất nhẹ, không tô full background.

---

# 14. DATA TABLE SYSTEM

## 14.1. Table container

- White surface.
- Border 1px.
- Radius 14px.
- Overflow hidden ở outer; x-scroll ở inner.

## 14.2. Header

```text
height: 44px
background: surface-muted
font: 12/500
color: text-secondary
padding x: 16px
border-bottom: 1px solid border
```

Sortable column có icon 12px. Không dùng caret luôn nổi bật khi chưa sort.

## 14.3. Row

```text
min-height: 56px
background: white
border-bottom: 1px solid border
padding x: 16px
font: 14px
hover: surface-hover
```

Row selected: `accent-soft` ở mức rất nhẹ + checkbox checked, nhưng vẫn đảm bảo text primary.

## 14.4. Alignment

- Text: left.
- Dates/times: left trừ bảng cần compare numeric.
- Numeric: right + tabular nums.
- Action menu: right, width 44px.
- Checkbox column: 44px.

## 14.5. Pagination

- Bottom bar min-height 52px.
- Left: `1–25 / 128`.
- Right: previous/next + page size nếu thực sự cần.
- Với dataset nhỏ <50 có thể không hiện page size.

## 14.6. Mobile table strategy

Không ép table 7 cột vào 390px. Chọn một trong hai:

1. Task/person/approval: card list responsive.
2. Timesheet/data audit: horizontal scroll có sticky first column nếu cần.

Phải có dấu hiệu UX nếu scroll ngang là bắt buộc.

---

# 15. TASK LIST / TASK ROW — COMPONENT QUAN TRỌNG NHẤT

## 15.1. Desktop TaskRow dạng list/table hybrid

Column gợi ý ở main list:

```text
[44] selection
[minmax(300,1fr)] title + metadata
[160] seller
[150] assignee
[140] deadline
[124] status
[44] overflow
```

Title block:

```text
Task title                       14/500 primary
TSK-000123 · Hằng ngày          12/400 muted
```

Deadline:
- Bình thường: `05/10 · 14:00` primary/secondary.
- Sắp hạn: warning only khi theo rule.
- Quá hạn: danger text + `Quá hạn 2 giờ` nếu backend cung cấp.

Assignee: `PersonLabel`, không avatar.

## 15.2. Mobile TaskCard

```text
[Status badge] [Daily indicator]
Task title 2 lines
Seller · Deadline
Người phụ trách / metadata tùy view
[Primary action nếu cần]
```

Padding 16px, gap 10–12px. Không có quá nhiều badge trên một hàng; wrap có kiểm soát.

## 15.3. Quick actions

Trong màn hình Today, task thuộc chính chủ có thể có:

- `Nhận việc` nếu chưa nhận.
- `Bắt đầu` nếu đã nhận chưa bắt đầu.
- `Cập nhật` nếu đang làm.
- `Nộp kết quả` nếu đủ điều kiện.
- `Báo vướng` secondary.

Không hiển thị 5 button cùng lúc. Chỉ 1 primary context action + overflow/secondary.

---

# 16. OVERLAYS: DROPDOWN, POPOVER, TOOLTIP, MODAL, DRAWER

## 16.1. Dropdown / Popover

- Border 1px.
- Radius 10px.
- Shadow overlay.
- Padding 4–8px.
- Animation fade + scale 0.98 → 1 trong 120ms.
- Flip placement khi thiếu không gian.

## 16.2. Tooltip

- Background primary.
- Text white 12px.
- Radius 6px.
- Max width 260px.
- Không chứa thao tác phức tạp.

## 16.3. ConfirmDialog

```text
width: min(440px, calc(100vw - 32px))
padding: 24px
radius: 14px
```

Cấu trúc:

1. Title 18/600.
2. Description 14/400 secondary, nêu hậu quả.
3. Optional object summary.
4. Footer right aligned desktop; stacked reverse mobile nếu destructive.

Ví dụ:

`Xóa mẫu công việc lặp?`  
`Các lần công việc đã phát sinh vẫn được giữ lại. Hệ thống sẽ không tạo thêm lần mới từ mẫu này.`

Buttons: `Hủy` + `Dừng lịch`.

## 16.4. Form Drawer

Desktop:

```text
width: 680px mặc định
min: 640px
max: 720px
right side
header: 64px
body padding: 24px
footer: 72px, sticky
```

Mobile: full-screen sheet, không drawer 90% làm chật.

Dùng cho `Giao việc`, edit task, create seller nếu cần.

## 16.5. Overlay

`background: var(--overlay)`.  
Không blur mạnh. Có thể `backdrop-filter: blur(2px)` tối đa nếu hiệu năng ổn; không bắt buộc.

---

# 17. TABS, ACCORDION, STEP, TIMELINE

## 17.1. Tabs

Task detail tabs:

`Nội dung · Kết quả · Trao đổi · Lịch sử`

- Tab height 40px.
- Text 13/500.
- Active text primary + underline 2px primary hoặc accent rất nhỏ.
- Không tạo pill tab màu lớn.
- Mobile tabs scroll ngang.

## 17.2. Accordion

- Header min 44px.
- Chevron 16px.
- Border-top/bottom nhẹ.
- Dùng cho `Thông tin bổ sung`, không ẩn field bắt buộc.

## 17.3. Stepper

Dùng cho onboarding và remote attendance challenge.

- Step label 12/500.
- Current accent/primary.
- Completed success check.
- Không dùng progress bar gradient.

## 17.4. Activity timeline

Task history/audit:

- Vertical line border.
- Event dot 8px neutral/semantic.
- Name + action 13/500, time 12 muted.
- Detail diff có thể expand.
- Không avatar.

---

# 18. FEEDBACK STATES

## 18.1. Toast

- Position desktop: bottom-right.
- Mobile: bottom above nav hoặc top-safe area tùy platform.
- Width 320–380 desktop.
- 3–4s success/info.
- Error quan trọng không chỉ toast; phải inline/persistent.
- Max 3 toast visible; queue phần còn lại.

## 18.2. Inline Alert

Variants neutral/info/warning/danger/success.  
Padding 12–14px, radius 10px, icon 16px, title optional 13/600, body 13/400.

## 18.3. Skeleton

- Hình skeleton phải gần cấu trúc nội dung thật.
- Không dùng spinner full-screen cho page đã có dữ liệu cache.
- Shimmer nhẹ 1.2–1.6s; respect reduced motion.

## 18.4. EmptyState

Cấu trúc:

```text
line icon 28px
Title 16/600
Description 13–14 secondary, max 360px
Action primary/secondary nếu user có quyền
```

Ví dụ task hôm nay trống:

`Không còn việc cần xử lý hôm nay`  
`Các công việc mới hoặc việc đến hạn sẽ xuất hiện tại đây.`

## 18.5. ErrorState

`Không tải được danh sách công việc.`  
`Kiểm tra kết nối và thử lại.`  
Button `Thử lại`.

Không hiển thị raw stack/error object cho user.

## 18.6. ConnectivityBanner

Sticky ở top main content khi offline:

`Đang mất kết nối. Dữ liệu đang hiển thị có thể chưa mới nhất.`

Màu warning-soft, không che topbar.

---

# 19. MICRO-INTERACTION VÀ MOTION

- Hover/press transition 120–180ms.
- Drawer 180–240ms ease-standard.
- Modal fade/scale 160–180ms.
- List item update không bounce.
- Success check có thể animate 160ms nhỏ.
- Không dùng spring mạnh trong app vận hành.
- `prefers-reduced-motion: reduce` → bỏ transform animation không thiết yếu.
- Khi realtime cập nhật row, có thể flash background accent-soft tối đa 600ms rồi fade; không nhấp nháy.

---

# 20. UX COPY VÀ NGÔN NGỮ

## 20.1. Cách viết

- Ngắn, hành động rõ.
- Không dùng thuật ngữ kỹ thuật như RPC, RLS với user.
- Không phán xét nhân viên.
- Không ghi `Bạn làm việc kém` hoặc `Bạn thường xuyên quên`.
- Ghi sự kiện: `2 công việc quá hạn chưa có cập nhật.`

## 20.2. Capitalization

Tiếng Việt dùng sentence case:

- `Giao việc nhanh`
- `Công việc của tôi`
- `Bảng công tháng`

Không dùng Title Case từng chữ.

## 20.3. Date/time copy

- Hôm nay: `Hôm nay · 04/10/2026`.
- Deadline gần: `Hôm nay · 14:00`.
- Khác ngày: `05/10 · 10:00`.
- Full detail: `05/10/2026 · 10:00`.

---

# 21. FRONT-END COMPONENT INVENTORY

Tối thiểu có các component dùng chung dưới đây.

```text
components/ui/
  button.tsx
  icon-button.tsx
  input.tsx
  textarea.tsx
  field.tsx
  checkbox.tsx
  radio-group.tsx
  switch.tsx
  select.tsx
  combobox.tsx
  date-picker.tsx
  time-picker.tsx
  segmented-control.tsx
  badge.tsx
  card.tsx
  data-table.tsx
  tabs.tsx
  accordion.tsx
  dropdown-menu.tsx
  popover.tsx
  tooltip.tsx
  dialog.tsx
  drawer.tsx
  toast.tsx
  alert.tsx
  skeleton.tsx
  empty-state.tsx
  error-state.tsx
  pagination.tsx

components/shell/
  app-shell.tsx
  sidebar.tsx
  sidebar-item.tsx
  topbar.tsx
  page-header.tsx
  mobile-bottom-nav.tsx
  mobile-topbar.tsx

components/tasks/
  task-row.tsx
  task-card.tsx
  task-status-badge.tsx
  priority-badge.tsx
  daily-indicator.tsx
  seller-chip.tsx
  person-label.tsx
  task-form.tsx
  task-filter-bar.tsx
  task-result-form.tsx
  task-history.tsx

components/attendance/
  attendance-status-card.tsx
  check-in-button.tsx
  wifi-diagnostic.tsx
  remote-session-qr.tsx
  selfie-capture.tsx
  attendance-timeline.tsx

components/requests/
  request-card.tsx
  request-form.tsx
  approval-panel.tsx

components/reports/
  report-summary.tsx
  report-person-section.tsx
  report-task-list.tsx
```

## 21.1. Quy tắc code component

- Primitive UI không import business API.
- Presentation component nhận props typed.
- Hook/mutation nằm feature layer.
- Không tạo `TaskRowAdmin`, `TaskRowEmployee`, `TaskRowToday` bằng copy; dùng một component với slot/variant có giới hạn.
- Tránh component >300–400 dòng; tách section hợp lý.
- Không đưa logic permission thật vào CSS/hidden; server/RLS vẫn là authority.

---

# 22. MÀN HÌNH THEO ROUTE — UI CONTRACT CHI TIẾT

Phần này là hợp đồng UI. AI phải triển khai đúng thứ tự phase; không phải tất cả trong một lần.

## P01 — `/login`

### Desktop

- Canvas `canvas` full viewport.
- Center app/auth area, không cần sidebar.
- Two-column ở >=1024:
  - Left 50–55%, surface-muted, padding 48–64.
  - Right 45–50%, white, form centered.
- Form width 400px.

### Content

```text
OpsDesk
Công việc rõ ràng. Vận hành gọn gàng.

Đăng nhập workspace
Theo dõi công việc, chấm công và phối hợp cùng đội ngũ.
Email công việc
Mật khẩu
[Quên mật khẩu?]
[Đăng nhập]
Chưa có tài khoản? Liên hệ quản trị viên để nhận lời mời.
```

### Mobile

- Không hero lớn.
- Padding 24px top, 16px sides.
- Logo + form.
- Button full width 44px.

---

## P02/P03 — Invite / Reset password

- Auth shell giống login.
- Không thêm sidebar.
- Invite card hiển thị workspace + email + role dưới dạng read-only metadata card.
- Password strength/help text rõ, không trang trí nhiều.

---

## P04 — `/onboarding`

- Desktop content max 760px, center.
- Stepper top.
- Mỗi step là card 20–24px padding.
- Footer sticky trong card/page: `Để sau` secondary, `Tiếp tục` primary.
- Admin onboarding 5 bước theo spec.
- Permission camera/Wi-Fi chỉ giải thích, không xin quyền trước khi cần.

---

## P05 — `/today`

Đây là **màn hình quan trọng nhất của employee**.

### Header

```text
Cá nhân / Hôm nay
Hôm nay                          [Lịch] [Tạo việc cá nhân nếu bật]
Thứ ..., 04/10/2026 · Tên nhân viên
```

### Attendance status card

- Full width.
- Desktop height khoảng 72–84px.
- Left: shift + location + attendance state.
- Right: one primary CTA.

Ví dụ:

`Ca 09:00–18:00 · Văn phòng`  
`Chưa chấm vào`  
`[Chấm vào]`

Không có avatar hoặc banner chào mừng.

### Summary cards

Desktop grid 4 cột, gap 12px:
- `Việc cần nhận`
- `Cần làm hôm nay`
- `Quá hạn`
- `Đang chờ / bị vướng`

Tablet 2x2. Mobile horizontal 2-column hoặc compact grid, không carousel bắt buộc.

### Task sections

Order:
1. `Việc mới cần nhận`
2. `Cần xử lý hôm nay`
3. `Đã quá hạn`
4. `Đang chờ / bị vướng`
5. `Đã hoàn thành hôm nay` collapsed mặc định nếu dài.

Mỗi section title có count. Không trộn overdue vào today rồi làm mất lý do.

### Filters

- `Ưu tiên xử lý` / `Tất cả` small segmented hoặc filter.
- Seller combobox.
- Search.

Mobile: filter button mở bottom sheet.

---

## P06 — `/my-tasks`

### Desktop

- PageHeader + task tabs/filter.
- Tabs/segments: `Đang mở`, `Chờ duyệt`, `Hoàn thành`, `Tất cả`.
- Toolbar: search, seller, date, status.
- Main task list/table.

### Mobile

- TaskCard list.
- Search sticky dưới header nếu danh sách dài.

---

## P07 — `/overview`

Manager/admin dashboard phải **gọn**, không biến thành BI dashboard.

### Top row KPI

Tối đa 4 card:
- Việc đến hạn hôm nay.
- Quá hạn chưa cập nhật.
- Chờ duyệt.
- Nhân sự đang có việc cần chú ý.

### Main content

Desktop 2 cột `minmax(0, 2fr) minmax(280px, 1fr)`:

Left:
- `Cần quản lý xử lý` list.
- `Công việc theo seller` table/compact summary.

Right:
- `Đơn cần duyệt` nếu có quyền HR.
- `Trạng thái báo cáo 18:00`.

Không dùng pie chart lớn. Nếu có chart sau này, chỉ khi trả lời câu hỏi quản lý rõ.

---

## P08 — `/tasks`

- DataTable full width.
- Toolbar search + seller + assignee + status + date + priority.
- Primary `Giao việc` top right.
- Bulk action chỉ xuất hiện khi selection >0.
- Checkbox đầu dòng = selection, không complete.
- URL giữ filter/query/page.

---

## P09 — `/tasks/new` hoặc Task Drawer

### Drawer header

`Giao việc` 20/600.  
Optional subtext `Tạo một công việc hoặc lịch công việc lặp.`

### Basic fields order

1. `Tên công việc` — text input.
2. `Seller` — combobox.
3. `Người chịu trách nhiệm` — person combobox.
4. `Ngày dự kiến làm` — date.
5. `Hạn hoàn thành` — datetime.
6. `Ưu tiên` — segmented/select.
7. **Daily checkbox**.

### Daily checkbox block

Render như bordered sub-card khi checked:

```text
☑ Daily task — Tự động lặp lại
Mỗi ngày phù hợp sẽ tạo một công việc riêng, có kết quả và lịch sử độc lập.

Lịch lặp          [Theo lịch làm việc v]
Ngày bắt đầu      [04/10/2026]
Kết thúc          [Không giới hạn v]
Giờ đến hạn       [10:00]
Phân công         [Cố định người đã chọn v]

7 lần tiếp theo
T2, 05/10 · 10:00 · Linh · Seller A
...
```

Padding 16px, border accent-soft/standard, không full accent background.

### Additional information accordion

- Mô tả.
- Checklist.
- Người phối hợp.
- Người duyệt.
- Yêu cầu kết quả.
- Bằng chứng.
- Tài liệu tham khảo.
- Ước lượng thời gian.
- Reminder profile.

### Footer

Desktop sticky:
- Left: `Hủy` ghost/secondary.
- Right: `Giao việc` primary hoặc `Tạo lịch công việc` khi daily.

Mobile: footer sticky bottom safe-area, primary full/large.

---

## P10 — `/tasks/:taskId`

### Header

- Breadcrumb.
- `TSK-000123` metadata.
- Title 22–24px.
- Status + seller + daily indicator.
- Right: primary contextual action + menu.

### Metadata grid

Desktop 4 cột hoặc 2x2 tùy width:
- Người phụ trách.
- Người giao.
- Reviewer.
- Ngày dự kiến.
- Deadline.
- Priority.

Dùng label 12 secondary + value 14/500.

### Tabs

`Nội dung · Kết quả · Trao đổi · Lịch sử`.

### Content tab

- Description.
- Checklist.
- Attachments.
- Related recurring template nếu có.

### Result tab

- Kết quả mới nhất.
- `Nộp kết quả` form nếu có quyền.
- Review state.

### Mobile

- Metadata stack compact.
- CTA sticky bottom nếu cần nộp/nhận/bắt đầu.

---

## P11/P12 — Recurring tasks

### List

Columns:
- Tên mẫu.
- Seller.
- Schedule.
- Người phụ trách.
- Lần tiếp theo.
- Trạng thái active/paused.
- Action.

### Detail

Top summary + tabs:
- `Thiết lập`
- `Lần thực hiện`
- `Lịch sử thay đổi`

Có preview 7 lần tiếp theo dạng timeline/table.

Action `Tạm dừng lịch` secondary destructive; `Dừng lịch` cần confirm.

---

## P13 — `/calendar`

- Header có previous/today/next.
- View desktop: week default; month optional nếu thực sự hữu ích.
- Mobile: agenda/day list ưu tiên hơn month grid.
- Task color không phụ thuộc seller brand; dùng status marker nhỏ.
- Daily task occurrence là item riêng.
- Leave/shift có layer riêng nhẹ.

Không nhồi 10 màu cho 10 seller.

---

## P14/P15 — Seller

### Seller list

Grid/list tùy dữ liệu nhưng mặc định table/list.  
Columns: seller, platform, manager/phụ trách, số task mở, trạng thái.

### Seller detail

Header:
- Tên seller.
- Platform chip.
- Trạng thái.
- `Giao việc`.

Tabs:
- `Tổng quan`
- `Công việc`
- `Nhân sự phụ trách`
- `Lịch công việc lặp`

Không dùng logo sàn to làm background.

---

## P16/P17 — Team

### Team list

Không avatar. Columns:
- Họ tên.
- Mã NV.
- Role.
- Chuyên môn.
- Seller phụ trách.
- Trạng thái tài khoản.

### Member detail

Header text-only:

`Nguyễn Văn A`  
`NV-012 · Vận hành · Nhân viên`

Tabs hiển thị theo quyền:
- `Công việc`
- `Seller`
- `Lịch làm việc`
- `Chấm công` chỉ người có quyền HR/chính chủ phù hợp.
- `Quyền` admin.

Không biến selfie thành profile picture.

---

## P18 — `/attendance`

### Top attendance card

Trạng thái rõ nhất trang:

```text
Ca hôm nay
09:00–18:00 · Văn phòng
Chưa chấm vào
[Chấm vào]
```

Nếu office:
- small diagnostic: `Mạng văn phòng: Chưa xác thực / Đã xác thực`.
- Link `Kiểm tra kết nối`.

Nếu remote:
- `Làm việc online đã được duyệt`.
- CTA `Bắt đầu chấm công online`.

### Today timeline

- Check-in.
- Break nếu hệ thống theo dõi.
- Check-out.
- Adjustment marker.

### History

List 7–30 ngày gần đây; link sang timesheet.

---

## P19 — `/attendance/live`

HR/admin only.

Table/card:
- Nhân sự.
- Ca.
- Hình thức: văn phòng/online/nghỉ.
- Chấm vào.
- Chấm ra.
- Trạng thái.
- Exception.

Không hiển thị thumbnail selfie ở table. Evidence mở trong protected detail/modal khi có quyền.

---

## P20 — `/attendance/remote-session`

Đây là page hiển thị trên máy tính để hỗ trợ selfie cùng máy làm việc.

- Background white, minimal.
- Center card.
- Session status.
- QR/code/challenge lớn đủ đọc.
- Countdown rõ.
- Text: `Giữ màn hình này hiển thị và chụp selfie từ điện thoại cùng máy tính làm việc.`
- Không có dữ liệu task/HR thừa trên màn hình.

---

## P21 — `/requests`

### List

Cards/table theo loại:
- Nghỉ.
- Về sớm/đi muộn.
- Làm online.
- Bổ sung chấm công.

Status badge.  
Primary `Tạo yêu cầu`.

### Create request form

Type first → render fields tương ứng. Không render 20 field cùng lúc.

---

## P22 — `/approvals`

### Desktop two-pane optional

Left list pending requests 320–380px.  
Right detail/decision panel flex 1.

Nếu implementation đơn giản, table + detail drawer cũng được nhưng phải giữ speed thao tác.

Actions:
- `Duyệt` primary.
- `Từ chối` danger subtle.
- Reason field bắt buộc khi từ chối nếu policy yêu cầu.

Hiển thị ảnh hưởng task nhưng không phơi thông tin ngoài quyền.

---

## P23/P24 — Timesheet

### `/timesheet/me`

Header month switch.  
Summary compact cards:
- Công thực làm.
- Nghỉ hưởng lương.
- Nghỉ không lương.
- Thiếu dữ liệu.

Table theo ngày:
- Ngày.
- Ca.
- In/Out.
- Thực làm.
- Nghỉ.
- Trạng thái.
- Ghi chú/exceptions.

### `/timesheets`

HR table theo nhân sự + month, có filter trạng thái chốt.  
Không dùng màu để biểu diễn số công; dùng số rõ.

---

## P25 — `/shifts`

- Calendar/list shift.
- Side panel create/edit shift.
- Holiday/non-working day management.
- Table nhân sự → ca nếu cần.
- Tránh spreadsheet clone quá dày ở V1; vẫn phải usable 5–10 người.

---

## P26/P27 — Reports 18:00

### Report list

Columns:
- Ngày.
- Cutoff.
- Trạng thái generation.
- Người nhận/phạm vi.
- Created time.

### Report detail

Header:

`Báo cáo vận hành · 04/10/2026`  
`Chốt dữ liệu lúc 18:00`

Summary table nhân sự.  
Mỗi `ReportPersonSection`:
- Tên.
- Seller phụ trách hôm đó.
- Đã hoàn thành.
- Chờ duyệt.
- Còn mở.
- Bị vướng.
- `Cần quản lý xử lý`.

Task item có deep link.  
Không hiển thị selfie/lý do nghỉ riêng tư.

---

## P28 — `/notifications`

List grouped:
- Hôm nay.
- Hôm qua.
- Cũ hơn.

Row:
- Icon semantic 18px.
- Title 14/500.
- Body 13 secondary.
- Time 12 muted.
- Unread marker nhỏ, không dùng card màu lớn.

Actions:
- `Đánh dấu đã đọc`.
- `Đánh dấu tất cả đã đọc`.

Deep link đúng task/request/report.

---

## P29 — `/settings/*`

Settings left sub-nav desktop, stacked mobile.

Sections:
- Workspace.
- Seller defaults nếu có.
- Mạng văn phòng.
- Reminder rules.
- Báo cáo 18:00.
- Data/privacy.

Form max width 760px.  
Save bar chỉ xuất hiện khi dirty hoặc button cuối section rõ.

---

## P30 — `/account`

- Họ tên.
- Email read-only/changing according auth flow.
- Chuyên môn read-only nếu admin-managed.
- Thiết bị/notification permissions.
- Đăng xuất.

Không có avatar upload V1.

---

## P31/P32 — System jobs / audit

Admin-only data tables, mật độ cao vừa phải.

System jobs:
- Job.
- Run time.
- Status.
- Duration.
- Retry count.
- Error summary.

Audit:
- Time.
- Actor.
- Action.
- Object.
- Summary.

Detail drawer để xem diff. Không show secret/token/raw sensitive evidence.

---

# 23. RESPONSIVE BEHAVIOR CHI TIẾT

## 23.1. 1440+

- Sidebar 252.
- Main page padding 28.
- Table full.
- Drawers 680.
- 4 KPI cards một hàng.

## 23.2. 1280

- Sidebar 240.
- Main padding 24.
- Table vẫn full, có thể giảm optional columns.
- KPI 4 hoặc 2x2 tùy width thực.

## 23.3. 1024

- Sidebar 224 hoặc collapsed rail.
- Filters wrap tối đa 2 hàng; ưu tiên search + 2 filter chính, phần còn lại `Bộ lọc`.
- Task table ẩn cột ít quan trọng vào secondary line/menu.

## 23.4. 768–1023

- Rail 72 hoặc overlay nav.
- Two-column detail → one column.
- Drawer có thể 80–90vw nhưng max 720.
- Table chuyển list/card ở task/person/approval.

## 23.5. <768

- Bottom nav.
- Page padding 16.
- Button touch target 44.
- Task list = card.
- Form fields stack.
- Date + time stack nếu không đủ 340px content.
- Sticky bottom action cho form/task CTA, có safe-area.
- Modal lớn → full-screen sheet.
- Không cho horizontal scroll toàn page.

## 23.6. 390px acceptance viewport

Mọi core flow phải usable ở 390px:

- Today.
- Open task.
- Receive/start/update task.
- Submit result.
- Attendance check-in/out.
- Create request.
- Notification deep link.

Text không bị clip và CTA không bị bottom nav che.

---

# 24. ACCESSIBILITY

MUST để phase UI PASS:

1. Contrast text/action đạt mức phù hợp WCAG AA cho nội dung thường.
2. Focus ring luôn thấy được với keyboard.
3. Tab order theo visual order.
4. Modal/drawer focus trap; trả focus về trigger khi đóng.
5. `Esc` đóng overlay khi không gây mất dữ liệu; dirty form hỏi xác nhận.
6. Input có `<label>` thật hoặc accessible label.
7. Error dùng `aria-describedby` và `aria-invalid`.
8. Icon-only button có label.
9. Checkbox/radio có clickable label.
10. Table có header semantics.
11. Status không chỉ màu; có text.
12. Skeleton không được screen reader đọc như nội dung thật.
13. Toast important dùng live region phù hợp, không spam.
14. Reduced motion được tôn trọng.
15. Mobile touch target >=44x44 cho hành động chính.

---

# 25. LOADING, CACHE, REALTIME VÀ UX KHI DỮ LIỆU THAY ĐỔI

## 25.1. Initial load

- Page skeleton theo layout.
- Không render `0` rồi đổi thành số thật nếu chưa load.

## 25.2. Background refresh

- Giữ dữ liệu cũ.
- Có subtle loading indicator ở toolbar nếu cần.
- Không blank page.

## 25.3. Mutation

- Disable submit.
- Không optimistic-create task nếu backend có thể từ chối do scope; chờ commit rồi toast success.
- Với checkbox checklist có thể optimistic nếu server contract/versioning cho phép; rollback rõ khi fail.

## 25.4. Realtime

- Row/task detail cập nhật không reset scroll.
- Nếu user đang edit field bị thay đổi bởi người khác, không silently overwrite; show conflict banner theo backend version policy.
- Notification count cập nhật nhẹ.

## 25.5. Offline

- Banner persistent.
- Read cache được phép với nhãn chưa mới.
- Mutation không giả success. Nếu product sau này hỗ trợ offline queue, phải có status explicit; V1 không tự invent.

---

# 26. FRONT-END PERMISSION UX

- Menu item không có quyền: ẩn khỏi sidebar.
- Button không được phép: thường ẩn; nếu user cần hiểu vì sao action không dùng được, disabled + tooltip/copy.
- Resource mất quyền sau khi đang mở: clear sensitive state/cache và show generic no-access.
- Manager không có HR permission không thấy attendance evidence hoặc lý do nghỉ chi tiết.
- Global search không gợi ý dữ liệu ngoài scope.
- Frontend gate không thay backend authorization.

---

# 27. FRONT-END CODE STYLE

## 27.1. Không dùng magic style

Không:

```tsx
style={{ color: '#5b5ce2', marginTop: 19, borderRadius: 13 }}
```

Dùng token hoặc utility mapped token.

## 27.2. Variant handling

Có thể dùng `class-variance-authority` hoặc pattern tương đương để quản lý `Button`, `Badge`, `Alert`. Không tạo chuỗi conditional class lộn xộn ở từng page.

Ví dụ concept:

```ts
type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'dangerSubtle';
type ButtonSize = 'sm' | 'md' | 'lg';
```

## 27.3. Form

- Schema validation dùng shared contract/Zod nếu stack đang dùng.
- Server error map về field hoặc form-level error.
- Khi API fail, giữ nguyên draft.
- Dirty state trước close/navigation.

## 27.4. State ownership

- Server state: query library/cache layer.
- Form draft: form state.
- UI-only state: local state.
- Filters shareable: URL query.
- Không copy server object vào global store chỉ vì tiện.

## 27.5. CSS/Tailwind

Nếu dùng Tailwind:
- Theme map toàn bộ color/spacing/radius/font token.
- Hạn chế arbitrary values.
- Component primitives chịu trách nhiệm states.

Nếu dùng CSS Modules/CSS-in-JS:
- Vẫn phải dùng CSS vars/token.

---

# 28. VISUAL REGRESSION VÀ FRONT-END TEST GATE

Mỗi phase có UI phải chạy tối thiểu:

## 28.1. Viewport matrix

- 1440x900.
- 1280x800.
- 1024x768.
- 768x1024.
- 390x844.

## 28.2. State matrix

Cho từng page quan trọng:

- Loading.
- Data loaded.
- Empty.
- API error.
- Permission-limited.
- Long text.
- Many rows.
- Mobile.

## 28.3. Interaction tests

- Keyboard open/close modal.
- Form validation focus first error.
- Dirty form confirm.
- Double click submit không tạo duplicate UI action.
- Filter giữ sau refresh.
- Deep link reload không mất context.
- Sidebar active đúng route.
- Mobile bottom nav không che CTA.

## 28.4. Visual acceptance against `UI_REFERENCE.png`

Không cần pixel-perfect nội dung vì app khác nghiệp vụ, nhưng phải PASS các điểm:

- [ ] Canvas xám nhạt.
- [ ] App/main surface trắng.
- [ ] Sidebar sáng, không dark.
- [ ] Active nav trắng nhẹ.
- [ ] Border mảnh.
- [ ] Shadow tối thiểu.
- [ ] Typography gần đen/xám, hierarchy rõ.
- [ ] Spacing thoáng, không chật.
- [ ] Button primary gần đen.
- [ ] Accent chỉ dùng vừa phải.
- [ ] Checkbox checked gần đen + tick trắng.
- [ ] Table header xám rất nhạt.
- [ ] Không avatar.
- [ ] Không gradient lớn.
- [ ] Không card dashboard đầy màu.

## 28.5. Front-end phase chỉ PASS khi

```text
Build                  PASS
Typecheck              PASS
Lint                   PASS
Unit component tests   PASS
E2E relevant flows     PASS
Keyboard navigation    PASS
Responsive matrix      PASS
Loading state          PASS
Empty state            PASS
Error state            PASS
Permission UX          PASS
Visual checklist       PASS
```

Nếu một core viewport vỡ layout thì phase frontend = FAIL.

---

# 29. DESIGN QA CHECKLIST THEO COMPONENT

## Button
- [ ] Đúng height token.
- [ ] Đúng variant.
- [ ] Hover/focus/disabled/loading đủ.
- [ ] Mobile >=44px hit target.
- [ ] Wording là động từ rõ.

## Input
- [ ] Label thật.
- [ ] Height 40 desktop / 44 mobile.
- [ ] Focus ring.
- [ ] Error inline.
- [ ] Disabled/read-only phân biệt.

## Table
- [ ] Header 44px.
- [ ] Row min 56px.
- [ ] Border nhẹ.
- [ ] Hover.
- [ ] Sticky header nếu dài.
- [ ] Mobile strategy rõ.

## Card
- [ ] Radius 14.
- [ ] Padding 20/16.
- [ ] Không shadow nặng.
- [ ] Không màu trang trí dư thừa.

## Drawer
- [ ] Width 640–720 desktop.
- [ ] Sticky header/footer.
- [ ] Dirty confirm.
- [ ] Mobile full-screen.

## Status badge
- [ ] 24px height.
- [ ] Text + màu semantic.
- [ ] Không màu neon.

---

# 30. ANTI-PATTERNS — AI KHÔNG ĐƯỢC TỰ LÀM

1. Dùng shadcn/default component mà không theme, dẫn đến giao diện mỗi component một style.
2. Sidebar đen/tím vì “dashboard hiện đại”.
3. Header có gradient hero.
4. Avatar tròn ở mọi nhân sự.
5. Mỗi seller một màu card riêng.
6. Dùng 20px radius cho tất cả button/input làm giao diện quá pill.
7. Button primary tím toàn app; primary của OpsDesk là gần đen.
8. Typography 700/800 quá nhiều.
9. Table row cao 72–80px không cần thiết, làm quản lý xem ít dữ liệu.
10. Table quá dày 36px khiến khó đọc.
11. Trộn checkbox selection với completion.
12. Nút hoàn thành task một chạm nếu nghiệp vụ yêu cầu kết quả.
13. Chỉ có spinner center page, không skeleton.
14. Toast lỗi biến mất nhưng không có inline error.
15. Modal 1000px cho form dài thay vì drawer.
16. Mobile giữ nguyên desktop table và bắt zoom.
17. Global search hiển thị dữ liệu HR ngoài scope.
18. Offline vẫn toast `Đã lưu` khi server chưa nhận.
19. Hardcode badge count/sidebar count.
20. Dùng font/asset remote không có fallback.

---

# 31. DEFINITION OF DONE RIÊNG CHO UX/UI

Một màn hình chỉ được đánh dấu UI DONE khi đủ:

1. Nội dung thật theo API contract, không mock production.
2. Đúng layout desktop + mobile.
3. Đúng spacing token.
4. Đúng typography token.
5. Đúng màu semantic.
6. Button/input đầy đủ state.
7. Loading/empty/error.
8. Permission state.
9. Long-text/truncation test.
10. Keyboard + focus test.
11. Mobile touch target test.
12. Screenshot/visual review theo reference.
13. Không avatar.
14. Không magic hex/spacing ở page.
15. E2E luồng chính PASS.

---

# 32. PROMPT KHỞI ĐẦU CHO AI FRONT-END

Dùng nguyên văn hoặc tương đương:

```text
Bạn đang triển khai OpsDesk.

Trước khi code, hãy đọc theo thứ tự:
1. DAC_TA_OPSDESK_APP_WEB_SUPABASE.md
2. PLAN_XAY_DUNG_OPSDESK_THEO_PHASE.md
3. FRONTEND_UX_UI_DESIGN_SYSTEM_OPSDESK.md
4. UI_REFERENCE.png
5. docs/IMPLEMENTATION_STATUS.md
6. docs/TEST_REPORT.md
7. docs/DECISIONS.md

FRONTEND_UX_UI_DESIGN_SYSTEM_OPSDESK.md là nguồn chi tiết nhất về layout,
spacing, color, typography, component, responsive và visual acceptance.
Đặc tả chính vẫn là nguồn nghiệp vụ/quyền/backend.

Không code toàn bộ project một lần.
Chỉ triển khai đúng phase hiện tại được PLAN cho phép.

Khi code frontend:
- dùng token, không hardcode style tùy ý;
- không avatar;
- primary button gần đen;
- sidebar và surface sáng theo UI_REFERENCE;
- form/list/table phải có loading, empty, error và permission state;
- responsive phải test 1440, 1280, 1024, 768 và 390px;
- mobile core action hit target tối thiểu 44px;
- không đánh dấu UI PASS nếu button chưa nối backend thật;
- không tự chuyển phase sau khi PASS.

Trước khi sửa code hãy liệt kê:
A. route/component của phase;
B. token/component dùng lại;
C. file sẽ tạo/sửa;
D. state cần hỗ trợ;
E. test sẽ chạy.

Sau khi code:
- build/typecheck/lint;
- test component/E2E liên quan;
- kiểm tra responsive;
- kiểm tra keyboard/focus;
- cập nhật TEST_REPORT và IMPLEMENTATION_STATUS;
- báo PASS/FAIL/BLOCKED;
- STOP.
```

---

# 33. THỨ TỰ ƯU TIÊN KHI AI KHÔNG ĐỦ CONTEXT

Nếu model code yếu hoặc context hạn chế, mỗi phase chỉ cần tải phần sau:

```text
1. Mục nghiệp vụ liên quan trong DAC_TA...
2. Phase hiện tại trong PLAN...
3. Mục 0–7 của file frontend này (foundation)
4. Component section liên quan
5. Route Pxx tương ứng ở mục 22
6. Mục 23–31 để test/acceptance
```

Không được bỏ đọc token rồi tự suy đoán style.

---

# 34. KẾT LUẬN THIẾT KẾ

OpsDesk không phải một dashboard SaaS nhiều màu. Đây là công cụ làm việc hằng ngày cho team vận hành 5–10 người. Giao diện phải ưu tiên:

1. **Biết ngay hôm nay phải làm gì.**
2. **Giao task và cập nhật task ít thao tác.**
3. **Nhìn trạng thái bằng text/spacing rõ hơn bằng màu.**
4. **Quản lý được nhiều dòng dữ liệu trên desktop mà vẫn thoáng.**
5. **Mobile thao tác nhanh, button đủ lớn, không bê nguyên table desktop.**
6. **Chấm công và HR có privacy rõ, không trộn vào profile/summary công khai.**
7. **Mọi màn hình nhìn cùng một sản phẩm**, không phải tập hợp component từ nhiều template khác nhau.

Nếu AI phân vân giữa “trang trí đẹp hơn” và “đúng hệ thống này hơn”, ưu tiên phương án ít trang trí hơn, rõ cấu trúc hơn và bám token trong file này.
