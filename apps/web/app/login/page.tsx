import Link from 'next/link';
import { demoWorkspaceAllowed } from '../../lib/demo/opsdesk-demo';
import LoginForm from './login-form';

export default function LoginPage() {
  const showDemoWorkspace = demoWorkspaceAllowed();

  return (
    <main className="auth-page">
      <section className="auth-hero" aria-labelledby="auth-hero-title">
        <div className="auth-brand">
          <div className="brand-mark" aria-hidden="true">
            O
          </div>
          <span>OpsDesk</span>
        </div>
        <div className="auth-hero-copy">
          <p className="eyebrow">WORKSPACE OPERATIONS</p>
          <h1 id="auth-hero-title">Công việc rõ ràng. Vận hành gọn gàng.</h1>
          <p>Theo dõi công việc, chấm công và phối hợp cùng đội ngũ trong một workspace.</p>
        </div>
        <p className="auth-hero-footnote">OpsDesk · Nền tảng vận hành team thương mại điện tử</p>
      </section>

      <section className="auth-panel" aria-labelledby="login-title">
        <div className="auth-panel-inner">
          <div className="mobile-auth-brand">
            <div className="brand-mark" aria-hidden="true">
              O
            </div>
            <span>OpsDesk</span>
          </div>
          <div className="auth-heading">
            <p className="eyebrow">WELCOME BACK</p>
            <h2 id="login-title">Đăng nhập workspace</h2>
            <p>Theo dõi công việc, chấm công và phối hợp cùng đội ngũ.</p>
          </div>
          <LoginForm />
          {showDemoWorkspace ? (
            <Link className="auth-demo-link" href="/overview">
              Mở workspace demo không cần đăng nhập →
            </Link>
          ) : null}
        </div>
      </section>
    </main>
  );
}
