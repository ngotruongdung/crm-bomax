'use client';

import { useState } from 'react';
import type { FormEvent } from 'react';
import { createSupabaseBrowserClient } from '../../lib/supabase/browser';

export default function ForgotPasswordForm() {
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage(null);
    setErrorMessage(null);
    setIsSubmitting(true);

    try {
      const supabase = createSupabaseBrowserClient();
      const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
        redirectTo: `${window.location.origin}/auth/callback?next=/reset-password`,
      });

      if (error) {
        setErrorMessage('Không thể gửi hướng dẫn lúc này. Thử lại sau.');
        return;
      }

      setMessage('Nếu email thuộc hệ thống, hướng dẫn đặt lại mật khẩu sẽ được gửi đến bạn.');
    } catch (error) {
      setErrorMessage(
        error instanceof Error && error.message.startsWith('Missing NEXT_PUBLIC_SUPABASE_')
          ? 'Workspace chưa được cấu hình kết nối Supabase.'
          : 'Không thể gửi hướng dẫn lúc này. Thử lại sau.',
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <form className="auth-form" onSubmit={handleSubmit}>
      <div className="field-group">
        <label htmlFor="reset-email">Email công việc</label>
        <input
          id="reset-email"
          name="email"
          type="email"
          autoComplete="email"
          placeholder="ten@congty.vn"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
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
        {isSubmitting ? 'Đang gửi…' : 'Gửi hướng dẫn'}
      </button>
    </form>
  );
}
