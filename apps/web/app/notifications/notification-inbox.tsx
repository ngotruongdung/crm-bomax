'use client';

import type { Notification } from '@opsdesk/contracts';
import type { WorkspaceDataSource } from '../../lib/demo/opsdesk-demo';
import { notificationRefreshFallback } from '@opsdesk/domain';
import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { createSupabaseBrowserClient } from '../../lib/supabase/browser';
import {
  isActionInboxItem,
  notificationTabs,
  parseNotificationInboxTab,
  type NotificationInboxTab,
} from './notification-projections';

function targetHref(item: Notification) {
  if (item.target_type === 'task' && item.target_id) return `/tasks/${item.target_id}`;
  if (item.target_type === 'request') return '/requests';
  if (item.target_type === 'report' && item.target_id) return `/reports/${item.target_id}`;
  if (item.target_type === 'report') return '/reports';
  return null;
}

function category(item: Notification): Exclude<NotificationInboxTab, 'all' | 'unread'> | 'system' {
  if (item.kind.startsWith('task_')) return 'tasks';
  if (item.kind === 'request_result') return 'hr';
  if (item.kind === 'report_ready') return 'reports';
  return 'system';
}

function categoryLabel(item: Notification) {
  if (category(item) === 'tasks') return 'Công việc';
  if (category(item) === 'hr') return 'Nhân sự';
  if (category(item) === 'reports') return 'Báo cáo';
  return 'Hệ thống';
}

function actionLabel(item: Notification) {
  if (item.target_type === 'request') return 'Xem yêu cầu';
  if (item.target_type === 'report') return 'Mở báo cáo';
  if (item.kind === 'task_assigned' || item.kind === 'task_unacknowledged') {
    return 'Xem & nhận việc';
  }
  if (item.kind === 'task_review_requested') return 'Xem để duyệt';
  return 'Mở công việc';
}

function relativeTime(value: string, referenceNow: string) {
  const deltaMinutes = Math.max(
    0,
    Math.round((Date.parse(referenceNow) - Date.parse(value)) / 60_000),
  );
  if (deltaMinutes < 1) return 'Vừa xong';
  if (deltaMinutes < 60) return `${deltaMinutes} phút trước`;
  const hours = Math.floor(deltaMinutes / 60);
  if (hours < 24) return `${hours} giờ trước`;
  return new Intl.DateTimeFormat('vi-VN', { day: '2-digit', month: '2-digit' }).format(
    new Date(value),
  );
}

export function NotificationInbox({
  initialItems,
  organizationId,
  referenceNow,
  source,
}: {
  initialItems: Notification[];
  organizationId: string;
  referenceNow: string;
  source: WorkspaceDataSource;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [items, setItems] = useState(initialItems);
  const [tab, setTab] = useState<NotificationInboxTab>(() =>
    parseNotificationInboxTab(searchParams.get('tab')),
  );
  const [busyId, setBusyId] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => setItems(initialItems), [initialItems]);

  useEffect(() => {
    const syncFromBrowserHistory = () => {
      setTab(parseNotificationInboxTab(new URLSearchParams(window.location.search).get('tab')));
    };
    window.addEventListener('popstate', syncFromBrowserHistory);
    return () => window.removeEventListener('popstate', syncFromBrowserHistory);
  }, []);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (tab === 'all') {
      params.delete('tab');
    } else {
      params.set('tab', tab);
    }
    const query = params.toString();
    const nextUrl = query ? `${pathname}?${query}` : pathname;
    window.history.replaceState(window.history.state, '', nextUrl);
  }, [pathname, tab]);

  useEffect(() => {
    if (source !== 'supabase') return;
    const refresh = () => router.refresh();
    const onFocus = () => {
      if (document.visibilityState === 'visible') refresh();
    };
    document.addEventListener('visibilitychange', onFocus);
    const timer = window.setInterval(refresh, notificationRefreshFallback.pollIntervalMs);

    let supabase: ReturnType<typeof createSupabaseBrowserClient> | null = null;
    let channel: ReturnType<ReturnType<typeof createSupabaseBrowserClient>['channel']> | null =
      null;
    try {
      supabase = createSupabaseBrowserClient();
      channel = supabase
        .channel(`notifications:${organizationId}`)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'notifications' }, refresh)
        .subscribe();
    } catch {
      // Focus + polling remain the authoritative fallback when Realtime is unavailable.
    }

    return () => {
      document.removeEventListener('visibilitychange', onFocus);
      window.clearInterval(timer);
      if (supabase && channel) void supabase.removeChannel(channel);
    };
  }, [organizationId, router, source]);

  const actionItems = useMemo(() => items.filter(isActionInboxItem), [items]);

  const visibleItems = useMemo(
    () =>
      actionItems.filter((item) => {
        if (tab === 'all') return true;
        if (tab === 'unread') return item.read_at === null;
        return category(item) === tab;
      }),
    [actionItems, tab],
  );
  const unreadCount = actionItems.filter((item) => item.read_at === null).length;
  const tabCounts = useMemo<Record<NotificationInboxTab, number>>(
    () => ({
      all: actionItems.length,
      unread: unreadCount,
      tasks: actionItems.filter((item) => category(item) === 'tasks').length,
      hr: actionItems.filter((item) => category(item) === 'hr').length,
      reports: actionItems.filter((item) => category(item) === 'reports').length,
    }),
    [actionItems, unreadCount],
  );

  async function markRead(item: Notification) {
    if (source === 'demo' || item.read_at || busyId) return;
    setBusyId(item.id);
    setError(null);
    try {
      const response = await fetch('/api/notifications/read', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          action: 'one',
          organization_id: organizationId,
          notification_id: item.id,
        }),
      });
      if (!response.ok) throw new Error('READ_FAILED');
      const now = new Date().toISOString();
      setItems((current) =>
        current.map((row) => (row.id === item.id ? { ...row, read_at: row.read_at ?? now } : row)),
      );
    } catch {
      setError('Không thể cập nhật trạng thái đã đọc. Vui lòng thử lại.');
    } finally {
      setBusyId(null);
    }
  }

  async function markAllRead() {
    if (source === 'demo' || unreadCount === 0 || busyId) return;
    setBusyId('all');
    setError(null);
    setNotice(null);
    const cutoff = new Date().toISOString();
    try {
      const response = await fetch('/api/notifications/read', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ action: 'all', organization_id: organizationId, cutoff }),
      });
      if (!response.ok) throw new Error('MARK_ALL_FAILED');
      setItems((current) =>
        current.map((row) =>
          !isActionInboxItem(row) || row.read_at || Date.parse(row.created_at) > Date.parse(cutoff)
            ? row
            : { ...row, read_at: cutoff },
        ),
      );
      setNotice('Đã đánh dấu các thông báo hiện có là đã đọc.');
    } catch {
      setError('Không thể đánh dấu tất cả đã đọc. Vui lòng thử lại.');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <>
      <section className="notification-toolbar">
        <div>
          <p className="notification-eyebrow">Action inbox</p>
          <strong>
            {unreadCount > 0 ? `${unreadCount} thông báo chưa đọc` : 'Bạn đã xem hết thông báo'}
          </strong>
          <p>Chỉ hiển thị các cập nhật cần phản hồi; đọc không đồng nghĩa với nhận việc.</p>
        </div>
        <div className="notification-toolbar-actions">
          <Link href="/today">Mở Hôm nay</Link>
          <button
            disabled={source === 'demo' || unreadCount === 0 || Boolean(busyId)}
            onClick={() => void markAllRead()}
            type="button"
          >
            {busyId === 'all' ? 'Đang cập nhật…' : 'Đánh dấu tất cả đã đọc'}
          </button>
        </div>
      </section>

      <nav className="notification-tabs" aria-label="Lọc thông báo">
        {notificationTabs.map((item) => (
          <button
            aria-pressed={tab === item.id}
            className={
              tab === item.id ? 'notification-tab notification-tab-active' : 'notification-tab'
            }
            key={item.id}
            onClick={() => setTab(item.id)}
            type="button"
          >
            {item.label}
            {tabCounts[item.id] > 0 ? <span>{tabCounts[item.id]}</span> : null}
          </button>
        ))}
      </nav>

      {notice ? (
        <div className="notification-inline-state" role="status">
          {notice}
        </div>
      ) : null}
      {error ? (
        <div className="notification-inline-state notification-inline-error" role="alert">
          {error}
        </div>
      ) : null}

      <section className="notification-list" aria-label="Danh sách thông báo">
        {visibleItems.map((item) => {
          const href = targetHref(item);
          return (
            <article
              className={
                item.read_at ? 'notification-row' : 'notification-row notification-row-unread'
              }
              key={item.id}
            >
              <span className="notification-kind-icon" aria-hidden="true">
                {category(item) === 'tasks'
                  ? '✓'
                  : category(item) === 'hr'
                    ? '◇'
                    : category(item) === 'reports'
                      ? '▤'
                      : '•'}
              </span>
              <div className="notification-copy">
                <div className="notification-title-line">
                  <strong>{item.title}</strong>
                  {item.read_at ? null : (
                    <span className="notification-unread-dot" aria-label="Chưa đọc" />
                  )}
                </div>
                <p>{item.body}</p>
                <span className="notification-meta">
                  <span>{categoryLabel(item)}</span>
                  <span aria-hidden="true">·</span>
                  <time dateTime={item.created_at}>
                    {relativeTime(item.created_at, referenceNow)}
                  </time>
                </span>
              </div>
              <div className="notification-actions">
                {item.read_at ? null : (
                  <button
                    disabled={busyId === item.id || source === 'demo'}
                    onClick={() => void markRead(item)}
                    type="button"
                  >
                    {busyId === item.id ? 'Đang lưu…' : 'Đánh dấu đã đọc'}
                  </button>
                )}
                {href ? (
                  <Link href={href} onClick={() => void markRead(item)}>
                    {actionLabel(item)}
                  </Link>
                ) : null}
              </div>
            </article>
          );
        })}
        {visibleItems.length === 0 ? (
          <div className="notification-empty">
            {actionItems.length === 0
              ? 'Không có mục nào cần bạn phản hồi ngay lúc này.'
              : 'Không có thông báo phù hợp với bộ lọc này.'}
          </div>
        ) : null}
      </section>
    </>
  );
}
