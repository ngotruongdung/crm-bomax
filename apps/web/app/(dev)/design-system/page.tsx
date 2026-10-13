import Link from 'next/link';
import {
  AppShell,
  Breadcrumb,
  Button,
  Checkbox,
  Combobox,
  DailyTaskCheckbox,
  EmptyState,
  ErrorState,
  Input,
  MobileBottomNavigation,
  PageHeader,
  PersonLabel,
  PriorityBadge,
  Select,
  Sidebar,
  Skeleton,
  StatusBadge,
  Table,
  Toast,
} from '../../../components/ui';
import OverlayPreview from './overlay-preview';

export default function DesignSystemPage() {
  return (
    <AppShell
      header={
        <Breadcrumb>
          <Link href="/">OpsDesk</Link>
          <span aria-hidden="true">/</span>
          <span>UI review</span>
        </Breadcrumb>
      }
      mobileNavigation={
        <MobileBottomNavigation>
          <Link className="workspace-nav-link workspace-nav-link-active" href="#buttons">
            Components
          </Link>
          <Link className="workspace-nav-link" href="#feedback">
            States
          </Link>
        </MobileBottomNavigation>
      }
      sidebar={
        <Sidebar label="UI review">
          <Link className="workspace-nav-link workspace-nav-link-active" href="#buttons">
            Components
          </Link>
          <Link className="workspace-nav-link" href="#data-display">
            Data display
          </Link>
          <Link className="workspace-nav-link" href="#feedback">
            Feedback
          </Link>
        </Sidebar>
      }
    >
      <div className="ui-preview-page">
        <PageHeader
          description="Các primitives dùng chung của OpsDesk, kiểm tra theo hướng dẫn P02 và UI reference."
          eyebrow="Internal review"
          title="Design system"
        />

        <section className="ui-preview-section" id="buttons">
          <h2>Controls</h2>
          <div className="ui-preview-row">
            <Button>Primary</Button>
            <Button variant="secondary">Secondary</Button>
            <Button variant="ghost">Ghost</Button>
            <Button variant="danger">Danger</Button>
          </div>
          <div className="ui-preview-form-grid">
            <Input
              hint="Không hiển thị dữ liệu từ backend trong preview."
              label="Input"
              placeholder="Nhập giá trị"
            />
            <Select
              label="Select"
              options={[
                { label: 'Chọn một giá trị', value: 'one' },
                { label: 'Giá trị thứ hai', value: 'two' },
              ]}
              placeholder="Chọn"
            />
            <Combobox
              label="Combobox"
              options={[
                { label: 'Hà Nội', value: 'ha-noi' },
                { label: 'Thành phố Hồ Chí Minh', value: 'ho-chi-minh' },
              ]}
              placeholder="Tìm khu vực"
            />
          </div>
          <div className="ui-preview-row ui-preview-column-mobile">
            <Checkbox label="Checkbox thường" />
            <DailyTaskCheckbox label="Daily task checkbox" />
          </div>
        </section>

        <section className="ui-preview-section" id="data-display">
          <h2>Data display</h2>
          <div className="ui-preview-row">
            <StatusBadge tone="neutral">Draft</StatusBadge>
            <StatusBadge tone="success">Active</StatusBadge>
            <StatusBadge tone="warning">Pending</StatusBadge>
            <StatusBadge tone="danger">Blocked</StatusBadge>
            <PriorityBadge priority="low" />
            <PriorityBadge priority="medium" />
            <PriorityBadge priority="high" />
            <PriorityBadge priority="urgent" />
          </div>
          <PersonLabel name="Nguyễn Minh Anh" role="Text-only person label" />
          <Table
            caption="Monochrome table density"
            columns={[
              { key: 'name', label: 'Name' },
              { key: 'status', label: 'Status' },
              { key: 'updated', label: 'Updated' },
            ]}
            rows={[
              { name: 'Workspace context', status: 'Ready', updated: '—' },
              { name: 'Business data', status: 'Not loaded', updated: '—' },
            ]}
          />
        </section>

        <section className="ui-preview-section" id="feedback">
          <h2>Feedback states</h2>
          <div className="ui-preview-state-grid">
            <EmptyState title="Empty state">
              <p>Không có bản ghi để hiển thị.</p>
            </EmptyState>
            <ErrorState title="Error state">
              <p>Thông báo lỗi không làm lộ chi tiết backend.</p>
            </ErrorState>
          </div>
          <Skeleton count={2} />
          <Toast message="Toast feedback" tone="success" />
          <OverlayPreview />
        </section>
      </div>
    </AppShell>
  );
}
