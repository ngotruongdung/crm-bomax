export type AttendanceChannel = 'office' | 'remote';
export type AttendanceDiagnosticCode =
  | 'BROWSER_WIFI_NOT_VERIFIABLE'
  | 'NATIVE_PERMISSION_REQUIRED'
  | 'SSID_BSSID_UNAVAILABLE'
  | 'WIFI_NOT_CONNECTED'
  | 'WIFI_BSSID_MISMATCH'
  | 'SOURCE_IP_MISMATCH'
  | 'TRUSTED_INGRESS_NOT_CONFIGURED'
  | 'TRUSTED_SOURCE_IP_UNAVAILABLE'
  | 'NO_SCHEDULED_SHIFT'
  | 'REMOTE_NOT_APPROVED'
  | 'CHALLENGE_EXPIRED'
  | 'LAPTOP_SESSION_INVALID'
  | 'LAPTOP_SESSION_LOCKED'
  | 'UPLOAD_FAILED'
  | 'SERVER_UNAVAILABLE';

export type AttendanceDiagnostic = {
  action: string;
  code: AttendanceDiagnosticCode;
  description: string;
  title: string;
};

export type AttendanceCommit = {
  event_id?: string | null;
  recorded_at?: string | null;
  state: 'failed' | 'pending' | 'recorded';
};

export function officeBrowserDiagnostic(): AttendanceDiagnostic {
  return {
    code: 'BROWSER_WIFI_NOT_VERIFIABLE',
    title: 'Cần xác thực bằng ứng dụng native',
    description:
      'Trình duyệt không thể xác thực SSID/BSSID Wi‑Fi công ty một cách strict. Không thể chấm công văn phòng từ web.',
    action: 'Mở OpsDesk trên ứng dụng native',
  };
}

export function attendanceDiagnosticFor(
  code: Exclude<AttendanceDiagnosticCode, 'BROWSER_WIFI_NOT_VERIFIABLE'>,
) {
  const diagnostics: Record<
    Exclude<AttendanceDiagnosticCode, 'BROWSER_WIFI_NOT_VERIFIABLE'>,
    AttendanceDiagnostic
  > = {
    NATIVE_PERMISSION_REQUIRED: {
      code,
      title: 'Cần quyền truy cập thông tin Wi‑Fi',
      description:
        'Ứng dụng chưa đọc được thông tin mạng cần thiết để xác thực chấm công tại văn phòng.',
      action: 'Mở cài đặt',
    },
    SSID_BSSID_UNAVAILABLE: {
      code,
      title: 'Không đọc được SSID/BSSID',
      description:
        'Thiết bị chưa cung cấp đủ thông tin mạng để xác minh chấm công tại văn phòng. Hệ thống giữ trạng thái fail-closed.',
      action: 'Kiểm tra quyền Wi-Fi và thử lại',
    },
    WIFI_NOT_CONNECTED: {
      code,
      title: 'Chưa kết nối Wi-Fi',
      description: 'Thiết bị chưa kết nối Wi-Fi nên chưa thể xác minh mạng văn phòng.',
      action: 'Kết nối Wi-Fi công ty',
    },
    WIFI_BSSID_MISMATCH: {
      code,
      title: 'Sai Wi-Fi văn phòng',
      description:
        'BSSID hiện tại không nằm trong danh sách mạng văn phòng được cho phép cho ca này.',
      action: 'Kết nối đúng Wi-Fi công ty',
    },
    SOURCE_IP_MISMATCH: {
      code,
      title: 'Sai public IP văn phòng',
      description: 'Public IP mà máy chủ xác minh không thuộc dải mạng văn phòng đã cấu hình.',
      action: 'Kiểm tra gateway/mạng văn phòng',
    },
    TRUSTED_INGRESS_NOT_CONFIGURED: {
      code,
      title: 'Chưa cấu hình nguồn IP tin cậy',
      description:
        'Máy chủ chưa có trusted ingress adapter để xác minh public IP. Chấm công văn phòng được khóa theo nguyên tắc fail-closed.',
      action: 'Liên hệ quản trị hệ thống',
    },
    TRUSTED_SOURCE_IP_UNAVAILABLE: {
      code,
      title: 'Không lấy được public IP tin cậy',
      description:
        'Request không cung cấp được source IP qua header đã được máy chủ tin cậy. Không ghi nhận chấm công.',
      action: 'Thử lại hoặc liên hệ quản trị hệ thống',
    },
    NO_SCHEDULED_SHIFT: {
      code,
      title: 'Không có ca làm việc phù hợp',
      description:
        'Không có ca hợp lệ cho thời điểm này. Bạn có thể gửi yêu cầu điều chỉnh nếu cần.',
      action: 'Tạo yêu cầu bổ sung chấm công',
    },
    REMOTE_NOT_APPROVED: {
      code,
      title: 'Chưa có quyền làm online',
      description:
        'Chấm công online yêu cầu ca cho phép remote hoặc yêu cầu làm online đã được duyệt.',
      action: 'Xem yêu cầu của tôi',
    },
    CHALLENGE_EXPIRED: {
      code,
      title: 'Phiên xác thực đã hết hạn',
      description:
        'Không dùng lại ảnh hoặc dữ liệu xác thực cũ. Hãy tạo challenge mới trước khi thử lại.',
      action: 'Lấy challenge mới',
    },
    LAPTOP_SESSION_INVALID: {
      code,
      title: 'Mã phiên máy tính không hợp lệ',
      description:
        'Mã 6 số không khớp, đã hết hạn hoặc không thuộc ca hiện tại. Không có giờ chấm công nào được ghi nhận.',
      action: 'Tạo mã phiên mới',
    },
    LAPTOP_SESSION_LOCKED: {
      code,
      title: 'Mã phiên máy tính đã bị khóa',
      description: 'Phiên bị khóa sau nhiều lần xác minh sai. Hãy tạo mã mới trên máy tính.',
      action: 'Tạo mã phiên mới',
    },
    UPLOAD_FAILED: {
      code,
      title: 'Không thể gửi bằng chứng',
      description: 'Ảnh chưa được xác nhận bởi máy chủ nên chưa có check-in/check-out chính thức.',
      action: 'Thử lại khi mạng ổn định',
    },
    SERVER_UNAVAILABLE: {
      code,
      title: 'Máy chủ xác thực chưa sẵn sàng',
      description:
        'Không có timestamp chính thức hoặc network adapter đáng tin cậy. Không ghi nhận chấm công offline.',
      action: 'Gửi yêu cầu bổ sung chấm công',
    },
  };
  return diagnostics[code];
}

export function isRecordedAttendance(commit: AttendanceCommit) {
  return commit.state === 'recorded' && Boolean(commit.event_id) && Boolean(commit.recorded_at);
}
