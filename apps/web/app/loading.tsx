import { Skeleton } from '../components/ui';

export default function AppLoading() {
  return (
    <main className="workspace-access-page" aria-busy="true">
      <section className="workspace-access-card" aria-label="Đang tải workspace">
        <p className="workspace-eyebrow">OpsDesk</p>
        <h1>Đang tải workspace</h1>
        <p>Đang chuẩn bị dữ liệu và quyền truy cập cho màn hình này.</p>
        <Skeleton count={3} />
      </section>
    </main>
  );
}
