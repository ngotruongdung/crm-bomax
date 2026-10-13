# OpsDesk backup, Storage và restore drill

Trạng thái hiện tại: **PREPARED / NOT EXECUTED**. Tài liệu này là gate của P10; không được đánh dấu P10 PASS cho tới khi restore drill thực tế hoàn tất trên staging hoặc môi trường tương đương.

## 1. Phạm vi backup bắt buộc

Một backup hợp lệ của OpsDesk gồm hai phần độc lập:

1. **PostgreSQL/Supabase database**: schema, dữ liệu nghiệp vụ, RLS/RPC, audit, Auth mapping cần thiết cho restore.
2. **Supabase Storage bytes**: toàn bộ object còn hiệu lực trong `task-files`, `attendance-evidence`, `request-evidence`, `exports`, kèm manifest `bucket_id`, `object_path`, `size`, checksum và thời điểm backup.

Backup database đơn lẻ **không** chứng minh file bytes đã được backup. Backup Storage đơn lẻ cũng không đủ vì ACL và liên kết file nằm trong database.

## 2. Retention và legal hold

Trước production, admin phải xác nhận policy `retention` với ít nhất `attendance_photo_retention_days`, `request_evidence_retention_days` và `export_retention_days`. Giá trị demo 30 ngày cho ảnh và 7 ngày cho export chỉ dùng kiểm thử, không phải khuyến nghị pháp lý mặc định.

Worker retention chỉ được xóa object khi metadata đã hết hạn và `legal_hold=false`. Xóa bytes không được xóa attendance event, timesheet snapshot hoặc audit lịch sử. Chính sách backup phải ghi rõ retention của bản backup; không hứa xóa tức thì khỏi mọi bản sao lưu.

## 3. Quy trình restore drill

1. Tạo môi trường staging/local-equivalent trống, tách biệt production.
2. Restore database vào môi trường đó và áp đúng migration version.
3. Restore Storage bytes theo manifest, giữ nguyên `bucket_id/object_path`.
4. Không dùng service-role key trên browser/mobile; chỉ cấu hình secret ở server/worker.
5. Tạo tối thiểu ba user test: admin, manager giới hạn seller, employee.
6. Kiểm tra task: assignee/reviewer/participant và manager seller scope vẫn đọc đúng, user ngoài scope nhận 404/deny.
7. Kiểm tra HR/attendance: employee chỉ xem dữ liệu của mình; quyền xem evidence đúng capability; request riêng tư không lộ cho manager chỉ có task scope.
8. Kiểm tra timesheet: period, revision, snapshot và totals giữ nguyên source hash/revision.
9. Kiểm tra report snapshot: revision cũ bất biến, manager mất seller scope không mở/export snapshot rộng hơn.
10. Với một file của từng bucket, đối chiếu metadata với object bytes/checksum; gateway phát URL ngắn và `Cache-Control: no-store`.
11. Bật `legal_hold` cho một file đã quá retention, chạy cleanup và chứng minh bytes vẫn còn.
12. Chạy full `pnpm verify:deployment` khi Docker, Supabase CLI và credentials thật đã sẵn sàng.

## 4. Evidence phải lưu sau drill

Ghi ngày giờ, commit SHA, migration head, môi trường, người thực hiện, database backup identifier, Storage manifest identifier, số lượng object/bytes, checksum sample, kết quả các bước 6–11 và mọi sai lệch/fix. Không ghi service-role key, access token, selfie hoặc private leave reason vào report drill.

## 5. Tiêu chí PASS P10 liên quan backup

Chỉ PASS khi cùng một drill chứng minh được: database restore thành công; Storage restore thành công; task/HR/timesheet/report ACL vẫn đúng; file links còn trỏ được tới bytes; legal hold hoạt động; không có secret trong client bundle; và toàn bộ lỗi nghiêm trọng đã được xử lý. Cho tới lúc đó trạng thái là `IN_PROGRESS_UNVERIFIED`.
