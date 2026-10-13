'use client';

import Link from 'next/link';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { createSupabaseBrowserClient } from '../../lib/supabase/browser';

export default function ResetPasswordPage() {
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [message, setMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage(null);
    setErrorMessage(null);

    if (password.length < 12) {
      setErrorMessage('Mật khẩu mới cần có ít nhất 12 ký tự.');
      return;
    }

    if (password !== confirmation) {
      setErrorMessage('Mật khẩu xác nhận chưa khớp.');
      return;
    }

    setIsSubmitting(true);

    try {
      const supabase = createSupabaseBrowserClient();
      const { error } = await supabase.auth.updateUser({ password });

      if (error) {
        setErrorMessage('Liên kết đặt lại mật khẩu không còn hợp lệ.');
        return;
      }

      setPassword('');
      setConfirmation('');
      setMessage('Mật khẩu đã được cập nhật. Bạn có thể đăng nhập lại.');
    } catch (error) {
      setErrorMessage(
        error instanceof Error && error.message.startsWith('Missing NEXT_PUBLIC_SUPABASE_')
          ? 'Workspace chưa được cấu hình kết nối Supabase.'
          : 'Không thể cập nhật mật khẩu lúc này. Thử lại sau.',
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="auth-page auth-page-single">
      <section className="auth-panel" aria-labelledby="reset-password-title">
        <div className="auth-panel-inner">
          <div className="mobile-auth-brand">
            <div className="brand-mark" aria-hidden="true">
              O
            </div>
            <span>OpsDesk</span>
          </div>
          <div className="auth-heading">
            <p className="eyebrow">ACCOUNT ACCESS</p>
            <h1 id="reset-password-title">Tạo mật khẩu mới</h1>
            <p>Mật khẩu mới sẽ bảo vệ quyền truy cập workspace của bạn.</p>
          </div>
          <form className="auth-form" onSubmit={handleSubmit}>
            <div className="field-group">
              <label htmlFor="new-password">Mật khẩu mới</label>
              <input
                id="new-password"
                type="password"
                autoComplete="new-password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                disabled={isSubmitting}
                required
              />
            </div>
            <div className="field-group">
              <label htmlFor="confirm-password">Xác nhận mật khẩu</label>
              <input
                id="confirm-password"
                type="password"
                autoComplete="new-password"
                value={confirmation}
                onChange={(event) => setConfirmation(event.target.value)}
                disabled={isSubmitting}
                required
              />
            </div>
            {message ? (
              <p className="auth-success" role="status">
                {message}
              </p>
            ) : null}
            {errorMessage ? (
              <p className="auth-error" role="alert">
                {errorMessage}
              </p>
            ) : null}
            <button className="primary-button" type="submit" disabled={isSubmitting}>
              {isSubmitting ? 'Đang cập nhật…' : 'Cập nhật mật khẩu'}
            </button>
          </form>
          <Link className="back-link" href="/login">
            ← Quay về đăng nhập
          </Link>
        </div>
      </section>
    </main>
  );
}
