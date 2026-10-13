# OPSDESK — ĐẶC TẢ SẢN PHẨM & TRIỂN KHAI APP/WEB QUẢN LÝ VẬN HÀNH THƯƠNG MẠI ĐIỆN TỬ

**Phiên bản:** 1.0 — ngày 04/10/2026  
**Đối tượng đọc:** AI lập trình, frontend developer, mobile developer, backend developer, QA và người triển khai.  
**Database đã được chủ dự án chốt:** **Supabase PostgreSQL**.  
**Ngôn ngữ giao diện:** Tiếng Việt. **Múi giờ nghiệp vụ ban đầu:** `Asia/Ho_Chi_Minh`.  
**Tên tạm dùng khi code:** `OpsDesk`; cho phép đổi trong cấu hình, không coi đây là tên thương hiệu đã được chủ dự án xác nhận.

> Đây là tài liệu nguồn để triển khai, không phải tài liệu giới thiệu sản phẩm. AI nhận tài liệu phải xây luồng hoạt động thật, dữ liệu thật, phân quyền thật, lịch tự động thật. Không được kết thúc ở một dashboard đẹp có số liệu giả hoặc các nút chưa hoạt động.
>
> Tài liệu tự chứa toàn bộ bối cảnh cần thiết. Không yêu cầu người dùng cung cấp lại cuộc trò chuyện. Những giá trị đánh dấu “mặc định đề xuất” là quyết định triển khai có thể cấu hình, không phải thông tin thực tế đã biết về công ty.

---

**MỤC LỤC TRIỂN KHAI**

Bản đồ đọc: **0–5** là nghiệp vụ và quyền; **6–24** là giao diện từng trang và app; **25–38** là backend, Supabase và thuật toán; **39–44** là dữ liệu mẫu, triển khai, kiểm thử và nguồn tham chiếu.

Tài liệu dài: AI có thể đọc theo phân đoạn và lưu tiến độ trong repository, nhưng phải giữ nguyên các bất biến bảo mật/nghiệp vụ giữa các giai đoạn. Các ví dụ code là chỉ dẫn triển khai; **147 ca kiểm thử là yêu cầu phải chạy sau khi xây app, không phải kết quả kiểm thử của một ứng dụng đã được xây sẵn**.

| Mục | Nội dung |
|---|---|
| 0 | [CHỈ THỊ CHO AI SẼ CODE DỰ ÁN](#section-0) |
| 1 | [BỐI CẢNH, MỤC TIÊU VÀ GIỚI HẠN SẢN PHẨM](#section-1) |
| 2 | [TỪ ĐIỂN NGHIỆP VỤ VÀ CÁC QUYẾT ĐỊNH MẶC ĐỊNH](#section-2) |
| 3 | [VAI TRÒ, PHẠM VI VÀ MA TRẬN QUYỀN](#section-3) |
| 4 | [VÒNG ĐỜI TASK — MỘT NGUỒN SỰ THẬT](#section-4) |
| 5 | [MỘT NGÀY SỬ DỤNG ĐẦY ĐỦ](#section-5) |
| 6 | [DESIGN SYSTEM — PHÂN TÍCH VÀ CHUYỂN ẢNH THAM CHIẾU THÀNH UI](#section-6) |
| 7 | [APP SHELL, ĐIỀU HƯỚNG VÀ ROUTE MAP](#section-7) |
| 8 | [QUY TẮC CHUNG CHO MỌI TRANG](#section-8) |
| 9 | [P01–P04 — ĐĂNG NHẬP, LỜI MỜI VÀ KHỞI TẠO](#section-9) |
| 10 | [P05 — MÀN HÌNH “HÔM NAY” CỦA NHÂN VIÊN](#section-10) |
| 11 | [P06–P08 — CÔNG VIỆC CỦA TÔI, TẤT CẢ CÔNG VIỆC VÀ TỔNG QUAN](#section-11) |
| 12 | [P09 — FORM GIAO VIỆC NHANH, DAILY CHECKBOX VÀ GIAO HÀNG LOẠT](#section-12) |
| 13 | [P10 — CHI TIẾT TASK VÀ NỘP KẾT QUẢ](#section-13) |
| 14 | [P11–P12 — QUẢN LÝ DAILY TEMPLATE](#section-14) |
| 15 | [P13 — LỊCH LÀM VIỆC](#section-15) |
| 16 | [P14–P15 — SELLER VÀ PHÂN CÔNG](#section-16) |
| 17 | [P16–P17 — NHÂN SỰ](#section-17) |
| 18 | [P18–P20 — CHẤM CÔNG VĂN PHÒNG, ONLINE VÀ THEO DÕI](#section-18) |
| 19 | [P21–P22 — ĐƠN TỪ VÀ PHÊ DUYỆT](#section-19) |
| 20 | [P23–P25 — LỊCH CA VÀ BẢNG CÔNG THÁNG](#section-20) |
| 21 | [P26–P27 — BÁO CÁO TỰ ĐỘNG 18:00](#section-21) |
| 22 | [P28 — HỘP THÔNG BÁO](#section-22) |
| 23 | [P29–P32 — CÀI ĐẶT, TÀI KHOẢN VÀ CHẨN ĐOÁN](#section-23) |
| 24 | [CHI TIẾT NATIVE APP VÀ KHÁC BIỆT SO VỚI WEB](#section-24) |
| 25 | [CHÍNH SÁCH NHẮC VIỆC CỤ THỂ](#section-25) |
| 26 | [KIẾN TRÚC TỔNG THỂ VÀ RANH GIỚI TRÁCH NHIỆM](#section-26) |
| 27 | [STACK MẶC ĐỊNH VÀ THƯ VIỆN](#section-27) |
| 28 | [CẤU TRÚC REPO VÀ IMPLEMENTATION FRONTEND](#section-28) |
| 29 | [DATABASE SUPABASE — DATA DICTIONARY CHUẨN](#section-29) |
| 30 | [RLS, GRANTS VÀ MẪU SQL TRIỂN KHAI](#section-30) |
| 31 | [HỢP ĐỒNG API/RPC — TÊN, INPUT, OUTPUT, QUYỀN](#section-31) |
| 32 | [THUẬT TOÁN DAILY TASK VÀ LỊCH CA](#section-32) |
| 33 | [THUẬT TOÁN CHẤM CÔNG VÀ TRUSTED GATEWAY](#section-33) |
| 34 | [TÍNH CÔNG, NGHỈ VÀ CHỐT THÁNG — CÔNG THỨC CHUẨN](#section-34) |
| 35 | [BÁO CÁO 18:00, REPLAY VÀ LỊCH MÁY CHỦ](#section-35) |
| 36 | [OUTBOX, WORKER, PUSH VÀ REALTIME](#section-36) |
| 37 | [STORAGE, QUYỀN RIÊNG TƯ, BẢO MẬT VÀ XUẤT FILE](#section-37) |
| 38 | [AI TRONG SẢN PHẨM — OPTIONAL, KHÔNG LÀ NGUỒN SỰ THẬT](#section-38) |
| 39 | [SEED, DỮ LIỆU DEMO VÀ NỘI DUNG MẪU](#section-39) |
| 40 | [CẤU HÌNH, TRIỂN KHAI VÀ VẬN HÀNH](#section-40) |
| 41 | [BỘ KIỂM THỬ VÀ TIÊU CHÍ NGHIỆM THU](#section-41) |
| 42 | [THỨ TỰ TRIỂN KHAI CHO AI LẬP TRÌNH](#section-42) |
| 43 | [MA TRẬN TRUY VẾT YÊU CẦU VÀ DEFINITION OF DONE](#section-43) |
| 44 | [NGUỒN KỸ THUẬT VÀ THAM CHIẾU](#section-44) |

---

<a id="section-0"></a>

## 0. CHỈ THỊ CHO AI SẼ CODE DỰ ÁN

### 0.1. Đọc và thực hiện theo thứ tự

1. Đọc toàn bộ tài liệu; lập bảng đối chiếu yêu cầu trước khi tạo giao diện.
2. Kiểm tra repository hiện có. Nếu đã có frontend framework, giữ framework đó khi có thể đáp ứng đặc tả; không tự viết lại toàn bộ chỉ vì sở thích. Nếu là repo mới, dùng stack mặc định ở mục 27.
3. Database, Auth, Storage, Realtime và tác vụ nền phải tích hợp Supabase theo tài liệu. Không thay bằng Firebase, SQLite local-only hay dữ liệu trong `localStorage`.
4. Tạo migration, seed thử nghiệm, kiểu dữ liệu, quyền truy cập và các hàm nghiệp vụ trước hoặc đồng thời với frontend.
5. Xây từng lát chức năng xuyên suốt: UI → API/RPC → PostgreSQL → kiểm thử → Realtime/thông báo.
6. Thực hiện theo các giai đoạn ở mục 42. Giai đoạn là thứ tự làm việc, không phải quyền bỏ các phần còn lại.
7. Dùng các mã kiểm thử ở mục 41 làm tiêu chí hoàn thành.
8. Mỗi khi bị giới hạn vì thiếu tài khoản dịch vụ, secret, chứng chỉ iOS hoặc thiết bị thật: ghi rõ trạng thái `BLOCKED_EXTERNAL_SETUP`, mô tả cách cấu hình, vẫn hoàn thiện phần code liên quan. Không thay bằng thông báo thành công giả.
9. Tạo `IMPLEMENTATION_STATUS.md`, `SETUP.md`, `TEST_REPORT.md`, `DEPLOYMENT_CHECKLIST.md` trong repo. Chỉ đánh dấu PASS khi đã chạy bài kiểm thử tương ứng.
10. Không đưa API key bí mật, mật khẩu, ảnh chấm công hoặc dữ liệu nhân sự thật vào Git.

### 0.2. Những việc tuyệt đối không được làm

- Không xây nhầm app tài chính cá nhân. Chủ dự án đã chuyển sang app quản lý team vận hành thương mại điện tử.
- Không thêm sàn tuyển dụng, mạng xã hội, CRM bán hàng, kế toán hoặc quản lý lương toàn diện vào V1.
- Không dùng tên “Synapse”, các tên folder hay nội dung demo trong ảnh làm nội dung sản phẩm.
- Không dùng avatar, ảnh đại diện, cụm avatar chồng nhau hoặc vòng tròn chữ cái thay cho avatar trong giao diện. Dùng tên, mã nhân viên và nhãn chuyên môn. Ảnh selfie chấm công là bằng chứng riêng tư, không phải avatar.
- Không dùng checklist hoàn thành, checkbox chọn dòng và checkbox Daily task như cùng một cơ chế.
- Không tính nhân viên đủ công chỉ vì đã hoàn thành task.
- Không tự trừ công chỉ vì task trễ.
- Không hứa website đọc chính xác SSID/BSSID Wi-Fi như ứng dụng native.
- Không coi gửi push thành công là nhân viên đã nhận việc.
- Không reset task cũ về trạng thái chưa làm để tạo daily task.
- Không đặt bộ đếm 18:00 bằng `setInterval` trên trình duyệt.
- Không để AI tự quyết định số công, phê duyệt nghỉ, đánh giá tính cách hay “độ chăm chỉ”.
- Không coi mọi loại nghỉ được duyệt là nghỉ không lương.
- Không đưa ảnh selfie hoặc lý do nghỉ chi tiết vào báo cáo gửi chung cho các quản lý seller.
- Không hardcode “26 công/tháng”, “tất cả đều làm thứ Hai–thứ Bảy”, “18:00 luôn là giờ tan ca”.
- Không cấp `service_role`/secret key cho web hoặc mobile.
- Không dùng một tài khoản admin giả chia sẻ cho toàn bộ team.
- Không sử dụng `any`, `@ts-ignore`, tắt RLS, hoặc policy `using (true)` trên dữ liệu riêng tư để chữa lỗi nhanh.

### 0.3. Mức bắt buộc

- **MUST:** bắt buộc để nghiệm thu V1.
- **SHOULD:** cần triển khai trừ khi có quyết định khác được ghi lại.
- **LATER:** thiết kế điểm mở rộng nhưng không cần triển khai V1.
- Không có nghĩa “UI có nút là tính năng đã hoàn thành”. MUST bao gồm backend, quyền, loading/error/empty, kiểm thử và dữ liệu lưu được.

---

<a id="section-1"></a>

## 1. BỐI CẢNH, MỤC TIÊU VÀ GIỚI HẠN SẢN PHẨM

### 1.1. Bối cảnh đã được xác nhận

Chủ dự án có team khoảng **5–10 người**, vận hành các tài khoản bán hàng thương mại điện tử. Cần dùng trên điện thoại và máy tính. Nhân sự được phân theo chuyên môn và seller; một người có thể phụ trách nhiều seller.

Cần giải quyết:

- Quản lý giao việc nhanh, nhân viên nhận việc nhanh.
- Mở app là thấy ngay hôm nay phải làm gì.
- Công việc lặp lại mỗi ngày được thiết lập ngay khi giao task bằng checkbox.
- Việc chưa nhận, sắp trễ, quá hạn chưa cập nhật được nhắc đúng người.
- **18:00 hằng ngày**, hệ thống tự tạo báo cáo công việc từng nhân sự cho người có quyền quản lý.
- Chấm công văn phòng yêu cầu xác thực Wi-Fi công ty.
- Nhân viên làm online chụp selfie trực tiếp cùng máy tính làm việc.
- Nhân viên xin nghỉ, về sớm hoặc bổ sung chấm công trong hệ thống; admin duyệt.
- Có bảng công tháng, đối soát và chốt công.
- UX/UI theo ảnh tham chiếu: nhẹ, sáng, trắng/xám, sidebar và danh sách rõ ràng, không rối.

### 1.2. Đầu ra bắt buộc

**Website responsive** cho quản lý và nhân viên, cùng **ứng dụng Android/iOS** dùng chung dữ liệu. Website không được coi là đã thay thế toàn bộ native app, vì việc kiểm tra Wi-Fi có ràng buộc hệ điều hành.

Bản thử nội bộ có thể phát hành web trước; nghiệm thu toàn bộ V1 vẫn phải kiểm tra app native trên thiết bị thật. Không cam kết phát hành App Store/Google Play tự động khi chưa có tài khoản, chứng chỉ và xét duyệt.

### 1.3. Giới hạn V1

- Một không gian làm việc thực tế, tạo bởi chủ dự án; đăng ký theo lời mời.
- Database có `organization_id` từ đầu để tránh trộn dữ liệu và có thể mở rộng nhiều team sau này.
- Chưa làm trang bán SaaS, gói trả phí, hóa đơn, đăng ký công khai nhiều tổ chức.
- Mỗi seller là **một tài khoản shop trên một nền tảng**. Shopee của thương hiệu A và TikTok Shop của A là hai seller khác nhau, có thể chung `brand_label`.
- Chưa kết nối API Shopee/TikTok Shop. Task “kiểm tra tồn kho” là nhân viên thực hiện và cập nhật; hệ thống không tự xác minh tồn kho trên sàn.
- Chưa tính tiền lương, thuế, bảo hiểm, tiền tăng ca. Chỉ tổng hợp thời gian/công, loại nghỉ, ngoại lệ và xuất dữ liệu.
- Không giám sát màn hình, không chụp ảnh định kỳ, không theo dõi vị trí liên tục.

### 1.4. Các mục tiêu cần đo khi thử nghiệm

Đây là mục tiêu nghiệm thu, không phải hiệu năng đã được đo:

- Giao một task đơn giản trong khoảng 3–5 thao tác sau khi mở biểu mẫu.
- Nhân viên xác nhận nhận việc trong một thao tác từ task đang xem.
- Xem được danh sách hôm nay trong màn hình đầu tiên sau đăng nhập.
- Cập nhật của máy tính xuất hiện trên điện thoại trong khoảng 5 giây khi mạng và Realtime hoạt động bình thường; có polling/focus refresh dự phòng.
- Bắt đầu chốt báo cáo lúc 18:00; mục tiêu xuất hiện trong app trước 18:02 trong điều kiện bình thường. Push có thể đến trễ hơn, không bảo đảm giao đúng giây.
- Không tạo trùng daily task, bản công hoặc thông báo trong tình huống retry.
- Không nhìn thấy dữ liệu ngoài quyền qua URL, API, file tải xuống hoặc Realtime.

---

<a id="section-2"></a>

## 2. TỪ ĐIỂN NGHIỆP VỤ VÀ CÁC QUYẾT ĐỊNH MẶC ĐỊNH

| Thuật ngữ | Định nghĩa triển khai |
|---|---|
| Workspace / tổ chức | Không gian dữ liệu của một team; khóa `organization_id`. |
| Admin | Người quản trị trong tổ chức; toàn quyền nghiệp vụ nhưng không được sửa lịch sử âm thầm. |
| Owner | Một thuộc tính của thành viên admin, giữ quyền chuyển chủ; không phải vai trò thứ tư trên UI. |
| Manager / quản lý | Quản lý task và báo cáo trong seller/phạm vi được phân. Không mặc định có quyền HR. |
| Employee / nhân viên | Làm task được giao/tham gia; xem chấm công, đơn từ và bảng công của chính mình. |
| Chuyên môn | Nhãn như Vận hành, Content, Thiết kế, Ads, Affiliate/KOC, CSKH. Không thay thế role. |
| Seller | Shop/tài khoản bán hàng trên một nền tảng. Không lưu mật khẩu đăng nhập shop. |
| Ngày dự kiến làm | Ngày task cần xuất hiện để thực hiện; độc lập với hạn hoàn thành. |
| Deadline | Mốc phải bàn giao; bắt buộc có cả ngày và giờ. |
| Daily task | Mẫu sinh các lần thực hiện riêng theo ngày, không phải một task vĩnh viễn. |
| Occurrence | Một lần dự kiến thực hiện của mẫu; có thể là task đã tạo hoặc lần được miễn/báo thiếu người. |
| Nhận việc | Xác nhận đã nhận trách nhiệm; không đồng nghĩa đang làm. |
| Nộp kết quả | Gửi một phiên bản kết quả để hoàn thành hoặc chờ duyệt. |
| Công thực làm | Thời gian hợp lệ đã đối soát trong các khoảng làm việc của ca. |
| Công nghỉ hưởng lương | Thời gian nghỉ được xử lý theo loại nghỉ hưởng lương; không gọi là thực làm. |
| Công tạm tính | Kết quả chưa hoàn tất do ca đang mở, thiếu chấm công hoặc đang chờ đối soát. |
| Chốt công | Đóng phiên bản bảng công tháng sau khi giải quyết ngoại lệ. |
| Báo cáo 18:00 | Snapshot dữ liệu theo cutoff 18:00 của ngày nghiệp vụ; không phải tự chấm ra ca. |

### 2.1. Các giá trị mặc định để chạy demo

| Cấu hình | Mặc định đề xuất | Cho phép đổi |
|---|---|---|
| Múi giờ | `Asia/Ho_Chi_Minh` | Có; không đổi lịch sử đã phát sinh. |
| Ca demo | 09:00–18:00, nghỉ 12:00–13:00 | Có; không coi là ca thực của công ty. |
| Tuần demo | Thứ Hai–thứ Sáu | Có. |
| Thời điểm báo cáo | 18:00 | Có ở admin; seed phải là 18:00. |
| Rà soát cuối ngày | 17:30 cho người đang trong ca phù hợp | Có. |
| Chưa nhận việc | Sau 30 phút làm việc | Có. |
| Nhắc trước hạn | 60 phút; task quá ngắn dùng quy tắc ở mục 25 | Có. |
| Dung sai đi muộn | 0 phút | Có; chỉ thay nhãn vi phạm, không tự cộng giờ làm. |
| Selfie online | Bắt buộc đầu ca; cuối ca có cấu hình, mặc định không bắt buộc | Có. |
| Wi-Fi văn phòng | Native Wi-Fi allowlist + public IP nguồn đáng tin cậy | Có quy trình ngoại lệ, không tự hạ cấp. |
| Tuổi thọ challenge | 120 giây | Giá trị kỹ thuật có thể cấu hình có giới hạn. |
| Xem ảnh selfie | Chính chủ + admin; HR được cấp riêng nếu triển khai | Có theo quyền, không theo seller role. |
| Nghỉ/về sớm | Chọn loại nghỉ rõ ràng; không mặc định đã trả lương hay không | Có theo chính sách được rà soát. |

---

<a id="section-3"></a>

## 3. VAI TRÒ, PHẠM VI VÀ MA TRẬN QUYỀN

### 3.1. Mô hình quyền

Một người có một `organization_members.role` thuộc `admin | manager | employee`. Chuyên môn nằm riêng. Quyền seller nằm trong `seller_members`.

V1 có ba quyền bổ sung tách khỏi role:

- `can_manage_attendance`: xem/đối soát chấm công người khác trong tổ chức.
- `can_approve_requests`: duyệt đơn HR.
- `can_view_attendance_evidence`: xem ảnh/IP chi tiết.

Admin mặc định có cả ba. Manager mặc định **không** có. Chỉ admin được cấp/thu hồi. Không tự cho manager xem HR của toàn bộ người đang làm task seller mình quản lý.

Những quyền bổ sung này V1 áp dụng toàn tổ chức; nếu muốn cấp HR theo nhóm hẹp phải bổ sung bảng scope riêng và test trước, không suy ra từ seller scope.

### 3.2. Ma trận

| Hành động | Admin | Manager | Employee |
|---|---|---|---|
| Xem task | Tất cả trong tổ chức | Task thuộc seller được quản lý, hoặc task mình tham gia | Task được giao, phối hợp hoặc duyệt |
| Tạo task cho người khác | Có | Trong seller được quản lý, chỉ người thuộc seller | Không; chỉ tạo việc cá nhân cho mình nếu bật |
| Tạo task nội bộ không seller | Có | Cho chính mình; giao người khác cần quyền riêng, V1 không có | Việc cá nhân, nếu bật |
| Đổi deadline/assignee | Có, có lý do khi đã giao | Trong phạm vi quản lý | Chỉ đề nghị |
| Nhận/bắt đầu/nộp task | Khi chính mình là assignee | Khi chính mình là assignee | Khi là assignee |
| Cập nhật checklist phối hợp | Theo quyền task | Theo quyền task | Người được giao item hoặc assignee chính |
| Duyệt kết quả | Khi là reviewer hoặc admin override có lý do | Khi là reviewer/phụ trách seller và có quyền duyệt | Chỉ khi được chọn reviewer và chính sách cho phép; V1 mặc định reviewer phải manager/admin |
| Sửa nội dung bình luận | Bình luận của mình trong 15 phút; admin ẩn vi phạm có audit | Như chính chủ | Như chính chủ |
| Quản lý daily template | Có | Trong seller được quản lý | Xem lần được giao, không đổi mẫu |
| Xem mọi task trong seller | Có | Seller được quản lý | Không chỉ vì là thành viên seller |
| Chấm công | Cho chính mình | Cho chính mình | Cho chính mình |
| Sửa chấm công người khác | Qua điều chỉnh được audit | Cần quyền HR | Không |
| Gửi đơn | Cho chính mình | Cho chính mình | Cho chính mình |
| Duyệt đơn người khác | Có | Cần quyền HR | Không |
| Duyệt đơn của chính mình | Không theo luồng thường | Không | Không |
| Xem công tháng | Tất cả | Chính mình; người khác cần quyền HR | Chính mình |
| Chốt công tháng | Admin, không tự chốt khi còn lỗi chặn | Không | Không |
| Báo cáo công việc 18:00 | Toàn tổ chức | Đúng scope seller/task | Bản tóm tắt của mình |
| Thông tin nghỉ trong báo cáo seller | Chỉ trạng thái sẵn sàng, không lý do riêng tư | Chỉ trạng thái sẵn sàng | Chính mình |
| Xuất dữ liệu | Đúng phạm vi, có audit | Đúng scope, không ảnh HR | Task/công của chính mình nếu bật |
| Quản lý role, Wi-Fi, cron | Có | Không | Không |

### 3.3. Điều kiện chi tiết

- Mọi kiểm tra phải có `membership.status = active`; JWT chưa hết hạn không giúp thành viên đã bị vô hiệu hóa tiếp tục thao tác.
- Không dùng `user_metadata` do client sửa được để quyết định role.
- Không tự cấp quyền xem task toàn seller khi thêm một người làm collaborator của một task.
- Người được giao phải đang hoạt động và thuộc seller của task. Thêm ngoại lệ chỉ qua admin với audit.
- Reviewer không được là assignee chính của cùng task cần duyệt.
- Người tạo không mặc định là người duyệt; trường reviewer phải cụ thể khi bật duyệt.
- Nếu chỉ có một admin và admin đó cần điều chỉnh công của mình: không giả lập “được duyệt bởi người khác”. Có chức năng riêng `Điều chỉnh hành chính` của owner với xác nhận, lý do và nhãn tự điều chỉnh; đây không phải đơn tự phê duyệt. Có thể yêu cầu thêm admin thứ hai trước khi bật nghiệp vụ nhạy cảm.
- Khi thu hồi scope của manager, báo cáo cũ chứa scope đó phải bị chặn hoặc cấp lại bản đã lọc; không để con số tổng tiết lộ seller đã bị thu hồi.

---

<a id="section-4"></a>

## 4. VÒNG ĐỜI TASK — MỘT NGUỒN SỰ THẬT

### 4.1. Trạng thái chính

```ts
type TaskStatus =
  | "todo"
  | "in_progress"
  | "in_review"
  | "done"
  | "canceled"
  | "waived";
```

Nhãn UI tương ứng: `Chưa bắt đầu`, `Đang làm`, `Chờ duyệt`, `Hoàn thành`, `Đã hủy`, `Được miễn`.

Các thuộc tính không phải trạng thái chính:

```ts
acknowledged_at: string | null;
blocked_at: string | null;
blocker_reason: string | null;
blocker_owner_member_id: string | null;
due_at: string;
planned_date: string;
submitted_at: string | null; // lần nộp hiện tại
completed_at: string | null;
```

`Chưa nhận`, `Bị vướng`, `Sắp đến hạn`, `Quá hạn` là nhãn suy ra. Không lưu một enum “overdue” cạnh enum trạng thái chính.

### 4.2. Bảng chuyển trạng thái

| Lệnh | Từ | Sang | Điều kiện | Side effect |
|---|---|---|---|---|
| Nhận việc | `todo` | `todo` | Assignee; chưa nhận | Ghi `acknowledged_at`, dừng nhắc chưa nhận |
| Bắt đầu | `todo` | `in_progress` | Assignee | Tự nhận nếu chưa nhận, ghi `started_at` |
| Nộp không cần duyệt | `todo/in_progress` | `done` | Kết quả + checklist bắt buộc hợp lệ | Tạo submission, ghi hoàn thành |
| Nộp cần duyệt | `todo/in_progress` | `in_review` | Reviewer hợp lệ, đủ kết quả | Tạo submission; nhắc reviewer |
| Duyệt | `in_review` | `done` | Reviewer/admin được phép; không tự duyệt | Ghi quyết định và `completed_at` |
| Yêu cầu làm lại | `in_review` | `in_progress` | Reviewer; lý do bắt buộc | Submission cũ giữ nguyên, tạo lượt sửa |
| Mở lại | `done` | `in_progress` | Quản lý; lý do | Lưu lịch sử, không sửa báo cáo đã chốt |
| Hủy | Chưa terminal | `canceled` | Quản lý; lý do | Không tính hoàn thành; dừng nhắc |
| Miễn lần thực hiện | Chưa terminal | `waived` | Quản lý; lý do nghiệp vụ | Không tính miss; không tính done |
| Báo vướng | `todo/in_progress` | Không đổi | Assignee; lý do và đầu mối | Đưa vào hàng đợi tháo gỡ |
| Giải quyết vướng | Có blocker | Không đổi | Người có quyền | Ghi ai giải quyết, dừng nhắc blocker |
| Giao lại | `todo/in_progress` | Giữ trạng thái hợp lý | Quản lý; lý do | Reset ack của người mới, giữ lịch sử người cũ |

Không cho sửa checklist hay kết quả đã nộp trong `in_review` theo kiểu ghi đè. Assignee có thể `Rút lại để sửa` nếu chưa được duyệt; lệnh tạo event và trả về `in_progress`.

### 4.3. Deadline và trách nhiệm

- Lưu `original_due_at` khi giao lần đầu; `due_at` hiện tại có thể đổi nhưng luôn có event.
- Đổi deadline chỉ áp dụng từ thời điểm đổi, không xóa các sự kiện trễ từng phát sinh.
- Submission nộp trước hạn rồi đang chờ duyệt: không gửi nhắc quá hạn thực hiện cho assignee.
- Submission bị trả lại: reviewer phải đặt hạn sửa mới hoặc xác nhận dùng hạn hiện tại. Không âm thầm coi thời gian reviewer giữ task là thời gian nhân viên trì hoãn.
- Giao lại task chưa xong không làm mất kết quả/bình luận trước đó. Người mới nhận trách nhiệm kể từ `assigned_at` mới.
- Task có kế hoạch hôm nay nhưng hạn ngày mai vẫn xuất hiện trong “Hôm nay”.
- `estimated_minutes` chỉ là ước lượng công việc để điều phối; không chuyển thành thời gian chấm công.

---

<a id="section-5"></a>

## 5. MỘT NGÀY SỬ DỤNG ĐẦY ĐỦ

### 5.1. Quản lý

1. Mở website → “Tổng quan đội ngũ”.
2. Xem người đang làm, việc chưa nhận, việc cần duyệt, việc bị vướng.
3. Bấm `Giao việc` → nhập tiêu đề, người làm, seller, deadline → giao.
4. Với việc lặp, tích `Daily task — Tự động lặp lại`.
5. Trong ngày duyệt kết quả và xử lý yêu cầu nhân sự.
6. 17:30 hệ thống nhắc các cập nhật còn thiếu cho người đang làm.
7. 18:00 nhận một báo cáo tổng có từng nhân sự và từng seller, không phải 10 push rời.
8. Xem các việc cần quyết định, mở task gốc hoặc đơn liên quan.
9. Cuối tháng đối soát và chốt công.

### 5.2. Nhân viên

1. Mở app → “Hôm nay”, thấy ca và các task.
2. Tại văn phòng: kết nối Wi-Fi đã đăng ký → chấm vào ca.
3. Online đã được phép: chụp selfie cùng máy tính → chấm vào.
4. Bấm nhận các task mới.
5. Bắt đầu/cập nhật checklist/nộp kết quả/báo vướng ngay tại task.
6. Cần nghỉ hoặc về sớm: gửi yêu cầu, kiểm tra trạng thái phê duyệt.
7. Cuối ca chấm ra. Chưa xong task vẫn được ghi nhận giờ ra thực tế.
8. Mở “Công của tôi” để kiểm tra, đề nghị sửa ngày bị thiếu.

---

<a id="section-6"></a>

## 6. DESIGN SYSTEM — PHÂN TÍCH VÀ CHUYỂN ẢNH THAM CHIẾU THÀNH UI

### 6.1. Ảnh cần được hiểu như thế nào

Ảnh tham chiếu do chủ dự án cung cấp là giao diện quản lý tài liệu, kích thước khoảng 1200×900. Các đặc điểm quan trọng:

- Nền ngoài xám trung tính, bên trong là khung ứng dụng sáng có góc bo lớn.
- Sidebar phía trái sáng hơn nền ngoài, sắc xám rất nhẹ, có nhiều khoảng thở.
- Một bảng nội dung trắng nằm bên phải; vùng breadcrumb, tiêu đề/toolbar, card và bảng tách bằng đường kẻ mảnh.
- Chữ gần đen, nhãn phụ xám; icon nhỏ, cùng một phong cách.
- Sidebar active là một thanh nền trắng bo tròn, không phải ô màu neon.
- Bảng dữ liệu có header xám cực nhạt, dòng cao vừa phải, phân cách mỏng.
- Checkbox vuông bo nhẹ; trạng thái chọn dùng nền gần đen và dấu tick trắng.
- Các folder xanh dạng bóng chỉ là minh họa của ứng dụng tài liệu. **Không cần tái sử dụng folder 3D ở mọi màn hình.**
- Ảnh có avatar trong bảng; **không đưa avatar vào OpsDesk**. Dùng tên người dạng chữ.
- Không sao chép khoảng lề ngoài khoảng 90px của ảnh vào mọi màn hình. Đó là cách trình bày mockup; sản phẩm thật phải tận dụng không gian laptop.

### 6.2. Quy tắc trực quan

**MUST:** nền sáng, phân cấp bằng khoảng cách/chữ/viền; nút chính gần đen; màu chỉ dùng cho trạng thái và một điểm nhấn tím xanh nhỏ.

**KHÔNG:** sidebar tối, nền xanh rêu, card gradient đậm, glassmorphism quá mức, biểu đồ trang trí lớn, emoji làm icon chính, avatar, banner chào mừng cao nửa màn hình.

### 6.3. Design tokens bắt buộc

```css
:root {
  --canvas: #edeef1;
  --sidebar: #f7f7fa;
  --surface: #ffffff;
  --surface-muted: #f8f8fa;
  --surface-hover: #f3f4f6;
  --border: #e9eaee;
  --border-strong: #d8dae1;
  --text-primary: #18191c;
  --text-secondary: #656a76;
  --text-muted: #777d89;
  --primary: #1c1d21;
  --primary-hover: #303238;
  --primary-foreground: #ffffff;
  --accent: #5b5ce2;
  --accent-soft: #efefff;
  --success: #23764b;
  --success-soft: #edf7f0;
  --warning: #8a5b12;
  --warning-soft: #fff7e7;
  --danger: #b93838;
  --danger-soft: #fff0f0;
  --info: #365f9d;
  --info-soft: #edf4ff;
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-lg: 14px;
  --radius-xl: 20px;
  --shadow-card: 0 4px 18px rgba(22, 25, 40, 0.04);
  --shadow-overlay: 0 16px 48px rgba(22, 25, 40, 0.12);
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;
  --space-8: 32px;
  --space-10: 40px;
}
```

Dùng font sans có đầy đủ tiếng Việt, mặc định `Inter` nếu dự án đã có quyền dùng và cách phân phối phù hợp; fallback `system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`. Không phụ thuộc tải font từ bên thứ ba để app hoạt động. Không cần chia sẻ font trong tài liệu.

| Thành phần chữ | Kích thước / weight / line-height |
|---|---|
| Tiêu đề trang | 24px / 600 / 32px |
| Tiêu đề khu vực | 16px / 600 / 24px |
| Body desktop | 14px / 400 / 22px |
| Body mobile | 15px / 400 / 23px |
| Nhãn form | 13px / 500 / 20px |
| Metadata | 12px / 400 / 18px |
| Số KPI | 26px / 600 / 32px; tabular-nums |
| Header bảng | 12px / 500 / 18px |

Kiểm tra contrast thực tế. Không dùng chữ xám quá nhạt cho thông tin cần đọc hoặc truyền đạt trạng thái chỉ bằng màu.

### 6.4. Kích thước layout

- Từ 1440px: padding ngoài 20px; sidebar 252px; content `min-width: 0`, chiếm phần còn lại.
- 1024–1439px: padding ngoài 12px; sidebar 224px hoặc thu gọn 72px theo lựa chọn.
- 768–1023px: mặc định sidebar rail 72px; click menu mở đầy đủ.
- Dưới 768px: bỏ lề khung desktop; sidebar thành sheet; bottom navigation cao 64px cộng safe-area.
- App shell cao `100dvh`; sidebar và vùng nội dung có scroll riêng khi cần.
- Header chính cao 64px; page padding desktop 28px, tablet 20px, mobile 16px.
- Border-radius khung app 20px desktop; mobile không bo cả màn hình.
- Bảng luôn có container `overflow-x:auto`; không làm toàn trang tràn ngang.
- Drawer chi tiết desktop 640–720px; mobile full-screen.
- Modal xác nhận nhỏ rộng tối đa 440px; form lớn tối đa 720px.
- Hit target ít nhất 44×44px trên mobile; checkbox nhìn thấy có thể 18px nhưng vùng bấm lớn hơn.

### 6.5. Component chung

| Component | Quy định |
|---|---|
| `PageHeader` | Breadcrumb nhỏ, title, subtitle tối đa 2 dòng; action chính bên phải. |
| `SidebarItem` | Cao 40px; icon 18px; nhãn; badge số từ API; active nền trắng và chữ đậm vừa. |
| `Button` | Desktop cao 36/40px; mobile 44px; primary đen; secondary nền trắng viền. |
| `StatusBadge` | Nhãn tiếng Việt + màu nhẹ; không dùng full pill chói. |
| `SellerChip` | Tên seller và nhãn nền tảng; không dùng màu thương hiệu phủ cả card. |
| `PersonLabel` | Họ tên, mã nhân viên tùy chỗ; không ảnh, không initials circle. |
| `TaskRow` | Tiêu đề 1–2 dòng, seller, người, deadline, status, daily indicator. |
| `DailyIndicator` | Icon lặp 14px + chữ “Hằng ngày”; tooltip lịch. |
| `InlineError` | Đặt dưới trường, có nội dung cụ thể, liên kết bằng `aria-describedby`. |
| `EmptyState` | Icon line đơn giản, title, 1 câu hướng dẫn, action phù hợp quyền. |
| `DataTable` | Header 44px, row 56px; sticky header; phân trang; sort/filter có URL state. |
| `Toast` | Thành công ngắn 3–4 giây; lỗi quan trọng còn inline, không chỉ toast. |
| `ConfirmDialog` | Nêu đối tượng + hậu quả + nút hành động cụ thể, không dùng “OK”. |
| `ConnectivityBanner` | “Đang mất kết nối. Dữ liệu đang hiển thị có thể chưa mới nhất.” |
| `PermissionBanner` | Giải thích quyền camera/Wi-Fi/push đúng mục đích; không ép bật tất cả khi đăng nhập. |

Ba checkbox riêng:
1. Đầu dòng bảng: **chọn dòng để thao tác hàng loạt**.
2. Trong checklist: **hoàn thành một bước**.
3. Trong form giao việc: **tạo lịch lặp Daily task**.

Không đặt một checkbox đầu dòng task rồi vừa chọn vừa đánh dấu hoàn thành; hành động hoàn thành cần đủ điều kiện nộp kết quả.

---

<a id="section-7"></a>

## 7. APP SHELL, ĐIỀU HƯỚNG VÀ ROUTE MAP

### 7.1. Sidebar desktop

```text
OpsDesk                           [Thu gọn]
Tên workspace

CÁ NHÂN
  Hôm nay
  Công việc của tôi               [số việc mở]
  Lịch làm việc
  Hộp thông báo                   [số chưa đọc]

VẬN HÀNH
  Tổng quan đội ngũ               (admin/manager)
  Tất cả công việc                (admin/manager)
  Seller
  Công việc lặp lại               (admin/manager)
  Báo cáo 18:00                   (quyền quản lý)

NHÂN SỰ
  Chấm công
  Yêu cầu của tôi
  Nhân sự                        (admin; manager xem danh bạ hạn chế)
  Duyệt yêu cầu                   (quyền HR)
  Bảng công tháng                (quyền HR)
  Lịch ca                        (quyền HR)

HỆ THỐNG
  Cài đặt                        (admin)
  Nhật ký & tác vụ nền           (admin)

Tên nhân viên · Vai trò
[Tài khoản] [Đăng xuất]
```

Employee không nhìn thấy menu quản trị rồi click mới báo lỗi; menu phải được lọc. Backend vẫn kiểm tra quyền dù menu bị ẩn.

### 7.2. Thanh trên

Trái: breadcrumb. Phải: tìm kiếm `Ctrl/Cmd+K`, nút `Giao việc` nếu có quyền, icon chuông kèm số, menu tài khoản dạng chữ.

Tìm kiếm chỉ tìm trong task/seller/người có thể xem; không index và gợi ý các nội dung HR riêng tư vào global search.

### 7.3. Route map web

| ID | Route | Trang | Quyền |
|---|---|---|---|
| P01 | `/login` | Đăng nhập | Public |
| P02 | `/auth/accept-invite` | Nhận lời mời | Theo token |
| P03 | `/auth/forgot-password`, `/auth/reset-password` | Khôi phục tài khoản | Theo luồng Auth |
| P04 | `/onboarding` | Thiết lập ban đầu / quyền thiết bị | Thành viên mới |
| P05 | `/today` | Hôm nay | Mọi thành viên |
| P06 | `/my-tasks` | Công việc của tôi | Mọi thành viên |
| P07 | `/overview` | Tổng quan đội ngũ | Admin/manager |
| P08 | `/tasks` | Tất cả công việc | Admin/manager |
| P09 | `/tasks/new` | Tạo task, có thể là drawer từ route khác | Người có quyền tạo |
| P10 | `/tasks/:taskId` | Chi tiết task, deep link độc lập | Theo ACL |
| P11 | `/recurring-tasks` | Mẫu công việc lặp | Admin/manager |
| P12 | `/recurring-tasks/:templateId` | Chi tiết mẫu, lịch sử lần thực hiện | Theo scope |
| P13 | `/calendar` | Lịch làm việc của tôi | Mọi thành viên |
| P14 | `/sellers` | Danh sách seller | Theo scope |
| P15 | `/sellers/:sellerId` | Chi tiết seller | Theo scope |
| P16 | `/team` | Nhân sự | Admin; manager danh bạ scope |
| P17 | `/team/:memberId` | Hồ sơ công việc và quản trị nhân sự | Theo quyền từng tab |
| P18 | `/attendance` | Chấm công & lịch sử của tôi | Mọi thành viên |
| P19 | `/attendance/live` | Theo dõi chấm công hôm nay | Quyền HR |
| P20 | `/attendance/remote-session` | Màn hình máy tính cho phiên online | Chính chủ |
| P21 | `/requests` | Yêu cầu của tôi | Mọi thành viên |
| P22 | `/approvals` | Duyệt đơn nhân sự | Quyền HR |
| P23 | `/timesheet/me` | Công tháng của tôi | Chính chủ |
| P24 | `/timesheets` | Tổng hợp công tháng | Quyền HR |
| P25 | `/shifts` | Lịch ca và ngày nghỉ | Quyền HR |
| P26 | `/reports` | Báo cáo 18:00 | Quản lý; cá nhân qua tab của mình |
| P27 | `/reports/:reportId` | Chi tiết bản báo cáo | Theo recipient + current scope |
| P28 | `/notifications` | Hộp thông báo | Chính chủ |
| P29 | `/settings/*` | Workspace, mạng, nhắc việc, dữ liệu | Admin |
| P30 | `/account` | Tài khoản và thiết bị | Chính chủ |
| P31 | `/system/jobs` | Trạng thái tác vụ nền | Admin |
| P32 | `/system/audit` | Nhật ký hệ thống | Admin |

Cần có trang 403, 404, lỗi 500, mất kết nối và không còn quyền workspace. Với ID tài nguyên không được phép xem, trả 404 chung để tránh dò ID.

### 7.4. Mobile navigation

Bottom tabs: **Hôm nay · Công việc · Chấm công · Thông báo · Thêm**.

- Tab “Thêm”: lịch, seller, yêu cầu của tôi, công tháng, tài khoản; thêm menu quản lý nếu được phép.
- Quản lý vẫn có nút nổi `+ Giao việc`; không che nút chấm công hoặc nội dung cuối màn hình.
- Push/deep link mở đúng màn hình; nếu chưa đăng nhập, đăng nhập xong quay về đích đã xác thực.
- Link đến task đã mất quyền: hiển thị “Bạn không còn quyền xem công việc này”, không đưa dữ liệu từ cache cũ.

---

<a id="section-8"></a>

## 8. QUY TẮC CHUNG CHO MỌI TRANG

1. **Loading:** skeleton đúng hình bố cục, không lấy số seed giả để lấp.
2. **Empty:** có nội dung giải thích và action đúng quyền.
3. **Error:** có thông báo cụ thể, nút thử lại, giữ input chưa gửi.
4. **Permission:** không hiển thị dữ liệu nhạy cảm trước khi xác minh rồi mới ẩn.
5. **Refreshing:** giữ dữ liệu cũ với nhãn đang cập nhật, không nhấp nháy trắng toàn trang.
6. **Mutation:** disable nút khi gửi; idempotency phía server; double-click không tạo trùng.
7. **Dirty form:** khi đóng form có nội dung chưa lưu, hỏi `Bỏ thay đổi?`.
8. **URL state:** các filter `seller`, `assignee`, `status`, `date`, `q`, `page` được lưu trong query string; refresh giữ nguyên.
9. **Thời gian:** dùng `dd/MM/yyyy`, giờ `HH:mm`; backend nhận ISO-8601 có timezone, không nhận chuỗi mơ hồ `05/10/2026 9h`.
10. **Tên người:** không rút còn mỗi chữ cái; khi dài thì ellipsis + tooltip; không avatar.
11. **Số liệu:** tất cả badge/header/table cùng dùng định nghĩa từ backend, không mỗi component tự đếm khác nhau.
12. **Accessibility:** keyboard navigation, focus ring, label form, focus trap modal, Escape để đóng khi an toàn, screen reader đọc được trạng thái.
13. **Responsive:** không giấu hành động quan trọng chỉ vì màn hình nhỏ; đổi bảng thành card hoặc scroll có hướng dẫn.
14. **Không phụ thuộc chat:** bình luận nằm trong task; không xây Slack mini.
15. **Dữ liệu mẫu:** chỉ trong local/demo với banner “Dữ liệu minh họa”. Production trống hiển thị empty state.

<a id="section-9"></a>

## 9. P01–P04 — ĐĂNG NHẬP, LỜI MỜI VÀ KHỞI TẠO

### 9.1. Đăng nhập

Bố cục desktop hai vùng: bên trái nền xám rất nhẹ có tên OpsDesk và câu “Công việc rõ ràng. Vận hành gọn gàng.”; bên phải card trắng rộng 400px. Mobile chỉ giữ card, không hero lớn.

Nội dung:

- Title: `Đăng nhập workspace`.
- Subtitle: `Theo dõi công việc, chấm công và phối hợp cùng đội ngũ.`
- `Email công việc`: type email, autocomplete email.
- `Mật khẩu`: type password, nút hiện/ẩn, autocomplete current-password.
- Nút `Đăng nhập`.
- Link `Quên mật khẩu?`.
- Dòng `Chưa có tài khoản? Liên hệ quản trị viên để nhận lời mời.`
- Không có đăng ký công khai ở V1.

Validation: trim email, không trim mật khẩu; lỗi đăng nhập chung không tiết lộ email có tồn tại. Rate limit theo IP/tài khoản; không chỉ disable nút frontend.

Sau đăng nhập: employee → `/today`; manager/admin → `/overview`; deep link hợp lệ được ưu tiên.

Tài khoản bị vô hiệu hóa: `Tài khoản của bạn đã bị tạm ngừng trong workspace này. Vui lòng liên hệ quản trị viên.` Không xóa lịch sử của tài khoản.

### 9.2. Nhận lời mời

Hiện workspace, email được mời, role đã được admin gán; người nhận không chỉnh role.

Fields: họ tên, mật khẩu mới, xác nhận mật khẩu. Nếu Supabase session đã có đúng email thì không tạo user mới; gắn membership qua token invite đã xác thực.

Token dùng một lần, có hạn; xác minh email người đang đăng nhập trùng lời mời. Lỗi: `Lời mời đã hết hạn hoặc đã được sử dụng.` Action `Quay về đăng nhập`. Không tự cấp membership chỉ từ `organization_id` trên URL.

### 9.3. Quên/đặt lại mật khẩu

Thông báo sau gửi email: `Nếu email thuộc hệ thống, hướng dẫn đặt lại mật khẩu sẽ được gửi đến bạn.` Chỉ dùng redirect URL allowlist. Sau đổi mật khẩu cho phép đăng xuất các phiên khác theo khả năng Auth và chính sách.

### 9.4. Onboarding

Nhân viên: kiểm tra họ tên/mã/chuyên môn, xem seller được giao, đọc quy định chấm công và dữ liệu cá nhân, kiểm tra quyền push; không xin camera/Wi-Fi cho tới khi dùng chức năng.

Admin lần đầu: wizard 5 bước:
1. Tên workspace và timezone.
2. Tạo seller.
3. Mời nhân sự, chọn role/chuyên môn/seller.
4. Tạo ca và ngày làm.
5. Cấu hình văn phòng/Wi-Fi và báo cáo 18:00.

Có thể `Để sau` cho bước 2–5, nhưng chấm công văn phòng phải hiện `Chưa cấu hình mạng văn phòng` và không giả pass.

Owner đầu tiên tạo bằng script bootstrap an toàn dùng server secret, không phải route public “tạo admin”.

---

<a id="section-10"></a>

## 10. P05 — MÀN HÌNH “HÔM NAY” CỦA NHÂN VIÊN

### 10.1. Bố cục desktop

```text
Cá nhân / Hôm nay
Hôm nay                                      [Lịch] [Tạo việc cá nhân]
Thứ ..., dd/MM/yyyy · Tên nhân viên

[ Ca 09:00–18:00 · Văn phòng · Chưa vào ca                 Chấm vào ]
[ 3 việc cần nhận ] [ 8 việc cần làm ] [ 2 quá hạn ] [ 1 đang chờ ]

[Ưu tiên xử lý]   [Tất cả]              Seller [Tất cả]  [Tìm việc...]

Việc mới cần nhận (3)
  Task row ...
Cần xử lý hôm nay (8)
  Task row ...
Đã quá hạn từ trước (2)
  Task row ...
Đang chờ / Bị vướng (1)
  Task row ...

Cột phụ 300px:
  Lịch trong ngày
  Yêu cầu gần nhất
  Ghi chú nhắc cuối ngày
```

Từ chiều rộng dưới 1200px, cột phụ chuyển xuống dưới. Không dùng bốn card KPI cao quá 96px.

### 10.2. Thẻ ca

Các trạng thái và câu chữ:

| Trạng thái | Dòng chính | Action |
|---|---|---|
| Chưa có ca | `Hôm nay chưa có lịch ca.` | `Xem lịch` / `Gửi yêu cầu` |
| Trước giờ ca | `Ca của bạn bắt đầu lúc 09:00.` | Chấm công chỉ trong cửa sổ được cấu hình |
| Chưa vào ca | `Chưa chấm vào ca` | `Chấm vào` |
| Đang làm | `Đã vào ca lúc 08:58 · Đang trong ca` | `Chấm ra`, `Xin về sớm` |
| Đã ra | `Đã ra ca lúc 18:03 · Công đang đối soát` | `Xem chi tiết` |
| Nghỉ cả ca đã duyệt | `Bạn có lịch nghỉ đã được duyệt hôm nay.` | `Xem yêu cầu` |
| Online được phép | `Hình thức: Online · Cần chụp ảnh khi vào ca` | `Chấm công online` |
| Thiếu chấm ra hôm trước | `Ca trước đang thiếu giờ ra.` | `Bổ sung chấm công` |

Trên web ở chế độ strict Wi-Fi: nút vào/ra mở hướng dẫn `Mở app để xác thực Wi-Fi và chấm công`; không dùng JS đo mạng rồi hiện “đúng Wi-Fi”.

### 10.3. Định nghĩa tập task hôm nay

Backend trả các nhóm **không trùng nhau**; ưu tiên phân nhóm:

1. `in_review` hoặc có blocker đang mở → nhóm “Đang chờ / Bị vướng”.
2. Task cần hành động của chính người đó, `due_at < start_of_today` và chưa terminal → “Quá hạn từ trước”.
3. Chưa nhận và `assigned_at <= now`, thuộc kế hoạch hôm nay/đã đến ngày hiển thị → “Việc mới cần nhận”.
4. Còn lại với `planned_date = today` hoặc deadline trong hôm nay hoặc công việc đã bắt đầu còn mở → “Cần xử lý hôm nay”.

Có tab `Đã hoàn thành hôm nay` thu gọn, không làm biến mất dấu vết công việc vừa nộp.

Task được giao cho ngày tương lai: gửi thông báo giao việc, hiện trong “Công việc của tôi”; không làm danh sách ưu tiên hôm nay tràn đầy việc tương lai. Nhân viên vẫn có thể nhận trước.

Sắp xếp trong nhóm: ưu tiên urgent/high → deadline tăng dần → thời điểm giao. Không đổi thứ tự liên tục khi Realtime cập nhật một metadata không liên quan.

### 10.4. Mỗi task row

- Checkbox đầu dòng **chỉ khi bật chế độ chọn nhiều**, mặc định không hiện ở Today.
- Tiêu đề; dưới là seller, nền tảng, nhãn daily nếu có.
- Deadline: `10:00 hôm nay`, hoặc `Quá hạn 1 ngày`; tooltip ngày giờ đầy đủ.
- Checklist `2/4`; status badge; số bình luận nếu có.
- Action nhanh: `Nhận việc` / `Bắt đầu` / `Cập nhật` / `Xem chờ duyệt`.
- Nút `…`: báo vướng, đề nghị đổi hạn, mở chi tiết.
- Không có nút “Hoàn thành” một chạm nếu task yêu cầu kết quả hoặc duyệt.

Empty: `Bạn chưa có công việc cần xử lý hôm nay.` Dòng phụ `Các công việc mới và lịch lặp sẽ xuất hiện tại đây.` Không ghi “Bạn đã hoàn thành tất cả” khi dữ liệu chưa load hoặc chưa có task được giao.

---

<a id="section-11"></a>

## 11. P06–P08 — CÔNG VIỆC CỦA TÔI, TẤT CẢ CÔNG VIỆC VÀ TỔNG QUAN

### 11.1. P06 — Công việc của tôi

Tabs: `Được giao` · `Tôi phối hợp` · `Cần tôi duyệt` · `Tôi đã giao` (nếu có quyền).

View: `Danh sách` mặc định; `Bảng trạng thái` tùy chọn. Filter seller, deadline, status, daily, mức ưu tiên, từ khóa.

Bảng desktop:
- Tiêu đề 36%.
- Seller 16%.
- Trạng thái 12%.
- Hạn hoàn thành 14%.
- Kế hoạch 10%.
- Tiến độ 8%.
- Menu 4%.

Action hàng loạt cho employee giới hạn `Nhận các việc đã chọn` khi đúng assignee; không cho hàng loạt nộp hoàn thành bỏ qua kết quả.

### 11.2. P08 — Tất cả công việc

Header `Tất cả công việc`, subtitle `Theo dõi và điều phối công việc theo seller, nhân sự và thời hạn.` Action `Giao việc`.

Saved filters mặc định: `Tất cả` · `Chưa nhận` · `Sắp đến hạn` · `Quá hạn` · `Chờ duyệt` · `Bị vướng`.

Bảng thêm cột `Người phụ trách`, `Người duyệt` tùy cấu hình hiển thị. Click title mở drawer, URL đổi để có deep link.

Bulk actions: đổi người, đổi ngày kế hoạch, đổi mức ưu tiên, hủy. Mỗi thao tác phải preview số dòng đủ quyền, các dòng không hợp lệ và yêu cầu lý do nếu ảnh hưởng lịch.

- Bulk không được nửa thành công mà không báo rõ.
- Mặc định mutation atomic theo nhóm tối đa 50 task; nếu chọn nhiều hơn tạo nhiều batch có kết quả từng batch.
- Xóa vật lý task đã giao không có trong UI. Dùng hủy với audit.
- Board kéo thả chỉ gọi command transition hợp lệ; kéo sang “Hoàn thành” mở form nộp/duyệt, không cập nhật status trực tiếp.

### 11.3. P07 — Tổng quan đội ngũ

Header: `Tổng quan đội ngũ`; sub `Tình hình công việc đến HH:mm, dd/MM/yyyy`. Date picker mặc định hôm nay, seller filter.

Bốn card tối đa:
1. `Việc đến hạn hôm nay`.
2. `Chưa có xác nhận`.
3. `Cần duyệt / hỗ trợ`.
4. `Quá hạn chưa xử lý`.

Dưới là hai cột:
- Trái rộng 65%: “Cần quản lý xử lý” với reviewer queue, blockers, recurrence thiếu người.
- Phải 35%: “Phân bổ hôm nay” bảng nhân sự, số task mở, ước lượng nếu có, cảnh báo quá nhiều việc cùng giờ.

Phần tiếp: bảng seller với việc đến hạn/đã nộp/chờ duyệt/còn mở. Không hiển thị doanh thu giả, vì chưa nối sàn.

Thẻ chấm công tổng chỉ hiện khi có quyền HR; manager thường chỉ thấy `Đang làm`, `Nghỉ đã duyệt`, `Chưa cập nhật lịch` trong phạm vi công việc, không thấy giờ vào cụ thể hoặc lý do nghỉ.

Một nhân sự có nhiều seller chỉ xuất hiện một lần trong bảng theo người; task được đếm một lần theo ID. Không cộng số collaborator vào tổng task được giao chính.

---

<a id="section-12"></a>

## 12. P09 — FORM GIAO VIỆC NHANH, DAILY CHECKBOX VÀ GIAO HÀNG LOẠT

### 12.1. Vị trí và cấu trúc

Từ button trên header mở drawer 680px. Deep link `/tasks/new` dùng cùng component, không tạo một form khác có validation khác.

Title: `Giao công việc`. Subtitle: `Chọn người phụ trách, seller và thời hạn. Các thông tin còn lại có thể bổ sung khi cần.`

### 12.2. Trường cơ bản

| Field | Kiểu | Bắt buộc | Default / validation |
|---|---|---|---|
| Tiêu đề | Textarea 2 dòng | Có | Trim; 3–160 ký tự |
| Seller | Searchable select | Có với task vận hành | Tự chọn seller đang mở; lựa chọn `Nội bộ / Không thuộc seller` chỉ khi đủ quyền |
| Người phụ trách | Searchable select một người | Có | Gợi ý từ seller + chuyên môn; không tự giao khi có nhiều ứng viên ngang nhau |
| Ngày dự kiến làm | Date picker | Có | Hôm nay; được chọn tương lai |
| Hạn hoàn thành | Date + time picker | Có | Hôm nay 17:00 nếu còn tương lai; nếu đã quá thì gợi ý giờ tương lai, không tự set quá hạn |
| Ưu tiên | Segmented/select | Có | Bình thường; `Thấp / Bình thường / Cao / Khẩn` |

Người không thuộc seller bị disable với giải thích, không chỉ biến mất khiến admin không hiểu. Link `Quản lý phân công seller` cho admin.

### 12.3. Checkbox Daily task

Nhãn nguyên văn:

**`Daily task — Tự động lặp lại`**

Mô tả: `Mỗi ngày phù hợp sẽ tạo một công việc riêng, có kết quả và lịch sử độc lập.`

Khi tích, đổi vùng ngày/hạn thành:

| Field | Default | Quy tắc |
|---|---|---|
| Lịch lặp | `Theo lịch làm việc` | `Theo lịch làm việc / Mỗi ngày (7 ngày) / Chọn ngày trong tuần` |
| Ngày trong tuần | Ẩn | Hiện khi custom; ít nhất 1 ngày |
| Ngày bắt đầu | Hôm nay | Không trước ngày hiện tại trong luồng thường |
| Kết thúc | `Không giới hạn` | Hoặc ngày kết thúc không nhỏ hơn bắt đầu |
| Giờ đến hạn | Giờ đã chọn | Hạn cố định từng ngày theo timezone của template |
| Phân công | `Cố định người đã chọn` | Hoặc `Theo người phụ trách seller/lịch trực` |
| Khi người phụ trách nghỉ | `Yêu cầu quản lý chọn người thay` | Không tự hủy nhiệm vụ thiết yếu |
| Áp dụng ngày nghỉ/lễ | Kế thừa lịch | Nếu chọn 7 ngày, vẫn cần người trực thực tế |

Bên dưới render preview 7 lần tiếp theo:
`Thứ Hai, 05/10 · 10:00 · Linh · Seller A`
`Thứ Ba, 06/10 · 10:00 · Cần chọn người thay` nếu có nghỉ.

Text nhắc: `Việc chưa xong hôm trước vẫn được giữ lại. Lần mới không tự đánh dấu hoàn thành theo lần cũ.`

Nút submit đổi thành `Tạo lịch công việc`. Tắt checkbox phải bảo toàn các trường cơ bản, bỏ recurrence draft sau khi xác nhận nếu đã thiết lập nhiều.

### 12.4. Các phần mở rộng

Accordion `Thông tin bổ sung`:
- Mô tả text/Markdown an toàn, tối đa 10.000 ký tự; sanitize khi render.
- Checklist: thêm dòng, reorder bằng nút hoặc drag, required flag, optional assigned member.
- Người phối hợp: chọn nhiều trong scope seller.
- Người duyệt: hiện khi bật `Cần duyệt kết quả`.
- `Yêu cầu kết quả khi hoàn thành`: mặc định on, một trong text/link/file.
- `Bắt buộc đính kèm bằng chứng`: mặc định off, mở theo loại task.
- `Cho phép “Đã kiểm tra — Không phát sinh”`: dành cho việc rà soát, mặc định off.
- Tài liệu tham khảo: link hoặc file private.
- Ước lượng thời gian: số phút, optional, không dùng để tính công.
- Nhắc việc: kế thừa chính sách, có thể chọn preset `Chuẩn / Sát hơn`, chỉ manager/admin. Chọn `Sát hơn` phải nhập lý do và ngày xem lại; lưu `reminder_profile`, `reminder_profile_reason`, `reminder_profile_review_at`. Nếu không mở phần này, dùng `standard`.

### 12.5. Giao hàng loạt theo seller

Toggle `Áp dụng cho nhiều seller`. Chọn seller tạo bảng preview:
`Seller | Người chịu trách nhiệm | Deadline | Trạng thái hợp lệ`.

Tạo một task riêng cho mỗi seller; một `batch_id` liên kết. Không tạo một task gắn nhiều seller, vì quyền và báo cáo sẽ khó tách.

Nếu daily + nhiều seller: một template có các target seller riêng; occurrence unique theo template + target + ngày. Người phụ trách có thể khác nhau từng target.

Nếu 1 seller thiếu người, chặn submit với danh sách lỗi; tùy chọn `Chỉ giao các seller hợp lệ` phải do quản lý chủ động chọn, không tự bỏ seller lỗi.

### 12.6. AI nhập câu chữ — SHOULD, không chặn V1 core

Ô riêng `Nhập nhanh bằng câu chữ`, ví dụ: `Giao Linh kiểm tra đánh giá Seller A trước 10h ngày mai, lặp mỗi ngày làm việc.`

AI chỉ trả JSON draft theo schema. Luôn render form preview và yêu cầu bấm giao. Không tự resolve tên trùng; hiển thị chọn người/seller. Nếu thiếu AI key, ẩn hoặc disable chức năng kèm lý do; form chuẩn vẫn đầy đủ.

### 12.7. Thành công và lỗi

Thành công: toast `Đã giao công việc cho Linh.` hoặc `Đã tạo lịch cho 3 seller.`; query cache cập nhật; có action `Mở công việc`.

Lỗi validation giữ form và focus trường đầu tiên. Lỗi server giữ idempotency key để retry cùng thao tác. Không phát push trước khi transaction tạo task commit.

---

<a id="section-13"></a>

## 13. P10 — CHI TIẾT TASK VÀ NỘP KẾT QUẢ

### 13.1. Bố cục

Header: mã task `TSK-000123`, seller chip, status, menu. Title lớn 22px. Badge daily nếu có, link `Xem lịch lặp`.

Grid metadata: người phụ trách, người giao, reviewer, kế hoạch, deadline, ưu tiên. Không hiển thị avatar.

Tabs: `Nội dung` · `Kết quả` · `Trao đổi` · `Lịch sử`.

Dưới header có action bar đúng trạng thái: `Nhận việc`, `Bắt đầu`, `Nộp kết quả`, `Báo vướng`, `Duyệt`, `Yêu cầu làm lại`.

### 13.2. Nội dung

Mô tả, checklist, tài liệu tham khảo. Checklist hiện số required/optional; chặn nộp nếu required chưa xong. Item checked ghi người và thời gian. Không để contributor tick item ngoài quyền khi task đã khóa nộp.

### 13.3. Nộp kết quả

Modal/drawer:
- `Kết quả đã thực hiện`: textarea.
- `Link kết quả`: nhiều URL HTTP/HTTPS; kiểm tra scheme.
- `Tệp đính kèm`: chọn upload; hiện trạng thái từng file.
- Với task cho phép: radio `Có phát sinh và đã xử lý` / `Đã kiểm tra — Không phát sinh`.
- Preview checklist còn thiếu.
- Nút `Gửi duyệt` hoặc `Hoàn thành công việc`.

Không phát request nộp khi file vẫn đang upload. File upload hỏng giữ text và cho retry file.

Mỗi lần nộp là `task_submissions` version mới. Kết quả cũ chỉ đọc; reviewer có thể so sánh.

### 13.4. Báo vướng

Fields: loại `Thiếu thông tin / Chờ người khác / Lỗi công cụ / Cần quyết định / Khác`; mô tả 10–2.000 ký tự; người cần hỗ trợ; dự kiến giải quyết optional.

Banner trên task: `Đang chờ hỗ trợ từ [tên]`. Không tự xóa deadline. Cảnh báo quá hạn có thể vẫn hiện, nhưng nhắc tháo gỡ chuyển sang đầu mối.

### 13.5. Lịch sử

Hiển thị event dạng:
`09:02 · Linh đã nhận việc.`
`09:15 · Dũng đổi hạn từ 10:00 sang 11:00. Lý do: chờ dữ liệu sàn.`
`10:42 · Linh nộp kết quả lần 1.`
`10:55 · Quản lý yêu cầu bổ sung.`
Không cho người dùng sửa event.

---

<a id="section-14"></a>

## 14. P11–P12 — QUẢN LÝ DAILY TEMPLATE

### 14.1. Danh sách mẫu

Header `Công việc lặp lại`, action `Tạo lịch công việc`.

Cột: tên mẫu, seller/target count, phân công, lịch lặp, giờ hạn, lần tiếp theo, trạng thái `Đang chạy / Tạm dừng / Đã kết thúc / Cần xử lý`, menu.

Filter theo seller, người, active/paused. Action: mở, tạm dừng, tiếp tục, kết thúc, nhân bản.

Tạm dừng có dialog: `Tạm dừng tạo công việc mới? Các công việc đã được tạo vẫn giữ nguyên.`

### 14.2. Chi tiết mẫu

Tabs:
- `Thiết lập`: nội dung, checklist, target, lịch, người.
- `Lịch sắp tới`: preview 30 ngày, phân biệt occurrence đã tạo và dự kiến.
- `Lịch sử thực hiện`: mỗi ngày một dòng.
- `Thay đổi mẫu`: phiên bản, người sửa, hiệu lực.

Lịch sử thực hiện có nhãn:
`Đã tạo task`, `Được miễn theo lịch`, `Không có ca phù hợp`, `Cần phân công người thay`, `Đã tạm dừng`.

Không gọi “Hoàn thành” cho ngày không tạo vì nghỉ.

### 14.3. Sửa mẫu

Dialog chọn:
- `Chỉ công việc đang xem`: sửa instance, không sửa mẫu.
- `Từ ngày được chọn trở đi`: tạo version mới, không thay instance đã bắt đầu hoặc hoàn tất.
- Không có lựa chọn sửa toàn bộ lịch sử mặc định.

Instance tương lai đã tạo nhưng chưa giao/bắt đầu: được cập nhật theo lựa chọn rõ ràng; phải lưu version mẫu đã dùng và event. Những instance có người thao tác giữ nguyên trừ admin chủ động sửa.

---

<a id="section-15"></a>

## 15. P13 — LỊCH LÀM VIỆC

View `Ngày / Tuần / Tháng`; mặc định tuần desktop, agenda list mobile.

Layers toggle: `Công việc` · `Ca làm` · `Nghỉ đã duyệt`. Công việc dự kiến từ template có đường viền nét đứt và chữ `Dự kiến`; task thật viền liền, có ID.

- Click task thật mở chi tiết.
- Click occurrence dự kiến mở preview lịch, không giả tạo task hoàn thành được.
- Kéo đổi ngày kế hoạch chỉ người có quyền; nếu chỉ đổi planned date phải giữ deadline, nếu muốn đổi hạn có dialog riêng.
- Chọn ngày để tạo task điền sẵn planned_date.
- Ca qua đêm thể hiện kéo sang ngày kế tiếp nhưng work_date là ngày bắt đầu ca.
- Manager có toggle theo seller/người trong scope; không kéo cả lịch nghỉ có lý do riêng tư.
- Khi nhân viên nghỉ: hiển thị `Nghỉ đã duyệt` chứ không lý do chi tiết cho đồng nghiệp.
- Lịch tháng nhiều việc: hiện 3 dòng + `+N việc`, click mở danh sách ngày.

---

<a id="section-16"></a>

## 16. P14–P15 — SELLER VÀ PHÂN CÔNG

### 16.1. Danh sách seller

Có segmented `Danh sách / Thẻ`; mặc định thẻ nếu dưới 8 seller, danh sách nếu nhiều hơn. Cách bố trí thẻ tham chiếu ba card folder trong ảnh nhưng thay bằng dữ liệu seller, không icon folder 3D.

Card: icon shop line, tên seller, nền tảng, brand label optional; `N việc hôm nay · M việc cần xử lý`; tên phụ trách vận hành; nút `Mở seller`.

Không hiện số đơn/doanh thu/tồn kho giả.

### 16.2. Tạo/sửa seller

Fields:
- Tên hiển thị 2–80 ký tự.
- Mã nội bộ duy nhất trong organization.
- Nền tảng: `Shopee / TikTok Shop / Lazada / Khác`.
- Nhãn thương hiệu optional.
- URL shop optional; chỉ URL public, không token.
- Nhân sự tham gia và chuyên môn tại seller.
- Quản lý seller.
- Người phụ trách mặc định từng chuyên môn.
- Trạng thái hoạt động.

Mỗi chuyên môn có thể nhiều người nhưng một `default_assignee` tại một thời điểm. Chọn “Theo lịch trực” cần có lịch coverage theo ngày, không random chia việc.

### 16.3. Chi tiết seller

Tabs `Tổng quan / Công việc / Lịch lặp / Nhân sự / Tệp tham khảo / Thiết lập`.

Tab tổng quan: card việc đến hạn/chờ duyệt/quá hạn + bảng cần xử lý. Nhân viên chỉ thấy task mình được quyền, các tổng phải theo tập được quyền chứ không toàn shop.

Archive seller: chặn tạo mới, cảnh báo template đang chạy và task mở; yêu cầu xử lý hoặc tạm dừng. Không xóa lịch sử.

---

<a id="section-17"></a>

## 17. P16–P17 — NHÂN SỰ

### 17.1. Bảng nhân sự

Cột: họ tên, mã, role, chuyên môn, seller, trạng thái tài khoản, công việc mở. Không có avatar.

Actions admin: `Mời nhân sự`, sửa phân quyền, gán seller, tạm ngừng, gửi lại lời mời. Manager chỉ xem danh bạ được phép và mở tình hình task, không đổi quyền.

### 17.2. Hồ sơ nhân sự

Header tên + mã; tabs:
- `Công việc`: trong scope người xem.
- `Phân công seller`: phạm vi được phép.
- `Lịch làm việc`: bản không có dữ liệu riêng tư nếu không có HR.
- `Chấm công & bảng công`: chính chủ/HR.
- `Quyền & tài khoản`: admin.

Email đăng nhập và thông tin HR không đưa vào API danh bạ chung nếu không cần. Không lưu CCCD, tài khoản ngân hàng, hợp đồng lao động trong V1.

### 17.3. Vô hiệu hóa nhân sự

Dialog phải liệt kê:
- Task đang mở.
- Template dùng người này.
- Seller đang đặt người này làm mặc định.
- Ca tương lai.
- Chấm công đang mở.

Admin chọn bàn giao hoặc đánh dấu cần xử lý. Sau xác nhận, membership inactive ngay; thu hồi thiết bị/push/session phù hợp. Không xóa lịch sử, không dùng `ON DELETE CASCADE` làm mất công tháng.

Người nhận task cũ mới phải nhận lại. Cron không tiếp tục giao cho thành viên inactive.

---

<a id="section-18"></a>

## 18. P18–P20 — CHẤM CÔNG VĂN PHÒNG, ONLINE VÀ THEO DÕI

### 18.1. Trang chấm công của tôi

Header `Chấm công`, sub `Ghi nhận thời gian làm việc theo ca đã được phân.`

Khối chính:
- Ngày, ca, nghỉ giữa ca, tổng phút theo lịch.
- Hình thức được phép `Văn phòng` hoặc `Online`.
- Thông tin mạng/ảnh cần kiểm tra.
- Nút lớn `Chấm vào ca` hoặc `Chấm ra ca`.
- Dòng `Thời gian chấm công lấy theo máy chủ.`

Timeline hôm nay: vào/ra từng phiên, nhãn phương thức, trạng thái đã ghi nhận/chờ điều chỉnh. Chỉ chính chủ hoặc HR xem ảnh. Dưới là lịch sử 7–30 ngày, filter tháng.

### 18.2. Check-in văn phòng trên native

Trước khi bật nút, lấy challenge và hiển thị từng kiểm tra:
- `Tài khoản đang hoạt động`.
- `Có ca làm việc phù hợp`.
- `Đã kết nối điểm Wi-Fi văn phòng`.
- `Đường mạng được máy chủ xác thực`.

Không hiển thị BSSID đầy đủ cho toàn bộ nhân viên nếu không cần; có thể hiện tên văn phòng và SSID.

States:
- Permission denied: `Cần quyền truy cập thông tin Wi-Fi để xác thực chấm công tại văn phòng.` Action `Mở cài đặt` / `Gửi yêu cầu hỗ trợ`.
- Wrong Wi-Fi: `Bạn chưa kết nối mạng Wi-Fi đã đăng ký của công ty.`
- Unknown network: `Chưa xác minh được mạng hiện tại. Bạn có thể thử lại hoặc gửi yêu cầu bổ sung.`
- VPN/source mismatch: `Kết nối hiện tại không khớp mạng văn phòng. Hãy kiểm tra VPN hoặc liên hệ quản trị viên.`
- Success: `Đã chấm vào lúc 08:58.`; không hiện success trước commit.
- Duplicate: trả lại record đã tạo; thông báo `Bạn đã chấm vào lúc 08:58.`

### 18.3. Chấm công online

Chỉ bật nếu ca cho phép hoặc request online đã duyệt phủ thời điểm tương ứng. Không có radio tự chọn online nhằm vượt Wi-Fi.

Luồng mobile:
1. Xem ca và thông báo quyền riêng tư ngắn.
2. Lấy challenge 120 giây.
3. Mở camera **trực tiếp trong app**, không có “Chọn từ thư viện”.
4. Hướng dẫn `Chụp rõ bạn và máy tính đang sử dụng để làm việc. Tránh để lộ thông tin nhạy cảm trên màn hình.`
5. Chụp, preview, `Chụp lại` hoặc `Dùng ảnh này`.
6. Upload private + finalize; server ghi nhận.
7. Nếu challenge hết hạn khi upload, giữ ảnh tạm ngắn hạn nhưng yêu cầu chụp lại theo challenge mới; không dùng ảnh cũ cho một phiên mới.
8. Xóa ảnh tạm trên thiết bị sau gửi thành công/hủy; không tự lưu vào thư viện.

UI không được hiện ảnh mẫu giả với nhãn chấm công thành công.

V1 không dùng AI nhận diện khuôn mặt/liveness. Ảnh là bằng chứng hỗ trợ có thể review; không bảo đảm chống giả mạo hoàn toàn. Lưu `camera_capture_declared=true` chỉ là dữ liệu khai báo từ client, không chứng cứ mật mã.

### 18.4. Trang máy tính cho online session — SHOULD

`/attendance/remote-session` hiển thị tên workspace, tên người, ngày giờ máy chủ, mã phiên 6 ký tự và countdown. Không hiện task riêng tư phía sau.

Nhân viên mở trang này trên máy tính rồi selfie cùng màn hình. Mã ngắn hạn gắn với account và challenge. V1 không bắt buộc OCR đọc mã; admin có thể kiểm tra thủ công. Không tuyên bố đã xác minh laptop chỉ vì ảnh được upload. Nếu bật yêu cầu này, backend kiểm tra có laptop session đang hiệu lực cùng người, còn nội dung ảnh được đánh dấu cần đối chiếu khi có nghi ngờ.

### 18.5. Check-out và phiên nhiều lần

- Vào và ra là hai event khác nhau.
- Có thể nhiều phiên trong một ca để ghi nhận ra/vào lại; chỉ một session mở tại một thời điểm cho một người trong organization.
- Không bắt chấm ra/vào bữa trưa nếu ca đã có break định sẵn; break luôn bị loại khỏi giờ làm hợp lệ theo lịch.
- Về sớm vẫn được chấm ra thực tế dù chưa có đơn; tạo ngoại lệ để đối soát, không chặn ghi nhận.
- Chấm ra văn phòng vẫn kiểm tra điều kiện theo chính sách. Nếu đã rời văn phòng, gửi correction, không tự cho bypass.
- Mất mạng: không ghi nhận chấm công chính thức offline với giờ máy. Cho lưu yêu cầu bổ sung; phân biệt rõ chưa chấm công.
- Ngoài ca/cửa sổ được phép: cho gửi request, không tự cộng tăng ca.

### 18.6. P19 — Theo dõi chấm công hôm nay

Chỉ HR. KPI: có ca / đang trong ca / đã kết thúc / nghỉ đã duyệt / cần đối soát.

Bảng: nhân sự, ca, hình thức, lần vào đầu, lần ra cuối, thời gian tạm tính, trạng thái, action. Click mở drawer có event, sessions, requests, evidence nếu đủ quyền.

Không ghép thành timeline giám sát vị trí. Không tự cập nhật “đang làm” từ trạng thái online của app.

---

<a id="section-19"></a>

## 19. P21–P22 — ĐƠN TỪ VÀ PHÊ DUYỆT

### 19.1. Yêu cầu của tôi

Tabs `Tất cả / Chờ duyệt / Đã duyệt / Từ chối / Đã hủy`. Nút `Tạo yêu cầu`.

Các loại:
- Nghỉ cả ngày/nhiều ngày.
- Nghỉ theo giờ/nửa ngày.
- Về sớm.
- Đi muộn.
- Làm online.
- Bổ sung/sửa chấm công.

Mỗi card: loại, khoảng thời gian, loại nghỉ/treatment, số phút dự kiến ảnh hưởng, trạng thái, thời điểm gửi. Không gọi mọi đơn là nghỉ phép hưởng lương.

### 19.2. Form nghỉ/về sớm

Fields:
- Loại yêu cầu.
- Ngày bắt đầu/kết thúc hoặc ca cụ thể.
- Khoảng giờ; nửa ngày được lấy từ working segments của ca, không luôn bằng 4 giờ.
- Loại nghỉ: options từ `leave_types`, kèm nhãn `Hưởng lương / Không lương / Cần HR xác định`.
- Lý do: 10–2.000 ký tự; hiển thị phạm vi người được xem.
- Tài liệu optional, private.
- Task bị ảnh hưởng: server preview tự liệt kê, không dùng client tự tính.
- Ghi chú bàn giao, người đề xuất nhận thay optional.

Preview: `Dự kiến ảnh hưởng 120 phút làm việc (0,25 công theo ca này). Chỉ áp dụng sau khi được duyệt.`

Không trừ giờ nghỉ trưa lần nữa. Không cho khoảng kết thúc <= bắt đầu. Đơn nghỉ chồng nhau đã duyệt bị chặn hoặc yêu cầu sửa đơn hiện có.

### 19.3. Form bổ sung chấm công

Chọn ca/ngày, vấn đề `Quên vào / Quên ra / Sai thời điểm / Lỗi mạng / Khác`; giờ đề xuất, lý do và bằng chứng optional.

Giờ đề xuất là **claim**, chưa phải event chấm công chính thức. Duyệt tạo adjustment có `effective_at` người đề xuất và `recorded_at` máy chủ; không sửa event gốc.

### 19.4. Duyệt yêu cầu

Bảng chờ duyệt: nhân sự, loại, khoảng, công ảnh hưởng, task ảnh hưởng, thời điểm gửi. Mở drawer:

- Thông tin yêu cầu.
- Lịch ca và các đơn liên quan.
- Preview công trước/sau.
- Task impacted: chọn từng task `Bàn giao / Giữ người và đổi kế hoạch / Miễn lần này / Cần xử lý sau`.
- Quyết định `Duyệt` hoặc `Từ chối`; từ chối cần lý do.
- Nếu chuyển loại nghỉ từ đề nghị, phải nêu treatment được duyệt và lý do; nhân viên nhận thông báo.
- Đơn duyệt xong cập nhật calendar, attendance projection và task routing trong cùng transaction hoặc outbox có trạng thái rõ.

Phê duyệt nghỉ **không được bị chặn chỉ vì chưa tìm được người làm task**. Cho duyệt nghỉ và tạo hàng đợi `Cần bàn giao`, nhưng không tự xóa task hay tiếp tục nhắc người đã nghỉ trong khoảng đó.

Hai người cùng duyệt: khóa row/version; người đến sau nhận `Yêu cầu đã được xử lý bởi ...`, không tạo hai quyết định.

### 19.5. Rút/hủy đơn

- Pending: người gửi rút.
- Approved chưa tác động kỳ công đã chốt: gửi đề nghị hủy; HR duyệt, tính lại có audit.
- Đã chốt công: cần mở kỳ hoặc điều chỉnh phiên bản kỳ; không silent recalc.
- Không xóa ảnh/bằng chứng tức thì nếu đang có yêu cầu giữ dữ liệu hợp lệ; áp dụng retention policy.

---

<a id="section-20"></a>

## 20. P23–P25 — LỊCH CA VÀ BẢNG CÔNG THÁNG

### 20.1. Lịch ca

Admin tạo `Mẫu ca`: tên, giờ bắt đầu/kết thúc, breaks, địa điểm/hình thức mặc định, cửa sổ vào/ra, chính sách phút dung sai.

- Ca qua đêm: end có `day_offset=1`.
- V1 hỗ trợ lịch một hoặc nhiều ca nhưng không cho hai ca của cùng người overlap.
- Mẫu ca thay đổi tạo version áp dụng tương lai; ca đã diễn ra giữ snapshot.
- Gán lịch theo ngày trong tuần, ngày hiệu lực; có override ngày đặc biệt.
- Ngày lễ/ngày nghỉ được nhập/cấu hình chính thức; không hardcode lịch lễ tự suy ra rồi tự trả lương.
- Nghỉ hưởng lương ngày lễ cần loại treatment riêng đã được cấu hình theo chính sách được rà soát.

UI `/shifts`: tuần dạng grid, hàng nhân sự, cột ngày; kéo gán chỉ admin/HR. Có panel mẫu ca và preview xung đột.

### 20.2. Công tháng của tôi

Header `Công tháng của tôi`, month picker, nhãn `Tạm tính / Đang đối soát / Đã chốt`.

Cards:
- Công theo lịch.
- Công thực làm.
- Nghỉ hưởng lương.
- Nghỉ không lương.
- Ngày cần đối soát (không gộp thiếu data thành nghỉ).

Bảng ngày:
`Ngày | Ca | Hình thức | Vào | Ra | Giờ hợp lệ | Nghỉ hưởng lương | Nghỉ không lương | Ngoại lệ | Action`.

Click ngày mở timeline và phép tính. Nút `Đề nghị điều chỉnh` điền sẵn ngày. Hiển thị phút/hh:mm chính xác; công có 2–4 số thập phân cho UI nhưng giữ precision khi cộng.

### 20.3. Bảng công tháng của quản lý

Header `Bảng công tháng` với tháng, tìm nhân sự, `Xuất Excel`, `Đối soát`, `Chốt tháng` đúng quyền.

Bảng tổng:
`Mã | Nhân sự | Công theo lịch | Văn phòng | Online | Tổng thực làm | Nghỉ hưởng lương | Nghỉ không lương | Vắng chưa giải trình | Thiếu dữ liệu | Trạng thái`.

Thêm các cột đi muộn/về sớm dạng phút khi mở rộng. Không tự chuyển những phút này thành tiền phạt.

Click người mở bảng ngày. Tab `Ngoại lệ` liệt kê thiếu vào/ra, overlap, đơn chưa duyệt, nghỉ và làm trùng nhau, chỉnh sửa sau cutoff.

### 20.4. Chốt tháng

Luồng:
1. HR chuyển sang đối soát, nhân viên được xem/gửi correction.
2. Admin chạy kiểm tra chốt.
3. Nếu còn exception loại blocking, không chốt; show danh sách cần giải quyết.
4. Admin xác nhận `Chốt bảng công tháng MM/YYYY`.
5. Tạo snapshot rows, version=1, người chốt, thời điểm chốt, policy version.
6. Export dùng snapshot đã chốt, không query lại raw events.
7. Sửa sau chốt: mở lại có lý do hoặc tạo revision theo cấu hình; giữ phiên bản cũ.

Thông báo xác nhận: `Sau khi chốt, các điều chỉnh sẽ cần mở lại kỳ và được lưu lịch sử. Việc chốt công không tự tính hoặc chi trả lương.`

---

<a id="section-21"></a>

## 21. P26–P27 — BÁO CÁO TỰ ĐỘNG 18:00

### 21.1. Danh sách báo cáo

Header `Báo cáo 18:00`; filter ngày, seller, nhân sự trong scope. Có trạng thái `Đang tạo / Đã tạo / Gửi thông báo lỗi / Tạo muộn / Đã cập nhật phiên bản`.

Card/dòng: ngày, cutoff, số nhân sự trong scope, task còn mở, việc cần quản lý, version.

Nếu chưa đến 18:00: `Báo cáo hôm nay sẽ được chốt lúc 18:00. Bạn đang xem dữ liệu trực tiếp.` Dữ liệu trực tiếp không mang nhãn snapshot đã chốt.

### 21.2. Chi tiết báo cáo

Header:
`Báo cáo vận hành — dd/MM/yyyy`
`Chốt đến 18:00 (giờ Việt Nam) · Tạo lúc 18:01 · Phiên bản 1`
`Phạm vi: Seller A, Seller B` hoặc `Toàn workspace`.

Bốn khối:
1. Tóm tắt điều hành: kết quả, tồn, quyết định cần quản lý.
2. Theo nhân sự.
3. Theo seller.
4. Việc cần xử lý tiếp.

Bảng nhân sự:
`Nhân sự | Đến hạn trong ngày ≤18:00 | Hoàn thành | Chờ duyệt | Còn mở | Có vướng mắc`.

`Có vướng mắc` là tập con của còn mở, không cộng ngang vào tổng.

Dưới mỗi người:
- Kết quả đã bàn giao có link task.
- Việc còn mở và nguyên nhân do người thực hiện cập nhật.
- Task đã quá hạn từ trước.
- Việc đến hạn sau 18:00.
- Việc ưu tiên ngày mai đã lên lịch.
- Chỉ trạng thái làm việc tổng quát nếu người xem không có quyền HR.

Không suy luận “không làm việc” từ thiếu update. Dùng `Chưa có cập nhật sau hạn`.

### 21.3. Phạm vi gửi

Admin: bản tổng toàn tổ chức. Manager: snapshot riêng theo quyền tại thời điểm tạo. Employee: tóm tắt cá nhân trong app; không nhận báo cáo người khác.

Mỗi recipient một thông báo tổng có link, không push riêng từng nhân viên. Khi manager mất seller scope, backend kiểm tra lại quyền trước mở/export. Nếu scope snapshot không còn là tập con quyền hiện tại, chặn bản gốc và cho yêu cầu bản đã lọc, không chỉ ẩn tên seller nhưng giữ tổng.

Ảnh chấm công, IP, lý do nghỉ, file y tế không đưa vào report JSON hoặc AI summary.

### 21.4. Không phụ thuộc AI

Core report luôn được SQL/hàm xác định tạo ra. Summary text có template fallback. AI chỉ diễn giải JSON đã lọc, không tự tính các con số.

Nếu AI timeout: hiển thị báo cáo bình thường với phần diễn giải theo mẫu, không trì hoãn báo cáo 18:00.

---

<a id="section-22"></a>

## 22. P28 — HỘP THÔNG BÁO

Tabs `Tất cả / Chưa đọc / Công việc / Nhân sự / Báo cáo`.

Notification row:
- Icon theo loại.
- Title: `Bạn có công việc mới`.
- Body: `Kiểm tra đánh giá Seller A · Hạn 10:00 hôm nay`.
- Thời gian.
- Action `Mở công việc`; có `Nhận việc` khi phù hợp và đã xác thực.
- Read/unread không dùng avatar.

Mark read không phải ack task. Bấm notification không tự nhận việc. Có `Đánh dấu tất cả đã đọc`.

Thông báo HR push ra màn hình khóa chỉ ghi chung: `Yêu cầu của bạn đã có kết quả.` Không đưa lý do nghỉ hoặc ảnh vào push.

Khi mất quyền với object, thông báo vẫn có thể giữ text đã được làm tối giản nhưng link không tiết lộ dữ liệu; tốt hơn scrub/restrict metadata khi revoke.

---

<a id="section-23"></a>

## 23. P29–P32 — CÀI ĐẶT, TÀI KHOẢN VÀ CHẨN ĐOÁN

### 23.1. Cài đặt workspace

Các tab, không dồn thành một form dài:
- `Thông tin chung`: tên, timezone, định dạng; đổi timezone chỉ tương lai, cần warning.
- `Quyền & thành viên`: role, HR capabilities.
- `Văn phòng & mạng`: offices, BSSID allowlist, IP/CIDR, phương thức xác thực.
- `Ca & loại nghỉ`: link module HR.
- `Nhắc việc`: thresholds, quiet hours, escalation, nhắc sát hơn.
- `Báo cáo`: giờ 18:00, recipient rules, bật email optional.
- `Dữ liệu & quyền riêng tư`: retention, export, evidence access.
- `Tích hợp`: AI/push/email trạng thái, không hiển thị secret.

### 23.2. Cấu hình mạng văn phòng

Fields: tên văn phòng, timezone, SSID label, một/nhiều BSSID, CIDR IPv4/IPv6 nguồn, trạng thái hiệu lực, note.

- Kiểm tra định dạng MAC BSSID, normalize lowercase.
- Không dùng địa chỉ MAC của điện thoại làm BSSID.
- Một văn phòng mesh có nhiều BSSID, cần đăng ký đủ điểm phát.
- IP nhà mạng thay đổi: admin cập nhật có audit và kiểm tra, không để nhân viên tự xác nhận mạng mới.
- Không đăng ký dải `0.0.0.0/0` hoặc `::/0` trong production.
- `Kiểm tra kết nối hiện tại` chỉ trả diagnostic, không tự thêm allowlist.
- Nếu chưa xác định trusted ingress, nút bật strict office attendance không được báo “Đã bảo mật”.

### 23.3. Tài khoản

Họ tên hiển thị, email readonly hoặc flow đổi được kiểm chứng, đổi mật khẩu, thiết bị đã đăng nhập, quyền thông báo, điều chỉnh tần suất nhắc trong phạm vi cho phép, đăng xuất.

Không cho đổi role từ màn hình tài khoản. Không xin camera cả ngày.

### 23.4. Tác vụ nền

Bảng admin: job, lần chạy gần nhất, kết quả, độ trễ, số xử lý, lỗi đã khử dữ liệu nhạy cảm, nút retry có idempotency.

Các job phải thấy: sinh ca, daily tasks, reminder tick, báo cáo 18:00, delivery, receipts, cleanup uploads/evidence, recompute attendance.

Không show toàn bộ JWT, request body ảnh, secret hoặc URL signed dài trong log.

### 23.5. Nhật ký

Filter người/hành động/entity/time. Các hành động quan trọng: phân quyền, đổi deadline, bàn giao, phê duyệt, điều chỉnh công, chốt/mở kỳ, thay mạng, xem ảnh nhạy cảm, export.

Chỉ đọc. Sự kiện hệ thống ghi actor `Hệ thống`; không mạo danh một admin.

---

<a id="section-24"></a>

## 24. CHI TIẾT NATIVE APP VÀ KHÁC BIỆT SO VỚI WEB

### 24.1. Các màn hình mobile bắt buộc

| Màn hình | Bố cục/điểm riêng |
|---|---|
| Login | Một cột, bàn phím email, giữ nút trên keyboard khi cần |
| Today | Thẻ ca đầu tiên, các nhóm task xếp dọc, pull-to-refresh |
| Task list | Filter bottom sheet, card thay bảng |
| Task detail | Full screen, action bar sticky đáy không che nội dung |
| Quick create | Sheet full-screen, trường tối thiểu đầu, Daily checkbox trong vùng nhìn thấy sớm |
| Attendance | Kiểm tra điều kiện theo từng bước, camera full-screen |
| Selfie preview | Ảnh, `Chụp lại`, `Dùng ảnh này`, countdown challenge |
| Requests | Danh sách và form theo khoảng thời gian |
| Timesheet | Tổng tháng + danh sách ngày, không nhồi 31 cột |
| Notifications | Danh sách, deep link |
| Manager overview | KPI gọn, hàng đợi xử lý; giao việc vẫn được |
| Report | Accordion từng nhân sự/seller, mở task gốc |

### 24.2. Module native Wi-Fi

Native API interface ở `packages/contracts`:

```ts
type WifiReadResult =
  | { status: "available"; ssid: string; bssid: string; capturedAtDevice: string }
  | { status: "permission_denied" | "location_disabled" | "not_wifi" | "unavailable"; message?: string };

interface OfficeWifiModule {
  getCurrentNetwork(): Promise<WifiReadResult>;
  openPermissionSettings(): Promise<void>;
}
```

`capturedAtDevice` chỉ diagnostic, không làm timestamp chấm công.

Android: module Kotlin dùng API hệ điều hành phù hợp để lấy WifiInfo. Khai báo/request quyền theo OS/API thực sự dùng; các thông tin SSID/BSSID có thể bị che nếu thiếu quyền. Không mặc định `NEARBY_WIFI_DEVICES` luôn đủ cho mọi API, không khai `neverForLocation` nếu chức năng đang dùng Wi-Fi để suy ra hiện diện văn phòng. [S07](#source-s07)

iOS: module Swift dùng `NEHotspotNetwork.fetchCurrent`, có Access Wi-Fi Information entitlement và điều kiện được Apple cho phép, bao gồm quyền precise location trong luồng được chọn. Khi trả nil phải hiển thị unavailable, không dựng SSID giả. [S06](#source-s06)

App dùng Expo development build/custom native module; không dùng Expo Go làm bằng chứng native Wi-Fi và remote push đã hoạt động. [S08](#source-s08)

Không cache kết quả Wi-Fi quá 5 giây trước finalizing; đọc lại gần thời điểm gửi. Dữ liệu client vẫn có thể bị giả trên thiết bị bị can thiệp; lớp IP server và audit hỗ trợ giảm rủi ro, không chứng minh hiện diện tuyệt đối.

### 24.3. Quyền thiết bị

Camera chỉ xin khi chấm online. Push xin sau khi giải thích lợi ích, từ chối vẫn xem task/inbox. Quyền thông tin Wi-Fi/location chỉ xin trong luồng office; giải thích không theo dõi vị trí liên tục.

Refresh token mobile lưu trong kho lưu trữ an toàn của hệ điều hành qua adapter phù hợp; không đặt vào AsyncStorage không bảo vệ. Phải test cơ chế dung lượng/chia nhỏ token của adapter đã chọn.

### 24.4. Offline

- Task list có thể đọc cache gần nhất, có timestamp.
- Comment/kết quả text có thể lưu nháp; không hiển thị “Đã hoàn thành” cho đến khi server xác nhận.
- Attendance chính thức không được chốt offline.
- Logout/inactive phải xóa cache riêng tư, token, ảnh tạm.
- Không sync lại nháp chứa token truy cập của người trước sau khi đổi account.

<a id="section-25"></a>

## 25. CHÍNH SÁCH NHẮC VIỆC CỤ THỂ

### 25.1. Nguyên tắc

Nhắc việc dựa trên trạng thái, trách nhiệm và giờ làm; không gửi một cron “nhắc mọi người mỗi giờ” bất kể họ đang làm gì. Mỗi rule phải có `dedupe_key`, thời điểm đủ điều kiện và điều kiện hủy.

| Rule key | Khi đủ điều kiện | Người nhận | Hủy khi |
|---|---|---|---|
| `task_assigned` | Task được giao/publish | Assignee mới | Không hủy record; không gửi lại nếu retry |
| `task_unacknowledged` | Chưa ack sau 30 phút làm việc | Assignee | Đã nhận/terminal/giao lại/nghỉ được duyệt |
| `task_due_soon` | Trước hạn 60 phút và cần thực hiện | Assignee | Đã nộp/terminal/đổi hạn/đang nghỉ |
| `task_overdue_update` | Đã quá hạn 15 phút, không có cập nhật hữu ích gần đây | Assignee | Đã nộp, có blocker đã được định tuyến, terminal |
| `task_overdue_escalation` | Quá hạn 120 phút làm việc, chưa có hướng xử lý | Quản lý seller | Đã có quyết định/terminal |
| `task_review_pending` | Nộp xong và chưa có quyết định | Reviewer | Duyệt/trả lại/rút kết quả |
| `task_blocked` | Có blocker mới | Blocker owner + manager phù hợp | Blocker được xử lý |
| `daily_assignment_missing` | Occurrence cần người nhưng không resolve được | Quản lý seller/admin | Đã bàn giao/miễn/đã có người |
| `daily_wrapup` | 17:30, người đang trong ca phù hợp, còn việc cần update | Nhân viên | Đã gửi digest ngày đó |
| `attendance_missing_in` | Sau ca bắt đầu + ngưỡng, chưa vào, không nghỉ | Nhân viên | Đã vào/correction accepted/nghỉ |
| `attendance_missing_out` | Sau cuối ca + ngưỡng, còn session mở | Nhân viên; HR nếu kéo dài | Đã ra/điều chỉnh |
| `request_decided` | Đơn có quyết định mới | Người gửi | Một lần mỗi decision |
| `report_ready` | Snapshot sẵn sàng | Recipient | Một lần mỗi report version |

### 25.2. “Phút làm việc” cho nhắc task

`working_elapsed(a,b,member)` = tổng giao của khoảng `[a,b)` với các working segments có hiệu lực của người đó, trừ approved leave.

Nếu giao lúc 20:00 cho nhân viên hết ca lúc 18:00: thông báo trong app có thể có ngay, push thông thường chờ ca tiếp theo; 30 phút chưa nhận được tính từ giờ làm tiếp theo.

Task khẩn ngoài giờ chỉ gửi khi người đó có ca trực hoặc chính sách bật rõ ràng. Không để manager vô tình dùng priority urgent để vượt mọi quiet hour.

Task có deadline cách lúc giao dưới 60 phút: không gửi nhắc due-soon ngay sau assigned; gửi một nhắc tối đa khi còn khoảng nửa thời gian hoặc 10 phút, tùy khoảng còn lại, và luôn giữ khoảng cách giữa push thông thường tối thiểu 10 phút.

### 25.3. Chống spam

Mặc định đề xuất:
- Tối đa 2 reminder thông thường/task/người/ngày, không tính thông báo giao mới và quyết định duyệt.
- Tối đa 6 push nhắc tổng/người/ngày; phần vượt được gộp digest trong app.
- Rule có `not_before`, `expires_at`. Worker không gửi reminder đã quá ngữ cảnh.
- Snooze cho nhắc trước hạn: tới mốc nhỏ hơn deadline hoặc `now + 60 phút`. Task đã quá hạn có thể hoãn nhắc tối đa 30 phút, chỉ một lần trong mỗi chu kỳ 60 phút; không hoãn thông báo duyệt/khẩn cấp vượt quyền. Snooze không đổi `due_at` và không xóa lịch sử trễ.
- Người dùng có thể tắt push, nhưng inbox vẫn có; quản lý vẫn xem trách nhiệm chưa được xác nhận.
- Mỗi lần gửi phải kiểm tra lại trạng thái, người nhận và quyền. Task đã giao lại không push cho người cũ.
- Các ngưỡng cấu hình là defaults thử nghiệm, không phải chuẩn đánh giá nhân sự.

### 25.4. Chế độ nhắc sát hơn

Manager có thể bật cho một người hoặc một số task trong scope. UI ghi rõ `Đang dùng chế độ nhắc sát hơn`, lý do và ngày xem lại; nhân viên nhìn thấy.

Gợi ý hệ thống có thể dựa trên 3 lần `unacknowledged_over_threshold` hoặc `overdue_without_update` trong 14 ngày có làm việc, nhưng **không tự bật mặc định** và không đánh giá thái độ.

Loại khỏi tín hiệu: đang nghỉ đã duyệt, chờ reviewer, blocker được báo đúng lúc, task tạo muộn do hệ thống, deadline bị đổi không đủ thời gian, lỗi hệ thống đã xác nhận. Lưu sự kiện khách quan để quản lý kiểm tra, không lưu “điểm lười”.

---

<a id="section-26"></a>

## 26. KIẾN TRÚC TỔNG THỂ VÀ RANH GIỚI TRÁCH NHIỆM

### 26.1. Một backend dùng chung

```text
Web Next.js --------------------------+
                                     |
Mobile React Native / Expo ----------+--> Supabase Auth
                                     |
                                     +--> Supabase Data API / RPC (user JWT, RLS)
                                     |
                                     +--> Supabase Storage (private, upload có kiểm soát)
                                     |
                                     +--> Supabase Realtime (invalidation + inbox)
                                     |
                                     +--> Next.js Attendance Gateway
                                           - xác minh JWT
                                           - lấy IP từ trusted ingress
                                           - kiểm tra challenge / evidence
                                           - gọi RPC đặc quyền giới hạn
                                               |
                                               v
                                     Supabase PostgreSQL
                                     - bảng nghiệp vụ
                                     - constraints/RLS
                                     - transaction functions
                                     - audit/outbox
                                               |
                                               v
                                     Supabase Cron + worker Edge Functions
                                     - sinh ca / daily task
                                     - nhắc việc
                                     - báo cáo 18:00
                                     - push/email retry
                                     - cleanup / đối soát
```

Next.js gateway là phần backend mỏng cho các việc cần server trust, đặc biệt IP nguồn. Không xây thêm một service quản lý task riêng có database riêng.

### 26.2. Phân lớp

- **Frontend:** hiển thị, nhập liệu, validation để UX tốt, cache, optimistic update an toàn. Không là nơi quyết định quyền hay số công.
- **PostgreSQL:** trạng thái chính xác, constraints, phân quyền dữ liệu, transaction, idempotency, tính công/report xác định.
- **RPC:** giao thức nghiệp vụ; tránh client gọi `.update({status:"done"})` trực tiếp.
- **Gateway:** xác thực mạng/ảnh, trusted server metadata, mời người qua Auth Admin, cấp link file nhạy cảm.
- **Edge worker:** gửi thông báo, gọi AI optional, xử lý queue ngắn hạn, retry.
- **Cron:** đánh thức job đều đặn; không phụ thuộc app mở.
- **Storage:** file riêng tư; metadata trong DB không thay thế backup bytes.
- **Realtime:** làm UI biết cần đọc lại dữ liệu; không thay nguồn sự thật và không quyết định đã nhận task.

### 26.3. Không cần quá nhiều hạ tầng cho 5–10 người

Dùng modular monolith + PostgreSQL. Chưa cần Kubernetes, Kafka, microservices, Redis hay Elasticsearch. Outbox/leases dùng PostgreSQL. Các adapter email/push/AI độc lập để thay nhà cung cấp sau này.

---

<a id="section-27"></a>

## 27. STACK MẶC ĐỊNH VÀ THƯ VIỆN

**Supabase là yêu cầu đã chốt. Các lựa chọn còn lại dưới đây là mặc định đề xuất cho repo mới, không phải yêu cầu công nghệ đã được người dùng đưa ra.**

| Lớp | Lựa chọn mặc định |
|---|---|
| Monorepo | pnpm workspaces |
| Web | Next.js App Router + TypeScript strict |
| UI web | Tailwind CSS + shadcn/Radix primitives; theme lại theo mục 6 |
| Form | React Hook Form + Zod |
| Server state | TanStack Query |
| Table | TanStack Table |
| Local UI state | React state; Zustand chỉ nếu thực sự cần |
| Icon | Lucide, một bộ icon thống nhất |
| Mobile | React Native + Expo development build + Expo Router |
| Native extension | Expo Modules API, Swift/Kotlin cho Wi-Fi |
| Backend chính | Supabase PostgreSQL, Auth, Storage, Realtime |
| Scheduled jobs | Supabase Cron (`pg_cron`), `pg_net` khi gọi worker |
| Worker | Supabase Edge Functions TypeScript |
| Push mobile | Expo Push Service, có receipts và token lifecycle |
| Email | Adapter SMTP/API; V1 inbox/push không phụ thuộc email |
| Test web | Vitest + Testing Library + Playwright |
| Test DB | pgTAP/Supabase CLI |
| Test mobile | Unit + E2E trên thiết bị/emulator; native Wi-Fi test thiết bị thật |
| Hosting web mặc định | Vercel trực tiếp cho trusted IP adapter; self-host cần adapter riêng |

Dùng phiên bản ổn định tương thích tại thời điểm triển khai, pin vào lockfile; ghi versions vào `SETUP.md`. Không copy dependency versions cũ rồi gọi là “latest”. Không trộn hai UI frameworks hoặc hai cơ chế auth.

Supabase SSR theo hướng dẫn chính thức, xác minh user claims/user trên server; không tin session object đọc từ cookie mà chưa xác thực. Các trang theo user không cache dùng chung giữa người dùng. [S02](#source-s02)

---

<a id="section-28"></a>

## 28. CẤU TRÚC REPO VÀ IMPLEMENTATION FRONTEND

### 28.1. Cây thư mục

```text
apps/
  web/
    app/
      (auth)/login/page.tsx
      (auth)/auth/accept-invite/page.tsx
      (app)/layout.tsx
      (app)/today/page.tsx
      (app)/overview/page.tsx
      (app)/my-tasks/page.tsx
      (app)/tasks/page.tsx
      (app)/tasks/[taskId]/page.tsx
      (app)/recurring-tasks/...
      (app)/calendar/...
      (app)/sellers/...
      (app)/team/...
      (app)/attendance/...
      (app)/requests/...
      (app)/approvals/...
      (app)/timesheets/...
      (app)/reports/...
      (app)/notifications/...
      (app)/settings/...
      (app)/system/...
      api/attendance/challenge/route.ts
      api/attendance/finalize/route.ts
      api/files/signed-url/route.ts
      api/admin/invitations/route.ts
    components/
      shell/
      ui/
      tasks/
      attendance/
      requests/
      timesheets/
      reports/
    lib/
      supabase/browser.ts
      supabase/server.ts
      supabase/admin.ts
      auth/require-member.ts
      auth/require-capability.ts
      network/trusted-client-ip.ts
      errors.ts
      query-keys.ts
    features/
      tasks/{api,hooks,schemas,mappers}.ts
      attendance/...
      requests/...
      reports/...
    tests/
  mobile/
    app/
      (auth)/
      (tabs)/today.tsx
      (tabs)/tasks.tsx
      (tabs)/attendance.tsx
      (tabs)/notifications.tsx
      (tabs)/more.tsx
      tasks/[taskId].tsx
      attendance/camera.tsx
    modules/office-wifi/
      ios/
      android/
    src/{components,features,lib}/
packages/
  contracts/              # Zod + request/response types + enums
  domain/                 # pure helpers; không tin client như authority
  design-tokens/
  api-client/
supabase/
  migrations/
  seed.sql
  functions/
    dispatch-outbox/
    check-push-receipts/
    ai-task-draft/
    ai-report-summary/
    cleanup-files/
    _shared/
  tests/
scripts/
  bootstrap-owner.ts
  seed-demo.ts
  verify-deployment.ts
docs/
  IMPLEMENTATION_STATUS.md
  SETUP.md
  TEST_REPORT.md
  DEPLOYMENT_CHECKLIST.md
```

### 28.2. Quy tắc component

- Một form tạo task dùng chung cho drawer, route và edit mode qua props; không copy thành 3 bản.
- Một `TaskStatusBadge` dùng cùng mapping enum toàn app.
- Một `AttendanceStatusCard` dùng projection backend, không tự suy luận đủ công.
- `PersonLabel` luôn text.
- Tách `TaskRow` presentation khỏi mutation hooks.
- Tách `PermissionGate` UX khỏi server authorization; gate chỉ để ẩn/disable.
- Query function không gọi Supabase admin client.
- Server admin client nằm file `server-only`; không được import từ client component hay shared package mobile.

### 28.3. Query keys và cập nhật

```ts
const keys = {
  today: (org: string, member: string, date: string) =>
    ["today", org, member, date] as const,
  tasks: (org: string, filtersHash: string) =>
    ["tasks", org, filtersHash] as const,
  task: (org: string, id: string) =>
    ["task", org, id] as const,
  attendanceDay: (org: string, member: string, date: string) =>
    ["attendance-day", org, member, date] as const,
  timesheet: (org: string, period: string, member?: string) =>
    ["timesheet", org, period, member ?? "all"] as const,
};
```

Query key luôn có org và phạm vi người; không cache task riêng tư chỉ bằng `["tasks"]`.

- Nhận việc/checklist: có thể optimistic, rollback khi lỗi/version conflict.
- Nộp kết quả, duyệt nghỉ, chấm công, chốt công: chờ server xác nhận, không optimistic thành công.
- Sau mutation: invalidate detail + related lists + summary đúng phạm vi.
- Realtime: chỉ invalidate; debounce 200–500ms để không fetch storm.
- Focus/online restore: refetch active queries.
- Fallback polling Today/attendance 60 giây khi Realtime hỏng; dừng khi tab hidden, refresh khi visible.
- Abort request khi đổi workspace/filter; response cũ không ghi đè state mới.

### 28.4. Form API pattern

```ts
type CommandResult<T> =
  | { ok: true; data: T; request_id: string }
  | { ok: false; error: {
      code: string; message: string;
      field_errors?: Record<string, string>;
    }; request_id: string };

type CommandMeta = {
  organization_id: string;
  idempotency_key: string;
  expected_version?: number;
};
```

UI giữ idempotency key khi retry đúng payload. Khi người dùng sửa payload tạo operation mới thì sinh key mới. Disable submit không thay thế idempotency server.

Định nghĩa `DomainError` và mapper HTTP/RPC dùng chung. Không dùng alert() cho lỗi nghiệp vụ.

---

<a id="section-29"></a>

## 29. DATABASE SUPABASE — DATA DICTIONARY CHUẨN

### 29.1. Quy ước chung

- UUID cho khóa; `gen_random_uuid()`.
- `timestamptz` cho thời điểm; lưu UTC; `date` cho ngày nghiệp vụ local; `time` chỉ cho giờ mẫu chưa gắn ngày.
- Bảng nghiệp vụ có `organization_id uuid NOT NULL`.
- Bảng editable có `version integer NOT NULL DEFAULT 1`, `created_at`, `updated_at`; timestamp do server.
- Composite unique `(organization_id,id)` trên bảng cha; composite FK con `(organization_id,parent_id)` để ngăn trộn tổ chức.
- Người trong nghiệp vụ tham chiếu `organization_members.id`, không dùng Auth user ID cho mọi quan hệ.
- `auth.users.id` chỉ liên kết qua membership. Không bao giờ query bảng Auth từ client.
- Tiền không thuộc phạm vi V1. Thời lượng/công lưu số nguyên giây hoặc NUMERIC có độ chính xác; không dùng float.
- Các khoảng thời gian dùng quy ước nửa mở `[start,end)`.
- Archive/inactive/canceled thay hard-delete với dữ liệu đã phát sinh.
- RLS bật trên mọi bảng public. Grant tối thiểu; không dựa vào RLS mà quên revoke quyền ghi trực tiếp. [S01](#source-s01)
- `private` schema không nằm trong Exposed Schemas, chứa helper đặc quyền, outbox/lease/idempotency.
- JSONB chỉ cho cấu hình có schema, snapshots và payload event có version; không nhét tất cả task/attendance của tổ chức vào một cột JSON.

Ký hiệu trong các bảng dưới:
- `NN`: NOT NULL.
- `?`: nullable.
- `O`: organization_id NN.
- `T`: created_at, updated_at NN.
- `V`: version NN default 1.
- Những field chưa ghi default phải được command cung cấp.
- Mọi check enum phải tạo CHECK hoặc PostgreSQL enum; frontend types phải được generate/đồng bộ.

### 29.2. Tổ chức, thành viên, quyền

| Bảng | Fields bắt buộc và kiểu |
|---|---|
| `organizations` | `id uuid PK`, `name text NN`, `slug text NN unique`, `timezone text NN default 'Asia/Ho_Chi_Minh'`, `owner_member_id uuid ?`, `status text NN [active,suspended]`, `settings_version int NN default 1`, T |
| `organization_members` | `id uuid PK`, O, `user_id uuid NN FK auth.users`, `employee_code text NN`, `display_name text NN`, `role text NN [admin,manager,employee]`, `status text NN [invited,active,inactive]`, `can_manage_attendance bool NN default false`, `can_approve_requests bool NN default false`, `can_view_attendance_evidence bool NN default false`, `scope_version int NN default 1`, T,V |
| `member_hr_settings` | `member_id uuid PK`, O, `employment_start date NN`, `employment_end date ?`, `standard_day_minutes int NN default 480`, `default_work_mode text NN [office,remote,hybrid]`, `policy_version_id uuid ?`, T,V |
| `specialties` | `id uuid PK`, O, `code text NN`, `name text NN`, `archived_at timestamptz ?`, T |
| `member_specialties` | O, `member_id uuid`, `specialty_id uuid`; PK `(organization_id,member_id,specialty_id)` |
| `invitations` | `id uuid PK`, O, `email text NN`, `invited_role text NN`, `invited_by uuid NN`, `auth_invite_reference text ?`, `token_hash text ?`, `expires_at timestamptz NN`, `accepted_at timestamptz ?`, `revoked_at timestamptz ?`, `capabilities jsonb NN`, T |
| `policy_versions` | `id uuid PK`, O, `policy_kind text NN [attendance,reminders,retention,report]`, `version_number int NN`, `effective_from timestamptz NN`, `config jsonb NN`, `created_by uuid NN`, `created_at timestamptz NN`; immutable |

Constraints:
- Unique member `(organization_id,user_id)` và `(organization_id,employee_code)`.
- Membership role/capabilities chỉ thay qua command admin. Owner phải là active admin cùng org.
- Tăng `organization_members.scope_version` khi role, capability, trạng thái membership hoặc phạm vi seller thay đổi. Đây là phiên bản hỗ trợ vô hiệu hóa cache/report ACL; mỗi lần đọc vẫn kiểm tra quyền hiện tại, không chỉ so số version.
- `standard_day_minutes > 0 AND <= 1440`.
- Không cho `employment_end < employment_start`.
- Không lưu quyền trong `auth.user_metadata`.
- `invitations` không để employee đọc token_hash/email cả workspace.

### 29.3. Seller và coverage

| Bảng | Fields |
|---|---|
| `sellers` | `id uuid PK`, O, `code text NN`, `name text NN`, `platform text NN [shopee,tiktok_shop,lazada,other]`, `brand_label text ?`, `shop_url text ?`, `archived_at timestamptz ?`, T,V |
| `seller_members` | `id uuid PK`, O, `seller_id uuid NN`, `member_id uuid NN`, `is_manager bool NN default false`, `active_from date NN`, `active_until date ?`, T |
| `seller_assignments` | `id uuid PK`, O, `seller_id uuid NN`, `specialty_id uuid NN`, `member_id uuid NN`, `is_default bool NN`, `effective_from date NN`, `effective_until date ?`, T,V |
| `seller_coverage` | `id uuid PK`, O, `seller_id uuid NN`, `specialty_id uuid NN`, `work_date date NN`, `member_id uuid NN`, `assigned_by uuid NN`, `note text ?`, T,V |

Unique:
- Seller code trong org.
- Membership seller không overlap active interval cho cùng người.
- Coverage `(organization_id,seller_id,specialty_id,work_date)`.
- Không có hai default assignments cùng seller/specialty trong khoảng hiệu lực chồng nhau.
- Default/coverage member phải active và thuộc seller. Constraint trigger kiểm tra cross-table, không chỉ frontend.

### 29.4. Văn phòng, ca và lịch

| Bảng | Fields |
|---|---|
| `offices` | `id uuid PK`, O, `name text NN`, `timezone text NN`, `active bool NN`, T,V |
| `office_networks` | `id uuid PK`, O, `office_id uuid NN`, `ssid_label text NN`, `bssid text NN`, `valid_from timestamptz NN`, `valid_until timestamptz ?`, T,V |
| `office_ip_ranges` | `id uuid PK`, O, `office_id uuid NN`, `ip_range cidr NN`, `valid_from timestamptz NN`, `valid_until timestamptz ?`, `note text ?`, T,V |
| `shift_templates` | `id uuid PK`, O, `name text NN`, `start_local time NN`, `end_local time NN`, `end_day_offset smallint NN default 0`, `breaks jsonb NN default '[]'`, `office_id uuid ?`, `allowed_mode text NN [office,remote,hybrid]`, `policy_version_id uuid NN`, `active bool NN`, T,V |
| `shift_assignments` | `id uuid PK`, O, `member_id uuid NN`, `shift_template_id uuid NN`, `weekdays smallint[] NN`, `effective_from date NN`, `effective_until date ?`, T,V |
| `calendar_overrides` | `id uuid PK`, O, `member_id uuid ?` (null = organization), `work_date date NN`, `kind text NN [nonworking,custom_shift,paid_holiday]`, `shift_template_id uuid ?`, `paid_credit_policy jsonb ?`, `reason text NN`, T,V |
| `shift_instances` | `id uuid PK`, O, `member_id uuid NN`, `template_id uuid ?`, `work_date date NN`, `starts_at timestamptz NN`, `ends_at timestamptz NN`, `working_segments jsonb NN`, `scheduled_seconds bigint NN`, `standard_day_minutes int NN`, `allowed_mode text NN`, `office_id uuid ?`, `policy_snapshot jsonb NN`, `status text NN [scheduled,canceled,closed]`, T,V |

`working_segments` là array có schema:
```json
[
  {"start":"2026-10-05T02:00:00Z","end":"2026-10-05T05:00:00Z"},
  {"start":"2026-10-05T06:00:00Z","end":"2026-10-05T11:00:00Z"}
]
```

Phải validate mỗi segment nằm trong shift, end>start, không overlap, sorted; tổng duration bằng scheduled_seconds. Đây là snapshot nhỏ của cấu trúc ca, không phải nơi chứa attendance events.

Weekdays dùng ISO 1=Monday … 7=Sunday. Không trộn JS 0=Sunday.

Constraint/trigger chống overlap shift_instances đang hiệu lực cùng member, kể cả qua ngày. Có thể dùng exclusion constraint `btree_gist` trên `tstzrange(starts_at,ends_at,'[)')`.

### 29.5. Task, recurrence và cộng tác

| Bảng | Fields |
|---|---|
| `task_templates` | `id uuid PK`, O, `name text NN`, `status text NN [active,paused,ended]`, `current_version_id uuid ?`, `created_by uuid NN`, T,V |
| `task_template_versions` | `id uuid PK`, O, `template_id uuid NN`, `revision int NN`, `effective_from date NN`, `config jsonb NN`, `created_by uuid NN`, `created_at timestamptz NN`; immutable |
| `task_template_targets` | `id uuid PK`, O, `template_id uuid NN`, `seller_id uuid ?`, `target_key text NN`, `active_from date NN`, `active_until date ?`, T |
| `task_occurrences` | `id uuid PK`, O, `template_id uuid NN`, `target_id uuid NN`, `template_version_id uuid NN`, `occurrence_date date NN`, `status text NN [created,not_scheduled,needs_assignment,waived,paused]`, `task_id uuid ?`, `reason_code text ?`, `resolution_note text ?`, `generated_at timestamptz NN`, T,V |
| `tasks` | `id uuid PK`, O, `task_number bigint NN`, `batch_id uuid ?`, `seller_id uuid ?`, `template_occurrence_id uuid ?`, `title text NN`, `description text NN default ''`, `assignee_member_id uuid NN`, `created_by_member_id uuid NN`, `reviewer_member_id uuid ?`, `priority text NN default 'normal'`, `status text NN default 'todo'`, `planned_date date NN`, `original_due_at timestamptz NN`, `due_at timestamptz NN`, `assigned_at timestamptz NN`, `visible_from timestamptz NN`, `acknowledged_at timestamptz ?`, `started_at timestamptz ?`, `submitted_at timestamptz ?`, `completed_at timestamptz ?`, `requires_review bool NN default false`, `requires_result bool NN default true`, `requires_attachment bool NN default false`, `allow_no_incident bool NN default false`, `reminder_profile text NN default 'standard' [standard,closer]`, `reminder_profile_reason text ?`, `reminder_profile_review_at date ?`, `estimated_minutes int ?`, `blocked_at timestamptz ?`, `blocker_reason text ?`, `blocker_owner_member_id uuid ?`, `last_meaningful_update_at timestamptz NN`, `current_submission_id uuid ?`, T,V |
| `task_participants` | O, `task_id uuid`, `member_id uuid`, `participation_role text NN [collaborator,watcher]`, `added_by uuid NN`, `created_at timestamptz NN`; PK `(organization_id,task_id,member_id)` |
| `task_checklist_items` | `id uuid PK`, O, `task_id uuid NN`, `title text NN`, `position int NN`, `required bool NN default true`, `assigned_member_id uuid ?`, `checked_at timestamptz ?`, `checked_by uuid ?`, T,V |
| `task_submissions` | `id uuid PK`, O, `task_id uuid NN`, `revision int NN`, `submitted_by uuid NN`, `result_text text NN`, `result_links jsonb NN default '[]'`, `no_incident bool NN default false`, `submitted_at timestamptz NN`, `decision text NN [pending,approved,changes_requested,withdrawn,not_required]`, `decided_by uuid ?`, `decided_at timestamptz ?`, `decision_reason text ?`, `revision_due_at timestamptz ?`, V |
| `task_comments` | `id uuid PK`, O, `task_id uuid NN`, `author_member_id uuid NN`, `body text NN`, `edited_at timestamptz ?`, `hidden_at timestamptz ?`, T,V |
| `task_events` | `id uuid PK`, O, `task_id uuid NN`, `event_type text NN`, `actor_member_id uuid ?`, `recorded_at timestamptz NN`, `payload jsonb NN`, `report_state_after jsonb NN`, `task_version int NN`; immutable |
| `task_file_links` | O, `task_id uuid NN`, `file_id uuid NN`, `submission_id uuid ?`, `comment_id uuid ?`, `purpose text NN [reference,result,comment]`, `created_at timestamptz NN`; unique phù hợp file/purpose |
| `task_reminder_snoozes` | O, `task_id uuid NN`, `member_id uuid NN`, `rule_key text NN`, `snoozed_until timestamptz NN`, `set_at timestamptz NN`, T,V; PK `(organization_id,task_id,member_id,rule_key)` |
| `task_handover_actions` | `id uuid PK`, O, `request_id uuid NN`, `task_id uuid ?`, `occurrence_id uuid ?`, `action text NN [pending,reassign,reschedule,waive,keep]`, `new_assignee_id uuid ?`, `new_planned_date date ?`, `new_due_at timestamptz ?`, `reason text ?`, `resolved_by uuid ?`, `resolved_at timestamptz ?`, T,V |

Unique:
- `(organization_id,task_number)`.
- Một task cho mỗi `template_occurrence_id` khác null.
- Một occurrence cho `(organization_id,target_id,occurrence_date)`; không thêm template_version vào khóa chống trùng.
- Submission revision unique theo task.
- Task event task_version unique theo task. Mọi thay đổi task hoặc children có đưa vào `task_events` (kể cả checklist, bình luận, nộp kết quả) phải khóa row task, tăng `tasks.version` đúng một lần và ghi đúng một event cho version đó trong cùng transaction; gom các thay đổi của một command vào payload. Chỉ hành động có ý nghĩa nghiệp vụ mới cập nhật `last_meaningful_update_at`; xem trang/đánh dấu thông báo đã đọc không cập nhật trường này.
- `task_reminder_snoozes` lưu lần hoãn nhắc theo task/người/quy tắc, không thay `due_at`. Worker kiểm tra snooze còn hiệu lực và người nhận vẫn được giao; dọn các bản hết hạn theo lịch. Đổi `reminder_profile` cần quyền quản lý task, lý do/ngày xem lại khi chọn `closer`; nhân viên chỉ được snooze trong giới hạn, không tự đổi chế độ nhắc.
- Checklist checked_at/checked_by cùng null hoặc cùng có giá trị.
- `requires_review => reviewer_member_id IS NOT NULL`.
- Reviewer khác assignee.
- `priority IN ('low','normal','high','urgent')`.
- Status theo mục 4.
- `done` phải có completed_at; các command phải giữ invariant này, không chỉ update status.

### 29.6. Đơn từ và loại nghỉ

| Bảng | Fields |
|---|---|
| `leave_types` | `id uuid PK`, O, `code text NN`, `name text NN`, `pay_treatment text NN [paid,unpaid,pending_hr]`, `consumes_balance bool NN default false`, `active bool NN`, T,V |
| `employee_requests` | `id uuid PK`, O, `member_id uuid NN`, `request_type text NN [leave,early_leave,late_arrival,remote_work,attendance_correction,cancel_approved_request]`, `status text NN [pending,approved,rejected,withdrawn,canceled]`, `starts_at timestamptz NN`, `ends_at timestamptz NN`, `leave_type_id uuid ?`, `reason_private text NN`, `handover_note text ?`, `target_request_id uuid ?`, `correction_payload jsonb ?`, `submitted_at timestamptz NN`, `decided_at timestamptz ?`, `decided_by uuid ?`, `decision_reason_private text ?`, T,V |
| `request_segments` | `id uuid PK`, O, `request_id uuid NN`, `shift_instance_id uuid NN`, `starts_at timestamptz NN`, `ends_at timestamptz NN`, `affected_seconds bigint NN`, `pay_treatment_snapshot text NN [paid,unpaid,not_applicable,pending_hr]`, `leave_type_version int ?` |
| `request_decisions` | `id uuid PK`, O, `request_id uuid NN`, `decision text NN`, `actor_member_id uuid NN`, `reason_private text ?`, `before_state jsonb NN`, `after_state jsonb NN`, `recorded_at timestamptz NN`; immutable |
| `request_file_links` | O, `request_id uuid NN`, `file_id uuid NN`, `linked_by uuid NN`, `created_at timestamptz NN`; PK `(organization_id,request_id,file_id)` |
| `leave_balance_entries` | `id uuid PK`, O, `member_id uuid NN`, `leave_type_id uuid NN`, `delta_seconds bigint NN`, `effective_date date NN`, `source_request_id uuid ?`, `reason text NN`, `created_by uuid ?`, `created_at timestamptz NN` |

Leave balance dùng ledger cộng/trừ, không cập nhật một số dư bằng client. Admin thiết lập entitlement theo chính sách được rà soát; không tự mặc định mọi người luôn có một quota pháp lý duy nhất.

`employee_requests` chứa dữ liệu riêng tư: không cho manager chỉ có task scope SELECT trực tiếp. Availability để calendar/report phải qua RPC trả loại trạng thái tối thiểu.

`request_file_links` kế thừa ACL của đơn từ, không kế thừa quyền xem seller/task. Chỉ file `ready`, cùng org, purpose `request` và thuộc upload intent hợp lệ mới được gắn; người không xem được đơn không được ký URL tải file đính kèm của đơn.

### 29.7. Chấm công

| Bảng | Fields |
|---|---|
| `attendance_challenges` | `id uuid PK`, O, `member_id uuid NN`, `shift_instance_id uuid NN`, `action text NN [check_in,check_out]`, `mode text NN [office,remote]`, `nonce_hash text NN`, `device_id uuid NN`, `issued_at timestamptz NN`, `expires_at timestamptz NN`, `consumed_at timestamptz ?`, `file_id uuid ?`, `laptop_session_id uuid ?`, `attempt_count int NN default 0` |
| `remote_laptop_sessions` | `id uuid PK`, O, `member_id uuid NN`, `challenge_id uuid ?`, `code_hash text NN`, `display_code_encrypted text ?`, `expires_at timestamptz NN`, `consumed_at timestamptz ?`, `created_at timestamptz NN` |
| `attendance_events` | `id uuid PK`, O, `member_id uuid NN`, `shift_instance_id uuid NN`, `event_kind text NN [check_in,check_out,adjustment]`, `effective_at timestamptz NN`, `recorded_at timestamptz NN`, `mode text NN [office,remote,manual_adjustment]`, `challenge_id uuid ?`, `source_request_id uuid ?`, `supersedes_event_id uuid ?`, `verification_status text NN [verified,approved_adjustment,flagged]`, `created_by_member_id uuid ?`, `idempotency_key text NN`; immutable |
| `attendance_evidence` | `id uuid PK`, O, `attendance_event_id uuid NN`, `file_id uuid ?`, `source_ip inet ?`, `office_network_id uuid ?`, `device_id uuid NN`, `wifi_claim_snapshot jsonb ?`, `verification_details jsonb NN`, `retention_until timestamptz ?`, `legal_hold bool NN default false`, `created_at timestamptz NN` |
| `attendance_sessions` | `id uuid PK`, O, `member_id uuid NN`, `shift_instance_id uuid NN`, `check_in_event_id uuid NN`, `check_out_event_id uuid ?`, `starts_at timestamptz NN`, `ends_at timestamptz ?`, `mode text NN`, `status text NN [open,closed,superseded]`, T,V |
| `attendance_day_summaries` | `id uuid PK`, O, `member_id uuid NN`, `work_date date NN`, `scheduled_seconds bigint NN`, `worked_office_seconds bigint NN`, `worked_remote_seconds bigint NN`, `paid_leave_seconds bigint NN`, `unpaid_leave_seconds bigint NN`, `unexplained_seconds bigint NN`, `unknown_seconds bigint NN`, `late_seconds bigint NN`, `early_seconds bigint NN`, `outside_schedule_seconds bigint NN`, `standard_day_minutes int NN`, `state text NN [provisional,needs_review,verified]`, `exceptions jsonb NN`, `calculation_version int NN`, `source_revision_hash text NN`, T,V |

Tách `attendance_evidence` khỏi events để employee/HR không có quyền ảnh có thể đọc timestamp mà không lộ IP/ảnh. RLS không tự che cột trong một row; không đặt dữ liệu nhạy cảm vào row vốn phải cho manager đọc.

Unique challenge consumed một lần; unique event idempotency theo org/member; partial unique một session open/member/org. Raw events không update/delete; correction tạo event mới.

### 29.8. Chốt công

| Bảng | Fields |
|---|---|
| `timesheet_periods` | `id uuid PK`, O, `month_start date NN`, `status text NN [open,reconciling,closed,reopened]`, `revision int NN default 1`, `closed_at timestamptz ?`, `closed_by uuid ?`, `reopen_reason text ?`, `policy_snapshot jsonb NN`, T,V |
| `timesheet_snapshots` | `id uuid PK`, O, `period_id uuid NN`, `revision int NN`, `member_id uuid NN`, `daily_rows jsonb NN`, `totals jsonb NN`, `source_hash text NN`, `created_at timestamptz NN`; immutable |
| `timesheet_period_events` | `id uuid PK`, O, `period_id uuid NN`, `event_type text NN`, `actor_member_id uuid NN`, `reason text NN`, `recorded_at timestamptz NN`, `payload jsonb NN`; immutable |

Unique `(organization_id,month_start)`. Snapshot unique `(period_id,revision,member_id)`.
Daily_rows phải có schema version và raw seconds, không chỉ chuỗi “0,75 công”.

### 29.9. Files, thiết bị, thông báo, báo cáo

| Bảng | Fields |
|---|---|
| `files` | `id uuid PK`, O, `uploaded_by uuid NN`, `bucket_id text NN`, `object_path text NN`, `original_name text NN`, `mime_type text NN`, `size_bytes bigint NN`, `sha256 text ?`, `purpose text NN [task,attendance,request,export]`, `state text NN [pending,ready,quarantined,deleted]`, `retention_until timestamptz ?`, `created_at timestamptz NN`, `deleted_at timestamptz ?` |
| `upload_intents` | `id uuid PK`, O, `member_id uuid NN`, `file_id uuid NN`, `target_kind text NN`, `target_id uuid ?`, `challenge_id uuid ?`, `expires_at timestamptz NN`, `consumed_at timestamptz ?`, `created_at timestamptz NN` |
| `export_jobs` | `id uuid PK`, O, `requested_by uuid NN`, `export_kind text NN [timesheet,report,tasks]`, `scope_snapshot jsonb NN`, `source_period_id uuid ?`, `source_revision int ?`, `status text NN [queued,processing,ready,failed,expired]`, `file_id uuid ?`, `idempotency_key text NN`, `expires_at timestamptz NN`, `error_code text ?`, T,V |
| `user_devices` | `id uuid PK`, O, `member_id uuid NN`, `installation_id text NN`, `platform text NN [web,ios,android]`, `label text NN`, `last_seen_at timestamptz NN`, `revoked_at timestamptz ?`, `created_at timestamptz NN` |
| `push_endpoints` | `id uuid PK`, O, `device_id uuid NN`, `provider text NN [expo,webpush]`, `token_encrypted text NN`, `token_hash text NN`, `active bool NN`, `last_error_code text ?`, T |
| `notification_preferences` | O, `member_id uuid PK`, `push_enabled bool NN`, `email_enabled bool NN`, `quiet_hours jsonb NN`, `closer_reminder_mode bool NN`, `closer_mode_reason text ?`, `closer_mode_review_at date ?`, T,V |
| `notifications` | `id uuid PK`, O, `recipient_member_id uuid NN`, `kind text NN`, `title text NN`, `body text NN`, `target_type text NN`, `target_id uuid ?`, `safe_payload jsonb NN`, `dedupe_key text NN`, `created_at timestamptz NN`, `read_at timestamptz ?`, `expires_at timestamptz ?` |
| `notification_deliveries` | `id uuid PK`, O, `notification_id uuid NN`, `endpoint_id uuid ?`, `channel text NN [in_app,push,email]`, `status text NN [pending,sending,accepted,provider_confirmed,failed,expired]`, `attempts int NN`, `next_attempt_at timestamptz NN`, `provider_ticket_id text ?`, `last_error_code text ?`, T |
| `report_runs` | `id uuid PK`, O, `report_date date NN`, `cutoff_at timestamptz NN`, `revision int NN default 1`, `status text NN [pending,building,ready,failed]`, `started_at timestamptz ?`, `finished_at timestamptz ?`, `is_late bool NN`, `algorithm_version int NN`, `error_code text ?`, T |
| `report_snapshots` | `id uuid PK`, O, `run_id uuid NN`, `scope_key text NN`, `authorized_seller_ids uuid[] NN`, `scope_kind text NN [organization,sellers,personal]`, `member_id uuid ?`, `facts jsonb NN`, `summary_text text NN`, `summary_source text NN [template,ai]`, `source_hash text NN`, `created_at timestamptz NN`; facts immutable |
| `report_recipients` | O, `snapshot_id uuid NN`, `recipient_member_id uuid NN`, `scope_version_at_creation int NN`, `notification_id uuid ?`, `created_at timestamptz NN`; PK `(snapshot_id,recipient_member_id)` |
| `audit_logs` | `id uuid PK`, O, `actor_member_id uuid ?`, `actor_kind text NN [member,system]`, `action text NN`, `entity_type text NN`, `entity_id uuid ?`, `recorded_at timestamptz NN`, `request_id uuid NN`, `safe_metadata jsonb NN`; immutable |

Unique notification `(organization_id,recipient_member_id,dedupe_key)`, delivery `(notification_id,channel,endpoint_id)` với xử lý null endpoint bằng index riêng/NULLS NOT DISTINCT tùy PostgreSQL version.
Report run unique `(organization_id,report_date,cutoff_at,revision)`.
Export unique `(organization_id,requested_by,idempotency_key)`; file export có TTL và ACL gắn với export job. Trước khi ký URL tải, kiểm tra requestor/capability hiện tại và toàn bộ scope_snapshot; thu hồi quyền không được tiếp tục tải file đã tạo trước đó bằng cách xin URL mới. URL đã ký chỉ sống tới TTL ngắn; không hứa thu hồi tức thì URL đang còn hiệu lực.

### 29.10. Bảng private vận hành backend

| Bảng | Fields |
|---|---|
| `private.outbox_events` | `id uuid PK`, `organization_id uuid NN`, `event_type text NN`, `aggregate_id uuid ?`, `dedupe_key text NN unique`, `payload jsonb NN`, `status text NN [pending,processing,done,failed]`, `available_at timestamptz NN`, `lease_owner uuid ?`, `lease_until timestamptz ?`, `attempts int NN default 0`, `last_error_code text ?`, `created_at timestamptz NN` |
| `private.command_idempotency` | `organization_id uuid`, `actor_key text`, `command_name text`, `idempotency_key text`, `payload_hash text NN`, `result jsonb NN`, `created_at timestamptz NN`; PK theo 4 field đầu |
| `private.job_runs` | `id uuid PK`, `organization_id uuid ?`, `job_name text NN`, `logical_key text NN`, `started_at timestamptz NN`, `finished_at timestamptz ?`, `status text NN`, `counters jsonb NN`, `error_code text ?` |
| `private.job_leases` | `job_key text PK`, `lease_owner uuid NN`, `lease_until timestamptz NN`, `updated_at timestamptz NN` |
| `private.task_number_counters` | `organization_id uuid PK`, `next_value bigint NN` |

Private tables không được client query/subscribe. Admin UI đọc diagnostic qua RPC đã lọc.

### 29.11. Index tối thiểu

```sql
-- Viết trong migration sau khi có bảng.
create index tasks_assignee_due_idx
  on public.tasks(organization_id, assignee_member_id, due_at)
  where status in ('todo','in_progress','in_review');

create index tasks_seller_planned_idx
  on public.tasks(organization_id, seller_id, planned_date, status);

create index tasks_review_idx
  on public.tasks(organization_id, reviewer_member_id, submitted_at)
  where status = 'in_review';

create index tasks_created_idx
  on public.tasks(organization_id, created_at desc, id);

create index task_events_asof_idx
  on public.task_events(organization_id, task_id, recorded_at desc, task_version desc);

create unique index occurrences_once_idx
  on public.task_occurrences(organization_id, target_id, occurrence_date);

create unique index attendance_one_open_session_idx
  on public.attendance_sessions(organization_id, member_id)
  where status = 'open';

create index notifications_unread_idx
  on public.notifications(organization_id, recipient_member_id, created_at desc)
  where read_at is null;

create index attendance_member_day_idx
  on public.attendance_day_summaries(organization_id, member_id, work_date);

create index requests_pending_idx
  on public.employee_requests(organization_id, submitted_at)
  where status = 'pending';

create index outbox_pending_idx
  on private.outbox_events(status, available_at)
  where status in ('pending','failed');
```

Ngoài các index trên: tạo index cho mọi FK dùng join thường xuyên và cột lookup policy membership/seller scope. Search ban đầu `ILIKE` có escape và limit, hoặc PostgreSQL FTS/trigram có migration; không cần search service bên ngoài.

<a id="section-30"></a>

## 30. RLS, GRANTS VÀ MẪU SQL TRIỂN KHAI

### 30.1. Chiến lược đọc/ghi

**Đọc:** SELECT qua RLS hoặc RPC projection có guard.  
**Ghi:** command RPC, không cho authenticated ghi trực tiếp các bảng nghiệp vụ.

Cấu trúc:
- `public.rpc_*`: wrapper `SECURITY INVOKER`, nằm trong schema được expose.
- `private.cmd_*`: hàm đặc quyền có `SECURITY DEFINER`, `search_path=''`, tự kiểm tra `auth.uid()`, membership và quyền.
- `private.can_*`: helper quyền được kiểm soát, không nhận tùy ý actor từ client.
- Những RPC dành gateway/worker: grant chỉ `service_role`, không cho `authenticated` execute.
- Revoke EXECUTE mặc định từ PUBLIC/anon; grant đúng chữ ký từng hàm.
- Không cấp quyền tạo object trong schema private cho authenticated.
- Không expose schema private trong Supabase API settings.
- View đọc dữ liệu user phải `security_invoker=true` khi PostgreSQL hỗ trợ; không vô tình bypass RLS qua view. [S01](#source-s01), [S17](#source-s17)

Mọi helper definer đều schema-qualify tables/functions. Kiểm tra owner và RLS recursion trong pgTAP; không thêm `FORCE RLS` làm helper recursive mà chưa thiết kế lại.

### 30.2. Khởi tạo bảo mật migration

```sql
create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
grant usage on schema private to authenticated;
grant usage on schema private to service_role;

-- Áp dụng cho các object mới do postgres tạo trong dự án này.
alter default privileges for role postgres in schema public
  revoke execute on functions from public;
alter default privileges for role postgres in schema private
  revoke execute on functions from public;

-- Mỗi bảng được tạo phải bật RLS ngay trong cùng migration.
alter table public.tasks enable row level security;
revoke all on public.tasks from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.tasks from authenticated;
grant select on public.tasks to authenticated;
```

Đây là pattern, AI phải áp dụng đầy đủ cho toàn bộ bảng mục 29. Không chạy blanket revoke trên `auth`, `storage`, `realtime` làm hỏng cơ chế Supabase.

### 30.3. Helper membership

```sql
create or replace function private.current_member_id(p_org uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id
  from public.organization_members as m
  join public.organizations as o on o.id = m.organization_id
  where m.organization_id = p_org
    and m.user_id = (select auth.uid())
    and m.status = 'active'
    and o.status = 'active'
  limit 1;
$$;

revoke all on function private.current_member_id(uuid) from public, anon;
grant execute on function private.current_member_id(uuid) to authenticated;
```

Không có fallback “không tìm được user thì lấy member đầu tiên”.

### 30.4. Helper đọc task

```sql
create or replace function private.can_read_task(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tasks as t
    join public.organization_members as m
      on m.organization_id = t.organization_id
     and m.user_id = (select auth.uid())
     and m.status = 'active'
    join public.organizations as o on o.id = t.organization_id
    where t.id = p_task_id
      and o.status = 'active'
      and (
        m.role = 'admin'
        or t.assignee_member_id = m.id
        or t.reviewer_member_id = m.id
        or exists (
          select 1
          from public.task_participants as p
          where p.organization_id = t.organization_id
            and p.task_id = t.id
            and p.member_id = m.id
        )
        or (
          m.role = 'manager'
          and exists (
            select 1
            from public.seller_members as sm
            where sm.organization_id = t.organization_id
              and sm.seller_id = t.seller_id
              and sm.member_id = m.id
              and sm.is_manager
              and sm.active_from <= (current_timestamp at time zone o.timezone)::date
              and (
                sm.active_until is null
                or sm.active_until >= (current_timestamp at time zone o.timezone)::date
              )
          )
        )
      )
  );
$$;

revoke all on function private.can_read_task(uuid) from public, anon;
grant execute on function private.can_read_task(uuid) to authenticated;

create policy tasks_read_by_acl
on public.tasks for select to authenticated
using (private.can_read_task(id));

alter table public.task_comments enable row level security;
create policy task_comments_read_by_parent
on public.task_comments for select to authenticated
using (private.can_read_task(task_id));
```

Helper này được migration owner tin cậy sở hữu để truy vấn không rơi vào recursion của policy task/participants. Bắt buộc test truy cập chéo org, inactive và revoked scope.

### 30.5. Mẫu command “Nhận việc” có transaction và idempotency

Đây là mẫu triển khai cho các command khác, dùng đúng schema ở mục 29. Cần tạo extension `pgcrypto` trong schema `extensions` nếu dùng `extensions.digest`.

```sql
create or replace function private.cmd_ack_task(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid := (p_input->>'organization_id')::uuid;
  v_task_id uuid := (p_input->>'task_id')::uuid;
  v_expected integer := (p_input->>'expected_version')::integer;
  v_key text := p_input->>'idempotency_key';
  v_actor uuid;
  v_task public.tasks%rowtype;
  v_old private.command_idempotency%rowtype;
  v_hash text;
  v_result jsonb;
  v_request_id uuid := gen_random_uuid();
begin
  if v_org is null or v_task_id is null or v_expected is null
     or v_key is null or length(v_key) < 16 or length(v_key) > 128 then
    raise sqlstate 'PT400' using message = 'VALIDATION_ERROR';
  end if;

  v_actor := private.current_member_id(v_org);
  if v_actor is null then
    raise sqlstate 'PT403' using message = 'MEMBERSHIP_INACTIVE_OR_MISSING';
  end if;

  -- Xác minh quyền hiện tại trước cả việc trả lại kết quả idempotent.
  if not private.can_read_task(v_task_id) then
    raise sqlstate 'PT404' using message = 'RESOURCE_NOT_FOUND';
  end if;

  v_hash := encode(extensions.digest(p_input::text, 'sha256'), 'hex');

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_org::text || ':' || v_actor::text || ':ack_task:' || v_key, 0
    )
  );

  select * into v_old
  from private.command_idempotency
  where organization_id = v_org
    and actor_key = v_actor::text
    and command_name = 'ack_task'
    and idempotency_key = v_key;

  if found then
    if v_old.payload_hash <> v_hash then
      raise sqlstate 'PT409' using message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_old.result;
  end if;

  select * into v_task
  from public.tasks
  where id = v_task_id and organization_id = v_org
  for update;

  if not found or v_task.assignee_member_id <> v_actor then
    raise sqlstate 'PT404' using message = 'RESOURCE_NOT_FOUND';
  end if;

  if v_task.version <> v_expected then
    raise sqlstate 'PT409' using message = 'VERSION_CONFLICT';
  end if;

  if v_task.status in ('done','canceled','waived') then
    raise sqlstate 'PT409' using message = 'TASK_NOT_ACTIONABLE';
  end if;

  if v_task.acknowledged_at is null then
    update public.tasks
    set acknowledged_at = clock_timestamp(),
        last_meaningful_update_at = clock_timestamp(),
        updated_at = clock_timestamp(),
        version = version + 1
    where id = v_task_id and organization_id = v_org
    returning * into v_task;

    insert into public.task_events (
      id, organization_id, task_id, event_type, actor_member_id,
      recorded_at, payload, report_state_after, task_version
    ) values (
      gen_random_uuid(), v_org, v_task_id, 'task_acknowledged', v_actor,
      clock_timestamp(), '{}'::jsonb, to_jsonb(v_task), v_task.version
    );

    insert into public.audit_logs (
      id, organization_id, actor_member_id, actor_kind, action,
      entity_type, entity_id, recorded_at, request_id, safe_metadata
    ) values (
      gen_random_uuid(), v_org, v_actor, 'member', 'task.acknowledged',
      'task', v_task_id, clock_timestamp(), v_request_id, '{}'::jsonb
    );

    insert into private.outbox_events (
      id, organization_id, event_type, aggregate_id, dedupe_key,
      payload, status, available_at, attempts, created_at
    ) values (
      gen_random_uuid(), v_org, 'task.changed', v_task_id,
      'task:' || v_task_id::text || ':v:' || v_task.version::text,
      jsonb_build_object('task_id',v_task_id,'version',v_task.version),
      'pending', clock_timestamp(), 0, clock_timestamp()
    ) on conflict (dedupe_key) do nothing;
  end if;

  v_result := jsonb_build_object(
    'ok',true,
    'request_id',v_request_id,
    'data',jsonb_build_object(
      'task_id',v_task.id,
      'version',v_task.version,
      'acknowledged_at',v_task.acknowledged_at
    )
  );

  insert into private.command_idempotency (
    organization_id, actor_key, command_name, idempotency_key,
    payload_hash, result, created_at
  ) values (
    v_org, v_actor::text, 'ack_task', v_key,
    v_hash, v_result, clock_timestamp()
  );

  return v_result;
end;
$$;

revoke all on function private.cmd_ack_task(jsonb) from public, anon;
grant execute on function private.cmd_ack_task(jsonb) to authenticated;

create or replace function public.rpc_ack_task(p_input jsonb)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.cmd_ack_task(p_input);
$$;

revoke all on function public.rpc_ack_task(jsonb) from public, anon;
grant execute on function public.rpc_ack_task(jsonb) to authenticated;
```

Ghi chú:
- `PT400`, `PT403`, `PT404`, `PT409` được PostgREST ánh xạ sang HTTP tương ứng; shared API client chuyển thành `CommandResult` lỗi chuẩn. [S18](#source-s18)
- Cast UUID/int malformed cần map về `VALIDATION_ERROR` ở boundary; không lộ raw SQL details cho UI.
- Những command khác phải kiểm tra đầy đủ quyền cụ thể, không chỉ copy `can_read_task` rồi cho mutate.
- Có thể tách append-event/outbox thành private helper dùng chung; không được bỏ audit/event vì muốn code ngắn.
- Snapshot trong mẫu dùng toàn bộ row task vì không chứa HR evidence. Production có thể dùng projection report nhỏ hơn nhưng phải đủ trường để replay.
- Không có `catch` trả success khi transaction thất bại.

### 30.6. RLS matrix theo nhóm bảng

| Nhóm bảng | SELECT | Ghi |
|---|---|---|
| Organizations | Thành viên active | Owner/admin command |
| Membership danh bạ | Chính chủ/admin; người có quan hệ seller/task nhận projection tối thiểu | Admin command |
| Member HR settings | Chính chủ/HR | HR command |
| Sellers | Member seller/admin/manager scope | Admin/manager command theo quyền |
| Tasks và children | `can_read_task` | Command riêng cho từng action |
| Templates | Admin/manager theo toàn bộ target được quyền; employee qua occurrence/task projection | Admin/manager |
| Requests/decisions/request_file_links | Chính chủ/HR; manager seller không được SELECT riêng tư | Submit/approve commands |
| Attendance events/sessions | Chính chủ/HR | Gateway và adjustment command |
| Attendance evidence | Chính chủ hoặc `can_view_attendance_evidence` | Gateway only |
| Day summaries | Chính chủ/HR | Worker recalculation only |
| Timesheet snapshots | Chính chủ/HR | Close/revision command only |
| Notifications | Đúng recipient active | Server tạo, recipient mark read qua command |
| Task reminder snoozes | Đúng member active và vẫn xem được task | Self snooze command có giới hạn; manager không sửa snooze của người khác để giả lịch sử |
| Export jobs | Requestor/capability hiện tại và toàn bộ scope còn hợp lệ | Export command/worker; tải qua gateway kiểm tra lại |
| Push endpoints | Không SELECT raw token từ client; chỉ danh sách thiết bị đã làm sạch | Register/revoke command |
| Reports | Recipient và scope hiện tại còn hợp lệ; admin org | Worker only |
| Audit logs | Admin, projection giới hạn | Append only từ server/command |
| Files | Theo entity parent + purpose, không chỉ uploader | Upload-intent/finalize flow |
| Private queues | Không client | Internal functions/worker |

### 30.7. Grants bổ sung bắt buộc kiểm thử

- Anon không xem được bất kỳ task/member/attendance/report nào.
- Authenticated không gọi được `rpc_internal_finalize_attendance`, `rpc_internal_build_reports`, `rpc_internal_dispatch`, `rpc_internal_invite_member`.
- Người dùng không tự tạo policy, role, bucket public hoặc signed URL cho file ngoài quyền.
- Xem ảnh HR thông qua gateway có audit và TTL ngắn. Không cấp policy SELECT toàn bucket chỉ vì là authenticated.
- SQL view aggregate không được làm lộ tổng ngoài scope.
- Realtime chỉ phát event tối thiểu; không phát JSON HR trên channel organization công khai.

---

<a id="section-31"></a>

## 31. HỢP ĐỒNG API/RPC — TÊN, INPUT, OUTPUT, QUYỀN

### 31.1. Quy ước transport

- Supabase RPC public nhận `p_input jsonb`; validation tương ứng Zod và DB.
- Web/mobile dùng package `api-client` chung.
- Command trả success envelope mục 28; lỗi DB trở thành transport error, api-client chuẩn hóa.
- Read APIs trả `data`, `server_now`, `next_cursor` khi phân trang.
- Cursor ổn định theo `(sort_column,id)`, không dựa vào offset cho stream lớn thay đổi liên tục; bảng nhỏ vẫn có page UI.
- Limit mặc định 25, tối đa 100; export là job riêng.
- Mọi command có organization, idempotency key; update có expected_version.
- Client không truyền `actor_user_id`, `is_admin`, `verified_ip`, `server_time` cho API user như bằng chứng tin cậy.

### 31.2. Read RPC

| RPC | Input bổ sung | Output chính |
|---|---|---|
| `rpc_get_context` | organization_id optional | user/member, role, capabilities, seller scope, timezone, server_now |
| `rpc_get_today` | organization_id, date | shift card, task groups disjoint, counters, own request summary |
| `rpc_list_tasks` | filters, cursor, limit | task rows + total scope-aware + next_cursor |
| `rpc_get_task` | task_id | detail, checklist, latest submission, allowed_actions, version |
| `rpc_list_task_events` | task_id, cursor | immutable timeline |
| `rpc_get_overview` | date, seller_ids? | manager queues, per-person/per-seller metrics |
| `rpc_list_templates` | filters, cursor | template rows, next occurrence, resolution issues |
| `rpc_preview_recurrence` | config, start, horizon<=30 | dates, targets, assignee resolutions, warnings |
| `rpc_get_calendar` | start_date,end_date<=62, layers, member/seller scope | real tasks, projected occurrences, shifts, redacted availability |
| `rpc_list_sellers` | filters | seller rows/cards counts in scope |
| `rpc_get_seller` | seller_id | header, authorized tabs, task summary, team projection |
| `rpc_list_members` | seller_id?, search | minimal directory |
| `rpc_get_member_workload` | member_id,date range | tasks in viewer scope, not full HR |
| `rpc_get_attendance_day` | member_id?,work_date | sessions, summaries, exceptions, permitted evidence metadata |
| `rpc_list_attendance_live` | date | HR-only team rows |
| `rpc_preview_request` | request draft | affected shifts/seconds/tasks, overlaps, leave balance warning |
| `rpc_list_requests` | own/HR filters | list per permission |
| `rpc_get_request` | request_id | detail + decisions + before/after preview if HR |
| `rpc_get_timesheet` | month,member_id? | live rows or closed snapshot + revision |
| `rpc_list_reports` | date range | allowed report runs/snapshots |
| `rpc_get_report` | snapshot_id | current-scope-validated facts, summary, metadata |
| `rpc_list_notifications` | category,unread,cursor | own notifications |
| `rpc_get_settings` | section | configuration with secrets redacted |
| `rpc_get_jobs_health` | date range | admin diagnostics, no private payload |
| `rpc_list_audit` | filters,cursor | admin safe audit |

Read quyền có thể triển khai bằng view security_invoker + RLS nếu đáp ứng đúng shape, nhưng tên contract phía client không đổi.

### 31.3. Task commands

| RPC | Input quan trọng | Guard | Atomic side effects |
|---|---|---|---|
| `rpc_create_task` | task draft | create scope, assignee/reviewer valid | task + children + created event + outbox |
| `rpc_create_task_batch` | common draft + targets[] | toàn bộ target hợp lệ hoặc explicit valid-only mode | từng task + batch_id, result từng target |
| `rpc_update_task` | task_id, allowed patch, version | manager scope; lý do đổi hạn/người | version,event,outbox |
| `rpc_ack_task` | task_id,version | assignee | ack,event |
| `rpc_start_task` | task_id,version | assignee | auto ack nếu cần + started,event |
| `rpc_toggle_checklist` | item_id,checked,version | assignee/item assignee, task editable | item update + task meaningful update/event |
| `rpc_submit_task` | task_id,result,links,file_ids,no_incident,version | checklist/result/file ready | submission + status + event + reviewer notification |
| `rpc_decide_submission` | task_id,submission_id,decision,reason,new_due_at?,version | reviewer/admin override, not self | decision,status,event |
| `rpc_withdraw_submission` | task_id,submission_id,version | assignee, pending only | withdrawn + in_progress,event |
| `rpc_set_blocker` | task_id,reason,owner,version | assignee | blocker,event,routing |
| `rpc_resolve_blocker` | task_id,note,version | permitted participants/manager | blocker cleared,event |
| `rpc_request_due_change` | task_id,proposed_due,reason,version | assignee | request event/inbox manager; không sửa due |
| `rpc_reassign_task` | task_id,new_assignee,reason,version | manager | assignment reset ack,event |
| `rpc_cancel_task` | task_id,reason,version | manager | canceled,event,reminders invalidated |
| `rpc_waive_occurrence` | occurrence_id/task_id,reason,version | manager | waived, audit, no done count |
| `rpc_reopen_task` | task_id,reason,new_due_at,version | manager | in_progress, clear current completion,event |
| `rpc_add_comment` | task_id,body,mention_member_ids | can_read + participant write | comment,outbox mentions scoped |
| `rpc_edit_comment` | comment_id,body,version | own within 15m | edit timestamp/event |
| `rpc_create_template` | template config+targets | scope all targets | template/version/targets + generate today if relevant |
| `rpc_update_template` | template_id,config,effective_from,version | scope | new immutable version |
| `rpc_pause_template` | template_id,reason,version | scope | paused, no history deletion |
| `rpc_resume_template` | template_id,start_date,version | scope | active, generate relevant |
| `rpc_end_template` | template_id,end_date,reason,version | scope | ended, no future new instances |
| `rpc_resolve_occurrence` | occurrence_id,assignee/action,reason,version | manager | create/bind task once or waive |

Due-change request có thể lưu trong `task_events` với event_type `due_change_requested`, payload có trạng thái và event quyết định liên kết; V1 không dùng `employee_requests` HR vì đây không phải dữ liệu nghỉ. Backend phải cung cấp pending action projection và chống duyệt hai lần.

### 31.4. Draft schema có kiểu rõ ràng

```ts
type UUID = string;
type ISODate = string; // YYYY-MM-DD
type ISOInstant = string; // ISO with offset/Z

type ChecklistDraft = {
  title: string;
  required: boolean;
  assigned_member_id: UUID | null;
};

type TaskDraft = {
  title: string;
  description: string;
  seller_id: UUID | null;
  assignee_member_id: UUID;
  reviewer_member_id: UUID | null;
  planned_date: ISODate;
  due_at: ISOInstant;
  priority: "low" | "normal" | "high" | "urgent";
  requires_review: boolean;
  requires_result: boolean;
  requires_attachment: boolean;
  allow_no_incident: boolean;
  reminder_profile: "standard" | "closer";
  reminder_profile_reason: string | null;
  reminder_profile_review_at: ISODate | null;
  estimated_minutes: number | null;
  collaborator_ids: UUID[];
  checklist: ChecklistDraft[];
  reference_file_ids: UUID[];
};

type RecurrenceConfig = {
  schema_version: 1;
  timezone: "Asia/Ho_Chi_Minh" | string;
  frequency: "working_days" | "every_day" | "weekdays";
  weekdays: number[]; // ISO 1..7; [] nếu không dùng
  starts_on: ISODate;
  ends_on: ISODate | null;
  due_local_time: string; // HH:mm
  due_day_offset: 0 | 1;
  assignment_strategy: "fixed" | "seller_default" | "seller_coverage";
  on_leave: "require_replacement" | "waive_if_explicitly_approved";
  business_critical: boolean;
  template_task: Omit<TaskDraft, "planned_date" | "due_at" | "seller_id" | "assignee_member_id">;
  targets: Array<{
    target_id?: UUID; // giữ ổn định khi sửa
    seller_id: UUID | null;
    fixed_assignee_id: UUID | null;
    specialty_id: UUID | null;
  }>;
};
```

Zod và SQL validate có điều kiện:
- `requires_review` cần reviewer; reviewer khác mọi fixed assignee tương ứng.
- `frequency=weekdays` phải có ít nhất 1 weekday.
- `seller_default/coverage` cần seller + specialty.
- Working-days cần resolve người và ca; nếu không có lịch trả warning/error rõ.
- `due_day_offset=1` chỉ cho công việc gắn ca qua đêm hoặc cấu hình đã giải thích; không mặc định deadline ngày sau.
- Không parse `HH:mm` bằng timezone máy khách; server chuyển local date/time theo template timezone.
- `fixed` cần assignee cho từng target.

### 31.5. Attendance gateway APIs

Các endpoint trên Next.js server, dùng chung cho web/native; strict office chỉ cho native đủ evidence.

| Endpoint | Input | Output |
|---|---|---|
| `POST /api/attendance/challenge` | org,shift_id,action,mode,device_id | challenge_id,nonce,expires_at,requirements,server_now |
| `POST /api/attendance/upload-intent` | challenge_id,mime,size | file_id,upload URL/path giới hạn |
| `POST /api/attendance/finalize` | challenge_id,nonce,device_id,wifi_claim?,file_id?,idempotency_key | event/session/day summary |
| `POST /api/attendance/laptop-session` | org,shift_id | short code + expiry, private |
| `GET /api/attendance/network-diagnostic` | org,office_id | matched/not matched/unknown; không thêm allowlist |
| `POST /api/files/signed-url` | file_id,purpose | short-lived URL nếu current ACL cho phép |

Gateway lấy actor từ JWT xác thực, IP từ trusted ingress, gọi các RPC internal grant service_role-only. Không cho client tự gọi internal RPC bằng user JWT.

Challenge raw nonce trả một lần, DB lưu hash. Khi finalizing phải hash và constant-time compare ở server phù hợp; không gửi nonce vào logs.

### 31.6. HR, settings, notification commands

| RPC/endpoint | Input | Điều kiện |
|---|---|---|
| `rpc_submit_request` | request draft + idempotency | self, valid interval, no forbidden overlap |
| `rpc_withdraw_request` | id,version | own pending |
| `rpc_decide_request` | id,decision,treatment,handover_actions,version | HR, not self |
| `rpc_apply_administrative_adjustment` | member,shift,correction,reason | owner/admin with audit, separate from approve |
| `rpc_cancel_approved_request` | request id,reason,version | HR, period policy |
| `rpc_set_leave_balance` | member,type,delta,reason | admin, ledger append |
| `rpc_create_shift_template` | template | HR |
| `rpc_assign_shift_pattern` | member,pattern,effective dates | HR, no overlap |
| `rpc_override_calendar_day` | member/org,date,kind | HR, impact preview |
| `rpc_recalculate_attendance` | member/date range | HR, no silent closed-period mutation |
| `rpc_begin_timesheet_reconciliation` | month,version | HR |
| `rpc_close_timesheet` | month,version | admin, no blocking exceptions |
| `rpc_reopen_timesheet` | period,reason,version | admin |
| `POST /api/exports/timesheet` | period,revision,scope | HR/self; export async/private |
| `POST /api/admin/invitations` | email,role,sellers,capabilities | admin verified, no self role escalation |
| `rpc_update_member_access` | member,role,capabilities,scope,version | admin, protect last owner/admin |
| `rpc_deactivate_member` | member,handover plan,version | admin |
| `rpc_create_or_update_seller` | seller input,version? | scope/admin |
| `rpc_update_seller_members` | seller,members | admin/authorized manager |
| `rpc_update_policy` | policy_kind,config,effective_from | admin, versioned |
| `rpc_register_device` | platform,installation_id,label | self |
| `POST /api/notifications/register-push` | device,token | self; encrypt server-side |
| `rpc_revoke_device` | device_id | self/admin |
| `rpc_mark_notification_read` | notification_id | recipient |
| `rpc_mark_all_notifications_read` | cutoff | recipient, không đánh dấu tương lai |
| `rpc_snooze_reminder` | task_id,rule_key,until,expected_version,idempotency_key | self, giới hạn ở mục 25; upsert task_reminder_snoozes, expected_version=0 khi chưa có bản ghi |
| `rpc_retry_job` | job_id,reason | admin, safe dedupe |
| `rpc_request_report_revision` | date,reason | admin, new revision explicit |

### 31.7. Mã lỗi và nội dung UI

| Code | UI |
|---|---|
| `VALIDATION_ERROR` | Hiển thị lỗi trường cụ thể |
| `AUTH_REQUIRED` | `Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.` |
| `MEMBERSHIP_INACTIVE_OR_MISSING` | `Bạn không còn quyền truy cập workspace này.` |
| `RESOURCE_NOT_FOUND` | `Không tìm thấy dữ liệu hoặc bạn không có quyền truy cập.` |
| `VERSION_CONFLICT` | `Dữ liệu vừa được cập nhật. Hãy tải lại trước khi lưu.` |
| `IDEMPOTENCY_KEY_REUSED` | `Thao tác gửi lại không khớp nội dung trước đó.` |
| `ASSIGNEE_NOT_IN_SELLER` | `Người được chọn chưa được phân công seller này.` |
| `REQUIRED_CHECKLIST_INCOMPLETE` | `Vui lòng hoàn tất các mục bắt buộc.` |
| `RESULT_REQUIRED` | `Vui lòng bổ sung kết quả trước khi gửi.` |
| `SELF_APPROVAL_NOT_ALLOWED` | `Bạn không thể tự duyệt yêu cầu của mình.` |
| `SHIFT_NOT_FOUND` | `Chưa có ca phù hợp để chấm công.` |
| `OPEN_SESSION_EXISTS` | `Bạn đang có một phiên làm việc chưa chấm ra.` |
| `NO_OPEN_SESSION` | `Chưa có phiên vào ca phù hợp để chấm ra.` |
| `REMOTE_NOT_APPROVED` | `Ca này chưa được phép chấm công online.` |
| `WIFI_UNAVAILABLE` | `Chưa đọc được thông tin Wi-Fi trên thiết bị.` |
| `OFFICE_NETWORK_MISMATCH` | `Kết nối hiện tại không khớp mạng văn phòng.` |
| `TRUSTED_IP_UNAVAILABLE` | `Máy chủ chưa xác minh được nguồn kết nối. Vui lòng dùng yêu cầu bổ sung.` |
| `CHALLENGE_EXPIRED` | `Phiên xác thực đã hết hạn. Vui lòng thực hiện lại.` |
| `CHALLENGE_ALREADY_USED` | Trả record cũ nếu retry cùng operation; nếu khác thì từ chối |
| `EVIDENCE_REQUIRED` | `Vui lòng chụp ảnh theo yêu cầu của ca.` |
| `REQUEST_OVERLAP` | `Khoảng thời gian trùng với một yêu cầu đang có hiệu lực.` |
| `ATTENDANCE_LEAVE_CONFLICT` | `Thời gian làm việc và nghỉ đã duyệt đang chồng nhau, cần đối soát.` |
| `PERIOD_CLOSED` | `Bảng công tháng đã chốt. Cần mở lại kỳ để điều chỉnh.` |
| `PENDING_EXCEPTIONS` | `Chưa thể chốt vì còn dữ liệu cần đối soát.` |
| `FILE_NOT_READY` | `Tệp chưa tải lên xong hoặc chưa được xác minh.` |
| `RATE_LIMITED` | `Bạn thao tác quá nhanh. Vui lòng thử lại sau ít giây.` |

Thông điệp frontend mapping theo code, không render raw stack trace/database SQL.

---

<a id="section-32"></a>

## 32. THUẬT TOÁN DAILY TASK VÀ LỊCH CA

### 32.1. Sinh ca

Job `materialize_shifts` sinh rolling horizon 30 ngày, đọc assignment/overrides theo ngày. Ca đã có event attendance không được cập nhật cấu trúc khi sửa mẫu.

Thứ tự ưu tiên: override cá nhân ngày đó → override tổ chức ngày đó → assignment có hiệu lực. Nếu có hai pattern cùng hiệu lực gây overlap, báo lỗi cấu hình, không tự lấy row đầu tiên.

Ca có version/policy snapshot. Cron rerun không tạo thêm ca nhờ natural key và overlap constraint.

### 32.2. Khi sinh daily task

Job `materialize_daily_tasks` chạy mỗi phút nhưng chỉ xử lý ngày/target chưa resolve. Tại 00:05 local, chuẩn bị các instance của ngày; nếu tạo mẫu vào 09:00 cùng ngày thì command trigger xử lý ngay ngày đó.

Mặc định chỉ materialize đến ngày hiện tại. Calendar tương lai dùng projection 30 ngày. Không cần tạo hàng nghìn task trước một năm.

Nếu muốn tạo trước để phân công, mở cấu hình horizon tối đa 7 ngày; phải giữ nguyên cơ chế publish notification theo ngày làm, không push tất cả task tương lai ngay.

### 32.3. Pseudocode chuẩn

```text
for each active organization:
  today = local_date(server_now, organization.timezone)
  acquire lease "daily:<org>:<today>"
  for each active template and stable target:
    for date D in missing/catch-up dates through today:
      V = effective template version on D
      if no V or D outside [starts_on, ends_on]: continue
      if recurrence rule excludes D: record not_scheduled if needed; continue

      assignee = resolve fixed/default/coverage using D
      if assignee missing/inactive/not in seller:
        upsert occurrence needs_assignment
        queue manager issue once
        continue

      shift = resolve work schedule relevant to D
      if frequency = working_days and no scheduled work:
        upsert occurrence not_scheduled(reason="NO_WORKING_SHIFT")
        continue

      if approved leave affects required execution:
        resolve replacement from explicit coverage/handover
        if no replacement:
          if explicit waiver decision exists:
            upsert occurrence waived with decision link
          else:
            upsert occurrence needs_assignment
          continue

      due_at = zoned_datetime(D + due_day_offset, due_local_time, V.timezone)
      begin transaction:
        lock/upsert occurrence unique(target_id,D)
        if occurrence already has task: return existing
        validate assignee/seller again
        create task with template content snapshot and fresh checklist
        bind task to occurrence
        add task_created event
        enqueue task_assigned not_before appropriate shift/publish time
      commit
```

`needs_assignment` occurrence có thể được resolve sau rồi tạo task; constraint bảo đảm không tạo trùng. Mẫu nghỉ/sửa/retry không được đổi target ID để lách unique constraint.

### 32.4. Nghỉ, lễ và công việc thiết yếu

- Working_days: ngày không có ca không tạo task cho nhân viên đó; không gắn miss.
- Every_day (7 ngày): nghĩa là nhu cầu nghiệp vụ cần được xử lý mỗi ngày, không đồng nghĩa cùng một người phải làm cả tuần.
- Khi người fixed nghỉ, tạo issue cho quản lý chọn người trực/thay.
- Request approved partial-day: task bị ảnh hưởng nếu planned execution/deadline rơi trong khoảng nghỉ hoặc manager xác nhận cần bàn giao; không bàn giao toàn bộ ngày một cách mù quáng.
- Người nghỉ vẫn có thể xem task lịch sử; reminders trong khoảng nghỉ bị suppress.
- Daily task đã bắt đầu trước nghỉ: giữ task, đánh dấu cần quyết định, không tự reset checklist.

### 32.5. Hệ thống gián đoạn hoặc tạo muộn

Catch-up tự động tối đa 7 ngày để phát hiện ngày thiếu. Những lần quá hạn do hệ thống sinh muộn được đánh dấu `SYSTEM_GENERATION_DELAY` trong occurrence/event. Không gửi dồn reminder trách nhân viên cho các ngày chưa từng được giao.

Ngoài 7 ngày: tạo diagnostic yêu cầu admin chạy backfill có preview. Backfill không tự tính “miss task” cho nhân viên.

### 32.6. Edit version

- Config có effective_from và revision immutable.
- Giữ original occurrence date, template_version_id đã dùng.
- Tương lai chưa materialize: dùng version mới.
- Instance đã tạo: mặc định giữ; sửa instance bằng command có audit.
- Pause: không tạo mới từ thời điểm hiệu lực; history cũ còn.
- Resume: không tự tạo bù mọi ngày đã pause; hỏi bắt đầu từ ngày nào.
- End: không xóa các task đã tạo.

<a id="section-33"></a>

## 33. THUẬT TOÁN CHẤM CÔNG VÀ TRUSTED GATEWAY

### 33.1. Vì sao không dùng website để đọc SSID

Web Network Information API không cung cấp cơ chế chuẩn để đọc SSID/BSSID của Wi-Fi đang kết nối. Vì vậy strict office attendance thuộc native app. Trên web có thể kiểm tra mạng qua IP nguồn, nhưng phải gọi đúng là kiểm tra nguồn mạng, không phải xác minh đúng Wi-Fi. [S09](#source-s09)

IP và Wi-Fi chỉ là các tín hiệu hỗ trợ kiểm tra điều kiện. Không quảng cáo hệ thống “chống chấm công hộ 100%”, “chứng minh ở văn phòng cả ngày” hoặc “selfie chắc chắn là ảnh thật”.

### 33.2. Lấy IP ở gateway

Mặc định triển khai web/gateway trực tiếp trên Vercel, sử dụng header nền tảng được cung cấp tại ingress theo tài liệu hiện hành. Vercel mô tả cơ chế ghi đè forwarded IP để hạn chế spoofing; khi thêm proxy phía trước phải đánh giá lại đường đi, không tin mọi `X-Forwarded-For`. [S10](#source-s10)

Mẫu adapter tối thiểu:

```ts
import { isIP } from "node:net";

export function readTrustedClientIp(request: Request): string {
  if (process.env.ATTENDANCE_INGRESS !== "vercel-direct") {
    throw new Error("TRUSTED_IP_UNAVAILABLE");
  }
  if (process.env.VERCEL !== "1") {
    throw new Error("TRUSTED_IP_UNAVAILABLE");
  }
  const raw = request.headers.get("x-vercel-forwarded-for")?.trim();
  if (!raw || raw.includes(",") || isIP(raw) === 0) {
    throw new Error("TRUSTED_IP_UNAVAILABLE");
  }
  return raw;
}
```

Đây là adapter cho đúng topology đã chọn, không phải hàm an toàn cho mọi hosting. Khi dùng self-host:
- Viết adapter riêng dựa trên peer IP và trusted proxy allowlist.
- Proxy phải loại bỏ/ghi đè các header nguồn do client gửi.
- Origin không được truy cập bypass proxy nếu đang tin header của proxy.
- Chưa kiểm chứng topology thì fail closed và dùng request bổ sung.
- Không dùng `body.ip`, kết quả IP từ ứng dụng hay header bất kỳ để auto-pass.
- Chuẩn hóa IPv4-mapped IPv6 trước đối chiếu; dùng kiểu `inet/cidr` PostgreSQL, không so chuỗi prefix.

Không gửi toàn bộ allowlist IP/BSSID cho người dùng chỉ để client tự quyết định pass/fail.

### 33.3. Phát challenge

1. Gateway xác minh access token bằng Supabase Auth (`getUser(jwt)` hoặc JWT verification phù hợp); không chỉ base64-decode JWT. [S19](#source-s19)
2. Tìm active membership thuộc org.
3. Xác minh device registration thuộc user này, chưa revoke.
4. Xác minh shift thuộc member, đúng cửa sổ check-in/check-out.
5. Xác minh mode được phép bởi shift hoặc approved remote request.
6. Tạo challenge ngẫu nhiên ít nhất 128 bit, lưu hash nonce, TTL 120 giây.
7. Trả requirements và server_now.
8. Rate limit đề xuất tối đa 10 challenge/5 phút/member và IP; có cấu hình, không khóa vĩnh viễn khi lỗi camera.

Việc issued challenge chưa phải chấm công.

### 33.4. Finalize văn phòng

Trong gateway:
- Xác minh JWT và membership lần nữa.
- Lấy IP thật qua adapter.
- Check body schema; wifi_claim gồm ssid/bssid/capturedAt, không gồm `verified:true` do client quyết định.
- Gọi internal RPC với actor đã xác minh và IP server.
- Internal RPC service-role-only thực hiện transaction:

```text
lock challenge row
validate org/member/device/action/mode/expiry/not-consumed
validate current membership and allowed shift again
validate source IP in active office_ip_ranges
normalize and match BSSID in active office_networks
SSID chỉ là nhãn bổ trợ, không đủ một mình
validate check-in has no open session or check-out has correct open session
resolve idempotency:
  same key + same operation already committed -> return existing
  same key + changed payload -> reject
insert attendance_event using database clock
insert evidence with verification details
insert/update session projection
consume challenge
append audit event
enqueue recompute day + UI invalidation
commit
```

Timestamp chính thức cho check-in/out là DB `clock_timestamp()` khi finalize, không phải timestamp client. `recorded_at` bằng thời điểm ghi. Thời gian thao tác chụp/upload có thể khiến mốc ghi nhận sau lúc mở camera; UI phải nói rõ, không âm thầm backdate.

Giá trị `verified` trong record có nghĩa đã vượt quy tắc mạng được cấu hình; không có nghĩa xác minh danh tính sinh trắc học.

### 33.5. Finalize online

Tương tự nhưng:
- Quyền online phải có hiệu lực đúng thời điểm.
- File gắn challenge, uploader, org, device và ca.
- File state ready, MIME/size hợp lệ, nằm private bucket đúng purpose.
- Không cho tái dùng file của task hoặc ảnh từ challenge khác.
- Đầu ca bắt buộc ảnh; cuối ca theo policy snapshot.
- Nếu bật laptop session, validate session cùng user còn hạn. Kiểm tra này không tự xác nhận nội dung ảnh.
- `mode='remote'`; không fake dữ liệu Wi-Fi.
- Nếu chụp không rõ, HR tạo yêu cầu đối soát/giải trình; không tự xóa event và trừ công.

### 33.6. Adjustment

Correction approved tạo attendance event `adjustment`, có:
- `effective_at`: thời điểm hợp lệ được HR chấp thuận.
- `recorded_at`: thời điểm duyệt/ghi thật.
- `source_request_id`.
- `supersedes_event_id` nếu thay một event sai.
- Reviewer/admin identity + lý do.

Không UPDATE timestamp của raw event. Projection sessions được rebuild theo event chain, giữ bản superseded.

Nếu tháng đã chốt: command từ chối hoặc yêu cầu reopen/revision rõ ràng trước khi thay snapshot.

### 33.7. Session pairing

- Check-in khi có open session: trả OPEN_SESSION_EXISTS, không mở thêm.
- Check-out khi chưa có open session: NO_OPEN_SESSION, cho correction.
- Check-in/out phải thuộc cùng member và shift. Cross-midnight dùng shift_id, không chỉ local date hiện tại.
- Nếu đổi hình thức office → remote giữa ca, đóng session cũ và mở session mới khi được phép; không overwrite mode của toàn ngày.
- Hai thiết bị check-in đồng thời: row lock/advisory lock theo org/member + partial unique ngăn trùng.
- Session open qua hết ca: state needs_review sau khoảng chờ; không tự chấm ra ở 18:00.
- Session chưa đóng: có thể hiển thị live elapsed tạm tính, nhưng phần chưa xác thực ra không được đưa vào tổng verified để chốt.
- Ngoài working segments được lưu vào outside_schedule_seconds cho đối soát, không tự quy thành tăng ca có trả lương.

---

<a id="section-34"></a>

## 34. TÍNH CÔNG, NGHỈ VÀ CHỐT THÁNG — CÔNG THỨC CHUẨN

### 34.1. Đơn vị và mẫu số

- Lưu duration nguồn bằng số nguyên giây.
- Hiển thị giờ/phút có định dạng; detail cho phép xem giây để giải thích sai khác.
- `standard_day_minutes` mặc định đề xuất 480, nhưng cấu hình theo người/chính sách và snapshot theo ngày/ca.
- **Công không mặc định bằng số ca.** Ca 4 giờ với chuẩn 8 giờ là 0,5 công; nếu hợp đồng/chính sách dùng chuẩn khác thì phải cấu hình rõ.
- Nếu nhiều ca/ngày, tổng hợp trước khi tính ngày công, không cho hai ca chồng nhau.
- Không làm tròn từng session rồi cộng; cộng giây trước, chia mẫu số bằng NUMERIC, chỉ làm tròn trình bày.
- Khi một ngày có nhiều ca với standard_day_minutes khác nhau, đánh dấu cấu hình xung đột và chặn chốt; không lấy tùy tiện một mẫu số.

### 34.2. Tập thời gian

Cho một người và ngày nghiệp vụ:

- `W`: hợp các working segments của ca; đã loại breaks.
- `A`: hợp các attendance sessions hợp lệ, đã đóng, không superseded.
- `P`: hợp khoảng nghỉ được duyệt với treatment paid, cắt trong W.
- `U`: hợp khoảng nghỉ được duyệt với treatment unpaid, cắt trong W.
- `X`: phần W có dữ liệu chưa đủ để xác định, như session mở/thiếu event hoặc correction đang chờ.
- `H`: phần ngày lễ hưởng lương đã cấu hình, nếu có; phải không trùng P và được chuẩn hóa về paid absence.

Các phép union/intersection/subtraction phải xử lý interval thực, không lấy `checkout - checkin - 1 giờ nghỉ` cho mọi ca.

### 34.3. Kiểm tra trước khi tính

- Sessions overlap: hợp để tránh double-count, đồng thời tạo exception để đối soát nguyên nhân.
- Approved paid và unpaid leave overlap: blocking error.
- `A ∩ (P ∪ U)` khác rỗng: `ATTENDANCE_LEAVE_CONFLICT`, yêu cầu xác định nhân viên thực làm hay thực nghỉ. Không vừa cộng giờ làm vừa cộng paid leave.
- Leave interval không cắt W: affected_seconds=0; UI phải giải thích.
- Thiếu check-in/out: không kết luận toàn bộ ngày là vắng không phép.
- Những khoảng correction pending không được ghi verified.
- Late/early chỉ là chỉ số diagnostic, không trừ lần hai khỏi thời gian đã tính.

### 34.4. Tính sau khi đã giải quyết overlap

```text
worked_office_seconds = duration(union(valid office sessions) ∩ W)
worked_remote_seconds = duration(union(valid remote sessions) ∩ W)
worked_seconds = worked_office_seconds + worked_remote_seconds

paid_leave_seconds = duration(P ∪ H)
unpaid_leave_seconds = duration(U)
unknown_seconds = duration(X not already classified)

unexplained_seconds =
  duration(W) - worked_seconds - paid_leave_seconds
              - unpaid_leave_seconds - unknown_seconds

scheduled_units = scheduled_seconds / (standard_day_minutes * 60)
worked_units = worked_seconds / (standard_day_minutes * 60)
paid_leave_units = paid_leave_seconds / (standard_day_minutes * 60)
unpaid_leave_units = unpaid_leave_seconds / (standard_day_minutes * 60)
```

Phải bảo đảm categories không âm và không overlap. Nếu không đạt invariant, state `needs_review`, không clamp số âm về 0 để che bug.

`unexplained_seconds` chỉ được xác định khi có đủ bằng chứng/đối soát; phần chưa đủ thông tin thuộc unknown. Mất một event không tự đổ toàn bộ thiếu vào unexplained.

**Không có công thức V1 tự động “lương = công × đơn giá”**. Có thể xuất cột `Công làm + nghỉ hưởng lương tham khảo` nhưng không đặt tên `Lương phải trả`.

### 34.5. Đi muộn và về sớm

- So với working segment đầu/cuối và khoảng nghỉ được duyệt.
- Ví dụ xin đi muộn được duyệt 09:00–10:00, vào 10:00: không nhãn đi muộn không phép; vẫn có 1 giờ nghỉ theo treatment.
- Dung sai 5 phút có thể bỏ nhãn “đi muộn” trong 5 phút; mặc định không làm tăng worked_seconds.
- Chấm vào 09:10: worked time tự ít hơn 10 phút; không trừ thêm “10 phút đi muộn” một lần nữa.
- Về sớm được duyệt không biến thành done mọi task trong ngày.

### 34.6. Ví dụ kiểm thử số học

Giả sử ca 09:00–18:00, nghỉ 12:00–13:00, chuẩn 480 phút:

| Case | Dữ liệu | Kết quả bắt buộc |
|---|---|---|
| A | Vào 09:00, ra 18:00 | 480 phút thực làm = 1 công |
| B | Vào 09:00, ra 16:00; unpaid leave 16:00–18:00 | 360 phút làm = 0,75; 120 phút unpaid = 0,25 |
| C | Như B nhưng paid leave | 0,75 thực làm + 0,25 nghỉ hưởng lương; không gọi là 1 công thực làm |
| D | Vào 09:00, ra 18:00; leave 16:00–18:00 đã duyệt | Conflict, không 1,25 công |
| E | Nghỉ 12:00–13:00 | 0 phút ảnh hưởng do trùng break |
| F | Vào 09:10, ra 18:00 | 470 phút làm; 10 phút thiếu được phân loại theo đối soát, không trừ 2 lần |
| G | Chỉ có vào 09:00, chưa ra | Tạm tính/thiếu dữ liệu; không auto 1 công hoặc 0 công |
| H | Vào 08:30, ra 18:30 | 480 phút trong lịch; 60 phút ngoài lịch, không tự trả OT |
| I | Hai session 09:00–11:00 và 10:00–12:00 | Không cộng thành 4 giờ; overlap cần review, union là 3 giờ |
| J | Remote được phép 09:00–18:00 đủ events | 1 công online, không giảm hệ số chỉ vì online |
| K | Ca 09:00–13:00, không break, chuẩn 480 phút | 0,5 công theo lịch và thực làm nếu đủ |
| L | Ca 22:00–06:00 hôm sau, break 02:00–03:00 | 420 phút theo lịch, work_date là ngày bắt đầu; không mất phần sau nửa đêm |

Tháng có 22 công theo lịch: 18 văn phòng + 2 online + 1 paid leave + 1 unpaid = 20 công thực làm, 1 nghỉ hưởng lương, 1 nghỉ không lương. Không mặc định 22 công thực làm.

### 34.7. Leave treatment và pháp lý

Nghỉ không lương đã duyệt không tính vào công thực làm hoặc phần nghỉ hưởng lương. Nghỉ hằng năm/nghỉ hưởng lương cần loại riêng; Điều 113 Bộ luật Lao động có quy định nghỉ hằng năm hưởng lương, nên không được lập trình “duyệt đơn nào cũng mất công hưởng lương”. Cấu hình cuối cùng phải được người phụ trách nhân sự/pháp lý rà soát theo trường hợp áp dụng và văn bản hiện hành. [S15](#source-s15)

Bản đặc tả không thay thế tư vấn pháp lý và không tự xác định mọi loại nghỉ bệnh/việc riêng/chế độ bảo hiểm là paid hay unpaid.

### 34.8. Recalculation và chốt kỳ

Mọi event/decision ảnh hưởng công enqueue recalculation theo `(org,member,work_date)`. Worker đọc dữ liệu nguồn, tính deterministically, lưu source_revision_hash.

Nếu ngày thuộc kỳ open/reconciling: update summary. Nếu closed: raw adjustment không được tự ghi đè snapshot; tạo yêu cầu mở kỳ/revision.

Khi close:
- Lock period row.
- Kiểm tra tất cả nhân sự/ngày trong kỳ đã có lịch đúng và không còn blocking exceptions.
- Chốt snapshot theo active employment range, bao gồm người đã nghỉ việc nhưng có công trong tháng.
- Tạo hash dữ liệu nguồn, version thuật toán và policy snapshots.
- Insert snapshots + period closed + audit trong một transaction.
- Export đọc đúng revision.

---

<a id="section-35"></a>

## 35. BÁO CÁO 18:00, REPLAY VÀ LỊCH MÁY CHỦ

### 35.1. Múi giờ và cutoff

```text
report_date = local date of organization
cutoff_local = report_date at configured 18:00
cutoff_at = convert cutoff_local using organization timezone
```

Với `Asia/Ho_Chi_Minh`, 18:00 tương ứng 11:00 UTC, nhưng code phải chuyển timezone, không hardcode `UTC+7` cho mọi organization trong tương lai.

Cron tick mỗi phút kiểm tra `now >= cutoff_at` và chưa có run tương ứng. Không chỉ chạy đúng một lần cron 11:00 rồi bỏ luôn báo cáo khi job lỗi.

### 35.2. Snapshot đúng thời điểm

Không query status hiện tại lúc 18:20 rồi gắn nhãn “chốt 18:00”.

Task events lưu state_after report-relevant mỗi thay đổi. Reconstruct bằng event mới nhất với `recorded_at <= cutoff_at`, tie-break `task_version`. Không dùng timestamp do client cung cấp.

Ví dụ:
- 17:59 todo.
- 18:10 done.
- Job retry 18:20.
- Báo cáo 18:00 vẫn ghi task còn mở; báo cáo trực tiếp hiện done.

Attendance adjustment được duyệt 19:00 nhưng effective_at 09:00 không làm báo cáo cũ tự đổi. Hiển thị dữ liệu bổ sung sau chốt hoặc tạo revision có nhãn rõ.

Transaction nghiệp vụ giữ ngắn, không chờ API ngoài khi đang giữ lock. Snapshot được xây trên một DB transaction nhất quán; ghi `generated_at` và source hash. Nếu phát hiện event ghi bổ sung/commit muộn ảnh hưởng cutoff đã chốt, đánh dấu cần đối soát và tạo revision theo quyền, không sửa facts version cũ âm thầm.

### 35.3. Công thức đếm task

Cohort chính của từng người:

```text
D = task tồn tại tại cutoff,
    assignee tại cutoff = người đang xét,
    local_date(due_at) = report_date,
    due_at <= cutoff_at,
    status không thuộc canceled/waived.

done_count = D có status done.
review_count = D có status in_review.
open_count = D có status todo hoặc in_progress.

due_count = done_count + review_count + open_count.
blocked_count = tập con open_count có blocker.
```

Các nhóm **tách riêng, không cộng tùy tiện vào cohort chính**:
- `overdue_previous_days`.
- `due_after_cutoff`.
- `completed_today_outside_due_cohort`.
- `canceled_or_waived_today`.
- `tomorrow_planned`.
- `needs_assignment_occurrences`.

Task nhiều collaborator chỉ đếm 1 lần dưới assignee. Có section đóng góp của người phối hợp nhưng không cộng vào số task chịu trách nhiệm chính.

### 35.4. JSON facts report

```json
{
  "schema_version": 1,
  "report_date": "2026-10-05",
  "cutoff_at": "2026-10-05T11:00:00Z",
  "timezone": "Asia/Ho_Chi_Minh",
  "scope": {"kind":"sellers","seller_ids":["<uuid>"]},
  "totals": {
    "due_count": 19,
    "done_count": 15,
    "review_count": 1,
    "open_count": 3,
    "blocked_count": 1
  },
  "people": [
    {
      "member_id": "<uuid>",
      "display_name": "Linh",
      "due_count": 8,
      "done_count": 6,
      "review_count": 1,
      "open_count": 1,
      "blocked_count": 0,
      "results": [],
      "open_tasks": [],
      "overdue_previous_days": [],
      "due_after_cutoff": [],
      "tomorrow_planned": [],
      "availability": "working"
    }
  ],
  "sellers": [],
  "manager_actions": [],
  "warnings": []
}
```

Các số trên chỉ là fixture minh họa, không hardcode vào UI.

Không để facts chứa signed image URL, source IP, email riêng tư hoặc reason_private. Owner HR muốn xem attendance chi tiết đi qua link được kiểm tra quyền riêng.

### 35.5. Tạo run và recipient snapshots

1. Claim logical key `(org,date,cutoff,revision)`.
2. Reconstruct state.
3. Xác định recipients active và scope hiện tại.
4. Tạo snapshot facts riêng cho scope organization/seller/personal.
5. Tạo summary template.
6. Lưu run ready, snapshots và outbox notifications trong transaction.
7. Worker gửi push/inbox/email optional.
8. AI summary có thể cập nhật trường summary với version/source rõ, không sửa facts; bản template luôn sẵn trước.

Manager không có seller scope chỉ nhận tóm tắt công việc mình tham gia, không nhận toàn workspace.

### 35.6. Cron cài đặt

Supabase Cron/pg_cron có thể gọi SQL và dùng pg_net gọi Edge Functions; secret đặt trong Vault hoặc hệ thống secret phù hợp, không hardcode migration công khai. [S04](#source-s04)

Mẫu SQL lịch:

```sql
select cron.schedule(
  'opsdesk-domain-tick',
  '* * * * *',
  $$ select private.scheduler_tick(clock_timestamp()); $$
);

select cron.schedule(
  'opsdesk-shifts-maintenance',
  '*/30 * * * *',
  $$ select private.materialize_shift_horizon(clock_timestamp(), 30); $$
);
```

`private.scheduler_tick`:
- Claim lease.
- Xác định organization due.
- Sinh occurrence thiếu có limit.
- Tạo reminders đủ điều kiện bằng SQL.
- Build report đã đến cutoff và chưa có.
- Enqueue recalculations.
- Ghi job_runs.
- Không gọi HTTP/AI trong transaction này.

Worker delivery được đánh thức mỗi phút qua cron HTTP, không dùng `setTimeout` giữ Edge Function sống lâu.

### 35.7. Lỗi và retry

- Report facts lỗi: run failed, admin thấy cảnh báo; retry cùng logical run, không tạo version 2 trừ người dùng yêu cầu revision.
- Push lỗi nhưng snapshot ready: vẫn xem report; chỉ delivery retry.
- Job đến trễ: `is_late=true`, ghi `Tạo muộn lúc ...`, cutoff giữ 18:00.
- Service gián đoạn vài ngày: catch-up theo date có limit, report dùng history; nếu thiếu history phải báo incomplete, không giả chính xác.
- Giờ báo cáo bị đổi trong ngày: tạo schedule config version; không tạo lại báo cáo cũ trừ command revision.

---

<a id="section-36"></a>

## 36. OUTBOX, WORKER, PUSH VÀ REALTIME

### 36.1. Transactional outbox

Không gửi push giữa transaction tạo task. Trình tự chuẩn:
`DB mutation → audit/event/outbox → commit → worker gửi`.

Outbox dedupe_key ví dụ:
- `task:{taskId}:assigned:{assignmentVersion}`.
- `reminder:{taskId}:{memberId}:{rule}:{deadlineVersion}:{localDate}`.
- `report:{runId}:{snapshotId}:{memberId}`.
- `request:{requestId}:decision:{version}`.

### 36.2. Claim và lease

Internal RPC `rpc_internal_claim_outbox(worker_id,limit)`:
- Grant service_role only.
- `FOR UPDATE SKIP LOCKED`.
- Chọn pending/failed đã đến available_at hoặc lease cũ hết hạn.
- Đặt status processing, lease_owner/lease_until, attempts+1.
- Trả tối đa 25 items; không giữ transaction khi gửi mạng.
- Worker ack/fail phải có đúng lease_owner, không cho worker cũ ack lease đã được người khác lấy.

Dùng `lease_owner` đã định nghĩa trong `private.outbox_events`; đây là field bắt buộc cho cơ chế claim. Lease mặc định 60 giây; worker batch nhỏ để hoàn thành trong giới hạn runtime.

Backoff đề xuất: 1 phút, 5 phút, 15 phút, 1 giờ; tối đa 5 lần cho lỗi tạm thời, có dead-letter state/diagnostic. Lỗi token không hợp lệ thì revoke endpoint, không retry vô hạn.

### 36.3. Xác thực worker

Worker cron không được coi publishable key là quyền admin.

Có thể dùng auth secret mode của Supabase Edge Functions với key riêng có tên `automations`; `verify_jwt=false` chỉ vì đây là service-to-service, nhưng handler bắt buộc xác minh secret. Không mở public handler không auth rồi dùng admin client. [S05](#source-s05)

Ví dụ pattern:

```ts
import { withSupabase } from "npm:@supabase/server@1";

export default {
  fetch: withSupabase(
    { auth: "secret:automations" },
    async (_request, ctx) => {
      // SCAFFOLD ONLY: replace this with the claim/process/ack flow
      // from sections 36.1-36.2 and the internal RPC contracts.
      // Fail closed until that implementation is present; never fake success.
      throw new Error("IMPLEMENTATION_REQUIRED: dispatch transactional outbox");
    }
  ),
};
```

Đây là scaffold thể hiện cách xác thực, chưa phải worker hoàn chỉnh. AI phải thay exception `IMPLEMENTATION_REQUIRED` bằng luồng claim/process/ack đã mô tả, trả counters thật và có bài test retry/lease trước khi nghiệm thu. Không thay exception bằng `{ok:true}` rỗng. Secret mode là xác thực server-to-server; secret vẫn có đặc quyền lớn, cần giới hạn nơi lưu và xoay khóa.

### 36.4. Push mobile

- Đăng ký Expo push token theo device + member; logout/revoke thì ngừng gửi.
- Tách `accepted` bởi dịch vụ và `provider_confirmed`; không có cột “nhân viên đã đọc” lấy từ push receipt.
- Kiểm tra receipts, xử lý DeviceNotRegistered, credentials error, payload error.
- Retry mạng/backoff, không spam token đã vô hiệu.
- Payload tối giản: kind, target ID, notification ID; text không chứa HR nhạy cảm.
- Bật bảo vệ server gửi push theo khả năng provider.
- Push service không bảo đảm mọi notification đến thiết bị đúng thời điểm; inbox DB là nguồn thông báo lưu bền. [S11](#source-s11)

**Cam kết kỹ thuật đúng:** một notification logic trong DB nhờ unique key. Gửi ra provider là at-least-once trong tình huống retry; có thể trùng push khi provider nhận rồi worker mất kết nối trước ack. Dùng notification ID/collapse semantics khi được hỗ trợ để giảm trùng, không hứa exactly-once trên mọi thiết bị.

### 36.5. Realtime

V1 ưu tiên Supabase Postgres Changes trên `notifications` của chính user và các bảng task được RLS bảo vệ; tránh subscribe cả bảng HR. Có thể dùng private Broadcast để invalidation tối giản. Quyền private channel và RLS phải được cấu hình đúng; thay quyền có thể chưa lập tức hủy authorization cache của một channel đang mở, nên không đưa nội dung nhạy cảm vào broadcast. [S12](#source-s12)

Event invalidation:
```json
{"type":"task_changed","organization_id":"...","task_id":"...","version":7}
```

Khi nhận event, client gọi lại API có RLS hiện tại. Không render dữ liệu task/ảnh chỉ từ message push.

Đăng xuất hoặc membership inactive:
- Unsubscribe channels.
- Clear query cache và persisted drafts phù hợp.
- Revoke tokens thiết bị.
- Mọi read/write DB vẫn kiểm tra active membership để ngăn JWT cũ.
- Signed URL đã phát có thể còn hiệu lực đến TTL; vì vậy TTL ảnh HR rất ngắn, xem mục 37.

### 36.6. Danh sách internal RPC cần có

Grant service_role only:
- `rpc_internal_claim_outbox`.
- `rpc_internal_ack_outbox`.
- `rpc_internal_fail_outbox`.
- `rpc_internal_create_attendance_challenge`.
- `rpc_internal_finalize_attendance`.
- `rpc_internal_finalize_upload`.
- `rpc_internal_register_push_endpoint`.
- `rpc_internal_recalculate_attendance`.
- `rpc_internal_build_report`.
- `rpc_internal_create_invited_membership`.
- `rpc_internal_get_file_access_context` (gateway dùng sau xác minh user, vẫn validate actor/scope).
- `rpc_internal_record_file_access`.
- `rpc_internal_cleanup_file_candidates`.

Private scheduler SQL không cần public wrapper cho mọi function. Không mở các function worker cho authenticated “để frontend test cho dễ”.

<a id="section-37"></a>

## 37. STORAGE, QUYỀN RIÊNG TƯ, BẢO MẬT VÀ XUẤT FILE

### 37.1. Bucket và đường dẫn

Tạo private buckets:
- `task-files`.
- `attendance-evidence`.
- `request-evidence`.
- `exports`.

Đường dẫn do server tạo:
```text
{organization_id}/{purpose}/{entity_id}/{random_uuid}.{allowed_extension}
```

Không dùng filename người dùng làm path. Không chứa họ tên, email hay lý do nghỉ trong tên object. `original_name` chỉ là metadata được lọc quyền.

Mặc định đề xuất:
- Selfie JPEG/WebP, tối đa 5 MB sau xử lý; chiều dài cạnh tối đa 1920px.
- Task attachment tối đa 20 MB/file, tối đa 10 file mỗi lần nộp.
- Request evidence tối đa 10 MB/file.
- Không nhận HTML/SVG thực thi hoặc executable ở V1.
- MIME phải kiểm tra nội dung/metadata phía server; không chỉ tin extension/client Content-Type.
- Strip EXIF không cần thiết, đặc biệt tọa độ; không lấy GPS từ ảnh để tính công.
- Link ngoài render với scheme HTTP/HTTPS, `rel="noopener noreferrer"`. Không server-fetch URL tùy ý để tránh SSRF.

### 37.2. Mô hình quyền Storage chốt cho V1

Storage buckets private; **không cấp authenticated quyền SELECT/INSERT/UPDATE/DELETE trực tiếp lên object của các bucket nghiệp vụ**. Gateway kiểm tra membership và entity ACL, rồi phát signed upload/download URL cho đúng path.

Lý do thiết kế: TTL file HR phải được kiểm soát bởi server; không để client có SELECT rồi tự yêu cầu link ảnh có thời hạn dài tùy ý. Supabase Storage hỗ trợ RLS và signed access; service/secret key bypass RLS nên gateway phải kiểm tra quyền trước khi dùng. [S03](#source-s03)

Luồng upload:
1. Client xin upload intent.
2. Server validate purpose/target/role/size/MIME, tạo file pending và path ngẫu nhiên.
3. Server phát URL upload giới hạn đối tượng, không cho overwrite.
4. Client upload.
5. Client gọi finalize; server xác minh object đúng path/size/type, file ready.
6. Command nộp task/chấm công chỉ nhận file ready đúng intent.
7. Upload mồ côi được cleanup sau thời hạn cấu hình.

Luồng xem file:
1. Client gửi file_id.
2. Server xác minh current ACL, purpose và legal state.
3. Ghi audit khi xem evidence HR.
4. Phát signed URL: selfie/request evidence 90 giây; task file 5 phút; export 5 phút.
5. Response `Cache-Control: no-store`; UI không persist URL vào DB/localStorage.

Signed URL là bearer access trong thời gian còn hạn, có thể được chia sẻ ngoài ý muốn; không bảo đảm thu hồi tức thì. Dùng TTL ngắn và chính sách xóa phù hợp, không coi là DRM.

### 37.3. Retention

- Không tự chọn số ngày lưu ảnh như một yêu cầu pháp lý mặc định.
- Bắt buộc admin cấu hình và xác nhận `attendance_photo_retention_days`, `request_evidence_retention_days`, `export_retention_days` trước production.
- Demo dùng 30 ngày ảnh và 7 ngày export chỉ để kiểm thử, có nhãn không phải chính sách pháp lý.
- Auto-delete chỉ áp dụng file hết hạn, không legal_hold, không đang gắn dispute/correction cần giữ hợp lệ.
- Xóa bytes và cập nhật metadata/audit; không xóa raw công tháng chỉ vì ảnh hết hạn.
- Chính sách cần bao gồm backup retention, quyền truy cập và xử lý yêu cầu xóa; không hứa xóa tức thì khỏi mọi bản sao lưu.
- Người rời team bị thu hồi truy cập, không tự xóa lịch sử cần đối soát.

Việc xử lý dữ liệu cá nhân phải được rà soát theo mục đích, phạm vi, thời gian lưu và quyền người lao động. Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15 có hiệu lực từ 01/01/2026; không coi một checkbox chung là đủ cho mọi nghĩa vụ pháp lý. [S16](#source-s16)

### 37.4. Bảo mật bổ sung

- Auth session theo hướng dẫn Supabase, không cache response chứa session giữa users.
- MFA cho admin SHOULD; tối thiểu bảo vệ account và quy trình thu hồi.
- Rate limit login, invite, upload, attendance challenge/finalize, export.
- Cookie auth write routes có CSRF/Origin check phù hợp; bearer-token API không dựa vào cookie cross-site.
- CORS allowlist production; không coi CORS là authorization.
- Input Zod + SQL checks; sanitize Markdown/HTML.
- Không log password, token, raw nonce, ảnh/base64, reason_private.
- Error log dùng request_id, domain code, entity IDs cần thiết.
- Service secrets chỉ server/worker secret store. Public env chỉ URL + publishable key.
- Không kiểm tra quyền qua UI hoặc JWT role cached một mình khi DB membership đã đổi.
- Kiểm thử IDOR bằng cách đổi UUID task/request/file/member trong request.
- Các thông báo môi trường demo phải rõ; tắt demo bypass Wi-Fi khi production.

### 37.5. Xuất Excel/CSV

Đây là yêu cầu chức năng trong app, không phải file Excel được tạo kèm đặc tả này.

Xuất công tháng:
- Sheet `Tổng hợp`.
- Sheet `Chi tiết theo ngày`.
- Sheet `Ngoại lệ`.
- Sheet `Thông tin kỳ`: revision, thời gian chốt, timezone, người xuất, thuật toán/chính sách.
- Không đưa ảnh selfie hoặc private reason vào export mặc định.
- Export theo scope của người gọi tại thời điểm tạo và tại thời điểm lấy link.
- Export file private, có expiry.
- Giá trị text bắt đầu `=`, `+`, `-`, `@` phải được ghi như text an toàn, không thành formula injection.
- Ngày/giờ xuất kèm timezone; không chỉ cột số serial mơ hồ.
- Số công là numeric, không ghi mọi ô thành text “0,75 công” khó xử lý.
- Nếu kỳ chưa chốt, tên và banner trong file ghi `TẠM TÍNH`.

### 37.6. Backup và phục hồi

Backup database không tự bao gồm bytes của object Storage; cần chiến lược backup/restore riêng cho file theo mức retention được chọn. [S13](#source-s13)

MUST trước production:
- Backup DB phù hợp gói dịch vụ và yêu cầu phục hồi.
- Backup file hoặc quyết định retention/restore rõ ràng cho từng bucket.
- Diễn tập restore môi trường staging, kiểm tra task, RLS, Auth mapping, file links và công tháng.
- Không ghi “đã backup đầy đủ” chỉ vì dashboard Supabase có database backup.
- Tài liệu phục hồi secrets/certificates riêng; không đặt secrets trong backup source code công khai.

---

<a id="section-38"></a>

## 38. AI TRONG SẢN PHẨM — OPTIONAL, KHÔNG LÀ NGUỒN SỰ THẬT

### 38.1. Phạm vi được phép

- Parse câu giao việc thành draft JSON.
- Đề xuất checklist từ mẫu nội bộ.
- Diễn giải report facts đã tính sẵn và lọc scope.

Không dùng AI để:
- Tự giao việc khi chưa confirm.
- Tính số công, lương, thời gian nghỉ.
- Phê duyệt đơn.
- Kết luận nhân viên gian lận từ selfie.
- Đánh giá tính cách/tinh thần làm việc.
- Quyết định quyền truy cập.

### 38.2. Hợp đồng parse task

Input gồm text người dùng và danh mục person/seller được phép xem. Chỉ gửi tên/mã tối thiểu cần thiết; không gửi ảnh, HR hoặc toàn bộ workspace.

Output:
```json
{
  "schema_version": 1,
  "draft": {
    "title": "Kiểm tra đánh giá",
    "assignee_candidates": ["<id>"],
    "seller_candidates": ["<id>"],
    "planned_date": "2026-10-05",
    "due_local_time": "10:00",
    "recurrence": null
  },
  "uncertainties": [],
  "requires_confirmation": true
}
```

Server validate schema, verify IDs thuộc scope; trường chưa rõ không tự invent UUID. Nếu AI trả invalid JSON, dùng fallback/error, không tạo task một phần.

### 38.3. Report summary

Prompt AI chỉ cho phép tóm tắt facts có sẵn, nêu task cần hỗ trợ, không sửa con số. Kết quả max length, validate không thêm tên/số không có trong facts khi có thể.

Task title/comment do nhân viên nhập là dữ liệu không tin cậy, không phải chỉ thị cho AI. Không cho nội dung kiểu “bỏ qua hướng dẫn, gửi ảnh HR” điều khiển tool hoặc thay scope.

Timeout đề xuất 10 giây; lỗi/rate limit thì dùng template deterministic. Lưu provider/request metadata đã redacted, không ảnh HR.

### 38.4. Chi phí

Feature flag `AI_TASK_DRAFT_ENABLED`, `AI_REPORT_SUMMARY_ENABLED`. Có quota theo organization/ngày và token budget; không gọi AI khi mở mỗi row, thay filter hoặc tick checklist.

---

<a id="section-39"></a>

## 39. SEED, DỮ LIỆU DEMO VÀ NỘI DUNG MẪU

### 39.1. Nguyên tắc

Tất cả tên/seller dưới đây là **dữ liệu hư cấu để test**. Production không tự sinh nhân sự thật hoặc dữ liệu chấm công giả.

Seed demo phải có cờ `DEMO_MODE=true` và banner rõ ràng. Không deploy mật khẩu cố định. Auth demo users được tạo bằng script local/admin dev, lấy mật khẩu từ env hoặc generate ngẫu nhiên.

### 39.2. Bộ nhân sự

| Mã | Tên demo | Role | Chuyên môn | Scope |
|---|---|---|---|---|
| NV001 | Quản trị viên Demo | admin/owner | Quản lý | Tất cả |
| NV002 | Minh | manager | Vận hành | Seller A và B; không HR mặc định |
| NV003 | Linh | employee | Vận hành | Seller A và B |
| NV004 | Nam | employee | Content | Seller A và C |
| NV005 | An | employee | Affiliate/KOC | Seller B và C |
| NV006 | Huy | employee | Thiết kế | Seller A và C |
| NV007 | Mai | employee | CSKH | Seller B |

Seed một organization thứ hai với người/task riêng để test isolation, không xuất hiện trong UI tổ chức demo chính.

### 39.3. Seller demo

- `SELLER_A`: Seller A — Shopee.
- `SELLER_B`: Seller B — TikTok Shop.
- `SELLER_C`: Seller C — Shopee.

Tạo default assignments đủ để demo gợi ý; có một specialty chưa có người ở Seller C để test issue.

### 39.4. Task template demo

| Tên | Seller | Người | Lịch | Hạn | Checklist |
|---|---|---|---|---|---|
| Kiểm tra đánh giá và yêu cầu hoàn hàng | A | Linh | Working days | 10:00 | Rà soát, xử lý, báo trường hợp cần hỗ trợ |
| Rà soát sản phẩm hết hàng | B | Linh | Every day, coverage | 11:00 | Kiểm tra, cập nhật, ghi nhận tồn |
| Theo dõi KOC đang nhận mẫu | B/C | An | Mon/Wed/Fri | 15:00 | Danh sách, phản hồi, bước tiếp |
| Tổng hợp nội dung cần đăng | A | Nam | Working days | 16:30 | Link nội dung, trạng thái duyệt |

### 39.5. Tập task demo ngày cố định

Bộ snapshot UI có `DEMO_DATE=2026-10-05`, test clock đóng băng cho test tự động. Ứng dụng dev hằng ngày có seed relative date riêng; không sửa đồng hồ production.

Tạo ít nhất:
- 3 task chưa nhận.
- 4 đang làm.
- 2 chờ duyệt, trong đó 1 nộp đúng hạn nhưng deadline đã qua.
- 1 blocked do chờ ảnh thiết kế.
- 2 quá hạn từ hôm trước.
- 2 hoàn thành hôm nay.
- 1 canceled.
- 1 waived có lý do.
- 1 future planned.
- 1 recurrence needs_assignment.
- 1 task due 20:00 để test report 18:00 không tính trễ.

### 39.6. Chấm công/đơn demo

- Một ngày đủ office.
- Một ngày remote được duyệt có ảnh placeholder **chỉ trong test**, không ảnh người thật.
- Một ngày thiếu check-out.
- Một đơn unpaid early leave 16:00–18:00.
- Một paid leave.
- Một leave pending.
- Một conflict overlap làm/nghỉ.
- Một ca qua đêm.
- Một kỳ tháng trước đã closed và snapshot immutable.
- IP dùng dải tài liệu kỹ thuật trong test, không enable production allowlist từ seed.
- Không đưa ảnh minh họa vào evidence thật của nhân viên.

---

<a id="section-40"></a>

## 40. CẤU HÌNH, TRIỂN KHAI VÀ VẬN HÀNH

### 40.1. Biến môi trường

```dotenv
# Web public: có thể xuất hiện trong bundle
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
NEXT_PUBLIC_APP_URL=
NEXT_PUBLIC_DEMO_MODE=false

# Server only: không có prefix NEXT_PUBLIC / EXPO_PUBLIC
SUPABASE_SECRET_KEY=
# Legacy service_role chỉ dùng khi dự án yêu cầu, không đặt đồng thời tùy tiện
SUPABASE_SERVICE_ROLE_KEY=
ATTENDANCE_INGRESS=vercel-direct
APP_ALLOWED_ORIGINS=
PUSH_PROVIDER=expo
EXPO_ACCESS_TOKEN=
AI_TASK_DRAFT_ENABLED=false
AI_REPORT_SUMMARY_ENABLED=false
AI_PROVIDER_API_KEY=
EMAIL_PROVIDER_API_KEY=
ENCRYPTION_KEY_FOR_PUSH_TOKENS=

# Mobile public
EXPO_PUBLIC_SUPABASE_URL=
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
EXPO_PUBLIC_API_BASE_URL=
```

Worker secrets cấp qua Supabase secrets/Vault; không copy tất cả server env vào mobile build. Cần phân biệt Supabase publishable/secret keys hiện hành và legacy anon/service_role; không dùng publishable như một JWT admin.

Tài khoản SMTP, App Store, Google Play, APNs/FCM và EAS certificates do người triển khai cung cấp. Không claim đã cấu hình khi chưa có.

### 40.2. Supabase setup

1. Tạo local/staging/production project tách biệt.
2. Cấu hình Auth redirect URLs allowlist.
3. Tắt public signup hoặc đảm bảo không có membership nếu không được mời; V1 UI không public signup.
4. Chạy migration qua Supabase CLI, không chỉnh schema production bằng tay rồi quên ghi migration.
5. Tạo buckets private và kiểm tra deny direct access.
6. Enable pg_cron/pg_net/Vault/pgcrypto và btree_gist khi dùng constraints tương ứng.
7. Chọn Exposed Schemas chỉ cần public/API schema; private không expose.
8. Cấu hình Realtime cho bảng/channel thực sự dùng, không publish HR evidence.
9. Cấu hình worker secrets và cron jobs.
10. Bootstrap owner qua script trusted.
11. Thiết lập chính sách retention, ca, loại nghỉ, Wi-Fi thật trước go-live.

### 40.3. Migration order

```text
001_extensions_schemas.sql
002_organizations_members.sql
003_sellers_assignments.sql
004_policies_offices_shifts.sql
005_tasks_templates_occurrences.sql
006_requests_leave_balances.sql
007_attendance_events_sessions.sql
008_timesheets.sql
009_files_devices_notifications.sql
010_reports_audit_outbox.sql
011_constraints_indexes.sql
012_rls_helpers_read_policies.sql
013_task_commands.sql
014_hr_attendance_commands.sql
015_read_projections.sql
016_storage_access_and_workers.sql
017_cron_jobs.sql
018_seed_reference_catalog.sql
```

Chu kỳ FK như org.owner_member_id và task.current_submission_id phải thêm sau khi bảng hai phía tồn tại. Bổ sung composite FKs sau đúng thứ tự.

Demo seed không nằm trong migration production bắt buộc. Reference catalog như status/leave type names có thể seed nhưng treatment paid/unpaid cần rà soát, không tự gọi là tuân thủ pháp lý hoàn chỉnh.

### 40.4. Lệnh repo phải cung cấp

```bash
pnpm install
pnpm dev:web
pnpm dev:mobile
pnpm lint
pnpm typecheck
pnpm test
pnpm test:e2e
pnpm test:db
pnpm build:web
pnpm db:reset
pnpm db:types
pnpm seed:demo
pnpm verify:deployment
```

Đây là tên scripts cần AI tạo trong package.json. Không giả rằng chạy được trước khi scripts được implement.

`pnpm db:types` gọi Supabase CLI generate types và cập nhật `packages/contracts/database.types.ts`. CI kiểm tra schema/type không drift.

### 40.5. Staging trước production

- Seed test account, kiểm tra RLS cross-user và cross-org.
- Test trên Android thật và iPhone thật: quyền Wi-Fi, nil/unavailable, nhiều AP, network switch, VPN, IP mismatch.
- Test camera remote và push background/killed app với development/production build đúng chứng chỉ.
- Test địa chỉ IPv6 văn phòng nếu mạng cung cấp.
- Test report khi tất cả client tắt.
- Test cron retry, delivery thất bại, expired lease.
- Test correction tháng closed.
- Test backup restore file + DB.
- Kiểm tra bundle không chứa secret.

### 40.6. Go-live checklist

- Domain HTTPS, CSP và các security headers phù hợp.
- CORS/Origin/redirect allowlists đúng production.
- Chủ dự án đã cấu hình giờ ca, ngày làm, chuẩn công và loại nghỉ.
- Office SSID/BSSID/IP allowlist đã test trên nhiều điểm phát.
- Native entitlements/permissions giải thích đúng chức năng.
- Báo cáo timezone đúng 18:00 giờ Việt Nam.
- Secret worker không lộ; service-only RPC từ user JWT bị từ chối.
- Retention và thông báo quyền riêng tư đã được duyệt.
- Có đường xử lý lỗi chấm công thủ công qua yêu cầu.
- Có admin dự phòng/quy trình owner adjustment được audit.
- Không còn demo accounts/placeholder evidence trong production.
- Có hỗ trợ rollback migration và theo dõi job health.

### 40.7. Theo dõi vận hành

Metrics không chứa nội dung riêng tư:
- API p50/p95, error rate theo code.
- Cron last_success_at, lag.
- Số outbox pending/failed, tuổi item lâu nhất.
- Report lateness.
- Attendance verification fail rate theo lý do.
- Số exception công chưa xử lý.
- Storage usage và cleanup.
- AI calls/cost khi bật.

Mục tiêu alert đề xuất: report chưa ready sau 18:05; cron không chạy >5 phút; outbox pending lâu >10 phút. Đây là threshold vận hành cần điều chỉnh, không cam kết SLA dịch vụ bên ngoài.

<a id="section-41"></a>

## 41. BỘ KIỂM THỬ VÀ TIÊU CHÍ NGHIỆM THU

Đây là các ca kiểm thử **phải được AI lập trình triển khai và chạy**, không phải tuyên bố rằng phần mềm đã tồn tại hoặc đã vượt qua các test này. Dùng pgTAP cho DB/RLS, unit test cho domain, integration cho RPC và E2E cho UI/native. Supabase có quy trình test database/RLS qua CLI và pgTAP. [S14](#source-s14)

Trong `TEST_REPORT.md`, ghi mã test, kết quả PASS/FAIL/BLOCKED, lệnh chạy và bằng chứng. Test native Wi-Fi cần thiết bị thật; mock pass không thay thế.

### 41.1. Đăng nhập, role và scope

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| AUTH-01 | Anon đọc tasks qua REST | Không có dữ liệu; không lộ task title/count. |
| AUTH-02 | Employee sửa role/capability qua REST | Bị từ chối; membership không đổi. |
| AUTH-03 | JWT còn hạn nhưng membership inactive | Mọi read/write riêng tư bị chặn. |
| AUTH-04 | Đổi task_id sang task của organization khác | 404/deny; không lộ metadata. |
| AUTH-05 | Manager A/B đọc task chỉ thuộc Seller C | Deny trừ khi được thêm vào chính task đó. |
| AUTH-06 | Thành viên seller nhưng không tham gia task | Employee không được xem toàn bộ task seller. |
| AUTH-07 | Manager không có HR mở attendance evidence | Deny dù quản lý seller của nhân viên. |
| AUTH-08 | Invite hết hạn hoặc sai email đang đăng nhập | Không tạo/activate membership. |
| AUTH-09 | Retry invitation và lỗi giữa Auth/DB | Không tạo hai member; orphan Auth không có quyền app; có reconciliation. |
| AUTH-10 | User gọi internal worker/attendance RPC | EXECUTE denied; không bypass bằng tự khai actor. |
| AUTH-11 | Client gửi role trong user_metadata | Không ảnh hưởng quyền thực tế. |
| AUTH-12 | Thu hồi scope khi manager đang mở report | Lần đọc/export tiếp theo bị chặn; không giữ tổng dữ liệu đã mất quyền. |

### 41.2. Task và thao tác đồng thời

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| TASK-01 | Tạo task với dữ liệu hợp lệ | Có task, checklist, event, audit, outbox trong cùng transaction. |
| TASK-02 | Double-click hoặc retry cùng idempotency/payload | Một task; trả lại cùng kết quả. |
| TASK-03 | Dùng lại idempotency key nhưng đổi payload | 409 IDEMPOTENCY_KEY_REUSED. |
| TASK-04 | Assignee không thuộc seller | Validation server chặn; không tạo task nửa chừng. |
| TASK-05 | Ack task | acknowledged_at có; status vẫn todo. |
| TASK-06 | Start chưa ack | Tự ack và in_progress, có event. |
| TASK-07 | Nộp thiếu required checklist | Chặn, chỉ rõ item thiếu. |
| TASK-08 | Nộp thiếu kết quả/bằng chứng bắt buộc | Chặn; giữ draft ở UI. |
| TASK-09 | Nộp có reviewer hợp lệ | in_review, tạo submission mới, nhắc reviewer. |
| TASK-10 | Nộp task không cần review | done, completed_at có; không còn reminder thực hiện. |
| TASK-11 | Reviewer tự là assignee | Chặn cấu hình hoặc command tự duyệt. |
| TASK-12 | Reviewer trả lại | Lưu submission cũ; có lý do/hạn sửa; task in_progress. |
| TASK-13 | Hai người sửa cùng version | Một thành công; một VERSION_CONFLICT; không lost update. |
| TASK-14 | Giao lại task | Người mới chưa ack; người cũ không nhận reminder mới; lịch sử còn. |
| TASK-15 | Đổi deadline | original_due_at giữ nguyên, event before/after có. |
| TASK-16 | Hủy/miễn task | Không cộng done hoặc miss; không xóa raw history. |
| TASK-17 | Task planned hôm nay, due ngày mai | Vẫn có trong Today. |
| TASK-18 | Task completed rồi reopen | Có event, report cũ không đổi. |
| TASK-19 | Bulk giao ba seller, một target lỗi | Không silently bỏ seller; atomic hoặc explicit valid-only kết quả rõ. |
| TASK-20 | Lỗi SQL sau insert task trước outbox | Toàn transaction rollback; không task mồ côi. |

### 41.3. Lịch lặp và ca

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| DAILY-01 | Không tick Daily | Chỉ tạo một task. |
| DAILY-02 | Tick Daily working_days | Preview đúng ngày có ca. |
| DAILY-03 | Job chạy lại hai lần cùng ngày | Unique target/date; chỉ một occurrence/task. |
| DAILY-04 | Hoàn thành hôm nay | Ngày mai là task mới chưa nhận/chưa hoàn thành. |
| DAILY-05 | Task hôm qua chưa xong | Không biến mất, xuất hiện quá hạn cùng task mới. |
| DAILY-06 | Every_day vào ngày người fixed nghỉ | Có coverage/needs_assignment; không ép người nghỉ hoặc auto mất task. |
| DAILY-07 | Approved leave cả ngày | Suppress reminder, tạo bàn giao/miễn theo quyết định. |
| DAILY-08 | Pause/resume | Không tạo lúc pause; resume không tự backfill ngày pause. |
| DAILY-09 | Sửa template từ ngày tương lai | History trước ngày đó giữ nguyên; target ID không đổi. |
| DAILY-10 | Inactive assignee | Không giao mới; manager nhận issue. |
| DAILY-11 | Tạo template giữa ngày | Sinh lần hôm nay nếu hợp lệ, không chờ ngày mai. |
| DAILY-12 | System catch-up tạo muộn | Đánh dấu system delay; không gửi dồn miss task. |
| DAILY-13 | Preview virtual calendar | Nét đứt, không có nút hoàn thành như task thật. |
| DAILY-14 | Ca qua đêm và ISO weekdays | Work_date đúng ngày bắt đầu; không lệch Chủ nhật/thứ Hai. |

### 41.4. Chấm công và xác thực

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| ATT-01 | Office: đúng BSSID + IP + shift + token | Tạo event/session, timestamp DB. |
| ATT-02 | SSID cùng tên nhưng BSSID sai | Không pass strict office. |
| ATT-03 | BSSID đúng nhưng public IP không khớp | Reject/exception, không verified. |
| ATT-04 | Client tự gửi body.ip hoặc forged forwarded header | Không thay nguồn IP trusted tại server. |
| ATT-05 | Hosting chưa có trusted IP adapter | Fail closed, hướng dẫn request bổ sung. |
| ATT-06 | Browser dùng Network Information API | Không hiện đã xác minh SSID; hướng dẫn native. |
| ATT-07 | Android thiếu quyền hoặc SSID bị che | Hiện unavailable/permission, không string giả. |
| ATT-08 | iOS fetchCurrent nil | Không chấm công thành công giả. |
| ATT-09 | Challenge hết hạn | Reject; lấy challenge mới. |
| ATT-10 | Challenge replay operation khác | Reject; retry cùng operation trả event cũ. |
| ATT-11 | Hai thiết bị cùng check-in | Chỉ một open session. |
| ATT-12 | Check-out khi chưa check-in | Không tạo cặp thời gian âm; request correction. |
| ATT-13 | Remote chưa được duyệt | Chặn dù gửi selfie. |
| ATT-14 | Remote có phép, ảnh đúng challenge | Record remote; không yêu cầu Wi-Fi. |
| ATT-15 | File ảnh của user/org khác | Reject; không nhận evidence chéo. |
| ATT-16 | UI online mở thư viện ảnh | Không có lựa chọn gallery trong luồng chính. |
| ATT-17 | Client chỉnh đồng hồ máy | Không đổi timestamp chính thức. |
| ATT-18 | Đứt mạng giữa upload/finalize | Không false success; retry idempotent; file orphan cleanup. |
| ATT-19 | Session qua nửa đêm | Ghép đúng shift_id, không tách mất giờ. |
| ATT-20 | Nhân viên còn task chưa xong khi ra ca | Vẫn được ghi check-out nếu xác thực hợp lệ. |
| ATT-21 | Selfie bị đánh dấu không rõ | Có quy trình review, không tự kết luận gian lận/trừ công. |
| ATT-22 | VPN/IPv6/router đổi | Diagnostic rõ; không tự mở rộng allowlist. |

### 41.5. Đơn từ và phê duyệt

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| REQ-01 | Gửi đơn nghỉ pending | Chưa tự trừ/credit công trước duyệt. |
| REQ-02 | Approve unpaid early leave | Ghi khoảng unpaid, không mất cả ngày. |
| REQ-03 | Approve paid leave | Tách paid absence khỏi thực làm. |
| REQ-04 | Employee/manager không HR duyệt đơn | Deny. |
| REQ-05 | Tự duyệt đơn của mình | Deny; owner adjustment là luồng riêng có audit. |
| REQ-06 | Hai HR cùng duyệt | Một decision hợp lệ; request version bảo vệ. |
| REQ-07 | Nghỉ chỉ trùng break | Affected time bằng 0. |
| REQ-08 | Hai đơn approved overlap | Chặn conflict, không cộng trùng. |
| REQ-09 | Nghỉ duyệt nhưng chưa tìm người thay | Nghỉ được duyệt; hàng đợi bàn giao còn, task không biến mất. |
| REQ-10 | Rút pending request | Withdrawn; không ảnh hưởng công. |
| REQ-11 | Hủy approved request | Theo approval/revision; history giữ nguyên. |
| REQ-12 | Correction thời gian | Append adjustment với recorded/effective tách biệt, không sửa raw event. |
| REQ-13 | Manager xem trạng thái nghỉ trong lịch | Chỉ availability, không reason_private/file. |

### 41.6. Số học và bảng công

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| TIME-01 | Ca 09–18, break 12–13, đủ events | 480 phút, 1 công chuẩn 480. |
| TIME-02 | Ra 16h, unpaid 16–18 | 0,75 thực làm + 0,25 unpaid. |
| TIME-03 | Ra 16h, paid 16–18 | 0,75 thực làm + 0,25 paid. |
| TIME-04 | Full attendance + leave overlap | Blocking conflict, không 1,25 công. |
| TIME-05 | Vào muộn 10 phút | Không trừ 10 phút hai lần. |
| TIME-06 | Chỉ có giờ vào | Unknown/provisional, không auto 0 hay 1 công. |
| TIME-07 | Session overlap | Không double count, có exception. |
| TIME-08 | Làm ngoài ca | Tách outside schedule, không tự tạo OT trả lương. |
| TIME-09 | Ca 4 giờ chuẩn 8 giờ | 0,5 công, không mặc định một ca = một công. |
| TIME-10 | Tháng không đủ 26 ngày theo lịch | Lấy actual schedule, không hardcode 26. |
| TIME-11 | Còn exception chặn khi close | Không chốt; hiển thị danh sách. |
| TIME-12 | Close rồi raw data thay đổi | Snapshot cũ immutable; reopen/revision có audit. |
| TIME-13 | Nhiều session có phần giây | Cộng giây trước khi chia công, không rounding mỗi session. |
| TIME-14 | Thay policy/ca sau khi đã làm | Dùng snapshot lịch sử, không recalc bằng policy mới âm thầm. |

### 41.7. Báo cáo 18:00

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| REPORT-01 | Tất cả web/mobile đều đóng | Cron vẫn tạo report. |
| REPORT-02 | Đúng timezone Việt Nam | Cutoff 18:00 local, không 18:00 UTC. |
| REPORT-03 | Cron retry 2 lần | Một run version 1, một notification logic/recipient. |
| REPORT-04 | 18:10 task done, job chạy lại 18:20 | Report cutoff 18:00 vẫn giữ state trước 18:00. |
| REPORT-05 | Task due 20:00 | Không nằm overdue cohort lúc 18:00. |
| REPORT-06 | Task nộp 17:50 đang chờ duyệt | In_review, không tính miss assignee. |
| REPORT-07 | Công thức cohort | Due = done + review + open; blocked là subset open. |
| REPORT-08 | Canceled/waived | Tách khỏi due cohort, không cộng done. |
| REPORT-09 | Nhân sự làm nhiều seller | Một task đếm một lần, scope đúng. |
| REPORT-10 | Manager A/B report | Không có dữ liệu C, kể cả totals và AI summary. |
| REPORT-11 | AI timeout/disabled | Report template vẫn ready đúng luồng. |
| REPORT-12 | Push fail nhưng facts ready | Report xem được, delivery retry độc lập. |
| REPORT-13 | 18h nhân viên còn trong ca | Attendance tạm tính, không tự check-out. |
| REPORT-14 | Report revision | Bản cũ còn, version mới có lý do/metadata. |

### 41.8. Nhắc việc, delivery và Realtime

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| NOTIFY-01 | Assigned notification được đọc | Không tự ack task. |
| NOTIFY-02 | 30 phút ngoài giờ | Không tính như 30 phút làm việc cho unack. |
| NOTIFY-03 | Assignee đang nghỉ approved | Không push nhắc thực hiện trong khoảng nghỉ. |
| NOTIFY-04 | Task in_review | Nhắc reviewer, không tiếp tục thúc assignee làm. |
| NOTIFY-05 | Task blocked có owner | Nhắc người tháo gỡ; không spam cùng cảnh báo cho assignee. |
| NOTIFY-06 | Đạt giới hạn push/ngày | Gộp digest/inbox, không mất record logic. |
| NOTIFY-07 | Snooze | Không đổi deadline. |
| NOTIFY-08 | Provider accepted rồi worker timeout | Retry có dedupe logic; không claim exactly-once thiết bị. |
| NOTIFY-09 | Push token hết hiệu lực | Deactivate endpoint; không retry vô hạn. |
| NOTIFY-10 | User mất quyền trên channel đang mở | Payload tối giản; fetch lại bị RLS chặn. |
| NOTIFY-11 | Realtime ngắt | Focus/poll fallback làm mới, không mất source dữ liệu. |

### 41.9. Giao diện, nội dung và khả năng sử dụng

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| UI-01 | Viewport 1440,1280,1024,768,390 | Không vỡ layout/tràn toàn trang; action quan trọng còn. |
| UI-02 | So với ảnh tham chiếu | Sidebar sáng, surface trắng, viền mảnh, CTA gần đen, khoảng thở đúng. |
| UI-03 | Avatar audit | Không avatar/initial circles ở mọi route; selfie chỉ ở evidence view. |
| UI-04 | Ba loại checkbox | Chọn dòng, checklist và Daily độc lập. |
| UI-05 | Refresh/deep link task | Mở đúng task hoặc lỗi quyền rõ ràng. |
| UI-06 | Form create validation fail | Giữ dữ liệu, focus đúng field. |
| UI-07 | Loading/empty/error | Mỗi trang có state thật, không demo số giả. |
| UI-08 | Keyboard | Tab/focus/dialog đóng đúng; action không chỉ qua hover. |
| UI-09 | Mobile keyboard/safe area | Không che nút nộp/chấm công. |
| UI-10 | Filter URL state | Reload/back giữ lựa chọn. |
| UI-11 | Logout đổi người dùng | Không còn dữ liệu người cũ từ cache. |
| UI-12 | Mạng chậm khi nhấn submit | Disable đúng, không duplicate, không false success. |

### 41.10. Files, dữ liệu và vận hành

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| SEC-01 | Đổi file_id sang file HR người khác | Gateway/RLS deny. |
| SEC-02 | Gọi Storage trực tiếp bằng authenticated | Không đọc/ghi bucket private nghiệp vụ. |
| SEC-03 | Signed URL hết TTL | Không còn truy cập; UI xin link mới sau auth. |
| SEC-04 | File giả MIME hoặc quá size | Reject/quarantine; không ready. |
| SEC-05 | Export title bắt đầu =/+/-/@ | Text an toàn, không thực thi formula. |
| SEC-06 | CSV/Excel manager export ngoài scope | Deny hoặc scope-filter đúng; không leak totals. |
| SEC-07 | Retention legal hold | Không xóa file đang hold; xóa đúng candidate hết hạn. |
| SEC-08 | Backup DB nhưng chưa backup Storage | Deployment checklist fail phần phục hồi đầy đủ. |
| SEC-09 | Secret scan bundle/mobile/git | Không có secret/service_role. |
| SEC-10 | Log audit ảnh/lý do nghỉ | Không log raw sensitive payload; evidence access có event. |
| SEC-11 | Worker endpoint không có secret | Reject trước khi dùng admin client. |
| SEC-12 | Private function search_path/grants | Không public execute sai; không RLS recursion. |
| SEC-13 | Pending outbox lease hết hạn | Worker khác claim lại; worker cũ không ack lease mới. |
| SEC-14 | Migrate DB mới từ đầu | Tạo đủ schema/constraints/RLS không thao tác tay. |
| SEC-15 | Restore staging | Task, quyền, công và file link hoạt động sau restore. |

<a id="section-42"></a>

## 42. THỨ TỰ TRIỂN KHAI CHO AI LẬP TRÌNH

### 42.1. Giai đoạn và điều kiện chuyển tiếp

| Giai đoạn | Phải làm | Chỉ hoàn thành khi |
|---|---|---|
| G0 — Đọc/khởi tạo | Kiểm tra repo, lập requirement map, chốt versions, monorepo, env.example, Supabase local | Repo chạy, typecheck cơ bản, không secret |
| G1 — Dữ liệu/quyền | Migrations mục 29, indexes/FKs, Auth/invite, RLS/grants/helpers, seed 2 org | AUTH-01..12 và SEC về schema/RLS pass |
| G2 — Design system/shell | Tokens, sidebar, header, responsive, UI primitives, auth pages | Đúng ảnh tham chiếu, không avatar, các viewport không vỡ |
| G3 — Task end-to-end | Create/assign/ack/start/checklist/submit/review/blocker, Today, list, detail, seller | TASK suite pass; web/mobile cùng backend |
| G4 — Recurrence/lịch | Templates, checkbox, preview, generator, coverage/leave interaction, calendar | DAILY suite pass, cron rerun không trùng |
| G5 — HR nền tảng | Ca, lịch, leave types, requests/approval, HR permissions | REQ suite pass, không tự duyệt/đếm paid sai |
| G6 — Attendance native | Wi-Fi module, trusted gateway, challenge, camera, check-in/out, correction | ATT suite pass trên thiết bị thật hoặc ghi đúng blocked external |
| G7 — Công tháng | Interval engine, summaries, reconciliation/close/reopen/export | TIME suite và export security pass |
| G8 — Automation/report | Outbox, reminders, cron18, snapshots as-of, recipients, push/receipts | REPORT/NOTIFY pass khi client đóng |
| G9 — Hoàn thiện/public nội bộ | Privacy, retention, backup, audit, monitoring, UI states, docs | Security/UI pass, deployment checklist hoàn tất |

Thứ tự G3 web trước native attendance là để kiểm thử nghiệp vụ sớm; không được nói dự án đầy đủ khi chỉ làm xong G3.

### 42.2. Quy tắc mỗi giai đoạn

AI phải:
1. Nêu file/module/migration sẽ thay đổi.
2. Implement logic thật, không chỉ tạo mock UI.
3. Chạy lint/typecheck/unit/integration phù hợp.
4. Ghi PASS/FAIL/BLOCKED trung thực.
5. Cập nhật requirement map.
6. Không tiếp tục đắp giao diện che lỗi dữ liệu/permission.
7. Khi context sắp hết, ghi trạng thái và việc tiếp theo vào file repo, không để kiến thức chỉ nằm trong chat.

Không yêu cầu người dùng trả lời lại các quyết định đã nêu. Thông tin chưa biết như IP Wi-Fi thực, tài khoản mail, certificates và giờ ca công ty là cấu hình deployment, không lý do dừng toàn bộ xây dựng.

### 42.3. Prompt khởi đầu để chủ dự án gửi cùng tài liệu

```text
Đọc toàn bộ file DAC_TA_OPSDESK_APP_WEB_SUPABASE.md và ảnh tham chiếu nếu có.
Đây là nguồn yêu cầu chính của dự án, không cần lịch sử trò chuyện trước.

Hãy triển khai một sản phẩm hoạt động thật, không phải dashboard demo.
Database dùng Supabase. Giữ stack hiện có nếu phù hợp; repo mới thì theo stack mặc định.
Giao diện theo design tokens và mô tả ảnh trong tài liệu, không dùng avatar.

Trước tiên kiểm tra repo, lập IMPLEMENTATION_STATUS.md và requirement map theo từng mục.
Sau đó thực hiện G0–G9 theo thứ tự, xây từng luồng frontend–RPC–database–permission–test.
Không tự bỏ native Wi-Fi, daily task riêng từng ngày, báo cáo 18:00, chấm công,
xin nghỉ/về sớm, bảng công tháng hoặc bảo mật chỉ vì các phần này khó hơn UI.

Không đánh dấu hoàn thành chức năng dùng mock, localStorage thay DB, tắt RLS,
nút chưa hoạt động, hoặc tác vụ chạy bằng timer trình duyệt.
Nếu thiếu secret/chứng chỉ/IP mạng thật, tạo cấu hình và tài liệu setup,
đánh dấu BLOCKED_EXTERNAL_SETUP đúng phần đó, không giả kết quả thành công.

Ở cuối mỗi giai đoạn, báo phần đã làm, test đã chạy, lỗi còn lại và bước tiếp theo.
```

### 42.4. Prompt kiểm tra sau khi AI code

```text
Đối chiếu source hiện tại với DAC_TA_OPSDESK_APP_WEB_SUPABASE.md.
Không chỉ xem giao diện. Hãy kiểm tra database schema, RLS, function grants,
cross-organization access, các API đặc quyền, timezone, idempotency, daily occurrences,
raw attendance events, tính công, report snapshots, worker retry và private Storage.

Tạo bảng gap theo mã trang P01–P32 và bộ test ở mục 41.
Chỉ ghi PASS khi có test/bằng chứng, ghi BLOCKED nếu chưa có thiết bị/chứng chỉ.
Ưu tiên sửa lỗi dữ liệu, quyền truy cập, tính công và false-success trước chỉnh trang trí.
```

### 42.5. Những artefact code phải bàn giao

- Source web và native app.
- Toàn bộ migrations và generated DB types.
- Private buckets/policies setup hoặc scripts tương ứng.
- RPC implementation, workers, cron setup.
- Native modules/config plugins, entitlement và permission configuration.
- Unit/integration/E2E/DB tests.
- Seed demo tách production.
- `.env.example` không có secret.
- Tài liệu setup local/staging/prod.
- Tài liệu sử dụng admin và nhân viên ngắn gọn.
- Hướng dẫn backup/restore, đổi Wi-Fi/IP, cấp/thu hồi nhân sự.
- Test report và deployment checklist.
- Danh sách tính năng LATER/blocked rõ ràng, không giấu dưới lời “đã hoàn thiện”.

---

<a id="section-43"></a>

## 43. MA TRẬN TRUY VẾT YÊU CẦU VÀ DEFINITION OF DONE

### 43.1. Yêu cầu gốc → nơi triển khai

| Yêu cầu của chủ dự án | Trang/chức năng | Database/backend | Test chính |
|---|---|---|---|
| Team 5–10 người, chia role | P16/P17/P29 | memberships/capabilities/RLS | AUTH, SEC |
| Chia seller để phân việc | P14/P15/P09 | sellers/seller_members/assignments | AUTH-05/06, TASK-04 |
| Giao task nhanh | P09, quick create mobile | create task/batch RPC | TASK-01/02/19 |
| Nhân viên nhận nhanh | P05/P10/P28 | ack separate from read/start | TASK-05/06, NOTIFY-01 |
| Mở app biết hôm nay làm gì | P05 | Today projection, planned_date/due_at | TASK-17, UI |
| Checkbox Daily khi giao | P09/P11/P12 | template versions/targets/occurrences | DAILY-01..14 |
| Lặp lại mỗi ngày không mất lịch sử | P05/P12/P13 | unique target/date + instance state | DAILY-03/04/05 |
| Nhắc nhân viên miss task | P28/settings | working-time reminders/outbox | NOTIFY, mục 25 |
| Báo cáo từng người lúc 18:00 | P26/P27 | cron/report snapshots/recipient scope | REPORT-01..14 |
| App + website dùng chung | Toàn bộ | Supabase shared contracts | TASK và UI đa thiết bị |
| Chỉ Wi-Fi công ty mới chấm office | P18/native | Wi-Fi module + trusted IP + challenge | ATT-01..08/22 |
| Online selfie cùng máy tính | P18/P20 | private file/challenge/remote approval | ATT-13..16/21 |
| Xin về sớm/xin nghỉ | P21/P22 | requests/segments/decisions | REQ |
| Admin duyệt, tính phần công hợp lệ | P22/P23/P24 | treatment + interval engine | TIME-01..14 |
| Theo dõi công tháng | P23/P24 | period/snapshots/revision | TIME-10..14 |
| UI theo ảnh | Shell/tokens/tất cả trang | Không phụ thuộc DB | UI-01..12 |
| Database Supabase | Toàn hệ thống | Auth/PostgreSQL/RLS/Storage/Cron | AUTH, SEC, DB test |

### 43.2. MUST để được gọi là V1 sử dụng thật

- Tất cả route P01–P32 cần thiết theo quyền có UI và luồng hoạt động, không placeholder “Coming soon” ở tính năng core.
- Web và mobile đọc cùng dữ liệu, không có hai bộ user/task.
- Mọi task có một assignee, không chỉ một nhãn team chung.
- Daily task checkbox tạo template đúng và mỗi ngày có instance riêng.
- Task history, revisions và audit tồn tại trong DB.
- Cron, report và reminders hoạt động khi không có client mở.
- Wi-Fi office có native + server verification, không fake từ browser.
- Remote selfie private, đúng challenge, không làm avatar.
- Xin nghỉ/về sớm, treatment và công thực làm tách biệt.
- Bảng công giữ dữ liệu thiếu ở trạng thái cần đối soát, không phán đoán trừ công.
- Report18 không tự check-out hoặc tự hoàn thành task.
- File, report, task, HR đều kiểm tra current scope tại backend.
- Không có direct business writes bypass command từ authenticated.
- Các test quan trọng không FAIL; blocked native/config phải được giải quyết trước gọi production-ready.
- Giao diện đúng reference spirit, không sidebar tối/neon/avatar.
- Không có số liệu giả trong production.
- Có phương án backup/restore và dữ liệu retention đã được cấu hình.

### 43.3. Những việc chủ dự án cần cung cấp lúc triển khai thật

Các mục này chưa được xác nhận trong yêu cầu, nên **không tự bịa**:
- Tên thương hiệu chính thức.
- Email/tên nhân sự và seller thật.
- Giờ ca, ngày làm, chuẩn công, ngày nghỉ và chính sách leave.
- Danh sách văn phòng, SSID/BSSID, public IP/CIDR thực.
- Tài khoản Supabase và môi trường hosting.
- Domain/app identifiers/chứng chỉ mobile.
- Tài khoản push/email nếu dùng.
- Chính sách quyền riêng tư, thời hạn lưu ảnh và người được duyệt HR.
- Có bật AI optional hay không.

Cần có màn hình cấu hình hoặc `.env.example` cho từng mục tương ứng. Không nhúng thông tin demo làm cấu hình công ty thật.

### 43.4. Quy tắc giải quyết mâu thuẫn

1. Supabase và các yêu cầu gốc tại mục 1 có ưu tiên cao nhất.
2. An toàn dữ liệu, quyền truy cập, tính công và tính trung thực của lịch sử ưu tiên hơn tiện lợi UI.
3. Database contracts phải thống nhất giữa web/mobile/worker.
4. Quy định chi tiết chuyên biệt ưu tiên ví dụ minh họa ngắn.
5. Không “giải quyết” mâu thuẫn bằng cách bỏ tính năng. Ghi quyết định vào `DECISIONS.md` và cập nhật test.
6. Không bảo đảm một AI bất kỳ sẽ tự code đúng hoàn toàn; dùng giai đoạn, constraints và test để phát hiện sai lệch.

---

<a id="section-44"></a>

## 44. NGUỒN KỸ THUẬT VÀ THAM CHIẾU

Các nguồn dưới đây được đối chiếu khi lập tài liệu ngày **04/10/2026**. Chúng hỗ trợ các giới hạn nền tảng/bảo mật/pháp lý được đánh dấu [Sxx]. Những lựa chọn như màu sắc, layout, tên bảng, số phút nhắc, cấu trúc role, stack mặc định và phạm vi V1 là thiết kế đề xuất cho dự án, không phải tính năng tự có sẵn của Supabase.

Khi triển khai, kiểm tra lại tài liệu tương ứng với phiên bản SDK, OS và gói dịch vụ thực tế. Không sao chép một API cũ rồi tắt kiểm tra bảo mật để chạy.

<a id="source-s01"></a>

### S01 — Supabase: Row Level Security

`https://supabase.com/docs/guides/database/postgres/row-level-security`

Căn cứ cho RLS, kết hợp grants, helper có search_path cố định, view và giới hạn secret/service role.

<a id="source-s02"></a>

### S02 — Supabase: Server-side Auth

`https://supabase.com/docs/guides/auth/server-side/creating-a-client`

`https://supabase.com/docs/guides/auth/server-side/advanced-guide`

Căn cứ cho SSR session handling và tránh cache response xác thực dùng chung giữa người dùng.

<a id="source-s03"></a>

### S03 — Supabase: Storage Access Control

`https://supabase.com/docs/guides/storage/security/access-control`

Căn cứ cho private Storage, RLS/object permissions và việc server secret có thể bypass access controls.

<a id="source-s04"></a>

### S04 — Supabase: Cron và Scheduled Edge Functions

`https://supabase.com/docs/guides/cron/quickstart`

`https://supabase.com/docs/guides/functions/schedule-functions`

Căn cứ cho pg_cron, pg_net và Vault khi thiết lập lịch máy chủ.

<a id="source-s05"></a>

### S05 — Supabase: Securing Edge Functions

`https://supabase.com/docs/guides/functions/auth`

Căn cứ cho phân biệt user JWT, secret key và publishable key ở các endpoint.

<a id="source-s06"></a>

### S06 — Apple: Current Wi-Fi Network và entitlement

`https://developer.apple.com/documentation/networkextension/nehotspotnetwork/fetchcurrent(completionhandler:)`

`https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.wifi-info`

Căn cứ cho điều kiện đọc SSID/BSSID trên iOS và xử lý trường hợp không có thông tin.

<a id="source-s07"></a>

### S07 — Android: Wi-Fi permissions và WifiInfo

`https://developer.android.com/develop/connectivity/wifi/wifi-permissions`

`https://developer.android.com/reference/android/net/wifi/WifiInfo`

Căn cứ cho quyền theo API/OS, thông tin Wi-Fi có thể bị che và giới hạn khai báo neverForLocation.

<a id="source-s08"></a>

### S08 — Expo: Development builds và native modules

`https://docs.expo.dev/develop/development-builds/faq/`

`https://docs.expo.dev/workflow/customizing/`

Căn cứ cho development build, custom Swift/Kotlin modules và giới hạn Expo Go.

<a id="source-s09"></a>

### S09 — MDN: Network Information API

`https://developer.mozilla.org/en-US/docs/Web/API/Network_Information_API`

Căn cứ cho giới hạn thông tin mạng mà trình duyệt web cung cấp.

<a id="source-s10"></a>

### S10 — Vercel: Request headers

`https://vercel.com/docs/headers/request-headers`

Căn cứ cho trusted ingress adapter cụ thể trên Vercel; không áp dụng tùy tiện cho mọi proxy/hosting.

<a id="source-s11"></a>

### S11 — Expo: Sending push notifications

`https://docs.expo.dev/push-notifications/sending-notifications/`

Căn cứ cho ticket, receipt, lỗi provider và việc gửi push không tương đương xác nhận đã đọc.

<a id="source-s12"></a>

### S12 — Supabase: Realtime Authorization

`https://supabase.com/docs/guides/realtime/authorization`

Căn cứ cho private channels, RLS và cache quyền trong kết nối Realtime.

<a id="source-s13"></a>

### S13 — Supabase: Database Backups

`https://supabase.com/docs/guides/platform/backups`

Căn cứ cho khác biệt giữa backup database và bytes trong Storage.

<a id="source-s14"></a>

### S14 — Supabase: Database testing

`https://supabase.com/docs/guides/local-development/testing/overview`

Căn cứ cho test schema/function/RLS qua pgTAP và CLI.

<a id="source-s15"></a>

### S15 — Bộ luật Lao động, nghỉ hằng năm hưởng lương

`https://vanban.chinhphu.vn/?docid=198540&pageid=27160`

`https://thads.moj.gov.vn/cantho/tin-tuc/chi-tiet/che-o-phep-cua-nguoi-lao-ong-tdupwp29d8.html`

Nguồn văn bản 45/2019/QH14 và nội dung giải thích của cơ quan thuộc Bộ Tư pháp về Điều 113. Tài liệu này không tự cấu hình đầy đủ mọi chế độ nghỉ/lương; cần rà soát quy định áp dụng tại thời điểm triển khai.

<a id="source-s16"></a>

### S16 — Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15

`https://vanban.chinhphu.vn/?docid=214590&pageid=27160&typegroupid=3`

`https://vbpl.vn/van-ban/chi-tiet/luat-bao-ve-du-lieu-ca-nhan-so-91-2025-qh15--179252`

Căn cứ về hiệu lực và nguyên tắc xử lý dữ liệu cá nhân; cần rà soát nghĩa vụ cụ thể khi triển khai.

<a id="source-s17"></a>

### S17 — Supabase: Database Functions

`https://supabase.com/docs/guides/database/functions`

Căn cứ cho RPC, security invoker/definer và quyền execute function.

<a id="source-s18"></a>

### S18 — PostgREST: Errors

`https://docs.postgrest.org/en/stable/references/errors.html`

Căn cứ cho mapping SQLSTATE/HTTP và lỗi PTxxx trong ví dụ command.

<a id="source-s19"></a>

### S19 — Supabase: Xác minh user/claims

`https://supabase.com/docs/reference/javascript/auth-getuser`

`https://supabase.com/docs/reference/javascript/auth-getclaims`

Căn cứ cho xác thực JWT/user phía server, không chỉ decode session do client gửi.

### Tham chiếu giao diện do chủ dự án cung cấp

Trong bộ ZIP kèm theo, ảnh nằm tại **`UI_REFERENCE.png`**, cùng thư mục với Markdown.

![Ảnh giao diện tham chiếu: sidebar sáng, nội dung trắng, bảng danh sách tối giản](UI_REFERENCE.png)

Ảnh là tham chiếu về hình thức, không phải màn hình cần chép nguyên nội dung. Khi chỉ có file Markdown mà chưa có ảnh, triển khai theo đầy đủ mô tả và tokens ở mục 6; không phụ thuộc ảnh để hiểu nghiệp vụ.

---

**KẾT THÚC ĐẶC TẢ**

Tóm tắt chỉ đạo cuối: xây đúng một hệ thống **quản lý công việc theo seller + daily task + chấm công + đơn từ + bảng công + báo cáo tự động 18:00**, có **web và app dùng chung Supabase**, giao diện **sáng, tối giản theo ảnh, không avatar**, dữ liệu **có phân quyền, lịch sử và kiểm thử**.

