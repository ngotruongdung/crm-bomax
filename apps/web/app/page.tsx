import { bootstrapStatus } from '@opsdesk/domain';
import Link from 'next/link';
import { demoWorkspaceAllowed } from '../lib/demo/opsdesk-demo';

export default function HomePage() {
  const showDemoWorkspace = demoWorkspaceAllowed();

  return (
    <main className="bootstrap-page">
      <section className="bootstrap-card" aria-labelledby="bootstrap-title">
        <div className="brand-mark" aria-hidden="true">
          O
        </div>
        <p className="eyebrow">OPSDesk · P00</p>
        <h1 id="bootstrap-title">Nền tảng đã sẵn sàng để xây dựng.</h1>
        <p className="intro">
          Đây là trang kiểm tra bootstrap của repository. Các màn hình nghiệp vụ sẽ được triển khai
          theo từng phase sau khi lớp Supabase/Auth và design system đạt gate.
        </p>
        <div className="status-row" role="status">
          <span className="status-dot" aria-hidden="true" />
          <span>{bootstrapStatus.label}</span>
        </div>
        <div className="bootstrap-actions">
          {showDemoWorkspace ? (
            <Link className="link-button" href="/overview">
              Mở workspace demo →
            </Link>
          ) : null}
          <Link className="bootstrap-login-link" href="/login">
            Đăng nhập workspace
          </Link>
        </div>
        <div className="meta-grid">
          <div>
            <span>Web</span>
            <strong>Next.js + TypeScript</strong>
          </div>
          <div>
            <span>Backend</span>
            <strong>Supabase</strong>
          </div>
          <div>
            <span>Ngôn ngữ</span>
            <strong>Tiếng Việt</strong>
          </div>
        </div>
      </section>
    </main>
  );
}
