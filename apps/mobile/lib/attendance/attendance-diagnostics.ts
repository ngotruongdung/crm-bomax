import type { WifiReadResult } from '@opsdesk/contracts';

export type AttendanceDiagnostic = {
  action?: string;
  canOpenSettings?: boolean;
  code: string;
  description: string;
  title: string;
};

function diagnostic(
  code: string,
  title: string,
  description: string,
  action?: string,
  canOpenSettings = false,
): AttendanceDiagnostic {
  return { action, canOpenSettings, code, description, title };
}

export function attendanceDiagnosticFromWifi(
  result: Exclude<WifiReadResult, { status: 'available' }>,
): AttendanceDiagnostic {
  switch (result.status) {
    case 'permission_denied':
      return diagnostic(
        'NATIVE_PERMISSION_REQUIRED',
        'Cần quyền truy cập Wi-Fi',
        'OpsDesk cần quyền Wi-Fi/vị trí theo yêu cầu của hệ điều hành để đọc SSID/BSSID hiện tại. Chưa xác minh được mạng thì sẽ không ghi nhận chấm công.',
        'Mở cài đặt quyền',
        true,
      );
    case 'location_disabled':
      return diagnostic(
        'LOCATION_SERVICE_DISABLED',
        'Dịch vụ vị trí đang tắt',
        'Android/iOS cần dịch vụ vị trí hoạt động để cung cấp SSID/BSSID cho ứng dụng. Chưa có dữ liệu mạng đáng tin cậy nên chấm công đang bị khóa.',
        'Mở cài đặt',
        true,
      );
    case 'not_wifi':
      return diagnostic(
        'WIFI_NOT_CONNECTED',
        'Chưa kết nối Wi-Fi',
        'Thiết bị chưa kết nối Wi-Fi. Hãy kết nối đúng mạng tại văn phòng rồi thử lại.',
        'Kiểm tra Wi-Fi',
      );
    case 'unavailable':
      return diagnostic(
        'SSID_BSSID_UNAVAILABLE',
        'Không đọc được SSID/BSSID',
        result.message ??
          'Hệ điều hành chưa cung cấp đủ thông tin mạng để xác minh. OpsDesk không ghi nhận chấm công khi thiếu SSID/BSSID.',
        'Thử lại sau khi kiểm tra quyền và Wi-Fi',
        true,
      );
  }
}

export function attendanceDiagnosticFromError(error: unknown): AttendanceDiagnostic {
  const code = error instanceof Error ? error.message : String(error || 'ATTENDANCE_UNKNOWN_ERROR');

  switch (code) {
    case 'NO_SCHEDULED_SHIFT':
    case 'SHIFT_NOT_FOUND':
      return diagnostic(
        'NO_SCHEDULED_SHIFT',
        'Không có ca làm việc hợp lệ',
        'Máy chủ chưa tìm thấy ca đang được phép chấm công. OpsDesk sẽ không tự tạo giờ vào/ra.',
        'Kiểm tra lịch làm việc',
      );
    case 'REMOTE_NOT_APPROVED':
      return diagnostic(
        code,
        'Chưa được phép làm online',
        'Ca hiện tại chưa cho phép remote hoặc chưa có quyền làm online đã được duyệt.',
        'Kiểm tra ca hoặc yêu cầu đã duyệt',
      );
    case 'WIFI_BSSID_MISMATCH':
      return diagnostic(
        code,
        'Sai Wi-Fi văn phòng',
        'BSSID hiện tại không nằm trong danh sách mạng văn phòng được phép. Hãy chuyển sang đúng Wi-Fi công ty.',
        'Kết nối lại Wi-Fi công ty',
      );
    case 'SOURCE_IP_MISMATCH':
      return diagnostic(
        code,
        'Sai mạng Internet văn phòng',
        'Wi-Fi có thể đúng nhưng public IP mà máy chủ nhận được không thuộc dải mạng văn phòng đã cấu hình.',
        'Kiểm tra mạng/gateway văn phòng',
      );
    case 'TRUSTED_INGRESS_NOT_CONFIGURED':
    case 'TRUSTED_SOURCE_IP_UNAVAILABLE':
      return diagnostic(
        code,
        'Máy chủ chưa xác minh được public IP',
        'Nguồn IP chưa đi qua adapter ingress đáng tin cậy nên hệ thống khóa chấm công văn phòng theo nguyên tắc fail-closed.',
        'Liên hệ quản trị viên hệ thống',
      );
    case 'WIFI_CLAIM_STALE_OR_MISSING':
      return diagnostic(
        code,
        'Thông tin Wi-Fi đã cũ',
        'Dữ liệu SSID/BSSID không còn đủ mới để xác minh. Hãy đọc lại mạng hiện tại và thử lại.',
        'Thử chấm công lại',
      );
    case 'CHALLENGE_EXPIRED':
    case 'CHALLENGE_ALREADY_CONSUMED':
      return diagnostic(
        code,
        'Phiên xác thực đã hết hiệu lực',
        'Challenge này không còn dùng được. OpsDesk sẽ tạo một phiên xác thực mới khi bạn thử lại.',
        'Thử lại',
      );
    case 'CHALLENGE_NOT_FOUND':
    case 'CHALLENGE_NONCE_MISMATCH':
    case 'CHALLENGE_OWNER_MISMATCH':
    case 'DEVICE_MISMATCH':
      return diagnostic(
        code,
        'Phiên xác thực không hợp lệ',
        'Thiết bị hoặc challenge không khớp với phiên chấm công hiện tại. Không có dữ liệu chấm công nào được ghi nhận.',
        'Tạo lại phiên chấm công',
      );
    case 'ATTENDANCE_SESSION_ALREADY_OPEN':
      return diagnostic(
        code,
        'Bạn đã chấm vào ca',
        'Máy chủ đã có một phiên làm việc đang mở. Hãy tải lại trạng thái trước khi thao tác tiếp.',
        'Tải lại trạng thái',
      );
    case 'ATTENDANCE_CHECK_IN_REQUIRED':
      return diagnostic(
        code,
        'Chưa có phiên để chấm ra',
        'Máy chủ không tìm thấy phiên chấm vào đang mở nên không thể tự tạo giờ chấm ra.',
        'Tải lại trạng thái',
      );
    case 'LAPTOP_SESSION_INVALID':
    case 'LAPTOP_SESSION_CODE_INVALID':
    case 'LAPTOP_SESSION_REQUIRED':
      return diagnostic(
        code,
        'Mã phiên máy tính không hợp lệ',
        'Mã 6 số không khớp, đã hết hạn hoặc không thuộc ca hiện tại. Hãy tạo mã mới trên máy tính rồi thử lại.',
        'Nhập mã mới',
      );
    case 'LAPTOP_SESSION_LOCKED':
      return diagnostic(
        code,
        'Mã phiên đã bị khóa',
        'Phiên máy tính đã bị khóa sau nhiều lần nhập sai. Hãy tạo một mã mới trên máy tính.',
        'Tạo mã phiên mới',
      );
    case 'LAPTOP_SESSION_EXPIRED':
      return diagnostic(
        code,
        'Mã phiên máy tính đã hết hạn',
        'Mã 6 số chỉ có hiệu lực trong thời gian ngắn. Hãy tạo mã mới rồi chụp lại selfie.',
        'Tạo mã phiên mới',
      );
    case 'CAMERA_PERMISSION_REQUIRED':
      return diagnostic(
        code,
        'Cần quyền camera',
        'Chấm công online yêu cầu chụp trực tiếp bằng camera trước. OpsDesk không cho chọn ảnh từ thư viện.',
        'Cho phép camera',
        true,
      );
    case 'CAMERA_CAPTURE_FAILED':
      return diagnostic(
        code,
        'Không chụp được selfie',
        'Camera chưa trả về ảnh hợp lệ. Hãy kiểm tra quyền camera và thử chụp lại.',
        'Chụp lại',
      );
    case 'UPLOAD_FAILED':
    case 'UPLOAD_INTENT_CONTRACT_INVALID':
    case 'REMOTE_UPLOAD_INTENT_INVALID':
    case 'REMOTE_EVIDENCE_NOT_UPLOADED':
    case 'REMOTE_EVIDENCE_VERIFY_FAILED':
    case 'REMOTE_EVIDENCE_FINALIZE_FAILED':
      return diagnostic(
        code,
        'Không thể gửi bằng chứng',
        'Ảnh chưa được máy chủ xác nhận nên chưa có check-in/check-out chính thức. Hãy giữ kết nối mạng ổn định và thử lại.',
        'Thử lại',
      );
    case 'REMOTE_EVIDENCE_INVALID':
    case 'REMOTE_EVIDENCE_INVALID_CONTENT':
      return diagnostic(
        code,
        'Ảnh bằng chứng không hợp lệ',
        'Máy chủ không chấp nhận ảnh hiện tại. Hãy chụp lại trực tiếp bằng camera trước.',
        'Chụp lại',
      );
    case 'REMOTE_ATTENDANCE_REQUIRES_NATIVE_APP':
    case 'NATIVE_WIFI_UNAVAILABLE_ON_WEB':
      return diagnostic(
        code,
        'Cần ứng dụng OpsDesk native',
        'Thiết bị hiện tại không hỗ trợ nguồn xác thực native cần thiết cho chấm công.',
        'Mở OpsDesk trên điện thoại',
      );
    case 'ATTENDANCE_API_NOT_CONFIGURED':
    case 'ATTENDANCE_SERVER_NOT_CONFIGURED':
    case 'ATTENDANCE_API_FAILED':
    case 'ATTENDANCE_FINALIZE_FAILED':
    case 'REMOTE_ATTENDANCE_LOAD_FAILED':
    case 'SERVER_UNAVAILABLE':
      return diagnostic(
        code,
        'Máy chủ chấm công chưa sẵn sàng',
        'Không thể xác minh với máy chủ nên OpsDesk không ghi nhận chấm công offline.',
        'Thử lại khi kết nối ổn định',
      );
    default:
      return diagnostic(
        code,
        'Không thể hoàn tất chấm công',
        'Yêu cầu chưa được máy chủ xác nhận. Không có giờ chấm công nào được tự tạo.',
        'Thử lại hoặc liên hệ quản trị viên',
      );
  }
}
