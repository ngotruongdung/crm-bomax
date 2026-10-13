export const bootstrapStatus = {
  code: 'P00_BOOTSTRAPPED',
  label: 'Bootstrap OpsDesk đã sẵn sàng',
} as const;

export const isIsoDate = (value: string): boolean => {
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().startsWith(value);
};

export type MembershipCapabilities = {
  can_manage_attendance: boolean;
  can_approve_requests: boolean;
  can_view_attendance_evidence: boolean;
};

export type SellerScopeAccess = {
  seller_id: string;
  is_manager: boolean;
};

export const canManageOrganization = (role: 'admin' | 'manager' | 'employee'): boolean =>
  role === 'admin';

export const effectiveCapabilities = (
  role: 'admin' | 'manager' | 'employee',
  capabilities: MembershipCapabilities,
): MembershipCapabilities => {
  if (role === 'admin') {
    return {
      can_manage_attendance: true,
      can_approve_requests: true,
      can_view_attendance_evidence: true,
    };
  }

  return capabilities;
};

export const canManageSeller = (
  role: 'admin' | 'manager' | 'employee',
  scope: SellerScopeAccess | undefined,
): boolean => role === 'admin' || (role === 'manager' && scope?.is_manager === true);

export * from './timesheet';
export * from './notification';
export * from './report';
export * from './security';
