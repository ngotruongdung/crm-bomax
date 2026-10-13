export type LoginCommand = {
  email: string;
  password: string;
};

export type LoginFailureCode =
  | 'INVALID_INPUT'
  | 'INVALID_CREDENTIALS'
  | 'EMAIL_NOT_CONFIRMED'
  | 'RATE_LIMITED'
  | 'MEMBERSHIP_REQUIRED'
  | 'CONTEXT_UNAVAILABLE';

const emailPattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function record(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

export function parseLoginCommand(value: unknown): LoginCommand | null {
  const input = record(value);
  const email = typeof input?.email === 'string' ? input.email.trim() : '';
  const password = typeof input?.password === 'string' ? input.password : '';

  if (!emailPattern.test(email) || !password || password.length > 1024) {
    return null;
  }

  return { email, password };
}

export function loginFailureFromAuthCode(code?: string): LoginFailureCode {
  if (code === 'invalid_credentials' || code === 'invalid_grant') {
    return 'INVALID_CREDENTIALS';
  }
  if (code === 'email_not_confirmed') return 'EMAIL_NOT_CONFIRMED';
  if (code === 'over_request_rate_limit' || code === 'over_email_send_rate_limit') {
    return 'RATE_LIMITED';
  }
  return 'CONTEXT_UNAVAILABLE';
}

export function loginFailureMessage(code: LoginFailureCode) {
  const messages: Record<LoginFailureCode, string> = {
    INVALID_INPUT: 'Nhập email công việc hợp lệ và mật khẩu để tiếp tục.',
    INVALID_CREDENTIALS: 'Email hoặc mật khẩu không đúng.',
    EMAIL_NOT_CONFIRMED: 'Email chưa được xác nhận. Hãy xác nhận email trong Supabase rồi thử lại.',
    RATE_LIMITED: 'Bạn đã thử quá nhiều lần. Vui lòng chờ một lúc rồi đăng nhập lại.',
    MEMBERSHIP_REQUIRED: 'Tài khoản chưa được cấp quyền trong workspace này.',
    CONTEXT_UNAVAILABLE: 'Không thể tải quyền truy cập. Thử lại sau.',
  };

  return messages[code];
}
