import Link from 'next/link';
import ForgotPasswordForm from './forgot-password-form';

export default function ForgotPasswordPage() {
  return (
    <main className="auth-page auth-page-single">
      <section className="auth-panel" aria-labelledby="forgot-password-title">
        <div className="auth-panel-inner">
          <div className="mobile-auth-brand">
            <div className="brand-mark" aria-hidden="true">
              O
            </div>
            <span>OpsDesk</span>
          </div>
          <div className="auth-heading">
            <p className="eyebrow">ACCOUNT ACCESS</p>
            <h1 id="forgot-password-title">Đặt lại mật khẩu</h1>
            <p>Nhập email công việc để nhận hướng dẫn đặt lại mật khẩu.</p>
          </div>
          <ForgotPasswordForm />
          <Link className="back-link" href="/login">
            ← Quay về đăng nhập
          </Link>
        </div>
      </section>
    </main>
  );
}
