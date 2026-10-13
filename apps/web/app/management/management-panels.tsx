'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import type { MemberDirectoryEntry, OrganizationRole, TaskListItem } from '@opsdesk/contracts';
import {
  Button,
  Checkbox,
  ConfirmDialog,
  Drawer,
  Input,
  Select,
  StatusBadge,
} from '../../components/ui';
import { createSupabaseBrowserClient } from '../../lib/supabase/browser';
import type { WorkspaceDataSource } from '../../lib/demo/opsdesk-demo';
import { localDateInTimeZone } from '../tasks/task-timezone';

export type SellerSummary = {
  id: string;
  code: string;
  name: string;
  platform: string;
  brand_label: string | null;
  shop_url: string | null;
  archived_at: string | null;
  version: number;
};

type CommandError = { error?: { code?: unknown } };

const roleOptions = [
  { value: 'employee', label: 'Nhân viên' },
  { value: 'manager', label: 'Quản lý' },
  { value: 'admin', label: 'Quản trị viên' },
];

const platformOptions = [
  { value: 'shopee', label: 'Shopee' },
  { value: 'tiktok_shop', label: 'TikTok Shop' },
  { value: 'lazada', label: 'Lazada' },
  { value: 'other', label: 'Khác' },
];

function commandMessage(error: { message?: string } | undefined, fallback: string) {
  if (error?.message?.includes('VERSION_CONFLICT'))
    return 'Dữ liệu vừa thay đổi. Hãy tải lại trước khi lưu.';
  if (error?.message?.includes('ADMIN_REQUIRED'))
    return 'Bạn không có quyền thực hiện thao tác này.';
  return fallback;
}

function responseMessage(payload: CommandError, fallback: string) {
  const code = typeof payload.error?.code === 'string' ? payload.error.code : '';
  if (code === 'MEMBER_ALREADY_ACTIVE') return 'Email này đã có membership active trong workspace.';
  if (code === 'SELF_INVITE_NOT_ALLOWED')
    return 'Không thể tự gửi lời mời để thay đổi quyền của chính mình.';
  if (code === 'INVITATION_DELIVERY_NOT_CONFIGURED') return 'Server chưa có cấu hình gửi lời mời.';
  return fallback;
}

function roleLabel(role: OrganizationRole) {
  return roleOptions.find((option) => option.value === role)?.label ?? role;
}

function platformLabel(platform: string) {
  return platformOptions.find((option) => option.value === platform)?.label ?? platform;
}

function taskIsTerminal(task: TaskListItem) {
  return task.status === 'done' || task.status === 'canceled' || task.status === 'waived';
}

function taskStatusLabel(status: TaskListItem['status']) {
  if (status === 'todo') return 'Chờ thực hiện';
  if (status === 'in_progress') return 'Đang làm';
  if (status === 'in_review') return 'Chờ duyệt';
  if (status === 'done') return 'Hoàn thành';
  if (status === 'canceled') return 'Đã hủy';
  return 'Đã miễn';
}

function taskStatusTone(status: TaskListItem['status']) {
  if (status === 'done') return 'success' as const;
  if (status === 'in_review') return 'warning' as const;
  if (status === 'canceled' || status === 'waived') return 'danger' as const;
  return 'neutral' as const;
}

function compactDateTime(value: string, timeZone: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone,
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function sellerScopeFor(member: MemberDirectoryEntry, sellerId: string) {
  return member.seller_scope.find((scope) => scope.seller_id === sellerId);
}

export function SellerManagementPanel({
  members,
  organizationId,
  role,
  sellers,
  source,
  tasks,
  timezone,
}: {
  members: MemberDirectoryEntry[];
  organizationId: string;
  role: OrganizationRole;
  sellers: SellerSummary[];
  source: WorkspaceDataSource;
  tasks: TaskListItem[];
  timezone: string;
}) {
  const router = useRouter();
  const isAdmin = role === 'admin';
  const [selectedSellerId, setSelectedSellerId] = useState(
    sellers.find((seller) => !seller.archived_at)?.id ?? sellers[0]?.id ?? '',
  );
  const [sellerTab, setSellerTab] = useState<'tasks' | 'members' | 'overview'>('tasks');
  const [isCreateOpen, setCreateOpen] = useState(false);
  const [editingSeller, setEditingSeller] = useState<SellerSummary | null>(null);
  const [scopeSeller, setScopeSeller] = useState<SellerSummary | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setSubmitting] = useState(false);
  const activeMembers = members.filter((member) => member.status === 'active');
  const selectedSeller =
    sellers.find((seller) => seller.id === selectedSellerId) ?? sellers[0] ?? null;
  const selectedSellerMembers = selectedSeller
    ? activeMembers.filter((member) => sellerScopeFor(member, selectedSeller.id))
    : [];
  const selectedSellerTasks = selectedSeller
    ? tasks.filter((task) => task.seller_id === selectedSeller.id)
    : [];
  const today = localDateInTimeZone(new Date().toISOString(), timezone);
  const openSelectedSellerTasks = selectedSellerTasks.filter((task) => !taskIsTerminal(task));
  const todaySelectedSellerTasks = openSelectedSellerTasks.filter(
    (task) => task.planned_date === today,
  );
  const overdueSelectedSellerTasks = openSelectedSellerTasks.filter(
    (task) => new Date(task.due_at).getTime() < Date.now(),
  );
  const reviewSelectedSellerTasks = openSelectedSellerTasks.filter(
    (task) => task.status === 'in_review',
  );
  const scopeMembers = useMemo(
    () =>
      scopeSeller
        ? activeMembers.filter((member) => Boolean(sellerScopeFor(member, scopeSeller.id)))
        : [],
    [activeMembers, scopeSeller],
  );
  const [selectedMemberIds, setSelectedMemberIds] = useState<string[]>([]);
  const [managerMemberIds, setManagerMemberIds] = useState<string[]>([]);

  function openScopeEditor(seller: SellerSummary) {
    const currentScopes = activeMembers
      .map((member) => ({ member, scope: sellerScopeFor(member, seller.id) }))
      .filter((entry) => entry.scope);
    setScopeSeller(seller);
    setSelectedMemberIds(currentScopes.map((entry) => entry.member.member_id));
    setManagerMemberIds(
      currentScopes
        .filter((entry) => entry.scope?.is_manager)
        .map((entry) => entry.member.member_id),
    );
    setError(null);
  }

  async function createSeller(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (source === 'demo') {
      setError('Chế độ demo chỉ đọc. Kết nối Supabase để tạo seller thật.');
      return;
    }
    const form = new FormData(event.currentTarget);
    setSubmitting(true);
    setError(null);
    try {
      const supabase = createSupabaseBrowserClient();
      const { error: rpcError } = await supabase.rpc('rpc_create_or_update_seller', {
        p_organization_id: organizationId,
        p_seller: {
          code: String(form.get('code') ?? '').trim(),
          name: String(form.get('name') ?? '').trim(),
          platform: String(form.get('platform') ?? ''),
          brand_label: String(form.get('brand_label') ?? '').trim(),
          shop_url: String(form.get('shop_url') ?? '').trim(),
        },
        p_expected_version: null,
      });
      if (rpcError) {
        setError(commandMessage(rpcError, 'Không thể tạo seller.'));
        return;
      }
      setCreateOpen(false);
      router.refresh();
    } catch {
      setError('Không thể kết nối để tạo seller.');
    } finally {
      setSubmitting(false);
    }
  }

  async function saveSellerScope() {
    if (!scopeSeller) return;
    if (source === 'demo') {
      setError('Chế độ demo chỉ đọc. Kết nối Supabase để lưu phân công seller.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const supabase = createSupabaseBrowserClient();
      const { error: rpcError } = await supabase.rpc('rpc_update_seller_members', {
        p_seller_id: scopeSeller.id,
        p_members: selectedMemberIds.map((memberId) => ({
          member_id: memberId,
          is_manager: managerMemberIds.includes(memberId),
        })),
      });
      if (rpcError) {
        setError(commandMessage(rpcError, 'Không thể cập nhật phân công seller.'));
        return;
      }
      setScopeSeller(null);
      router.refresh();
    } catch {
      setError('Không thể kết nối để cập nhật phân công seller.');
    } finally {
      setSubmitting(false);
    }
  }

  async function updateSeller(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!editingSeller) return;
    if (source === 'demo') {
      setError('Chế độ demo chỉ đọc. Kết nối Supabase để cập nhật seller.');
      return;
    }
    const form = new FormData(event.currentTarget);
    setSubmitting(true);
    setError(null);
    try {
      const supabase = createSupabaseBrowserClient();
      const { error: rpcError } = await supabase.rpc('rpc_create_or_update_seller', {
        p_organization_id: organizationId,
        p_seller: {
          id: editingSeller.id,
          code: String(form.get('code') ?? '').trim(),
          name: String(form.get('name') ?? '').trim(),
          platform: String(form.get('platform') ?? ''),
          brand_label: String(form.get('brand_label') ?? '').trim(),
          shop_url: String(form.get('shop_url') ?? '').trim(),
          archived: form.get('archived') === 'on',
        },
        p_expected_version: editingSeller.version,
      });
      if (rpcError) {
        setError(commandMessage(rpcError, 'Không thể cập nhật seller.'));
        return;
      }
      setEditingSeller(null);
      router.refresh();
    } catch {
      setError('Không thể kết nối để cập nhật seller.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="management-section seller-workspace" aria-labelledby="seller-list-title">
      <div className="management-section-header">
        <div>
          <p className="workspace-eyebrow">Seller workspace</p>
          <h2 id="seller-list-title">Không gian vận hành theo seller</h2>
          <p>Chọn seller để xem công việc và đội ngũ đúng phạm vi được cấp.</p>
        </div>
        {isAdmin ? (
          <Button disabled={source === 'demo'} onClick={() => setCreateOpen(true)}>
            {source === 'demo' ? 'Tạo seller · Demo' : 'Tạo seller'}
          </Button>
        ) : null}
      </div>

      {source === 'demo' ? (
        <p className="management-helper">Chế độ demo · danh sách mẫu, thao tác ghi đang khóa.</p>
      ) : null}

      {sellers.length === 0 ? (
        <div className="management-empty">
          <h3>Chưa có seller nào trong phạm vi</h3>
          <p>
            {isAdmin
              ? 'Tạo seller đầu tiên để bắt đầu cấu hình team.'
              : 'Liên hệ admin để được cấp seller scope.'}
          </p>
        </div>
      ) : (
        <div className="seller-workspace-layout">
          <nav className="seller-workspace-nav" aria-label="Danh sách seller">
            {sellers.slice(0, 8).map((seller) => {
              const assigned = activeMembers.filter((member) => sellerScopeFor(member, seller.id));
              const sellerOpenTasks = tasks.filter(
                (task) => task.seller_id === seller.id && !taskIsTerminal(task),
              );
              return (
                <button
                  className={seller.id === selectedSeller?.id ? 'is-active' : ''}
                  key={seller.id}
                  onClick={() => {
                    setSelectedSellerId(seller.id);
                    setSellerTab('tasks');
                  }}
                  type="button"
                >
                  <span>
                    <strong>{seller.name}</strong>
                    <small>
                      {platformLabel(seller.platform)} · {assigned.length} nhân sự
                    </small>
                  </span>
                  <em>{sellerOpenTasks.length}</em>
                </button>
              );
            })}
            {sellers.length > 8 ? (
              <p className="seller-nav-more">+ {sellers.length - 8} seller khác</p>
            ) : null}
          </nav>

          {selectedSeller ? (
            <div className="seller-workspace-main">
              <header className="seller-workspace-header">
                <div>
                  <div className="seller-workspace-kicker">
                    <span className="seller-code">{selectedSeller.code}</span>
                    <StatusBadge tone={selectedSeller.archived_at ? 'warning' : 'success'}>
                      {selectedSeller.archived_at ? 'Đã lưu trữ' : 'Đang hoạt động'}
                    </StatusBadge>
                  </div>
                  <h3>{selectedSeller.name}</h3>
                  <p>
                    {platformLabel(selectedSeller.platform)}
                    {selectedSeller.brand_label ? ` · ${selectedSeller.brand_label}` : ''}
                  </p>
                </div>
                <div className="seller-workspace-actions">
                  <Link
                    className="ui-button ui-button-secondary"
                    href={`/tasks?seller=${selectedSeller.id}`}
                  >
                    Mở tất cả công việc
                  </Link>
                  {role !== 'employee' ? (
                    <Button
                      disabled={source === 'demo'}
                      onClick={() => {
                        setEditingSeller(selectedSeller);
                        setError(null);
                      }}
                      variant="ghost"
                    >
                      Chỉnh sửa
                    </Button>
                  ) : null}
                  {isAdmin ? (
                    <Button
                      disabled={source === 'demo'}
                      onClick={() => openScopeEditor(selectedSeller)}
                      variant="ghost"
                    >
                      Phân công đội ngũ
                    </Button>
                  ) : null}
                </div>
              </header>

              <div className="seller-workspace-tabs" role="tablist" aria-label="Khu vực seller">
                <button
                  aria-selected={sellerTab === 'tasks'}
                  className={sellerTab === 'tasks' ? 'is-active' : ''}
                  onClick={() => setSellerTab('tasks')}
                  role="tab"
                  type="button"
                >
                  Công việc
                </button>
                <Link href="/recurring-tasks">Daily tasks</Link>
                <button
                  aria-selected={sellerTab === 'members'}
                  className={sellerTab === 'members' ? 'is-active' : ''}
                  onClick={() => setSellerTab('members')}
                  role="tab"
                  type="button"
                >
                  Thành viên
                </button>
                <button
                  aria-selected={sellerTab === 'overview'}
                  className={sellerTab === 'overview' ? 'is-active' : ''}
                  onClick={() => setSellerTab('overview')}
                  role="tab"
                  type="button"
                >
                  Tổng quan
                </button>
              </div>

              <div className="seller-summary-strip" aria-label="Tổng quan seller">
                <div>
                  <span>Task hôm nay</span>
                  <strong>{todaySelectedSellerTasks.length}</strong>
                </div>
                <div>
                  <span>Quá hạn</span>
                  <strong>{overdueSelectedSellerTasks.length}</strong>
                </div>
                <div>
                  <span>Chờ duyệt</span>
                  <strong>{reviewSelectedSellerTasks.length}</strong>
                </div>
                <div>
                  <span>Người phụ trách</span>
                  <strong>{selectedSellerMembers.length}</strong>
                </div>
              </div>

              {sellerTab === 'tasks' ? (
                <div className="seller-task-list" role="list" aria-label="Công việc seller">
                  {openSelectedSellerTasks.length === 0 ? (
                    <div className="seller-workspace-empty">Không có công việc đang mở.</div>
                  ) : (
                    openSelectedSellerTasks.slice(0, 10).map((task) => (
                      <Link
                        className="seller-task-row"
                        href={`/tasks/${task.id}`}
                        key={task.id}
                        role="listitem"
                      >
                        <div>
                          <small>{task.task_number}</small>
                          <strong>{task.title}</strong>
                        </div>
                        <span>{task.assignee_name}</span>
                        <span>{compactDateTime(task.due_at, timezone)}</span>
                        <StatusBadge tone={taskStatusTone(task.status)}>
                          {taskStatusLabel(task.status)}
                        </StatusBadge>
                      </Link>
                    ))
                  )}
                </div>
              ) : null}

              {sellerTab === 'members' ? (
                <div className="seller-member-list" role="list" aria-label="Thành viên seller">
                  {selectedSellerMembers.length === 0 ? (
                    <div className="seller-workspace-empty">
                      Seller chưa có nhân sự trong scope.
                    </div>
                  ) : (
                    selectedSellerMembers.map((member) => {
                      const scope = sellerScopeFor(member, selectedSeller.id);
                      const openTasks = openSelectedSellerTasks.filter(
                        (task) => task.assignee_member_id === member.member_id,
                      ).length;
                      return (
                        <div className="seller-member-row" key={member.member_id} role="listitem">
                          <div>
                            <strong>{member.display_name}</strong>
                            <small>{member.employee_code}</small>
                          </div>
                          <span>
                            {scope?.is_manager ? 'Quản lý seller' : roleLabel(member.role)}
                          </span>
                          <span>{openTasks} task đang mở</span>
                        </div>
                      );
                    })
                  )}
                </div>
              ) : null}

              {sellerTab === 'overview' ? (
                <div className="seller-overview-grid">
                  <div>
                    <span>Tổng công việc trong dữ liệu hiện tại</span>
                    <strong>{selectedSellerTasks.length}</strong>
                  </div>
                  <div>
                    <span>Đang mở</span>
                    <strong>{openSelectedSellerTasks.length}</strong>
                  </div>
                  <div>
                    <span>Platform</span>
                    <strong>{platformLabel(selectedSeller.platform)}</strong>
                  </div>
                  <div>
                    <span>Brand</span>
                    <strong>{selectedSeller.brand_label ?? 'Chưa cấu hình'}</strong>
                  </div>
                </div>
              ) : null}
            </div>
          ) : null}
        </div>
      )}

      <Drawer
        footer={
          <>
            <Button onClick={() => setCreateOpen(false)} variant="secondary">
              Hủy
            </Button>
            <Button disabled={isSubmitting} form="create-seller-form" type="submit">
              {isSubmitting ? 'Đang tạo…' : 'Tạo seller'}
            </Button>
          </>
        }
        onClose={() => setCreateOpen(false)}
        open={isCreateOpen}
        title="Tạo seller"
      >
        <form className="management-form" id="create-seller-form" onSubmit={createSeller}>
          <Input
            label="Mã seller"
            maxLength={40}
            name="code"
            placeholder="VD: BOMAX-SHP"
            required
          />
          <Input label="Tên seller" maxLength={160} name="name" required />
          <Select label="Nền tảng" name="platform" options={platformOptions} required />
          <Input label="Nhãn thương hiệu (tuỳ chọn)" maxLength={120} name="brand_label" />
          <Input label="Đường dẫn shop (tuỳ chọn)" maxLength={2000} name="shop_url" type="url" />
          {error ? <p className="auth-error">{error}</p> : null}
        </form>
      </Drawer>

      <Drawer
        footer={
          <>
            <Button onClick={() => setEditingSeller(null)} variant="secondary">
              Hủy
            </Button>
            <Button disabled={isSubmitting} form="edit-seller-form" type="submit">
              {isSubmitting ? 'Đang lưu…' : 'Lưu seller'}
            </Button>
          </>
        }
        onClose={() => setEditingSeller(null)}
        open={Boolean(editingSeller)}
        title={editingSeller ? `Chỉnh sửa · ${editingSeller.name}` : 'Chỉnh sửa seller'}
      >
        {editingSeller ? (
          <form className="management-form" id="edit-seller-form" onSubmit={updateSeller}>
            <Input
              defaultValue={editingSeller.code}
              label="Mã seller"
              maxLength={40}
              name="code"
              required
            />
            <Input
              defaultValue={editingSeller.name}
              label="Tên seller"
              maxLength={160}
              name="name"
              required
            />
            <Select
              defaultValue={editingSeller.platform}
              label="Nền tảng"
              name="platform"
              options={platformOptions}
              required
            />
            <Input
              defaultValue={editingSeller.brand_label ?? ''}
              label="Nhãn thương hiệu (tuỳ chọn)"
              maxLength={120}
              name="brand_label"
            />
            <Input
              defaultValue={editingSeller.shop_url ?? ''}
              label="Đường dẫn shop (tuỳ chọn)"
              maxLength={2000}
              name="shop_url"
              type="url"
            />
            {isAdmin ? (
              <Checkbox
                defaultChecked={Boolean(editingSeller.archived_at)}
                label="Lưu trữ seller (không xóa lịch sử)"
                name="archived"
              />
            ) : null}
            {error ? <p className="auth-error">{error}</p> : null}
          </form>
        ) : null}
      </Drawer>

      <Drawer
        footer={
          <>
            <Button onClick={() => setScopeSeller(null)} variant="secondary">
              Hủy
            </Button>
            <Button disabled={isSubmitting} onClick={saveSellerScope}>
              {isSubmitting ? 'Đang lưu…' : 'Lưu phân công'}
            </Button>
          </>
        }
        onClose={() => setScopeSeller(null)}
        open={Boolean(scopeSeller)}
        title={scopeSeller ? `Đội ngũ · ${scopeSeller.name}` : 'Đội ngũ seller'}
      >
        <div className="management-form">
          <p className="management-helper">
            Chỉ admin thay đổi seller scope và quyền quản lý seller.
          </p>
          {activeMembers.map((member) => {
            const selected = selectedMemberIds.includes(member.member_id);
            const manager = managerMemberIds.includes(member.member_id);
            return (
              <div className="scope-member-row" key={member.member_id}>
                <Checkbox
                  checked={selected}
                  label={`${member.display_name} · ${roleLabel(member.role)}`}
                  onChange={(event) => {
                    setSelectedMemberIds((current) =>
                      event.target.checked
                        ? [...current, member.member_id]
                        : current.filter((id) => id !== member.member_id),
                    );
                    if (!event.target.checked) {
                      setManagerMemberIds((current) =>
                        current.filter((id) => id !== member.member_id),
                      );
                    }
                  }}
                />
                {member.role !== 'employee' ? (
                  <Checkbox
                    checked={manager}
                    disabled={!selected}
                    label="Quản lý seller"
                    onChange={(event) =>
                      setManagerMemberIds((current) =>
                        event.target.checked
                          ? [...current, member.member_id]
                          : current.filter((id) => id !== member.member_id),
                      )
                    }
                  />
                ) : null}
              </div>
            );
          })}
          {scopeMembers.length === 0 ? (
            <p className="management-helper">Chưa có người trong seller này.</p>
          ) : null}
          {error ? <p className="auth-error">{error}</p> : null}
        </div>
      </Drawer>
    </section>
  );
}

export function TeamManagementPanel({
  members,
  organizationId,
  sellers,
  role,
  source,
  tasks,
}: {
  members: MemberDirectoryEntry[];
  organizationId: string;
  role: OrganizationRole;
  sellers: SellerSummary[];
  source: WorkspaceDataSource;
  tasks: TaskListItem[];
}) {
  const router = useRouter();
  const isAdmin = role === 'admin';
  const [teamQuery, setTeamQuery] = useState('');
  const [viewingMember, setViewingMember] = useState<MemberDirectoryEntry | null>(null);
  const [inviteOpen, setInviteOpen] = useState(false);
  const [editingMember, setEditingMember] = useState<MemberDirectoryEntry | null>(null);
  const [deactivatingMember, setDeactivatingMember] = useState<MemberDirectoryEntry | null>(null);
  const [editRole, setEditRole] = useState<OrganizationRole>('employee');
  const [editCapabilities, setEditCapabilities] = useState({
    can_manage_attendance: false,
    can_approve_requests: false,
    can_view_attendance_evidence: false,
  });
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setSubmitting] = useState(false);
  const [inviteScopeIds, setInviteScopeIds] = useState<string[]>([]);
  const [editScopeIds, setEditScopeIds] = useState<string[]>([]);
  const [editManagerScopeIds, setEditManagerScopeIds] = useState<string[]>([]);
  const normalizedTeamQuery = teamQuery.trim().toLocaleLowerCase('vi-VN');
  const visibleMembers = members.filter((member) => {
    if (!normalizedTeamQuery) return true;
    return [
      member.display_name,
      member.employee_code,
      roleLabel(member.role),
      ...member.seller_scope.map((scope) => scope.name),
    ].some((value) => value.toLocaleLowerCase('vi-VN').includes(normalizedTeamQuery));
  });

  function memberOpenTaskCount(memberId: string) {
    return tasks.filter((task) => task.assignee_member_id === memberId && !taskIsTerminal(task))
      .length;
  }

  function openMemberEditor(member: MemberDirectoryEntry) {
    setEditingMember(member);
    setEditRole(member.role);
    setEditCapabilities({
      can_manage_attendance: member.capabilities?.can_manage_attendance ?? false,
      can_approve_requests: member.capabilities?.can_approve_requests ?? false,
      can_view_attendance_evidence: member.capabilities?.can_view_attendance_evidence ?? false,
    });
    setEditScopeIds(member.seller_scope.map((scope) => scope.seller_id));
    setEditManagerScopeIds(
      member.seller_scope.filter((scope) => scope.is_manager).map((scope) => scope.seller_id),
    );
    setError(null);
  }

  async function inviteMember(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (source === 'demo') {
      setError('Chế độ demo chỉ đọc. Kết nối Supabase để gửi lời mời thật.');
      return;
    }
    const form = new FormData(event.currentTarget);
    setSubmitting(true);
    setError(null);
    try {
      const response = await fetch('/api/admin/invitations', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          organization_id: organizationId,
          email: String(form.get('email') ?? '').trim(),
          role: String(form.get('role') ?? 'employee'),
          capabilities: {},
          seller_scope: inviteScopeIds.map((sellerId) => ({
            seller_id: sellerId,
            is_manager: false,
          })),
        }),
      });
      const payload = (await response.json().catch(() => ({}))) as CommandError;
      if (!response.ok) {
        setError(responseMessage(payload, 'Không thể gửi lời mời.'));
        return;
      }
      setInviteOpen(false);
      setInviteScopeIds([]);
      router.refresh();
    } catch {
      setError('Không thể kết nối để gửi lời mời.');
    } finally {
      setSubmitting(false);
    }
  }

  async function saveMemberAccess(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!editingMember) return;
    if (source === 'demo') {
      setError('Chế độ demo chỉ đọc. Kết nối Supabase để cập nhật quyền nhân sự.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const supabase = createSupabaseBrowserClient();
      const { error: rpcError } = await supabase.rpc('rpc_update_member_access', {
        p_member_id: editingMember.member_id,
        p_role: editRole,
        p_capabilities: editCapabilities,
        p_scope: editScopeIds.map((sellerId) => ({
          seller_id: sellerId,
          is_manager: editRole === 'employee' ? false : editManagerScopeIds.includes(sellerId),
        })),
        p_expected_version: editingMember.version,
      });
      if (rpcError) {
        setError(commandMessage(rpcError, 'Không thể cập nhật quyền nhân sự.'));
        return;
      }
      setEditingMember(null);
      router.refresh();
    } catch {
      setError('Không thể kết nối để cập nhật quyền nhân sự.');
    } finally {
      setSubmitting(false);
    }
  }

  async function deactivateMember() {
    if (!deactivatingMember) return;
    if (source === 'demo') {
      setError('Chế độ demo chỉ đọc. Kết nối Supabase để tạm ngừng nhân sự.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const supabase = createSupabaseBrowserClient();
      const { error: rpcError } = await supabase.rpc('rpc_deactivate_member', {
        p_member_id: deactivatingMember.member_id,
        p_handover_plan: {},
        p_expected_version: deactivatingMember.version,
      });
      if (rpcError) {
        setError(commandMessage(rpcError, 'Không thể tạm ngừng nhân sự.'));
        return;
      }
      setDeactivatingMember(null);
      router.refresh();
    } catch {
      setError('Không thể kết nối để tạm ngừng nhân sự.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="management-section team-workspace" aria-labelledby="team-list-title">
      <div className="management-section-header">
        <div>
          <p className="workspace-eyebrow">Team</p>
          <h2 id="team-list-title">Nhân sự trong phạm vi</h2>
          <p>Danh bạ vận hành gọn, không avatar và không hiển thị dữ liệu HR riêng tư.</p>
        </div>
        {isAdmin ? (
          <Button disabled={source === 'demo'} onClick={() => setInviteOpen(true)}>
            {source === 'demo' ? 'Mời nhân sự · Demo' : 'Mời nhân sự'}
          </Button>
        ) : null}
      </div>

      {source === 'demo' ? (
        <p className="management-helper">Chế độ demo · danh bạ mẫu, thao tác quản trị đang khóa.</p>
      ) : null}

      <div className="team-command-bar">
        <Input
          aria-label="Tìm nhân sự"
          onChange={(event) => setTeamQuery(event.target.value)}
          placeholder="Tìm tên, mã nhân sự hoặc seller..."
          value={teamQuery}
        />
        <div className="team-command-meta">
          <span>{visibleMembers.length} nhân sự</span>
          <span>
            {members.filter((member) => member.status === 'active').length} đang hoạt động
          </span>
        </div>
      </div>

      <div className="team-table" role="table" aria-label="Danh sách nhân sự">
        <div className="team-table-head" role="row">
          <span role="columnheader">Tên</span>
          <span role="columnheader">Role</span>
          <span role="columnheader">Seller phụ trách</span>
          <span role="columnheader">Trạng thái</span>
          <span role="columnheader">Task đang mở</span>
          <span aria-hidden="true" />
        </div>
        {visibleMembers.length === 0 ? (
          <div className="team-table-empty">Không tìm thấy nhân sự phù hợp.</div>
        ) : (
          visibleMembers.map((member) => (
            <article className="team-row" key={member.member_id} role="row">
              <button
                className="team-row-main"
                onClick={() => setViewingMember(member)}
                type="button"
              >
                <div className="team-person-cell" role="cell">
                  <strong>{member.display_name}</strong>
                  <span>{member.employee_code}</span>
                </div>
                <div role="cell">
                  <strong className="team-role-label">
                    {member.is_owner ? `Owner · ${roleLabel(member.role)}` : roleLabel(member.role)}
                  </strong>
                </div>
                <div className="team-row-scopes" role="cell">
                  {member.seller_scope.length === 0
                    ? 'Chưa có seller'
                    : member.seller_scope
                        .map((scope) => `${scope.name}${scope.is_manager ? ' · quản lý' : ''}`)
                        .join(', ')}
                </div>
                <div className="team-row-status" role="cell">
                  <StatusBadge tone={member.status === 'active' ? 'success' : 'neutral'}>
                    {member.status === 'active' ? 'Hoạt động' : 'Tạm ngừng'}
                  </StatusBadge>
                </div>
                <div className="team-open-task-count" role="cell">
                  <strong>{memberOpenTaskCount(member.member_id)}</strong>
                </div>
              </button>
              {isAdmin ? (
                <div className="team-row-actions" role="cell">
                  <Button
                    disabled={source === 'demo' || member.is_owner || member.status !== 'active'}
                    onClick={() => openMemberEditor(member)}
                    variant="ghost"
                  >
                    Sửa quyền
                  </Button>
                </div>
              ) : (
                <span aria-hidden="true" />
              )}
            </article>
          ))
        )}
      </div>

      <Drawer
        onClose={() => setViewingMember(null)}
        open={Boolean(viewingMember)}
        size="compact"
        title={viewingMember ? viewingMember.display_name : 'Chi tiết nhân sự'}
      >
        {viewingMember ? (
          <div className="team-detail-drawer">
            <div className="team-detail-heading">
              <span>{viewingMember.employee_code}</span>
              <StatusBadge tone={viewingMember.status === 'active' ? 'success' : 'neutral'}>
                {viewingMember.status === 'active' ? 'Hoạt động' : 'Tạm ngừng'}
              </StatusBadge>
            </div>
            <dl className="team-detail-list">
              <div>
                <dt>Vai trò</dt>
                <dd>
                  {viewingMember.is_owner
                    ? `Owner · ${roleLabel(viewingMember.role)}`
                    : roleLabel(viewingMember.role)}
                </dd>
              </div>
              <div>
                <dt>Task đang mở</dt>
                <dd>{memberOpenTaskCount(viewingMember.member_id)}</dd>
              </div>
              <div>
                <dt>Chuyên môn</dt>
                <dd>Chưa cấu hình</dd>
              </div>
            </dl>
            <section className="team-detail-sellers">
              <h3>Seller phụ trách</h3>
              {viewingMember.seller_scope.length === 0 ? (
                <p>Chưa được cấp seller.</p>
              ) : (
                viewingMember.seller_scope.map((scope) => (
                  <div key={scope.seller_id}>
                    <strong>{scope.name}</strong>
                    <span>{scope.is_manager ? 'Quản lý seller' : 'Thành viên'}</span>
                  </div>
                ))
              )}
            </section>
            {isAdmin ? (
              <div className="team-detail-actions">
                <Button
                  disabled={
                    source === 'demo' || viewingMember.is_owner || viewingMember.status !== 'active'
                  }
                  onClick={() => {
                    setViewingMember(null);
                    openMemberEditor(viewingMember);
                  }}
                  variant="secondary"
                >
                  Sửa quyền truy cập
                </Button>
                <Button
                  disabled={
                    source === 'demo' || viewingMember.is_owner || viewingMember.status !== 'active'
                  }
                  onClick={() => {
                    setViewingMember(null);
                    setDeactivatingMember(viewingMember);
                  }}
                  variant="ghost"
                >
                  Tạm ngừng nhân sự
                </Button>
              </div>
            ) : null}
          </div>
        ) : null}
      </Drawer>

      <Drawer
        footer={
          <>
            <Button onClick={() => setInviteOpen(false)} variant="secondary">
              Hủy
            </Button>
            <Button disabled={isSubmitting} form="invite-member-form" type="submit">
              {isSubmitting ? 'Đang gửi…' : 'Gửi lời mời'}
            </Button>
          </>
        }
        onClose={() => setInviteOpen(false)}
        open={inviteOpen}
        title="Mời nhân sự"
      >
        <form className="management-form" id="invite-member-form" onSubmit={inviteMember}>
          <Input label="Email công việc" name="email" required type="email" />
          <Select label="Vai trò" name="role" options={roleOptions} defaultValue="employee" />
          <div className="management-scope-picker">
            <span>Seller được cấp</span>
            {sellers.map((seller) => (
              <Checkbox
                checked={inviteScopeIds.includes(seller.id)}
                key={seller.id}
                label={`${seller.name} · ${seller.code}`}
                onChange={(event) =>
                  setInviteScopeIds((current) =>
                    event.target.checked
                      ? [...current, seller.id]
                      : current.filter((id) => id !== seller.id),
                  )
                }
              />
            ))}
          </div>
          {error ? <p className="auth-error">{error}</p> : null}
        </form>
      </Drawer>

      <Drawer
        footer={
          <>
            <Button onClick={() => setEditingMember(null)} variant="secondary">
              Hủy
            </Button>
            <Button disabled={isSubmitting} form="member-access-form" type="submit">
              {isSubmitting ? 'Đang lưu…' : 'Lưu quyền'}
            </Button>
          </>
        }
        onClose={() => setEditingMember(null)}
        open={Boolean(editingMember)}
        title={editingMember ? `Quyền · ${editingMember.display_name}` : 'Quyền nhân sự'}
      >
        {editingMember ? (
          <form className="management-form" id="member-access-form" onSubmit={saveMemberAccess}>
            <Select
              label="Vai trò"
              name="role"
              onChange={(event) => {
                const nextRole = event.target.value as OrganizationRole;
                setEditRole(nextRole);
                if (editingMember.role === 'admin' && nextRole !== 'admin') {
                  setEditCapabilities({
                    can_manage_attendance: false,
                    can_approve_requests: false,
                    can_view_attendance_evidence: false,
                  });
                }
              }}
              options={roleOptions}
              value={editRole}
            />
            <div className="management-scope-picker">
              <span>HR capabilities</span>
              <Checkbox
                checked={editRole === 'admin' || editCapabilities.can_manage_attendance}
                disabled={editRole === 'admin'}
                label="Quản lý chấm công"
                name="can_manage_attendance"
                onChange={(event) =>
                  setEditCapabilities((current) => ({
                    ...current,
                    can_manage_attendance: event.target.checked,
                  }))
                }
              />
              <Checkbox
                checked={editRole === 'admin' || editCapabilities.can_approve_requests}
                disabled={editRole === 'admin'}
                label="Duyệt đơn"
                name="can_approve_requests"
                onChange={(event) =>
                  setEditCapabilities((current) => ({
                    ...current,
                    can_approve_requests: event.target.checked,
                  }))
                }
              />
              <Checkbox
                checked={editRole === 'admin' || editCapabilities.can_view_attendance_evidence}
                disabled={editRole === 'admin'}
                label="Xem evidence chấm công"
                name="can_view_attendance_evidence"
                onChange={(event) =>
                  setEditCapabilities((current) => ({
                    ...current,
                    can_view_attendance_evidence: event.target.checked,
                  }))
                }
              />
            </div>
            <div className="management-scope-picker">
              <span>Seller scope</span>
              {sellers.map((seller) => {
                const selected = editScopeIds.includes(seller.id);
                const manager = editManagerScopeIds.includes(seller.id);
                return (
                  <div className="scope-member-row" key={seller.id}>
                    <Checkbox
                      checked={selected}
                      label={`${seller.name} · ${seller.code}`}
                      onChange={(event) => {
                        setEditScopeIds((current) =>
                          event.target.checked
                            ? [...current, seller.id]
                            : current.filter((id) => id !== seller.id),
                        );
                        if (!event.target.checked)
                          setEditManagerScopeIds((current) =>
                            current.filter((id) => id !== seller.id),
                          );
                      }}
                    />
                    <Checkbox
                      checked={manager}
                      disabled={!selected}
                      label="Quản lý seller"
                      onChange={(event) =>
                        setEditManagerScopeIds((current) =>
                          event.target.checked
                            ? [...current, seller.id]
                            : current.filter((id) => id !== seller.id),
                        )
                      }
                    />
                  </div>
                );
              })}
            </div>
            {error ? <p className="auth-error">{error}</p> : null}
          </form>
        ) : null}
      </Drawer>

      <ConfirmDialog
        confirmLabel={isSubmitting ? 'Đang tạm ngừng…' : 'Tạm ngừng'}
        onCancel={() => setDeactivatingMember(null)}
        onConfirm={deactivateMember}
        open={Boolean(deactivatingMember)}
        title="Tạm ngừng nhân sự"
      >
        <p>
          Membership sẽ mất quyền ngay ở request tiếp theo. Task, template và bàn giao chi tiết sẽ
          được kiểm tra khi module công việc được bật.
        </p>
        {error ? <p className="auth-error">{error}</p> : null}
      </ConfirmDialog>
    </section>
  );
}
