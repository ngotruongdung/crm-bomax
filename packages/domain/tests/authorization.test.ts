import { describe, expect, it } from 'vitest';
import { canManageOrganization, canManageSeller, effectiveCapabilities } from '../src/index';

describe('organization authorization primitives', () => {
  it('does not infer admin access from a manager role', () => {
    expect(canManageOrganization('manager')).toBe(false);
    expect(canManageOrganization('employee')).toBe(false);
    expect(canManageOrganization('admin')).toBe(true);
  });

  it('gives admin the fixed baseline capabilities', () => {
    expect(
      effectiveCapabilities('admin', {
        can_manage_attendance: false,
        can_approve_requests: false,
        can_view_attendance_evidence: false,
      }),
    ).toEqual({
      can_manage_attendance: true,
      can_approve_requests: true,
      can_view_attendance_evidence: true,
    });
  });

  it('does not infer seller management from seller membership alone', () => {
    expect(canManageSeller('admin', undefined)).toBe(true);
    expect(canManageSeller('manager', { seller_id: 'seller-a', is_manager: true })).toBe(true);
    expect(canManageSeller('manager', { seller_id: 'seller-a', is_manager: false })).toBe(false);
    expect(canManageSeller('employee', { seller_id: 'seller-a', is_manager: true })).toBe(false);
  });
});
