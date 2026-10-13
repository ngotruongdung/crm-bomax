'use client';

import { useState } from 'react';
import { createSupabaseBrowserClient } from '../lib/supabase/browser';

export function SignOutButton() {
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSignOut() {
    setErrorMessage(null);
    setIsSubmitting(true);

    try {
      const supabase = createSupabaseBrowserClient();
      const { error } = await supabase.auth.signOut();

      if (error) {
        setErrorMessage('Không thể đăng xuất. Thử lại sau.');
        return;
      }

      window.location.replace('/login');
    } catch (error) {
      setErrorMessage(
        error instanceof Error && error.message.startsWith('Missing NEXT_PUBLIC_SUPABASE_')
          ? 'Workspace chưa được cấu hình kết nối Supabase.'
          : 'Không thể đăng xuất lúc này. Thử lại sau.',
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className="workspace-sign-out">
      <button
        className="workspace-sign-out-button"
        disabled={isSubmitting}
        onClick={handleSignOut}
        type="button"
      >
        {isSubmitting ? 'Đang đăng xuất…' : 'Đăng xuất'}
      </button>
      {errorMessage ? (
        <span className="workspace-sign-out-error" role="alert">
          {errorMessage}
        </span>
      ) : null}
    </div>
  );
}
