# OPSDESK — FRONT-END REDESIGN SPEC (CLICKUP-INSPIRED)

**Version:** 1.0  
**Purpose:** Tài liệu dùng để **refactor / redesign front-end sau khi project core đã hoàn tất**, không dùng để thay đổi backend hiện tại trong lúc dự án còn đang code nghiệp vụ.  
**Scope:** Web app + mobile responsive behavior + shared design system.  
**Product:** OpsDesk — hệ thống quản lý công việc, seller, nhân sự, chấm công và báo cáo cho team vận hành thương mại điện tử.  
**Database / backend hiện tại:** Supabase; giữ nguyên contracts, schema, RLS, RPC và business rules trừ khi có quyết định riêng.  
**Ngôn ngữ UI:** Tiếng Việt.  

---

# 0. CHỈ THỊ QUAN TRỌNG CHO AI / DEVELOPER

## 0.1. Không triển khai file này ngay khi project nghiệp vụ còn chưa hoàn tất

File này là **spec dành cho giai đoạn redesign front-end sau khi toàn bộ core feature đã chạy ổn định**.

AI/developer phải hiểu đúng:

- **Không được tự ý dừng phase backend hiện tại để redesign UI.**
- **Không được đổi schema Supabase chỉ để phù hợp giao diện.**
- **Không được rewrite logic nghiệp vụ đang PASS chỉ vì UI mới cần dữ liệu khác cách trình bày.**
- Khi chủ dự án nói rõ: **“Bắt đầu fix lại frontend theo file ClickUp”** thì mới thực hiện file này.
- Nếu feature chưa tồn tại, vẫn giữ placeholder thiết kế trong spec nhưng không giả lập dữ liệu production.

## 0.2. Mục tiêu redesign

OpsDesk không copy ClickUp nguyên bản. Mục tiêu là:

> **Lấy cấu trúc thao tác, mật độ thông tin và trải nghiệm quản lý task kiểu ClickUp, nhưng giữ giao diện gọn, sáng, dễ đọc và đơn giản hơn cho team 5–10 người.**

Các đặc điểm cần đạt:

- Sidebar workspace rõ ràng.
- Task List là trung tâm.
- List / Board / Calendar là 3 view chính.
- Quick Add Task cực nhanh.
- Task Detail mở dạng side drawer/panel.
- Filter / Group / Sort nằm ngay toolbar.
- Seller là phạm vi công việc quan trọng.
- Today/My Work tối ưu cho nhân viên.
- Inbox tối ưu cho việc cần phản hồi.
- Tránh dashboard quá nhiều biểu đồ.
- Không avatar.
- Không màu sắc rối.
- Không copy logo, icon độc quyền, asset hoặc pixel-perfect layout từ ClickUp.

## 0.3. Thứ tự ưu tiên nguồn yêu cầu

Khi triển khai redesign, đọc theo thứ tự:

1. `DAC_TA_OPSDESK_APP_WEB_SUPABASE.md` — nghiệp vụ/backend là nguồn sự thật.
2. `PLAN_XAY_DUNG_OPSDESK_THEO_PHASE.md` — quy trình kiểm thử và gate.
3. `FRONTEND_REDESIGN_CLICKUP_STYLE_OPSDESK.md` — file này, quyết định frontend mới.
4. `FRONTEND_UX_UI_DESIGN_SYSTEM_OPSDESK.md` — spec cũ, chỉ tham khảo những phần không mâu thuẫn.
5. `docs/IMPLEMENTATION_STATUS.md` — trạng thái thực tế repo.
6. `docs/DECISIONS.md` — các quyết định mới hơn.

Nếu file frontend cũ mâu thuẫn file này, **file này thắng về UX/UI sau khi redesign bắt đầu**.

---

# 1. ĐỊNH HƯỚNG SẢN PHẨM SAU REDESIGN

## 1.1. Mental model

Người dùng cần cảm giác:

- Vào app → biết hôm nay làm gì.
- Quản lý → biết team đang làm gì.
- Vào seller → thấy mọi task liên quan seller đó.
- Click task → thao tác ngay trong panel, không bị điều hướng qua nhiều trang.
- Tạo task → chỉ cần vài trường cơ bản.
- Muốn chi tiết → mở thêm tùy chọn nâng cao.
- Không cần đọc dashboard dài mới biết vấn đề.

## 1.2. Ba trụ cột UI

### A. Navigation-first

Sidebar phải cho người dùng biết mình đang ở đâu, đang xem seller nào, module nào.

### B. Task-list-first

Task list là màn hình quan trọng nhất, không phải dashboard biểu đồ.

### C. Progressive disclosure

Thông tin nâng cao chỉ mở khi cần:

- Daily task
- Reviewer
- Checklist
- Evidence
- Reminder
- Attachment
- Advanced filters

Không bày mọi field ngay từ đầu.

---

# 2. INFORMATION ARCHITECTURE MỚI

## 2.1. Sidebar desktop

Cấu trúc đề xuất:

```text
OpsDesk

HOME
  Hôm nay
  Inbox
  Lịch

CÔNG VIỆC
  Công việc của tôi
  Tất cả công việc
  Daily Tasks

SELLERS
  Shopee · Seller A
  TikTok · Seller B
  Shopee · Seller C
  + Quản lý seller

TEAM
  Nhân sự
  Chấm công
  Đơn từ
  Bảng công

MANAGEMENT
  Báo cáo
  Phê duyệt

────────────────────
Cài đặt
```

### Quy tắc

- Không hiển thị avatar user.
- Có thể hiển thị tên user dạng text ở footer/sidebar bottom.
- Seller list tối đa 8 seller trước khi dùng `Xem thêm`.
- Seller đang active có background nhạt, text đậm hơn.
- Module đang active có left indicator 2px hoặc background nhẹ, không tô màu đậm toàn hàng.
- Count badge chỉ hiển thị nếu > 0.
- Badge không dùng màu đỏ trừ trường hợp lỗi/overdue thực sự.

## 2.2. Mobile navigation

Dưới 768px, sidebar chuyển thành bottom navigation:

```text
Hôm nay | Công việc | Chấm công | Inbox | Thêm
```

`Thêm` mở bottom sheet chứa:

- Seller
- Lịch
- Nhân sự
- Đơn từ
- Báo cáo
- Cài đặt

---

# 3. DESIGN TOKENS

## 3.1. Font

**Primary:** Inter  
Fallback:

```css
font-family:
  Inter,
  system-ui,
  -apple-system,
  BlinkMacSystemFont,
  "Segoe UI",
  sans-serif;
```

## 3.2. Font weight

```text
400 = Regular
500 = Medium
600 = Semibold
700 = chỉ dùng cực hạn chế cho số lớn / tiêu đề đặc biệt
```

Không dùng 800/900.

## 3.3. Type scale

```text
Page title            24px / 32px / 600
Section title         16px / 24px / 600
Panel title           18px / 26px / 600
Task title            14px / 20px / 500
Body                  14px / 22px / 400
Body strong           14px / 22px / 500
Form label            13px / 20px / 500
Meta                  12px / 18px / 400
Meta strong           12px / 18px / 500
Tiny label            11px / 16px / 500
```

## 3.4. Color tokens

### Neutral

```css
--bg-app: #f7f8fa;
--bg-sidebar: #f5f6f8;
--bg-surface: #ffffff;
--bg-hover: #f5f6f8;
--bg-selected: #eef0f4;

--border-subtle: #eceef2;
--border-default: #dfe2e7;
--border-strong: #cfd4dc;

--text-primary: #202124;
--text-secondary: #5f6368;
--text-muted: #8a9099;
--text-disabled: #b8bdc5;
```

### Brand/accent

```css
--accent: #6c5ce7;
--accent-hover: #5d50cc;
--accent-soft: #f0edff;
--accent-border: #d8d1ff;
```

Accent chỉ dùng có chủ đích:

- focus
- active tab
- highlight nhỏ
- link quan trọng
- recurring/daily indicator

Không dùng accent làm màu cho mọi button.

### Semantic

```css
--success: #23865f;
--success-soft: #edf8f3;

--warning: #a66a14;
--warning-soft: #fff7e7;

--danger: #c74646;
--danger-soft: #fff0f0;

--info: #4776d0;
--info-soft: #eef4ff;
```

## 3.5. Radius

```text
4px   tiny tag
6px   compact controls
8px   default button/input/dropdown
10px  cards / panel inner
12px  modal/drawer sections
14px  large card
```

Không dùng radius 20–24px hàng loạt.

## 3.6. Shadow

Giao diện chủ yếu dùng border, không dùng shadow nặng.

```css
--shadow-popover:
  0 8px 24px rgba(16, 24, 40, 0.08),
  0 2px 8px rgba(16, 24, 40, 0.05);

--shadow-drawer:
  -8px 0 24px rgba(16, 24, 40, 0.08);
```

## 3.7. Spacing scale

```text
2px
4px
6px
8px
10px
12px
16px
20px
24px
28px
32px
40px
48px
```

Không dùng spacing tùy ý 13px, 19px, 27px trừ trường hợp icon alignment đặc biệt.

---

# 4. APP SHELL

## 4.1. Desktop >= 1280px

```text
Sidebar       240px
Topbar         52px
Content max    none, fluid
Content pad X  24px
Content pad Y  20px
```

## 4.2. Desktop 1024–1279px

```text
Sidebar       216px
Content pad X  20px
```

## 4.3. Tablet 768–1023px

- Sidebar collapsed rail: 64px.
- Seller list ẩn vào popover.
- Main content full width.
- Task table giảm cột.

## 4.4. Mobile < 768px

- Không sidebar.
- Bottom navigation 56px.
- Topbar 52px.
- Page padding 12–16px.
- Task row biến thành task card.

---

# 5. SIDEBAR COMPONENT

## 5.1. Kích thước

```text
Width desktop       240px
Padding top         12px
Padding x           10px
Section gap         18px
Nav item height     36px
Nav item radius      7px
Icon                16px
Text                13px / 500
Count               11px / 500
```

## 5.2. Section label

```text
Font       11px / 600
Color      text-muted
Uppercase  yes
Letter     0.04em
Padding X  8px
Margin B   6px
```

## 5.3. Active state

```css
background: #eceff3;
color: #202124;
font-weight: 600;
```

Có thể có indicator trái 2px accent, nhưng không bắt buộc.

---

# 6. TOPBAR / PAGE HEADER

## 6.1. Global topbar

Height: 52px.

Bên trái:

- breadcrumb ngắn
- title hiện tại

Bên phải:

- Search global
- Quick Create
- Notification
- User menu text

## 6.2. Page header

Page header nằm trong content:

```text
Title                         [Primary action]
Subtitle / meta               [Secondary action]
```

Không dùng hero header lớn.

---

# 7. BUTTON SYSTEM

## 7.1. Size

```text
XS  28px
SM  32px
MD  36px
LG  40px
```

Default web: `SM` hoặc `MD`.

## 7.2. Primary

```css
height: 36px;
background: #202124;
color: #fff;
border: 1px solid #202124;
border-radius: 8px;
padding: 0 12px;
font-size: 13px;
font-weight: 500;
```

Hover:

```css
background: #34363a;
```

## 7.3. Secondary

```css
background: #fff;
border: 1px solid #dfe2e7;
color: #202124;
```

## 7.4. Ghost

```css
background: transparent;
border: none;
color: #5f6368;
```

Hover: `#f1f3f5`.

## 7.5. Danger

Chỉ dùng cho xóa/hủy có hậu quả.

## 7.6. Icon button

```text
32x32 desktop
36x36 mobile
Icon 16px
```

Tooltip bắt buộc nếu icon không tự giải thích.

---

# 8. INPUT SYSTEM

## 8.1. Text input

```text
Height             36px
Mobile min         44px
Padding X          10px
Border             1px solid #dfe2e7
Radius             8px
Font               13px / 400
Placeholder        #9aa0a8
```

Focus:

```css
border-color: #6c5ce7;
box-shadow: 0 0 0 3px rgba(108, 92, 231, 0.10);
```

## 8.2. Search input

- Icon trái 16px.
- Clear button phải 28px.
- Có keyboard shortcut hiển thị khi desktop.

## 8.3. Select / Combobox

- Height 36px.
- Dropdown width tối thiểu 220px.
- Searchable nếu > 8 items.
- Person picker không dùng avatar, chỉ tên + role/specialty.
- Seller picker hiển thị platform + seller name.

## 8.4. Textarea

```text
Min height 96px
Max auto grow 240px
Padding 10px 12px
```

## 8.5. Checkbox

```text
16x16
Radius 4px
Border 1.5px
```

Task row selection checkbox **không dùng để complete task**.

## 8.6. Switch

```text
Width 34px
Height 20px
Thumb 16px
```

Dùng cho setting on/off, không dùng thay checkbox trong form multiple selection.

---

# 9. TASK LIST — CORE EXPERIENCE

## 9.1. Task toolbar

Thứ tự:

```text
[List] [Board] [Calendar]

Search | Filter | Group | Sort | Fields

                           + Tạo task
```

### Quy tắc

- View switcher bên trái.
- Filters giữa.
- Primary action bên phải.
- Trên mobile: controls gói vào `Filter` sheet.

## 9.2. Group header

Ví dụ:

```text
▾ CHƯA BẮT ĐẦU          6                           + Add task
```

Kích thước:

```text
Height      36px
Text        12px / 600
Uppercase   optional
Background  transparent hoặc #fafbfc
Border B    1px
```

## 9.3. Task row desktop

Default height: **44px**.

Grid đề xuất:

```text
36px                 Selection
minmax(280px, 1fr)   Task
140px                Seller
140px                Assignee
120px                Due date
112px                Status
80px                 Priority
36px                 More
```

### Task title area

Có thể gồm:

```text
[icon recurring] Task title
                 small meta/checklist progress
```

Không cho title bị ellipsis quá sớm; width min 280px.

## 9.4. Row states

### Default
White.

### Hover
`#f8f9fb`.

### Selected
`#f0f1f5`.

### Overdue
Không tô đỏ toàn hàng. Chỉ:

- due text đỏ
- small overdue badge

### High priority
Icon/chip nhỏ, không đổi background toàn task.

## 9.5. Quick add task row

Cuối mỗi group có:

```text
+ Thêm công việc
```

Click → inline input:

```text
[Tên công việc________________] [Assignee] [Due] [Enter để tạo]
```

Tạo nhanh xong mới có thể mở panel để bổ sung.

---

# 10. VIEW: LIST

List là view mặc định.

Các chức năng:

- group by status
- group by seller
- group by assignee
- group by due date
- sort
- filter
- field visibility

Default seller page: group by status.
Default My Tasks: group by due date/status tùy trang.

---

# 11. VIEW: BOARD

## 11.1. Column

Default theo status.

```text
Column width: 280px
Gap: 12px
Header: 40px
Card gap: 8px
```

## 11.2. Task card

```text
Title
Seller
Assignee text
Due date
Priority
Checklist progress
```

Không avatar.

Card padding 10–12px.

Drag/drop chỉ update khi backend confirm, optimistic phải rollback nếu fail.

---

# 12. VIEW: CALENDAR

## 12.1. Month view

Hiển thị task theo due date.

Task chip:

```text
09:00 Kiểm tra tồn kho
Seller A
```

Không nhồi quá 3 task mỗi cell, còn lại `+4 việc khác`.

## 12.2. Week view

Có giờ.

Daily task recurrence có icon riêng.

---

# 13. TASK DETAIL DRAWER

## 13.1. Behavior

- Desktop: drawer bên phải.
- Width: 520px default.
- Có thể expand 720px.
- Mobile: full-screen page/sheet.
- URL phải thay đổi để deep-link được.
- Refresh giữ đúng task detail.

## 13.2. Header

```text
TSK-000123     [Daily] [•••]
Kiểm tra tồn kho Seller A
```

Title edit inline.

## 13.3. Core fields

Hiển thị compact 2-column labels:

```text
Trạng thái     Đang làm
Người làm      Linh
Seller         Seller A · Shopee
Deadline       Hôm nay, 10:00
Ưu tiên        Cao
Reviewer       Nam
```

## 13.4. Content sections

```text
Mô tả
Checklist
Kết quả
Tệp đính kèm
Trao đổi
Lịch sử
```

Các section có divider nhẹ.

## 13.5. Footer action

Sticky bottom nếu task còn thao tác:

```text
[Nhận việc] [Bắt đầu] [Nộp kết quả]
```

Chỉ show action hợp lệ theo state.

---

# 14. CREATE TASK DRAWER

## 14.1. Default simple mode

Chỉ show:

```text
Tên công việc
Người phụ trách
Seller
Deadline
Priority

[+ Thêm tùy chọn]
```

Button:

```text
Hủy                     Tạo công việc
```

## 14.2. Advanced options

Khi mở:

- Mô tả
- Checklist
- Collaborators
- Reviewer
- Daily task
- Reminder
- Evidence requirement
- Attachment
- Estimated time

## 14.3. Daily task section

Checkbox:

```text
□ Daily task — Tự động lặp lại
```

Khi bật:

```text
Lặp lại             Theo lịch làm việc
Bắt đầu             05/10/2026
Kết thúc            Không giới hạn
Giờ đến hạn         10:00
Phân công           Người hiện tại
Khi nghỉ            Yêu cầu người thay
```

Preview 7 lần tiếp theo ở dưới.

---

# 15. TODAY / MY WORK

Đây là trang mặc định của employee sau login.

## 15.1. Header

```text
Hôm nay
Thứ Hai, 05 tháng 10
```

Bên phải:

- `+ Tạo task`
- quick attendance status nếu liên quan

## 15.2. Summary strip

4 chỉ số nhỏ, không dùng card lớn:

```text
Cần làm        8
Sắp đến hạn    2
Quá hạn        1
Chờ duyệt      2
```

Có divider, không quá nhiều màu.

## 15.3. Sections

```text
Việc mới cần nhận
Cần làm hôm nay
Quá hạn
Đang chờ / Bị vướng
Đã hoàn thành hôm nay
```

Mỗi section dùng same task row component.

---

# 16. INBOX

Inbox chỉ chứa item cần phản hồi/attention:

- task mới giao chưa nhận
- mention
- request approval
- task returned
- overdue reminder
- attendance exception

Không biến inbox thành activity log toàn hệ thống.

Item layout:

```text
[Type icon] Nội dung chính
            Meta · thời gian
            [Action nếu cần]
```

Read/unread bằng weight/background, không dùng chấm màu quá nhiều.

---

# 17. SELLER WORKSPACE

## 17.1. Seller header

```text
Seller A
Shopee · Brand X

[List] [Board] [Calendar]
```

Sub tabs:

```text
Công việc
Daily tasks
Thành viên
Tổng quan
```

## 17.2. Seller overview

Chỉ cần:

- task hôm nay
- overdue
- chờ duyệt
- người phụ trách
- daily tasks đang active

Không cần dashboard biểu đồ marketing nếu chưa có dữ liệu seller API.

---

# 18. DAILY TASKS PAGE

Table/List:

```text
Tên mẫu
Seller
Assignee rule
Lịch lặp
Giờ hạn
Lần tiếp theo
Trạng thái
```

Click template mở detail drawer.

Action:

- pause
- edit future occurrences
- duplicate
- stop

Không sửa ngược lịch sử occurrence đã sinh.

---

# 19. TEAM PAGE

Không avatar.

Table:

```text
Tên
Role
Chuyên môn
Seller phụ trách
Trạng thái hôm nay
Task đang mở
```

Employee row click mở detail panel.

Không hiển thị selfie ở team page.

---

# 20. ATTENDANCE PAGE

## 20.1. Employee view

Top section:

```text
Ca hôm nay
09:00–18:00
Trạng thái: Chưa chấm vào

[Chấm vào]
```

Sau check-in:

```text
Đã chấm vào 08:57
[Chấm ra]
```

Dưới:

- lịch sử 7 ngày
- yêu cầu điều chỉnh
- công tạm tính tháng

## 20.2. Manager/Admin attendance monitor

Table:

```text
Nhân sự
Hình thức
Chấm vào
Chấm ra
Trạng thái
Ngoại lệ
```

Selfie chỉ mở trong evidence drawer nếu user có quyền.

---

# 21. REQUESTS / APPROVALS

## 21.1. Request types

Tabs:

```text
Tất cả
Nghỉ phép
Về sớm
Đi muộn
Làm online
Bổ sung chấm công
```

## 21.2. Request row

```text
Tên nhân sự
Loại yêu cầu
Thời gian
Trạng thái
Gửi lúc
```

Click → side panel.

Approval CTA:

```text
[Từ chối] [Yêu cầu bổ sung] [Duyệt]
```

---

# 22. TIMESHEET / BẢNG CÔNG

Monthly header:

```text
Bảng công · Tháng 10/2026
< Tháng trước   Tháng sau >
```

Summary:

```text
Công thực làm
Nghỉ hưởng lương
Nghỉ không lương
Đi muộn
Về sớm
Thiếu dữ liệu
```

Table giữ compact, hỗ trợ horizontal scroll trên tablet.

---

# 23. REPORTS PAGE

## 23.1. Daily 18:00 report list

```text
Ngày
Cutoff
Trạng thái
Nhân sự
Task hoàn thành
Task còn mở
Vấn đề cần quản lý
```

Click report mở detail.

## 23.2. Report detail

Layout:

```text
Tổng quan ngày

Linh
- Hoàn thành ...
- Còn mở ...
- Cần hỗ trợ ...

Nam
...
```

Không đưa selfie hoặc lý do nghỉ chi tiết vào đây.

---

# 24. FILTER / SORT / GROUP SYSTEM

## 24.1. Filter button

Hiển thị count nếu active:

```text
Filter 3
```

Popover chứa:

- Status
- Assignee
- Seller
- Due date
- Priority
- Daily / one-off
- Overdue
- Reviewer

## 24.2. Group

Options:

- Status
- Seller
- Assignee
- Due date
- Priority
- None

## 24.3. Sort

- Deadline
- Priority
- Created time
- Updated time
- Task name

---

# 25. STATUS SYSTEM

Không dùng màu quá mạnh.

```text
Chưa bắt đầu    neutral gray
Đang làm        soft blue
Chờ duyệt       soft purple
Hoàn thành      soft green
Bị vướng        soft orange
Quá hạn         soft red / derived label
```

Badge height 22px.
Font 11–12px / 500.

---

# 26. PRIORITY SYSTEM

```text
Thấp       gray
Bình thường neutral
Cao        orange
Khẩn       red
```

Priority dùng icon nhỏ + label khi đủ chỗ.

Không dùng background card toàn màu.

---

# 27. ICONOGRAPHY

Dùng một icon library nhất quán, ví dụ Lucide.

Default size:

```text
14px compact
16px standard
18px large controls
20px mobile primary nav
```

Stroke 1.5–2.

Không mix nhiều icon style.

---

# 28. DROPDOWN / POPOVER / CONTEXT MENU

## 28.1. Popover

```text
Min width 220px
Radius 10px
Padding 6px
Item height 34px
```

## 28.2. Context menu

Task `•••`:

```text
Mở chi tiết
Đổi người phụ trách
Đổi deadline
Nhân bản
Chuyển seller
────────────────
Xóa task
```

Chỉ show hành động user có quyền.

---

# 29. MODAL / DRAWER

Ưu tiên drawer cho object detail.

Modal chỉ dùng cho:

- confirm destructive action
- small setup
- invite member
- simple decision

Không dùng modal 900px cho form dài.

---

# 30. TOAST / FEEDBACK

Toast bottom-right desktop, bottom mobile.

```text
Success  3–4s
Error    persistent until close hoặc 6–8s
```

Toast chỉ xuất hiện sau backend success thực.

Ví dụ:

```text
Đã tạo công việc.
Đã cập nhật deadline.
Không thể lưu thay đổi. Thử lại.
```

---

# 31. LOADING STATES

Không dùng spinner full-screen cho mọi thứ.

### Table
Skeleton rows.

### Drawer
Skeleton fields.

### Button submit
Spinner nhỏ + text:

```text
Đang lưu...
```

### Background refresh
Không chặn UI.

---

# 32. EMPTY STATES

Ngắn, action-oriented.

Ví dụ:

```text
Chưa có công việc hôm nay.
Các task được giao hoặc daily task sẽ xuất hiện tại đây.
```

CTA nếu user có quyền:

```text
+ Tạo công việc
```

Không dùng illustration lớn.

---

# 33. ERROR STATES

## 33.1. Inline

Field error ngay dưới input.

## 33.2. Page error

```text
Không thể tải dữ liệu.
[Thử lại]
```

## 33.3. Permission denied

```text
Bạn không có quyền xem nội dung này.
```

Không redirect silently nếu user đã deep-link tới page hợp lệ nhưng thiếu quyền.

---

# 34. RESPONSIVE BREAKPOINTS

```text
>= 1440   Large desktop
1280–1439 Desktop
1024–1279 Small desktop
768–1023  Tablet
< 768     Mobile
```

Test bắt buộc:

```text
1440x900
1280x800
1024x768
768x1024
390x844
```

---

# 35. MOBILE TASK CARD

Khi < 768px, table row đổi thành card compact:

```text
Kiểm tra tồn kho
Seller A · Shopee

Đang làm          Hôm nay 10:00
Linh               Cao
```

Card padding 12px.
Gap 8px.
No heavy shadow.

Swipe action không bắt buộc V1 redesign.

---

# 36. KEYBOARD SHORTCUTS

Desktop SHOULD:

```text
C              Create task
/              Focus search
Esc            Close drawer/popover
Ctrl/Cmd + K   Command menu
```

Không override shortcut phổ biến của browser nếu xung đột.

---

# 37. COMMAND MENU

Optional but recommended.

`Ctrl/Cmd + K` mở:

```text
Tạo task
Đi tới Hôm nay
Đi tới Inbox
Mở Seller A
Mở Chấm công
Tìm task...
```

Command menu không thay search global.

---

# 38. SEARCH GLOBAL

Search kết quả chia nhóm:

```text
Tasks
Sellers
People
Reports
```

Không search selfie/evidence.

---

# 39. ACCESSIBILITY

MUST:

- focus visible
- keyboard navigation cơ bản
- aria-label icon-only controls
- contrast đạt mức đọc tốt
- touch target mobile >= 44px
- error không chỉ thể hiện bằng màu

---

# 40. ANIMATION

Rất nhẹ.

```text
Hover     100–150ms
Drawer    180–220ms
Popover   120–160ms
```

Không dùng spring/bounce quá nhiều.

---

# 41. FRONTEND ARCHITECTURE

## 41.1. Không rewrite backend

Frontend redesign phải thích nghi với API/contracts hiện tại.

## 41.2. Component groups

Đề xuất:

```text
components/
  app-shell/
  navigation/
  tasks/
  sellers/
  attendance/
  requests/
  reports/
  ui/
```

## 41.3. Shared primitives

```text
Button
IconButton
Input
Textarea
Checkbox
Switch
Select
Combobox
Popover
DropdownMenu
Tooltip
Tabs
Badge
StatusBadge
PriorityBadge
Drawer
Modal
Table
EmptyState
ErrorState
Skeleton
Toast
```

## 41.4. Domain components

```text
TaskRow
TaskCard
TaskGroup
TaskToolbar
TaskDrawer
TaskCreateDrawer
TaskStatusSelect
AssigneePicker
SellerPicker
DueDatePicker
DailyTaskEditor
AttendanceCard
RequestRow
ReportPersonSection
```

---

# 42. STATE MANAGEMENT

Không lưu server state chính trong global store nếu không cần.

Ưu tiên:

- query cache cho server state
- local component state cho popover/form
- URL cho view/filter quan trọng

Ví dụ URL:

```text
/tasks?view=list&group=status&seller=abc&status=open
```

Task drawer:

```text
/tasks?task=tsk_123
```

---

# 43. URL / DEEP LINK RULES

Mỗi object chính phải deep-link được:

- task
- seller
- request
- timesheet
- report

Không để drawer chỉ tồn tại state local mà refresh mất.

---

# 44. DATA DENSITY RULES

Mục tiêu ClickUp-inspired nhưng bớt rối.

### Desktop

Task row 44px.
Form label compact.
Toolbar 36px controls.

### Mobile

Tăng touch target nhưng vẫn gọn.

Không dùng card 120px cho task đơn giản.

---

# 45. KHÔNG DÙNG AVATAR

Điều này giữ nguyên từ yêu cầu trước.

Thay vì avatar:

```text
Linh Nguyễn
Vận hành
```

hoặc compact:

```text
Linh Nguyễn · Vận hành
```

Không dùng circle initials.

Selfie attendance chỉ nằm trong privacy-protected evidence view.

---

# 46. ANTI-PATTERNS — AI TUYỆT ĐỐI KHÔNG LÀM

```text
❌ Copy pixel-for-pixel ClickUp
❌ Dùng logo/branding/asset ClickUp
❌ Sidebar tối màu kiểu admin template
❌ Gradient header
❌ Mỗi seller một màu rực
❌ Avatar tròn
❌ Font 700/800 khắp nơi
❌ Card shadow nặng
❌ Border radius 20px toàn app
❌ Dashboard đầy biểu đồ không cần thiết
❌ Task table hàng cao 70–90px
❌ Mobile bê nguyên table desktop
❌ Checkbox task = complete
❌ Toast success khi backend chưa thành công
❌ Mock count production
❌ Hardcode seller/user list
❌ Redesign bằng cách rewrite business logic đã PASS
```

---

# 47. MIGRATION PLAN KHI BẮT ĐẦU REDESIGN

## Phase FE-R0 — Audit UI hiện tại

- Screenshot toàn bộ page.
- Liệt kê component đang dùng.
- Xác định logic frontend có dính business logic không.
- Freeze API contracts.
- Lập visual baseline.

**Gate:** Không thay đổi behavior.

## Phase FE-R1 — Design tokens + primitives

- Font
- Color
- Spacing
- Button
- Input
- Badge
- Popover
- Drawer
- Tabs

**Gate:** Story/component test + visual check.

## Phase FE-R2 — App shell + navigation

- Sidebar
- Topbar
- Mobile nav
- Breadcrumb

**Gate:** route/permission vẫn hoạt động.

## Phase FE-R3 — Task List

- Toolbar
- Group
- TaskRow
- Filter
- Sort
- Quick Add

**Gate:** CRUD task hiện tại không regression.

## Phase FE-R4 — Task Drawer + Create Task

- Task detail side panel
- Inline edit
- Daily task progressive form

**Gate:** toàn bộ task lifecycle pass.

## Phase FE-R5 — Board + Calendar

- Board
- Drag/drop
- Calendar

**Gate:** mutation rollback + permission test.

## Phase FE-R6 — Today + Inbox

- My Work
- Notifications/action inbox

**Gate:** đúng task scope.

## Phase FE-R7 — Sellers + Team

- Seller workspace
- Team compact pages

## Phase FE-R8 — Attendance + Requests + Timesheet

- UI refactor only
- Không thay logic attendance

## Phase FE-R9 — Reports + Settings

- report readability
- admin utilities

## Phase FE-R10 — Mobile polish + accessibility

- 390px
- tablet
- keyboard
- focus

## Phase FE-R11 — Full regression

- Playwright
- permissions
- screenshots
- performance

Chỉ deploy redesign khi FE-R11 PASS.

---

# 48. VISUAL ACCEPTANCE CHECKLIST

Mỗi page phải PASS:

```text
[ ] Sidebar đúng width / state
[ ] Header gọn
[ ] Không avatar
[ ] Button hierarchy đúng
[ ] Input height đúng
[ ] Spacing theo token
[ ] Task density đúng
[ ] Status màu nhẹ
[ ] Empty/loading/error đầy đủ
[ ] Responsive 1440
[ ] Responsive 1280
[ ] Responsive 1024
[ ] Responsive 768
[ ] Responsive 390
[ ] Keyboard focus rõ
[ ] Deep link hoạt động
[ ] Không regression permission
[ ] Không fake data
```

---

# 49. FUNCTIONAL REGRESSION CHECKLIST SAU REDESIGN

Frontend đẹp nhưng nếu làm hỏng nghiệp vụ thì FAIL.

Bắt buộc test lại:

```text
Task create
Task assign
Task accept
Task start
Task submit
Task review
Task overdue
Daily recurrence
Bulk task
Seller scope
Manager scope
Employee scope
Attendance check-in
Attendance check-out
Remote selfie
Request create
Request approve/reject
Timesheet calculation display
Report 18:00 view
Notification deep link
Logout clears private cache
```

---

# 50. PERFORMANCE TARGET

Mục tiêu frontend:

- page interaction không bị lag với vài trăm task.
- virtualize nếu table > 200 rows visible.
- debounce search 200–300ms.
- không refetch toàn app khi update 1 task.
- drawer mở gần như tức thì nếu task đã có trong cache.
- optimistic update chỉ dùng nơi rollback an toàn.

---

# 51. COPY / MICROCOPY STYLE

Ngắn, trực tiếp.

Dùng:

```text
Tạo công việc
Giao cho
Đến hạn
Chờ duyệt
Đã quá hạn
Báo vướng
Nộp kết quả
```

Tránh:

```text
Vui lòng tiến hành thao tác...
Hệ thống xin thông báo...
Bạn có chắc chắn rằng bạn muốn...
```

Confirm tốt:

```text
Xóa công việc này?
Hành động này không thể hoàn tác.
```

---

# 52. PAGE-BY-PAGE REDESIGN MAPPING

| Page hiện tại | UI sau redesign |
|---|---|
| Dashboard | Hôm nay / Overview gọn |
| My Tasks | ClickUp-like List |
| All Tasks | Dense List + Filter/Group |
| Task Detail | Right Drawer |
| Create Task | Compact Drawer |
| Daily Templates | Recurring task manager |
| Calendar | Calendar view thật |
| Sellers | Workspace/list hybrid |
| Seller Detail | Seller task workspace |
| Team | Compact people table |
| Attendance | Operational status page |
| Requests | Inbox-like approval list |
| Timesheet | Monthly operational table |
| Reports | Readable management report |
| Notifications | Action Inbox |
| Settings | Dense settings sections |

---

# 53. DEFINITION OF DONE CHO REDESIGN

Không được nói “frontend đã giống ClickUp” nếu chỉ đổi CSS.

Redesign chỉ DONE khi:

1. Information architecture mới hoạt động.
2. Sidebar mới hoạt động.
3. Task List mới là core view.
4. Task Drawer hoạt động deep-link.
5. Quick Add hoạt động backend thật.
6. Filters/groups/sort hoạt động dữ liệu thật.
7. Mobile responsive đúng.
8. Không mất permission behavior.
9. Không đổi business logic đã nghiệm thu.
10. Full regression PASS.

---

# 54. PROMPT DÙNG SAU NÀY KHI CHỦ DỰ ÁN BẮT ĐẦU FIX FRONTEND

Copy prompt này cho AI code khi project core đã hoàn tất:

```text
Dự án OpsDesk đã hoàn thành core feature. Bây giờ bắt đầu phase frontend redesign.

Đọc theo thứ tự:
1. DAC_TA_OPSDESK_APP_WEB_SUPABASE.md
2. PLAN_XAY_DUNG_OPSDESK_THEO_PHASE.md
3. FRONTEND_REDESIGN_CLICKUP_STYLE_OPSDESK.md
4. docs/IMPLEMENTATION_STATUS.md
5. docs/TEST_REPORT.md
6. docs/DECISIONS.md

Mục tiêu:
Refactor UX/UI theo FRONTEND_REDESIGN_CLICKUP_STYLE_OPSDESK.md.
Giao diện lấy cảm hứng từ mô hình thao tác của ClickUp nhưng không sao chép branding, logo, asset hay pixel-perfect layout.

QUAN TRỌNG:
- Không rewrite backend.
- Không thay đổi Supabase schema/RLS/RPC trừ khi thật sự cần và phải báo trước.
- Không thay đổi business rules đã PASS.
- Không fake dữ liệu.
- Không làm toàn bộ redesign trong một lần.

Bắt đầu từ FE-R0.
Mỗi phiên chỉ làm đúng một phase FE-Rx.
Sau khi hoàn thành:
- lint
- typecheck
- unit test
- E2E liên quan
- permission regression
- responsive check
- visual check
- update IMPLEMENTATION_STATUS.md
- update TEST_REPORT.md
rồi STOP.

Không tự chuyển sang phase tiếp theo trong cùng phiên.
```

---

# 55. KẾT LUẬN

OpsDesk sau redesign phải tạo cảm giác:

> **Nhanh như một task manager chuyên nghiệp, rõ như ClickUp nhưng nhẹ và dễ dùng hơn cho team vận hành thương mại điện tử quy mô nhỏ.**

Ưu tiên số 1 không phải “đẹp giống ClickUp”, mà là:

1. tìm việc nhanh;
2. giao việc nhanh;
3. cập nhật nhanh;
4. ít click;
5. ít rối;
6. đúng quyền;
7. không phá backend/logic đã ổn định.

Đây là spec dùng **sau khi core project hoàn thành** và chủ dự án yêu cầu bắt đầu refactor frontend.
