'use client';

import Link from 'next/link';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { loginFailureMessage, type LoginFailureCode } from '../../lib/auth/login';
import { safeAuthRedirect } from '../../lib/auth/redirect';

function getNextPath() {
  if (typeof window === 'undefined') {
    return '/';
  }

  return safeAuthRedirect(new URLSearchParams(window.location.search).get('next'));
}

export default function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrorMessage(null);

    setIsSubmitting(true);

    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ email, password }),
      });
      const payload = (await response.json().catch(() => null)) as
        | { ok: true }
        | { ok: false; error?: { code?: LoginFailureCode } }
        | null;

      if (!response.ok || !payload || payload.ok !== true) {
        const failureCode = payload && payload.ok === false ? payload.error?.code : undefined;
        setErrorMessage(loginFailureMessage(failureCode ?? 'CONTEXT_UNAVAILABLE'));
        return;
      }

      const defaultPath =
        response.headers.get('X-OpsDesk-Role') === 'employee' ? '/today' : '/overview';
      const nextPath = getNextPath();
      window.location.assign(nextPath === '/' ? defaultPath : nextPath);
    } catch {
      setErrorMessage('Không thể đăng nhập lúc này. Thử lại sau.');
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <form className="auth-form" onSubmit={handleSubmit} noValidate>
      <div className="field-group">
        <label htmlFor="email">Email công việc</label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          inputMode="email"
          placeholder="ten@congty.vn"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          disabled={isSubmitting}
        />
      </div>

      <div className="field-group">
        <div className="field-label-row">
          <label htmlFor="password">Mật khẩu</label>
          <button
            className="password-toggle"
            type="button"
            onClick={() => setShowPassword((current) => !current)}
            aria-pressed={showPassword}
            disabled={isSubmitting}
          >
            {showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
          </button>
        </div>
        <input
          id="password"
          name="password"
          type={showPassword ? 'text' : 'password'}
          autoComplete="current-password"
          placeholder="Nhập mật khẩu"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          disabled={isSubmitting}
        />
      </div>

      {errorMessage ? (
        <p className="auth-error" role="alert">
          {errorMessage}
        </p>
      ) : null}

      <button className="primary-button" type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Đang đăng nhập…' : 'Đăng nhập'}
      </button>

      <div className="auth-form-footer">
        <Link href="/forgot-password">Quên mật khẩu?</Link>
        <p>Chưa có tài khoản? Liên hệ quản trị viên để nhận lời mời.</p>
      </div>
    </form>
  );
}
