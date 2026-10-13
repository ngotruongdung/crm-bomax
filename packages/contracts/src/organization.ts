import { z } from 'zod';

export const organizationRoleSchema = z.enum(['admin', 'manager', 'employee']);
export type OrganizationRole = z.infer<typeof organizationRoleSchema>;

export const membershipStatusSchema = z.enum(['invited', 'active', 'inactive']);
export type MembershipStatus = z.infer<typeof membershipStatusSchema>;

export const organizationStatusSchema = z.enum(['active', 'suspended']);
export type OrganizationStatus = z.infer<typeof organizationStatusSchema>;

export const capabilitySchema = z.enum([
  'can_manage_attendance',
  'can_approve_requests',
  'can_view_attendance_evidence',
]);
export type Capability = z.infer<typeof capabilitySchema>;

export const membershipCapabilitiesSchema = z.object({
  can_manage_attendance: z.boolean().optional(),
  can_approve_requests: z.boolean().optional(),
  can_view_attendance_evidence: z.boolean().optional(),
});
export type MembershipCapabilities = z.infer<typeof membershipCapabilitiesSchema>;

export const sellerPlatformSchema = z.enum(['shopee', 'tiktok_shop', 'lazada', 'other']);
export type SellerPlatform = z.infer<typeof sellerPlatformSchema>;

export const sellerScopeSchema = z.object({
  seller_id: z.string().uuid(),
  code: z.string(),
  name: z.string(),
  platform: sellerPlatformSchema,
  is_manager: z.boolean(),
});
export type SellerScope = z.infer<typeof sellerScopeSchema>;

export const sellerScopeInputSchema = z.object({
  seller_id: z.string().uuid(),
  is_manager: z.boolean().optional(),
});
export type SellerScopeInput = z.infer<typeof sellerScopeInputSchema>;

export const invitationValidationSchema = z.object({
  invitation_id: z.string().uuid(),
  organization_id: z.string().uuid(),
  organization_name: z.string(),
  organization_slug: z.string(),
  email: z.string().email(),
  role: organizationRoleSchema,
  capabilities: membershipCapabilitiesSchema,
  seller_scope: z.array(sellerScopeSchema),
  expires_at: z.string().datetime({ offset: true }),
});
export type InvitationValidation = z.infer<typeof invitationValidationSchema>;

export const invitationAcceptanceSchema = z.object({
  member_id: z.string().uuid(),
  organization_id: z.string().uuid(),
  role: organizationRoleSchema,
  status: z.literal('active'),
  already_accepted: z.boolean(),
});
export type InvitationAcceptance = z.infer<typeof invitationAcceptanceSchema>;

export const memberDirectoryEntrySchema = z.object({
  member_id: z.string().uuid(),
  employee_code: z.string(),
  display_name: z.string(),
  role: organizationRoleSchema,
  status: membershipStatusSchema,
  is_owner: z.boolean(),
  capabilities: membershipCapabilitiesSchema.nullable(),
  seller_scope: z.array(sellerScopeSchema),
  scope_version: z.number().int().positive(),
  version: z.number().int().positive(),
});
export type MemberDirectoryEntry = z.infer<typeof memberDirectoryEntrySchema>;

export const memberDirectorySchema = z.array(memberDirectoryEntrySchema);

export const organizationContextSchema = z.object({
  organization_id: z.string().uuid(),
  organization_name: z.string(),
  organization_slug: z.string(),
  timezone: z.string(),
  member_id: z.string().uuid(),
  user_id: z.string().uuid(),
  employee_code: z.string(),
  display_name: z.string(),
  role: organizationRoleSchema,
  status: z.literal('active'),
  is_owner: z.boolean(),
  capabilities: z.array(capabilitySchema),
  seller_scope: z.array(sellerScopeSchema),
  scope_version: z.number().int().positive(),
  server_now: z.string(),
});

export type OrganizationContext = z.infer<typeof organizationContextSchema>;
