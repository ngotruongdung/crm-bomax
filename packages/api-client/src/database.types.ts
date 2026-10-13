export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  public: {
    Tables: {
      organizations: {
        Row: {
          id: string;
          name: string;
          slug: string;
          timezone: string;
          owner_member_id: string | null;
          status: string;
          settings_version: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          slug: string;
          timezone?: string;
          owner_member_id?: string | null;
          status?: string;
          settings_version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          slug?: string;
          timezone?: string;
          owner_member_id?: string | null;
          status?: string;
          settings_version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'organizations_owner_member_fk';
            columns: ['id', 'owner_member_id'];
            isOneToOne: false;
            referencedRelation: 'organization_members';
            referencedColumns: ['organization_id', 'id'];
          },
        ];
      };
      organization_members: {
        Row: {
          id: string;
          organization_id: string;
          user_id: string;
          employee_code: string;
          display_name: string;
          role: string;
          status: string;
          can_manage_attendance: boolean;
          can_approve_requests: boolean;
          can_view_attendance_evidence: boolean;
          scope_version: number;
          version: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          user_id: string;
          employee_code: string;
          display_name: string;
          role?: string;
          status?: string;
          can_manage_attendance?: boolean;
          can_approve_requests?: boolean;
          can_view_attendance_evidence?: boolean;
          scope_version?: number;
          version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          user_id?: string;
          employee_code?: string;
          display_name?: string;
          role?: string;
          status?: string;
          can_manage_attendance?: boolean;
          can_approve_requests?: boolean;
          can_view_attendance_evidence?: boolean;
          scope_version?: number;
          version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'organization_members_organization_id_fkey';
            columns: ['organization_id'];
            isOneToOne: false;
            referencedRelation: 'organizations';
            referencedColumns: ['id'];
          },
        ];
      };
      member_hr_settings: {
        Row: {
          member_id: string;
          organization_id: string;
          employment_start: string;
          employment_end: string | null;
          standard_day_minutes: number;
          default_work_mode: string;
          policy_version_id: string | null;
          version: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          member_id: string;
          organization_id: string;
          employment_start: string;
          employment_end?: string | null;
          standard_day_minutes?: number;
          default_work_mode?: string;
          policy_version_id?: string | null;
          version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          member_id?: string;
          organization_id?: string;
          employment_start?: string;
          employment_end?: string | null;
          standard_day_minutes?: number;
          default_work_mode?: string;
          policy_version_id?: string | null;
          version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'member_hr_settings_member_id_fkey';
            columns: ['member_id'];
            isOneToOne: true;
            referencedRelation: 'organization_members';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'member_hr_settings_policy_version_fk';
            columns: ['organization_id', 'policy_version_id'];
            isOneToOne: false;
            referencedRelation: 'policy_versions';
            referencedColumns: ['organization_id', 'id'];
          },
        ];
      };
      specialties: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          archived_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          archived_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          archived_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'specialties_organization_id_fkey';
            columns: ['organization_id'];
            isOneToOne: false;
            referencedRelation: 'organizations';
            referencedColumns: ['id'];
          },
        ];
      };
      member_specialties: {
        Row: {
          organization_id: string;
          member_id: string;
          specialty_id: string;
        };
        Insert: {
          organization_id: string;
          member_id: string;
          specialty_id: string;
        };
        Update: {
          organization_id?: string;
          member_id?: string;
          specialty_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'member_specialties_organization_id_member_id_fkey';
            columns: ['organization_id', 'member_id'];
            isOneToOne: false;
            referencedRelation: 'organization_members';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'member_specialties_organization_id_specialty_id_fkey';
            columns: ['organization_id', 'specialty_id'];
            isOneToOne: false;
            referencedRelation: 'specialties';
            referencedColumns: ['organization_id', 'id'];
          },
        ];
      };
      sellers: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          platform: string;
          brand_label: string | null;
          shop_url: string | null;
          archived_at: string | null;
          version: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          platform: string;
          brand_label?: string | null;
          shop_url?: string | null;
          archived_at?: string | null;
          version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          platform?: string;
          brand_label?: string | null;
          shop_url?: string | null;
          archived_at?: string | null;
          version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'sellers_organization_id_fkey';
            columns: ['organization_id'];
            isOneToOne: false;
            referencedRelation: 'organizations';
            referencedColumns: ['id'];
          },
        ];
      };
      seller_members: {
        Row: {
          id: string;
          organization_id: string;
          seller_id: string;
          member_id: string;
          is_manager: boolean;
          active_from: string;
          active_until: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          seller_id: string;
          member_id: string;
          is_manager?: boolean;
          active_from: string;
          active_until?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          seller_id?: string;
          member_id?: string;
          is_manager?: boolean;
          active_from?: string;
          active_until?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'seller_members_organization_id_seller_id_fkey';
            columns: ['organization_id', 'seller_id'];
            isOneToOne: false;
            referencedRelation: 'sellers';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'seller_members_organization_id_member_id_fkey';
            columns: ['organization_id', 'member_id'];
            isOneToOne: false;
            referencedRelation: 'organization_members';
            referencedColumns: ['organization_id', 'id'];
          },
        ];
      };
      tasks: {
        Row: {
          id: string;
          organization_id: string;
          task_number: string;
          batch_id: string | null;
          seller_id: string | null;
          template_occurrence_id: string | null;
          title: string;
          description: string | null;
          assignee_member_id: string;
          created_by_member_id: string;
          reviewer_member_id: string | null;
          priority: string;
          status: string;
          planned_date: string;
          original_due_at: string;
          due_at: string;
          assigned_at: string;
          visible_from: string | null;
          acknowledged_at: string | null;
          started_at: string | null;
          submitted_at: string | null;
          completed_at: string | null;
          requires_review: boolean;
          requires_result: boolean;
          requires_attachment: boolean;
          allow_no_incident: boolean;
          reminder_profile: Json;
          reminder_profile_reason: string | null;
          reminder_profile_review_at: string | null;
          estimated_minutes: number | null;
          blocked_at: string | null;
          blocker_reason: string | null;
          blocker_owner_member_id: string | null;
          last_meaningful_update_at: string;
          current_submission_id: string | null;
          created_at: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          id?: string;
          organization_id: string;
          task_number: string;
          batch_id?: string | null;
          seller_id?: string | null;
          template_occurrence_id?: string | null;
          title: string;
          description?: string | null;
          assignee_member_id: string;
          created_by_member_id: string;
          reviewer_member_id?: string | null;
          priority?: string;
          status?: string;
          planned_date: string;
          original_due_at: string;
          due_at: string;
          assigned_at?: string;
          visible_from?: string | null;
          acknowledged_at?: string | null;
          started_at?: string | null;
          submitted_at?: string | null;
          completed_at?: string | null;
          requires_review?: boolean;
          requires_result?: boolean;
          requires_attachment?: boolean;
          allow_no_incident?: boolean;
          reminder_profile?: Json;
          reminder_profile_reason?: string | null;
          reminder_profile_review_at?: string | null;
          estimated_minutes?: number | null;
          blocked_at?: string | null;
          blocker_reason?: string | null;
          blocker_owner_member_id?: string | null;
          last_meaningful_update_at?: string;
          current_submission_id?: string | null;
          created_at?: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          id?: string;
          organization_id?: string;
          task_number?: string;
          batch_id?: string | null;
          seller_id?: string | null;
          template_occurrence_id?: string | null;
          title?: string;
          description?: string | null;
          assignee_member_id?: string;
          created_by_member_id?: string;
          reviewer_member_id?: string | null;
          priority?: string;
          status?: string;
          planned_date?: string;
          original_due_at?: string;
          due_at?: string;
          assigned_at?: string;
          visible_from?: string | null;
          acknowledged_at?: string | null;
          started_at?: string | null;
          submitted_at?: string | null;
          completed_at?: string | null;
          requires_review?: boolean;
          requires_result?: boolean;
          requires_attachment?: boolean;
          allow_no_incident?: boolean;
          reminder_profile?: Json;
          reminder_profile_reason?: string | null;
          reminder_profile_review_at?: string | null;
          estimated_minutes?: number | null;
          blocked_at?: string | null;
          blocker_reason?: string | null;
          blocker_owner_member_id?: string | null;
          last_meaningful_update_at?: string;
          current_submission_id?: string | null;
          created_at?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [];
      };
      task_participants: {
        Row: {
          organization_id: string;
          task_id: string;
          member_id: string;
          participant_role: string;
          created_at: string;
        };
        Insert: {
          organization_id: string;
          task_id: string;
          member_id: string;
          participant_role: string;
          created_at?: string;
        };
        Update: {
          organization_id?: string;
          task_id?: string;
          member_id?: string;
          participant_role?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      task_checklist_items: {
        Row: {
          id: string;
          organization_id: string;
          task_id: string;
          title: string;
          sort_order: number;
          is_required: boolean;
          checked_at: string | null;
          checked_by_member_id: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          task_id: string;
          title: string;
          sort_order?: number;
          is_required?: boolean;
          checked_at?: string | null;
          checked_by_member_id?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          task_id?: string;
          title?: string;
          sort_order?: number;
          is_required?: boolean;
          checked_at?: string | null;
          checked_by_member_id?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      task_submissions: {
        Row: {
          id: string;
          organization_id: string;
          task_id: string;
          revision: number;
          submitted_by_member_id: string;
          result_text: string | null;
          no_incident: boolean;
          evidence: Json;
          review_state: string;
          reviewed_by_member_id: string | null;
          reviewed_at: string | null;
          review_reason: string | null;
          revision_due_at: string | null;
          submitted_at: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          task_id: string;
          revision: number;
          submitted_by_member_id: string;
          result_text?: string | null;
          no_incident?: boolean;
          evidence?: Json;
          review_state: string;
          reviewed_by_member_id?: string | null;
          reviewed_at?: string | null;
          review_reason?: string | null;
          revision_due_at?: string | null;
          submitted_at?: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          task_id?: string;
          revision?: number;
          submitted_by_member_id?: string;
          result_text?: string | null;
          no_incident?: boolean;
          evidence?: Json;
          review_state?: string;
          reviewed_by_member_id?: string | null;
          reviewed_at?: string | null;
          review_reason?: string | null;
          revision_due_at?: string | null;
          submitted_at?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      task_events: {
        Row: {
          id: string;
          organization_id: string;
          task_id: string;
          task_version: number;
          event_type: string;
          actor_member_id: string | null;
          event_payload: Json;
          report_state_after: Json;
          occurred_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          task_id: string;
          task_version: number;
          event_type: string;
          actor_member_id?: string | null;
          event_payload?: Json;
          report_state_after?: Json;
          occurred_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          task_id?: string;
          task_version?: number;
          event_type?: string;
          actor_member_id?: string | null;
          event_payload?: Json;
          report_state_after?: Json;
          occurred_at?: string;
        };
        Relationships: [];
      };
      invitation_seller_scopes: {
        Row: {
          organization_id: string;
          invitation_id: string;
          seller_id: string;
          is_manager: boolean;
        };
        Insert: {
          organization_id: string;
          invitation_id: string;
          seller_id: string;
          is_manager?: boolean;
        };
        Update: {
          organization_id?: string;
          invitation_id?: string;
          seller_id?: string;
          is_manager?: boolean;
        };
        Relationships: [
          {
            foreignKeyName: 'invitation_seller_scopes_organization_id_invitation_id_fkey';
            columns: ['organization_id', 'invitation_id'];
            isOneToOne: false;
            referencedRelation: 'invitations';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'invitation_seller_scopes_organization_id_seller_id_fkey';
            columns: ['organization_id', 'seller_id'];
            isOneToOne: false;
            referencedRelation: 'sellers';
            referencedColumns: ['organization_id', 'id'];
          },
        ];
      };
      invitations: {
        Row: {
          id: string;
          organization_id: string;
          email: string;
          invited_role: string;
          invited_by: string;
          auth_invite_reference: string | null;
          token_hash: string | null;
          expires_at: string;
          accepted_at: string | null;
          revoked_at: string | null;
          capabilities: Json;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          email: string;
          invited_role: string;
          invited_by: string;
          auth_invite_reference?: string | null;
          token_hash?: string | null;
          expires_at: string;
          accepted_at?: string | null;
          revoked_at?: string | null;
          capabilities?: Json;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          email?: string;
          invited_role?: string;
          invited_by?: string;
          auth_invite_reference?: string | null;
          token_hash?: string | null;
          expires_at?: string;
          accepted_at?: string | null;
          revoked_at?: string | null;
          capabilities?: Json;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'invitations_organization_id_invited_by_fkey';
            columns: ['organization_id', 'invited_by'];
            isOneToOne: false;
            referencedRelation: 'organization_members';
            referencedColumns: ['organization_id', 'id'];
          },
        ];
      };
      policy_versions: {
        Row: {
          id: string;
          organization_id: string;
          policy_kind: string;
          version_number: number;
          effective_from: string;
          config: Json;
          created_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          policy_kind: string;
          version_number: number;
          effective_from: string;
          config: Json;
          created_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          policy_kind?: string;
          version_number?: number;
          effective_from?: string;
          config?: Json;
          created_by?: string;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'policy_versions_organization_id_created_by_fkey';
            columns: ['organization_id', 'created_by'];
            isOneToOne: false;
            referencedRelation: 'organization_members';
            referencedColumns: ['organization_id', 'id'];
          },
        ];
      };
      files: {
        Row: {
          id: string;
          organization_id: string;
          uploaded_by_member_id: string;
          bucket_id: string;
          object_path: string;
          original_name: string;
          mime_type: string;
          size_bytes: number;
          sha256: string | null;
          purpose: string;
          state: string;
          retention_until: string | null;
          legal_hold: boolean;
          verified_at: string | null;
          verification_code: string | null;
          created_at: string;
          deleted_at: string | null;
        };
        Insert: {
          id?: string;
          organization_id: string;
          uploaded_by_member_id: string;
          bucket_id: string;
          object_path: string;
          original_name: string;
          mime_type: string;
          size_bytes: number;
          sha256?: string | null;
          purpose: string;
          state?: string;
          retention_until?: string | null;
          legal_hold?: boolean;
          verified_at?: string | null;
          verification_code?: string | null;
          created_at?: string;
          deleted_at?: string | null;
        };
        Update: {
          id?: string;
          organization_id?: string;
          uploaded_by_member_id?: string;
          bucket_id?: string;
          object_path?: string;
          original_name?: string;
          mime_type?: string;
          size_bytes?: number;
          sha256?: string | null;
          purpose?: string;
          state?: string;
          retention_until?: string | null;
          legal_hold?: boolean;
          verified_at?: string | null;
          verification_code?: string | null;
          created_at?: string;
          deleted_at?: string | null;
        };
        Relationships: [];
      };
      export_jobs: {
        Row: {
          id: string;
          organization_id: string;
          requested_by: string;
          export_kind: string;
          format: string;
          scope_snapshot: Json;
          parameters: Json;
          source_period_id: string | null;
          source_revision: number | null;
          status: string;
          file_id: string | null;
          idempotency_key: string;
          requested_at: string;
          completed_at: string | null;
          expires_at: string | null;
          error_code: string | null;
          worker_id: string | null;
          processing_started_at: string | null;
          updated_at: string;
          version: number;
        };
        Insert: {
          id?: string;
          organization_id: string;
          requested_by: string;
          export_kind: string;
          format?: string;
          scope_snapshot: Json;
          parameters?: Json;
          source_period_id?: string | null;
          source_revision?: number | null;
          status?: string;
          file_id?: string | null;
          idempotency_key: string;
          requested_at?: string;
          completed_at?: string | null;
          expires_at?: string | null;
          error_code?: string | null;
          worker_id?: string | null;
          processing_started_at?: string | null;
          updated_at?: string;
          version?: number;
        };
        Update: {
          id?: string;
          organization_id?: string;
          requested_by?: string;
          export_kind?: string;
          format?: string;
          scope_snapshot?: Json;
          parameters?: Json;
          source_period_id?: string | null;
          source_revision?: number | null;
          status?: string;
          file_id?: string | null;
          idempotency_key?: string;
          requested_at?: string;
          completed_at?: string | null;
          expires_at?: string | null;
          error_code?: string | null;
          worker_id?: string | null;
          processing_started_at?: string | null;
          updated_at?: string;
          version?: number;
        };
        Relationships: [];
      };
      audit_logs: {
        Row: {
          id: string;
          organization_id: string;
          actor_member_id: string | null;
          actor_kind: string;
          action: string;
          entity_type: string;
          entity_id: string | null;
          recorded_at: string;
          request_id: string;
          safe_metadata: Json;
        };
        Insert: {
          id?: string;
          organization_id: string;
          actor_member_id?: string | null;
          actor_kind: string;
          action: string;
          entity_type: string;
          entity_id?: string | null;
          recorded_at?: string;
          request_id?: string;
          safe_metadata?: Json;
        };
        Update: {
          id?: string;
          organization_id?: string;
          actor_member_id?: string | null;
          actor_kind?: string;
          action?: string;
          entity_type?: string;
          entity_id?: string | null;
          recorded_at?: string;
          request_id?: string;
          safe_metadata?: Json;
        };
        Relationships: [
          {
            foreignKeyName: 'audit_logs_organization_id_actor_member_id_fkey';
            columns: ['organization_id', 'actor_member_id'];
            isOneToOne: false;
            referencedRelation: 'organization_members';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'audit_logs_organization_id_fkey';
            columns: ['organization_id'];
            isOneToOne: false;
            referencedRelation: 'organizations';
            referencedColumns: ['id'];
          },
        ];
      };
      leave_types: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          pay_treatment: string;
          consumes_balance: boolean;
          active: boolean;
          created_at: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          pay_treatment: string;
          consumes_balance?: boolean;
          active?: boolean;
          created_at?: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          pay_treatment?: string;
          consumes_balance?: boolean;
          active?: boolean;
          created_at?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [];
      };
      employee_requests: {
        Row: {
          id: string;
          organization_id: string;
          member_id: string;
          request_type: string;
          status: string;
          starts_at: string;
          ends_at: string;
          leave_type_id: string | null;
          pay_treatment_snapshot: string;
          reason_private: string;
          handover_note: string | null;
          target_request_id: string | null;
          correction_payload: Json | null;
          submitted_at: string;
          decided_at: string | null;
          decided_by_member_id: string | null;
          decision_reason_private: string | null;
          idempotency_key: string;
          created_at: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          id?: string;
          organization_id: string;
          member_id: string;
          request_type: string;
          status?: string;
          starts_at: string;
          ends_at: string;
          leave_type_id?: string | null;
          pay_treatment_snapshot?: string;
          reason_private: string;
          handover_note?: string | null;
          target_request_id?: string | null;
          correction_payload?: Json | null;
          submitted_at?: string;
          decided_at?: string | null;
          decided_by_member_id?: string | null;
          decision_reason_private?: string | null;
          idempotency_key: string;
          created_at?: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          id?: string;
          organization_id?: string;
          member_id?: string;
          request_type?: string;
          status?: string;
          starts_at?: string;
          ends_at?: string;
          leave_type_id?: string | null;
          pay_treatment_snapshot?: string;
          reason_private?: string;
          handover_note?: string | null;
          target_request_id?: string | null;
          correction_payload?: Json | null;
          submitted_at?: string;
          decided_at?: string | null;
          decided_by_member_id?: string | null;
          decision_reason_private?: string | null;
          idempotency_key?: string;
          created_at?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [];
      };
      request_segments: {
        Row: {
          id: string;
          organization_id: string;
          request_id: string;
          shift_instance_id: string;
          starts_at: string;
          ends_at: string;
          affected_seconds: number;
          pay_treatment_snapshot: string;
          leave_type_version: number | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          request_id: string;
          shift_instance_id: string;
          starts_at: string;
          ends_at: string;
          affected_seconds: number;
          pay_treatment_snapshot: string;
          leave_type_version?: number | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          request_id?: string;
          shift_instance_id?: string;
          starts_at?: string;
          ends_at?: string;
          affected_seconds?: number;
          pay_treatment_snapshot?: string;
          leave_type_version?: number | null;
          created_at?: string;
        };
        Relationships: [];
      };
      task_handover_actions: {
        Row: {
          id: string;
          organization_id: string;
          request_id: string;
          task_id: string | null;
          occurrence_id: string | null;
          action: string;
          new_assignee_member_id: string | null;
          new_planned_date: string | null;
          new_due_at: string | null;
          reason: string | null;
          resolved_by_member_id: string | null;
          resolved_at: string | null;
          created_at: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          id?: string;
          organization_id: string;
          request_id: string;
          task_id?: string | null;
          occurrence_id?: string | null;
          action?: string;
          new_assignee_member_id?: string | null;
          new_planned_date?: string | null;
          new_due_at?: string | null;
          reason?: string | null;
          resolved_by_member_id?: string | null;
          resolved_at?: string | null;
          created_at?: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          id?: string;
          organization_id?: string;
          request_id?: string;
          task_id?: string | null;
          occurrence_id?: string | null;
          action?: string;
          new_assignee_member_id?: string | null;
          new_planned_date?: string | null;
          new_due_at?: string | null;
          reason?: string | null;
          resolved_by_member_id?: string | null;
          resolved_at?: string | null;
          created_at?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      rpc_authorize_file_download: {
        Args: { p_file_id: string };
        Returns: Json;
      };
      rpc_create_export_job: {
        Args: {
          p_export_kind: string;
          p_idempotency_key: string;
          p_organization_id: string;
          p_parameters: Json;
        };
        Returns: Json;
      };
      rpc_get_export_job: {
        Args: { p_job_id: string };
        Returns: Json;
      };
      rpc_list_audit_logs: {
        Args: {
          p_action?: string | null;
          p_before?: string | null;
          p_entity_type?: string | null;
          p_limit?: number;
          p_organization_id: string;
        };
        Returns: Json;
      };
      rpc_accept_invitation: {
        Args: { p_display_name: string; p_token: string };
        Returns: Json;
      };
      rpc_create_invitation: {
        Args: {
          p_capabilities: Json;
          p_email: string;
          p_expires_at: string;
          p_organization_id: string;
          p_role: string;
          p_seller_scope: Json;
          p_token_hash: string;
        };
        Returns: Json;
      };
      rpc_create_or_update_seller: {
        Args: {
          p_expected_version?: number | null;
          p_organization_id: string;
          p_seller: Json;
        };
        Returns: Json;
      };
      rpc_create_task: {
        Args: { p_idempotency_key: string; p_organization_id: string; p_task: Json };
        Returns: Json;
      };
      rpc_create_employee_request: {
        Args: { p_idempotency_key: string; p_organization_id: string; p_payload: Json };
        Returns: Json;
      };
      rpc_decide_employee_request: {
        Args: {
          p_decision: string;
          p_expected_version: number;
          p_idempotency_key: string;
          p_reason_private: string;
          p_request_id: string;
        };
        Returns: Json;
      };
      rpc_create_task_batch: {
        Args: {
          p_common_task: Json;
          p_idempotency_key: string;
          p_mode?: string;
          p_organization_id: string;
          p_targets: Json;
        };
        Returns: Json;
      };
      rpc_deactivate_member: {
        Args: { p_expected_version: number; p_handover_plan: Json; p_member_id: string };
        Returns: Json;
      };
      rpc_get_context: {
        Args: {
          p_organization_id?: string | null;
        };
        Returns: Json;
      };
      rpc_get_attendance_day: {
        Args: {
          p_member_id?: string | null;
          p_organization_id: string;
          p_work_date?: string;
        };
        Returns: Json;
      };
      rpc_internal_create_invited_membership: {
        Args: { p_display_name: string; p_invitation_id: string; p_user_id: string };
        Returns: Json;
      };
      rpc_internal_set_invitation_auth_reference: {
        Args: { p_auth_invite_reference: string; p_invitation_id: string };
        Returns: undefined;
      };
      rpc_list_members_by_scope: {
        Args: { p_organization_id: string };
        Returns: Json;
      };
      rpc_list_tasks: {
        Args: { p_include_terminal?: boolean; p_organization_id: string };
        Returns: Json;
      };
      rpc_get_task: {
        Args: { p_task_id: string };
        Returns: Json;
      };
      rpc_get_timesheet: {
        Args: { p_member_id?: string | null; p_month_start: string; p_organization_id: string };
        Returns: Json;
      };
      rpc_list_notifications: {
        Args: {
          p_before?: string | null;
          p_limit?: number;
          p_organization_id: string;
        };
        Returns: Json;
      };
      rpc_mark_notification_read: {
        Args: { p_notification_id: string };
        Returns: Json;
      };
      rpc_mark_all_notifications_read: {
        Args: { p_cutoff: string; p_organization_id: string };
        Returns: Json;
      };
      rpc_snooze_reminder: {
        Args: {
          p_expected_version: number;
          p_idempotency_key: string;
          p_rule_key: string;
          p_task_id: string;
          p_until: string;
        };
        Returns: Json;
      };
      rpc_revoke_device: {
        Args: { p_device_id: string };
        Returns: Json;
      };
      rpc_internal_generate_due_reports: {
        Args: { p_limit?: number; p_now?: string };
        Returns: Json;
      };
      rpc_list_reports: {
        Args: { p_limit?: number; p_organization_id: string };
        Returns: Json;
      };
      rpc_get_report: {
        Args: { p_run_id: string };
        Returns: Json;
      };
      rpc_create_report_revision: {
        Args: {
          p_expected_version: number;
          p_idempotency_key: string;
          p_organization_id: string;
          p_reason: string;
          p_run_id: string;
        };
        Returns: Json;
      };
      rpc_begin_timesheet_reconciliation: {
        Args: {
          p_expected_version: number;
          p_idempotency_key: string;
          p_month_start: string;
          p_organization_id: string;
        };
        Returns: Json;
      };
      rpc_close_timesheet: {
        Args: {
          p_expected_version: number;
          p_idempotency_key: string;
          p_month_start: string;
          p_organization_id: string;
        };
        Returns: Json;
      };
      rpc_reopen_timesheet: {
        Args: {
          p_expected_version: number;
          p_idempotency_key: string;
          p_organization_id: string;
          p_period_id: string;
          p_reason: string;
        };
        Returns: Json;
      };
      rpc_task_command: {
        Args: {
          p_action: string;
          p_expected_version: number;
          p_idempotency_key: string;
          p_payload: Json;
          p_task_id: string;
        };
        Returns: Json;
      };
      rpc_update_task: {
        Args: {
          p_expected_version: number;
          p_idempotency_key: string;
          p_patch: Json;
          p_task_id: string;
        };
        Returns: Json;
      };
      rpc_withdraw_employee_request: {
        Args: { p_expected_version: number; p_idempotency_key: string; p_request_id: string };
        Returns: Json;
      };
      rpc_update_member_access: {
        Args: {
          p_capabilities: Json;
          p_expected_version: number;
          p_member_id: string;
          p_role: string;
          p_scope: Json;
        };
        Returns: Json;
      };
      rpc_update_seller_members: {
        Args: { p_members: Json; p_seller_id: string };
        Returns: Json;
      };
      rpc_validate_invitation: {
        Args: { p_token: string };
        Returns: Json;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

export type Tables<
  PublicTableNameOrOptions extends
    | keyof (Database['public']['Tables'] & Database['public']['Views'])
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof (Database[PublicTableNameOrOptions['schema']]['Tables'] &
        Database[PublicTableNameOrOptions['schema']]['Views'])
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? (Database[PublicTableNameOrOptions['schema']]['Tables'] &
      Database[PublicTableNameOrOptions['schema']]['Views'])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : PublicTableNameOrOptions extends keyof Database['public']['Tables']
    ? Database['public']['Tables'][PublicTableNameOrOptions] extends { Row: infer R }
      ? R
      : never
    : never;

export type TablesInsert<
  PublicTableNameOrOptions extends keyof Database['public']['Tables'] | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions['schema']]['Tables']
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions['schema']]['Tables'][TableName] extends { Insert: infer I }
    ? I
    : never
  : PublicTableNameOrOptions extends keyof Database['public']['Tables']
    ? Database['public']['Tables'][PublicTableNameOrOptions] extends { Insert: infer I }
      ? I
      : never
    : never;

export type TablesUpdate<
  PublicTableNameOrOptions extends keyof Database['public']['Tables'] | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions['schema']]['Tables']
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions['schema']]['Tables'][TableName] extends { Update: infer U }
    ? U
    : never
  : PublicTableNameOrOptions extends keyof Database['public']['Tables']
    ? Database['public']['Tables'][PublicTableNameOrOptions] extends { Update: infer U }
      ? U
      : never
    : never;

export type Enums<
  PublicEnumNameOrOptions extends keyof Database['public']['Enums'] | { schema: keyof Database },
  EnumName extends PublicEnumNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicEnumNameOrOptions['schema']]['Enums']
    : never = never,
> = PublicEnumNameOrOptions extends { schema: keyof Database }
  ? Database[PublicEnumNameOrOptions['schema']]['Enums'][EnumName]
  : PublicEnumNameOrOptions extends keyof Database['public']['Enums']
    ? Database['public']['Enums'][PublicEnumNameOrOptions]
    : never;
