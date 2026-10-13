'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import {
  invitationAcceptanceSchema,
  invitationValidationSchema,
  type InvitationValidation,
} from '@opsdesk/contracts';
import { createSupabaseBrowserClient } from '../../../lib/supabase/browser';

type InviteViewState =
  | { kind: 'loading' }
  | { kind: 'login-required' }
  | { kind: 'wrong-email' }
  | { kind: 'invalid' }
  | { kind: 'ready'; invitation: InvitationValidation }
  | { kind: 'error' };

function mapInviteError(message: string | undefined): InviteViewState {
  if (message?.includes('AUTHENTICATION_REQUIRED')) return { kind: 'login-required' };
  if (message?.includes('INVITE_EMAIL_MISMATCH')) return { kind: 'wrong-email' };
  if (message?.includes('INVITE_INVALID_OR_EXPIRED')) return { kind: 'invalid' };
  return { kind: 'error' };
}

function stateCopy(state: InviteViewState) {
  switch (state.kind) {
    case 'loading':
      return {
        title: 'Đang xác thực lời mời',
        detail: 'Đang kiểm tra liên kết với quyền truy cập hiện tại.',
      };
    case 'login-required':
      return {
        title: 'Đăng nhập để xác thực lời mời',
        detail:
          'Dùng đúng email mà quản trị viên đã mời. Workspace chỉ hiện sau khi backend xác thực token.',
      };
    case 'wrong-email':
      return {
        title: 'Email hiện tại không khớp lời mời',
        detail:
          'Hãy đăng xuất, rồi đăng nhập bằng đúng email được mời. Chưa có membership nào được cấp.',
      };
    case 'invalid':
      return {
        title: 'Liên kết lời mời không hợp lệ',
        detail:
          'Lời mời đã hết hạn, bị thu hồi hoặc đã được thay thế. Hãy yêu cầu quản trị viên gửi lại.',
      };
    case 'error':
      return {
        title: 'Không thể xác thực lời mời',
        detail: 'Thử tải lại. Nếu lỗi tiếp diễn, liên hệ quản trị viên để kiểm tra lời mời.',
      };
    case 'ready':
      return {
        title: `Tham gia ${state.invitation.organization_name}`,
        detail: 'Xác nhận tên hiển thị để kích hoạt quyền đã được cấp.',
      };
  }
}

export function AcceptInviteClient({ token }: { token: string }) {
  const [state, setState] = useState<InviteViewState>({ kind: 'loading' });
  const [displayName, setDisplayName] = useState('');
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const loginHref = useMemo(
    () =>
      `/login?next=${encodeURIComponent(`/auth/accept-invite?token=${encodeURIComponent(token)}`)}`,
    [token],
  );

  useEffect(() => {
    let isCurrent = true;

    async function validateInvite() {
      if (!token) {
        setState({ kind: 'invalid' });
        return;
      }

      try {
        const supabase = createSupabaseBrowserClient();
        const { data: userData, error: userError } = await supabase.auth.getUser();
        if (userError || !userData.user) {
          if (isCurrent) setState({ kind: 'login-required' });
          return;
        }

        const { data, error } = await supabase.rpc('rpc_validate_invitation', { p_token: token });
        if (error) {
          if (isCurrent) setState(mapInviteError(error.message));
          return;
        }

        const parsed = invitationValidationSchema.safeParse(data);
        if (!parsed.success) {
          if (isCurrent) setState({ kind: 'error' });
          return;
        }

        if (isCurrent) setState({ kind: 'ready', invitation: parsed.data });
      } catch {
        if (isCurrent) setState({ kind: 'error' });
      }
    }

    void validateInvite();
    return () => {
      isCurrent = false;
    };
  }, [token]);

  async function acceptInvite(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalizedName = displayName.trim();
    if (!normalizedName) {
      setSubmitError('Nhập tên hiển thị để tiếp tục.');
      return;
    }

    setIsSubmitting(true);
    setSubmitError(null);
    try {
      const supabase = createSupabaseBrowserClient();
      const { data, error } = await supabase.rpc('rpc_accept_invitation', {
        p_token: token,
        p_display_name: normalizedName,
      });
      if (error) {
        const nextState = mapInviteError(error.message);
        if (nextState.kind === 'wrong-email' || nextState.kind === 'invalid') {
          setState(nextState);
        } else {
          setSubmitError('Không thể kích hoạt quyền. Thử lại sau hoặc liên hệ quản trị viên.');
        }
        return;
      }

      const accepted = invitationAcceptanceSchema.safeParse(data);
      if (!accepted.success) {
        setSubmitError('Phản hồi kích hoạt không hợp lệ. Thử lại sau.');
        return;
      }

      window.location.assign(accepted.data.role === 'employee' ? '/today' : '/overview');
    } catch {
      setSubmitError('Không thể kết nối để kích hoạt quyền. Thử lại sau.');
    } finally {
      setIsSubmitting(false);
    }
  }

  const copy = stateCopy(state);

  return (
    <section className="auth-panel" aria-labelledby="invite-title">
      <div className="auth-panel-inner">
        <div className="mobile-auth-brand">
          <span className="brand-mark" aria-hidden="true">
            O
          </span>
          <span>OpsDesk</span>
        </div>
        <div className="auth-heading">
          <p className="eyebrow">OpsDesk · Lời mời</p>
          <h1 id="invite-title">{copy.title}</h1>
          <p>{copy.detail}</p>
        </div>

        {state.kind === 'ready' ? (
          <form className="auth-form" onSubmit={acceptInvite} noValidate>
            <div className="invite-state-card" role="status">
              <span className="invite-state-label">Quyền đã xác minh</span>
              <p>
                {state.invitation.email} · {state.invitation.role}
              </p>
            </div>
            <div className="field-group">
              <label htmlFor="display-name">Tên hiển thị</label>
              <input
                id="display-name"
                name="display-name"
                autoComplete="name"
                maxLength={160}
                value={displayName}
                onChange={(event) => setDisplayName(event.target.value)}
                disabled={isSubmitting}
              />
            </div>
            {submitError ? (
              <p className="auth-error" role="alert">
                {submitError}
              </p>
            ) : null}
            <button className="primary-button" type="submit" disabled={isSubmitting}>
              {isSubmitting ? 'Đang kích hoạt…' : 'Kích hoạt workspace'}
            </button>
          </form>
        ) : (
          <div className="invite-state-card" role={state.kind === 'invalid' ? 'alert' : 'status'}>
            <span className="invite-state-label">Bảo vệ quyền truy cập</span>
            <p>
              Membership không được tạo từ URL; token và email đăng nhập luôn được kiểm tra ở
              backend.
            </p>
          </div>
        )}

        {state.kind === 'login-required' || state.kind === 'wrong-email' ? (
          <Link className="primary-button invite-action-link" href={loginHref}>
            Đăng nhập đúng email
          </Link>
        ) : null}
        {state.kind !== 'ready' && state.kind !== 'loading' ? (
          <Link className="back-link" href="/login">
            Về trang đăng nhập
          </Link>
        ) : null}
      </div>
    </section>
  );
}
