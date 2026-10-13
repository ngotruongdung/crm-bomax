import { z } from 'zod';

export const attendanceActionSchema = z.enum(['check_in', 'check_out']);
export type AttendanceAction = z.infer<typeof attendanceActionSchema>;

export const attendanceModeSchema = z.enum(['office', 'remote']);
export type AttendanceMode = z.infer<typeof attendanceModeSchema>;

export const wifiReadResultSchema = z.discriminatedUnion('status', [
  z.object({
    status: z.literal('available'),
    ssid: z.string().min(1),
    bssid: z.string().min(1),
    capturedAtDevice: z.string().datetime({ offset: true }),
  }),
  z.object({
    status: z.enum(['permission_denied', 'location_disabled', 'not_wifi', 'unavailable']),
    message: z.string().max(500).optional(),
  }),
]);

export type WifiReadResult = z.infer<typeof wifiReadResultSchema>;

export interface OfficeWifiModule {
  getCurrentNetwork(): Promise<WifiReadResult>;
  openPermissionSettings(): Promise<void>;
}

export const attendanceDeviceRegistrationRequestSchema = z.object({
  organization_id: z.string().uuid(),
  installation_id: z.string().min(8).max(240),
  platform: z.enum(['web', 'ios', 'android']),
  label: z.string().max(120).default(''),
});

export const attendanceDeviceRegistrationResponseSchema = z.object({
  device_id: z.string().uuid(),
  registered_at: z.string().datetime({ offset: true }),
});

export const attendanceChallengeRequestSchema = z.object({
  organization_id: z.string().uuid(),
  shift_instance_id: z.string().uuid(),
  action: attendanceActionSchema,
  mode: attendanceModeSchema,
  device_id: z.string().uuid(),
});

export type AttendanceChallengeRequest = z.infer<typeof attendanceChallengeRequestSchema>;

export const attendanceChallengeResponseSchema = z.object({
  challenge_id: z.string().uuid(),
  nonce: z.string().min(16),
  expires_at: z.string().datetime({ offset: true }),
  server_now: z.string().datetime({ offset: true }),
  requirements: z.object({
    wifi_required: z.boolean(),
    trusted_network_required: z.boolean(),
    selfie_required: z.boolean(),
    laptop_session_required: z.boolean(),
  }),
});

export type AttendanceChallengeResponse = z.infer<typeof attendanceChallengeResponseSchema>;

export const attendanceUploadIntentRequestSchema = z.object({
  challenge_id: z.string().uuid(),
  mime_type: z.enum(['image/jpeg', 'image/webp']),
  size_bytes: z
    .number()
    .int()
    .positive()
    .max(5 * 1024 * 1024),
});

export type AttendanceUploadIntentRequest = z.infer<typeof attendanceUploadIntentRequestSchema>;

export const attendanceUploadIntentResponseSchema = z.object({
  file_id: z.string().uuid(),
  bucket_id: z.string().min(1),
  object_path: z.string().min(1),
  signed_url: z.string().url(),
  token: z.string().min(1),
  expires_at: z.string().datetime({ offset: true }),
});

export type AttendanceUploadIntentResponse = z.infer<typeof attendanceUploadIntentResponseSchema>;

export const attendanceFinalizeRequestSchema = z.object({
  challenge_id: z.string().uuid(),
  nonce: z.string().min(16),
  device_id: z.string().uuid(),
  idempotency_key: z.string().min(8).max(240),
  // Native apps send a freshly-read SSID/BSSID claim. A browser cannot read those
  // values reliably, so office web attendance omits this field and is verified by a
  // trusted source IP against an administrator-configured office CIDR instead.
  wifi_claim: z
    .object({
      ssid: z.string().min(1),
      bssid: z.string().min(1),
      captured_at_device: z.string().datetime({ offset: true }),
    })
    .optional(),
  file_id: z.string().uuid().optional(),
  laptop_session_id: z.string().uuid().optional(),
});

export type AttendanceFinalizeRequest = z.infer<typeof attendanceFinalizeRequestSchema>;

export const attendanceCommitSchema = z.object({
  event_id: z.string().uuid(),
  session_id: z.string().uuid(),
  event_kind: z.enum(['check_in', 'check_out']),
  mode: attendanceModeSchema,
  effective_at: z.string().datetime({ offset: true }),
  recorded_at: z.string().datetime({ offset: true }),
  duplicate: z.boolean().default(false),
});

export type AttendanceCommit = z.infer<typeof attendanceCommitSchema>;

export const attendanceDaySchema = z.object({
  member_id: z.string().uuid(),
  work_date: z.string().date(),
  server_now: z.string().datetime({ offset: true }),
  shift: z
    .object({
      id: z.string().uuid(),
      starts_at: z.string().datetime({ offset: true }),
      ends_at: z.string().datetime({ offset: true }),
      scheduled_seconds: z.number().int().nonnegative(),
      allowed_mode: z.enum(['office', 'remote', 'hybrid']),
      office_id: z.string().uuid().nullable(),
      status: z.enum(['scheduled', 'canceled', 'closed']),
    })
    .nullable(),
  sessions: z.array(
    z.object({
      id: z.string().uuid(),
      starts_at: z.string().datetime({ offset: true }),
      ends_at: z.string().datetime({ offset: true }).nullable(),
      mode: attendanceModeSchema,
      status: z.enum(['open', 'closed', 'superseded']),
    }),
  ),
  events: z.array(
    z.object({
      id: z.string().uuid(),
      event_kind: z.enum(['check_in', 'check_out', 'adjustment']),
      effective_at: z.string().datetime({ offset: true }),
      recorded_at: z.string().datetime({ offset: true }),
      mode: z.enum(['office', 'remote', 'manual_adjustment']),
      verification_status: z.enum(['verified', 'approved_adjustment', 'flagged']),
    }),
  ),
});

export type AttendanceDay = z.infer<typeof attendanceDaySchema>;

export const remoteLaptopSessionSchema = z.object({
  session_id: z.string().uuid(),
  display_code: z.string().regex(/^\d{6}$/),
  expires_at: z.string().datetime({ offset: true }),
  server_now: z.string().datetime({ offset: true }),
});

export type RemoteLaptopSession = z.infer<typeof remoteLaptopSessionSchema>;

export const remoteLaptopSessionRequestSchema = z.object({
  organization_id: z.string().uuid(),
  shift_instance_id: z.string().uuid(),
});

export const remoteLaptopSessionResolveRequestSchema = z.object({
  organization_id: z.string().uuid(),
  shift_instance_id: z.string().uuid(),
  display_code: z.string().regex(/^\d{6}$/),
});

export const remoteLaptopSessionResolveResponseSchema = z.object({
  session_id: z.string().uuid(),
  expires_at: z.string().datetime({ offset: true }),
});

export type RemoteLaptopSessionResolveResponse = z.infer<
  typeof remoteLaptopSessionResolveResponseSchema
>;
