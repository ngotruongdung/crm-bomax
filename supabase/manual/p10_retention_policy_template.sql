-- P10 manual setup template. Review these values with your real privacy/legal policy before production.
-- The values below are DEMO/TEST examples only. Replace organization/member UUIDs and retention days.

insert into public.policy_versions (
  organization_id,
  policy_kind,
  version_number,
  effective_from,
  config,
  created_by
)
values (
  'REPLACE_ORGANIZATION_UUID'::uuid,
  'retention',
  1,
  timezone('utc', now()),
  jsonb_build_object(
    'attendance_photo_retention_days', 30,
    'request_evidence_retention_days', 30,
    'task_file_retention_days', 90,
    'export_retention_days', 7
  ),
  'REPLACE_ADMIN_MEMBER_UUID'::uuid
);
