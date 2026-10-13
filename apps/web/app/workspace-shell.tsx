import type { OrganizationContext, OrganizationRole } from '@opsdesk/contracts';
import Link from 'next/link';
import type { ReactNode } from 'react';
import {
  ActiveMembershipRequiredError,
  AuthenticationRequiredError,
} from '../lib/auth/require-member';
import { loadWorkspaceContext } from '../lib/data/workspace-data';
import type { WorkspaceDataSource } from '../lib/demo/opsdesk-demo';
import { SignOutButton } from './sign-out-button';

export type WorkspaceSection =
  | 'overview'
  | 'today'
  | 'my-tasks'
  | 'tasks'
  | 'recurring-tasks'
  | 'calendar'
  | 'requests'
  | 'approvals'
  | 'schedule'
  | 'attendance'
  | 'attendance-monitor'
  | 'attendance-settings'
  | 'timesheet-me'
  | 'timesheets'
  | 'notifications'
  | 'reports'
  | 'sellers'
  | 'team'
  | 'audit';

type WorkspaceShellProps = {
  activeSection: WorkspaceSection;
  context: OrganizationContext;
  description: string;
  eyebrow: string;
  source?: WorkspaceDataSource;
  title: string;
  children: ReactNode;
};

type WorkspaceRouteProps = Omit<WorkspaceShellProps, 'context' | 'children'>;

type NavigationItem = {
  href: string;
  id: WorkspaceSection;
  label: string;
};

type NavigationGroup = {
  id: string;
  label: string;
  items: NavigationItem[];
};

const roleLabels: Record<OrganizationRole, string> = {
  admin: 'Quản trị viên',
  manager: 'Quản lý',
  employee: 'Nhân viên',
};

const navigationGroups: NavigationGroup[] = [
  {
    id: 'home',
    label: 'Home',
    items: [
      { href: '/overview', id: 'overview', label: 'Tổng quan' },
      { href: '/today', id: 'today', label: 'Hôm nay' },
      { href: '/notifications', id: 'notifications', label: 'Inbox' },
      { href: '/calendar', id: 'calendar', label: 'Lịch' },
    ],
  },
  {
    id: 'work',
    label: 'Công việc',
    items: [
      { href: '/my-tasks', id: 'my-tasks', label: 'Công việc của tôi' },
      { href: '/tasks', id: 'tasks', label: 'Tất cả công việc' },
      { href: '/recurring-tasks', id: 'recurring-tasks', label: 'Daily Tasks' },
    ],
  },
  {
    id: 'sellers',
    label: 'Sellers',
    items: [{ href: '/sellers', id: 'sellers', label: 'Quản lý seller' }],
  },
  {
    id: 'team',
    label: 'Team',
    items: [
      { href: '/team', id: 'team', label: 'Nhân sự' },
      { href: '/attendance', id: 'attendance', label: 'Chấm công' },
      { href: '/requests', id: 'requests', label: 'Đơn từ' },
      { href: '/schedule', id: 'schedule', label: 'Lịch làm việc' },
      { href: '/timesheet/me', id: 'timesheet-me', label: 'Công tháng của tôi' },
      { href: '/timesheets', id: 'timesheets', label: 'Bảng công' },
    ],
  },
  {
    id: 'management',
    label: 'Management',
    items: [
      { href: '/reports', id: 'reports', label: 'Báo cáo' },
      { href: '/approvals', id: 'approvals', label: 'Phê duyệt' },
      {
        href: '/attendance/monitor',
        id: 'attendance-monitor',
        label: 'Theo dõi chấm công',
      },
      {
        href: '/settings/attendance',
        id: 'attendance-settings',
        label: 'Thiết lập chấm công',
      },
      { href: '/system/audit', id: 'audit', label: 'Nhật ký hệ thống' },
    ],
  },
];

const mobilePrimarySections: WorkspaceSection[] = [
  'today',
  'my-tasks',
  'attendance',
  'notifications',
];

function isSupabaseConfigurationError(error: unknown) {
  return (
    error instanceof Error &&
    (error.message.includes('Missing NEXT_PUBLIC_SUPABASE_URL') ||
      error.message.includes('Missing NEXT_PUBLIC_SUPABASE_ANON_KEY'))
  );
}

function navClassName(active: boolean) {
  return active ? 'workspace-nav-link workspace-nav-link-active' : 'workspace-nav-link';
}

function WorkspaceIcon({ section }: { section: WorkspaceSection }) {
  if (section === 'overview') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <rect height="7" rx="1.5" width="7" x="3" y="3" />
        <rect height="7" rx="1.5" width="7" x="14" y="3" />
        <rect height="7" rx="1.5" width="7" x="3" y="14" />
        <rect height="7" rx="1.5" width="7" x="14" y="14" />
      </svg>
    );
  }

  if (section === 'sellers') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M4 10.5 5.5 4h13L20 10.5" />
        <path d="M4 10.5c0 1.7 1.3 3 3 3 1.2 0 2.2-.7 2.7-1.7.5 1 1.5 1.7 2.8 1.7s2.3-.7 2.8-1.7c.5 1 1.5 1.7 2.7 1.7 1.7 0 3-1.3 3-3" />
        <path d="M6.5 13.2V20h11v-6.8M10 20v-4h4v4" />
      </svg>
    );
  }

  if (section === 'tasks' || section === 'my-tasks' || section === 'recurring-tasks') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M8 6h11M8 12h11M8 18h11" />
        <path d="m3.5 6 1.2 1.2L6.8 5M3.5 12l1.2 1.2L6.8 11M3.5 18l1.2 1.2L6.8 17" />
      </svg>
    );
  }

  if (section === 'team') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <circle cx="9" cy="8" r="3" />
        <path d="M3.8 20c.4-3.4 2.2-5.2 5.2-5.2s4.8 1.8 5.2 5.2M16 5.5a2.5 2.5 0 0 1 0 5M17 14.8c1.9.5 3 2.1 3.2 4.7" />
      </svg>
    );
  }

  if (
    section === 'calendar' ||
    section === 'schedule' ||
    section === 'attendance' ||
    section === 'timesheet-me' ||
    section === 'timesheets'
  ) {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <rect height="17" rx="2" width="18" x="3" y="4" />
        <path d="M7 2v4M17 2v4M3 9h18M7 13h3M12 13h3M7 17h3" />
      </svg>
    );
  }

  if (section === 'requests' || section === 'approvals') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M7 4.5h10M7 9h10M7 13.5h7" />
        <path d="M4 4.5h.01M4 9h.01M4 13.5h.01" />
        <path d="m14.5 18 2 2 4-5" />
      </svg>
    );
  }

  if (section === 'notifications') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M18 9a6 6 0 0 0-12 0c0 6-2.5 6-2.5 7.5h17C20.5 15 18 15 18 9Z" />
        <path d="M10 20h4" />
      </svg>
    );
  }

  if (section === 'reports') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M4 20V10M10 20V4M16 20v-7M22 20V7" />
        <path d="M3 20h20" />
      </svg>
    );
  }

  if (section === 'audit') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M12 3 19 6v5c0 4.8-2.8 8-7 10-4.2-2-7-5.2-7-10V6l7-3Z" />
        <path d="M9 12.2 11 14l4-4" />
      </svg>
    );
  }

  if (section === 'attendance-monitor') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M4 19V9M10 19V5M16 19v-7M22 19V3" />
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <rect height="17" rx="2" width="17" x="3.5" y="3.5" />
      <path d="M7 8.5h10M7 12h6M7 15.5h4" />
    </svg>
  );
}

export function WorkspaceShell({
  activeSection,
  context,
  description,
  eyebrow,
  source = 'supabase',
  title,
  children,
}: WorkspaceShellProps) {
  const canAccessNavigationItem = (item: NavigationItem) => {
    if (item.id === 'audit') return context.role === 'admin';
    if (item.id === 'approvals') return context.capabilities.includes('can_approve_requests');
    if (item.id === 'attendance-monitor')
      return context.capabilities.includes('can_manage_attendance');
    if (item.id === 'attendance-settings')
      return context.role === 'admin' || context.capabilities.includes('can_manage_attendance');
    if (item.id === 'timesheets') return context.capabilities.includes('can_manage_attendance');
    return (
      context.role !== 'employee' ||
      (item.id !== 'tasks' &&
        item.id !== 'recurring-tasks' &&
        item.id !== 'sellers' &&
        item.id !== 'team')
    );
  };
  const visibleNavigationGroups = navigationGroups
    .map((group) => ({ ...group, items: group.items.filter(canAccessNavigationItem) }))
    .filter((group) => group.items.length > 0);
  const visibleNavigationItems = visibleNavigationGroups.flatMap((group) => group.items);
  const mobilePrimaryItems = mobilePrimarySections
    .map((section) => visibleNavigationItems.find((item) => item.id === section))
    .filter((item): item is NavigationItem => Boolean(item));
  const mobileMoreItems = visibleNavigationItems.filter(
    (item) => !mobilePrimarySections.includes(item.id),
  );

  return (
    <div className="workspace-page">
      <aside className="workspace-sidebar" aria-label="Điều hướng workspace">
        <Link className="workspace-brand" href="/overview">
          <span className="brand-mark" aria-hidden="true">
            O
          </span>
          <span className="workspace-brand-name">OpsDesk</span>
        </Link>

        <div className="workspace-navigation-scroll">
          <nav className="workspace-nav" aria-label="Điều hướng chính">
            {visibleNavigationGroups.map((group) => (
              <section className="workspace-nav-group" key={group.id}>
                <p className="workspace-sidebar-label">{group.label}</p>
                <div className="workspace-nav-group-links">
                  {group.items.map((item) => (
                    <Link
                      aria-current={activeSection === item.id ? 'page' : undefined}
                      className={navClassName(activeSection === item.id)}
                      href={item.href}
                      key={item.id}
                      title={item.label}
                    >
                      <span className="workspace-nav-icon" aria-hidden="true">
                        <WorkspaceIcon section={item.id} />
                      </span>
                      <span className="workspace-nav-text">{item.label}</span>
                    </Link>
                  ))}
                </div>
              </section>
            ))}
          </nav>
        </div>

        <div className="workspace-member-card">
          <span className="workspace-member-name">{context.display_name}</span>
          <span className="workspace-member-role">{roleLabels[context.role]}</span>
          <span className="workspace-member-org">{context.organization_name}</span>
          <SignOutButton />
        </div>
      </aside>

      <div className="workspace-main-column">
        <header className="workspace-header">
          <div className="workspace-breadcrumb" aria-label="Breadcrumb">
            <Link href="/overview">Workspace</Link>
            <span aria-hidden="true">/</span>
            <span>{title}</span>
          </div>
          <span className="workspace-scope">{context.timezone}</span>
        </header>

        <main className="workspace-main">
          <div className="workspace-heading">
            <p className="workspace-eyebrow">{eyebrow}</p>
            <h1 className="workspace-page-title">{title}</h1>
            <p className="workspace-description">{description}</p>
          </div>

          <div className="workspace-context-strip" aria-label="Ngữ cảnh hiện tại">
            <span>{context.organization_name}</span>
            <span aria-hidden="true">·</span>
            <span>{roleLabels[context.role]}</span>
            <span aria-hidden="true">·</span>
            <span>Mã nhân sự {context.employee_code}</span>
          </div>

          {source === 'demo' ? (
            <div className="workspace-demo-notice" role="status">
              <strong>Dữ liệu demo</strong>
              <span>Đang dùng dữ liệu mẫu cục bộ; các thao tác ghi dữ liệu được tạm khóa.</span>
            </div>
          ) : null}

          {children}
        </main>

        <nav className="workspace-mobile-nav" aria-label="Điều hướng workspace trên mobile">
          {mobilePrimaryItems.map((item) => (
            <Link
              aria-current={activeSection === item.id ? 'page' : undefined}
              className={navClassName(activeSection === item.id)}
              href={item.href}
              key={item.id}
            >
              <span className="workspace-nav-icon" aria-hidden="true">
                <WorkspaceIcon section={item.id} />
              </span>
              <span className="workspace-mobile-nav-label">
                {item.id === 'my-tasks'
                  ? 'Công việc'
                  : item.id === 'notifications'
                    ? 'Inbox'
                    : item.label}
              </span>
            </Link>
          ))}
          <details className="workspace-mobile-more">
            <summary className="workspace-nav-link" aria-label="Mở thêm điều hướng">
              <span className="workspace-nav-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                  <circle cx="5" cy="12" r="1.2" fill="currentColor" stroke="none" />
                  <circle cx="12" cy="12" r="1.2" fill="currentColor" stroke="none" />
                  <circle cx="19" cy="12" r="1.2" fill="currentColor" stroke="none" />
                </svg>
              </span>
              <span className="workspace-mobile-nav-label">Thêm</span>
            </summary>
            <div className="workspace-mobile-more-menu">
              {mobileMoreItems.map((item) => (
                <Link
                  aria-current={activeSection === item.id ? 'page' : undefined}
                  className={navClassName(activeSection === item.id)}
                  href={item.href}
                  key={item.id}
                >
                  <span className="workspace-nav-icon" aria-hidden="true">
                    <WorkspaceIcon section={item.id} />
                  </span>
                  <span>{item.label}</span>
                </Link>
              ))}
            </div>
          </details>
        </nav>
      </div>
    </div>
  );
}

function WorkspaceEmptyState({ activeSection }: { activeSection: WorkspaceSection }) {
  const isToday = activeSection === 'today';

  return (
    <section className="workspace-empty-state" aria-labelledby="workspace-empty-title">
      <span className="workspace-empty-icon" aria-hidden="true">
        <WorkspaceIcon section={activeSection} />
      </span>
      <h2 id="workspace-empty-title">
        {isToday ? 'Bạn chưa có công việc cần xử lý hôm nay.' : 'Workspace đang chờ dữ liệu'}
      </h2>
      <p>
        {isToday
          ? 'Các công việc mới và lịch lặp sẽ xuất hiện tại đây.'
          : 'Các chỉ số và hoạt động sẽ xuất hiện ở đây khi các module nghiệp vụ được triển khai.'}
      </p>
    </section>
  );
}

export function WorkspaceAccessState({
  kind,
  nextPath,
}: {
  kind: 'configuration' | 'authentication' | 'membership' | 'error';
  nextPath: string;
}) {
  const content = {
    configuration: {
      title: 'Workspace chưa được cấu hình',
      description: 'Kết nối Supabase local và chạy migration trước khi sử dụng workspace.',
      action: 'Về trang bắt đầu',
      href: '/',
    },
    authentication: {
      title: 'Cần đăng nhập để tiếp tục',
      description: 'Đăng nhập bằng tài khoản workspace để xem ngữ cảnh tổ chức của bạn.',
      action: 'Đăng nhập workspace',
      href: `/login?next=${encodeURIComponent(nextPath)}`,
    },
    membership: {
      title: 'Tài khoản chưa có quyền truy cập',
      description:
        'Tài khoản chưa có membership active trong tổ chức này. Hãy liên hệ quản trị viên.',
      action: 'Quay lại trang đăng nhập',
      href: '/login',
    },
    error: {
      title: 'Không thể tải workspace',
      description: 'Có lỗi khi tải ngữ cảnh workspace. Vui lòng thử lại sau.',
      action: 'Về trang bắt đầu',
      href: '/',
    },
  }[kind];

  return (
    <main className="workspace-access-page">
      <section className="workspace-access-card" aria-labelledby="workspace-access-title">
        <span className="brand-mark" aria-hidden="true">
          O
        </span>
        <p className="workspace-eyebrow">OPSDesk · Workspace</p>
        <h1 id="workspace-access-title" className="workspace-page-title">
          {content.title}
        </h1>
        <p className="workspace-description">{content.description}</p>
        <Link className="link-button" href={content.href}>
          {content.action} →
        </Link>
      </section>
    </main>
  );
}

export function WorkspaceAccessFallback({ error, nextPath }: { error: unknown; nextPath: string }) {
  if (isSupabaseConfigurationError(error)) {
    return <WorkspaceAccessState kind="configuration" nextPath={nextPath} />;
  }

  if (error instanceof AuthenticationRequiredError) {
    return <WorkspaceAccessState kind="authentication" nextPath={nextPath} />;
  }

  if (error instanceof ActiveMembershipRequiredError) {
    return <WorkspaceAccessState kind="membership" nextPath={nextPath} />;
  }

  if (process.env.NODE_ENV === 'development') {
    console.error('[OpsDesk] Workspace load failed:', error);
  }

  return <WorkspaceAccessState kind="error" nextPath={nextPath} />;
}

export async function WorkspaceRoute({
  activeSection,
  description,
  eyebrow,
  title,
}: WorkspaceRouteProps) {
  const nextPaths: Record<WorkspaceSection, string> = {
    overview: '/overview',
    today: '/today',
    'my-tasks': '/my-tasks',
    tasks: '/tasks',
    'recurring-tasks': '/recurring-tasks',
    calendar: '/calendar',
    requests: '/requests',
    approvals: '/approvals',
    schedule: '/schedule',
    attendance: '/attendance',
    'attendance-monitor': '/attendance/monitor',
    'attendance-settings': '/settings/attendance',
    'timesheet-me': '/timesheet/me',
    timesheets: '/timesheets',
    notifications: '/notifications',
    reports: '/reports',
    sellers: '/sellers',
    team: '/team',
    audit: '/system/audit',
  };
  const nextPath = nextPaths[activeSection];

  try {
    const { context, source } = await loadWorkspaceContext();

    return (
      <WorkspaceShell
        activeSection={activeSection}
        context={context}
        description={description}
        eyebrow={eyebrow}
        source={source}
        title={title}
      >
        <WorkspaceEmptyState activeSection={activeSection} />
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath={nextPath} />;
  }
}
