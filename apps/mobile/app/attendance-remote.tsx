import type { AttendanceDay, OrganizationContext } from '@opsdesk/contracts';
import { colors, controls, layout, radii, spacing, typography } from '@opsdesk/design-tokens';
import { CameraView, useCameraPermissions } from 'expo-camera';
import * as FileSystem from 'expo-file-system';
import { useRouter } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  createAttendanceChallenge,
  createAttendanceUploadIntent,
  finalizeRemoteAttendance,
  loadAttendanceDay,
  registerAttendanceDevice,
} from '../lib/attendance/attendance-api';
import {
  attendanceDiagnosticFromError,
  type AttendanceDiagnostic,
} from '../lib/attendance/attendance-diagnostics';
import { getMobileContextErrorMessage, loadMobileMemberContext } from '../lib/member-context';

function organizationDate(timezone: string) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

export default function RemoteAttendanceScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const cameraRef = useRef<CameraView | null>(null);
  const [permission, requestPermission] = useCameraPermissions();
  const [context, setContext] = useState<OrganizationContext | null>(null);
  const [day, setDay] = useState<AttendanceDay | null>(null);
  const [deviceId, setDeviceId] = useState<string | null>(null);
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [cameraReady, setCameraReady] = useState(false);
  const [diagnostic, setDiagnostic] = useState<AttendanceDiagnostic | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let active = true;
    async function prepare() {
      try {
        const nextContext = await loadMobileMemberContext();
        const platform =
          Platform.OS === 'ios' ? 'ios' : Platform.OS === 'android' ? 'android' : null;
        if (!platform) throw new Error('REMOTE_ATTENDANCE_REQUIRES_NATIVE_APP');
        const [nextDay, device] = await Promise.all([
          loadAttendanceDay(nextContext.organization_id, organizationDate(nextContext.timezone)),
          registerAttendanceDevice(nextContext.organization_id, platform),
        ]);
        if (!nextDay.shift || !['remote', 'hybrid'].includes(nextDay.shift.allowed_mode)) {
          throw new Error('REMOTE_NOT_APPROVED');
        }
        if (!active) return;
        setContext(nextContext);
        setDay(nextDay);
        setDeviceId(device.device_id);
      } catch (error) {
        if (!active) return;
        if (error instanceof Error && error.message.startsWith('MOBILE_')) {
          setDiagnostic({
            code: error.message,
            title: 'Không thể mở chấm công online',
            description: getMobileContextErrorMessage(error),
            action: 'Đăng nhập lại',
          });
        } else {
          setDiagnostic(attendanceDiagnosticFromError(error));
        }
      } finally {
        if (active) setLoading(false);
      }
    }
    void prepare();
    return () => {
      active = false;
    };
  }, []);

  async function takeSelfie() {
    if (!cameraReady || !cameraRef.current || busy) return;
    setBusy(true);
    setDiagnostic(null);
    setSuccessMessage(null);
    try {
      const picture = await cameraRef.current.takePictureAsync({ quality: 0.72, exif: false });
      if (!picture?.uri) throw new Error('CAMERA_CAPTURE_FAILED');
      setPhotoUri(picture.uri);
    } catch (error) {
      setDiagnostic(attendanceDiagnosticFromError(error));
    } finally {
      setBusy(false);
    }
  }

  async function submitRemoteAttendance() {
    if (!context || !day?.shift || !deviceId || !photoUri || busy) return;

    setBusy(true);
    setDiagnostic(null);
    setSuccessMessage(null);
    try {
      const openSession = day.sessions.find((item) => item.status === 'open');
      const action = openSession ? 'check_out' : 'check_in';
      const challenge = await createAttendanceChallenge({
        organizationId: context.organization_id,
        shiftInstanceId: day.shift.id,
        action,
        mode: 'remote',
        deviceId,
      });

      const localFile = await FileSystem.getInfoAsync(photoUri);
      if (!localFile.exists || !localFile.size || localFile.size > 5 * 1024 * 1024) {
        throw new Error('REMOTE_EVIDENCE_INVALID');
      }
      const sizeBytes = localFile.size;
      const mimeType = photoUri.toLowerCase().endsWith('.webp') ? 'image/webp' : 'image/jpeg';
      const intent = await createAttendanceUploadIntent({
        challengeId: challenge.challenge_id,
        mimeType,
        sizeBytes,
      });

      const upload = await FileSystem.uploadAsync(intent.signed_url, photoUri, {
        httpMethod: 'PUT',
        uploadType: FileSystem.FileSystemUploadType.BINARY_CONTENT,
        headers: {
          'cache-control': 'max-age=3600',
          'content-type': mimeType,
          'x-upsert': 'false',
        },
      });
      if (upload.status < 200 || upload.status >= 300) throw new Error('UPLOAD_FAILED');

      const commit = await finalizeRemoteAttendance({
        challengeId: challenge.challenge_id,
        nonce: challenge.nonce,
        deviceId,
        fileId: intent.file_id,
      });
      setSuccessMessage(
        `Đã ${commit.event_kind === 'check_in' ? 'chấm vào' : 'chấm ra'} online lúc ${new Date(commit.recorded_at).toLocaleTimeString('vi-VN')}`,
      );
      setTimeout(() => router.replace('/attendance'), 900);
    } catch (error) {
      const nextDiagnostic = attendanceDiagnosticFromError(error);
      setDiagnostic(nextDiagnostic);
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }

  const cameraAllowed = permission?.granted === true;
  const canShowCamera = cameraAllowed && !photoUri;

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={styles.root}
    >
      <ScrollView
        contentContainerStyle={[
          styles.container,
          {
            paddingTop: insets.top + layout.mobileWorkspacePadding,
            paddingBottom: insets.bottom + 40,
          },
        ]}
        keyboardShouldPersistTaps="handled"
      >
        <Pressable onPress={() => router.replace('/attendance')}>
          <Text style={styles.back}>← Quay lại chấm công</Text>
        </Pressable>
        <Text style={styles.eyebrow}>REMOTE ATTENDANCE</Text>
        <Text style={styles.title}>Chụp ảnh xác nhận</Text>
        <Text style={styles.body}>
          Khi chấm công online, bạn tự chụp ảnh trực tiếp bằng camera điện thoại. Ảnh được tải lên
          kho riêng tư để máy chủ xác minh cùng timestamp của ca làm việc.
        </Text>

        {!cameraAllowed ? (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>1. Cho phép camera trước</Text>
            <Text style={styles.cardBody}>
              OpsDesk chỉ mở camera khi bạn chủ động chấm công online. Không có lựa chọn ảnh từ thư
              viện.
            </Text>
            <Pressable
              onPress={() => {
                setDiagnostic(null);
                void requestPermission().then((nextPermission) => {
                  if (!nextPermission.granted) {
                    setDiagnostic(
                      attendanceDiagnosticFromError(new Error('CAMERA_PERMISSION_REQUIRED')),
                    );
                  }
                });
              }}
              style={styles.primaryButton}
            >
              <Text style={styles.primaryText}>Cho phép camera</Text>
            </Pressable>
          </View>
        ) : null}

        {canShowCamera ? (
          <View style={styles.cameraCard}>
            <CameraView
              facing="front"
              mirror
              onCameraReady={() => setCameraReady(true)}
              ref={cameraRef}
              style={styles.camera}
            />
            <Text style={styles.cameraHint}>Đặt cả khuôn mặt và máy tính trong khung hình</Text>
            <Pressable
              disabled={!cameraReady || busy}
              onPress={() => void takeSelfie()}
              style={cameraReady && !busy ? styles.primaryButton : styles.disabledButton}
            >
              <Text style={cameraReady && !busy ? styles.primaryText : styles.disabledText}>
                {busy ? 'Đang chụp...' : 'Chụp selfie'}
              </Text>
            </Pressable>
          </View>
        ) : null}

        {photoUri ? (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>2. Kiểm tra ảnh trước khi gửi</Text>
            <Image resizeMode="cover" source={{ uri: photoUri }} style={styles.preview} />
            <View style={styles.buttonRow}>
              <Pressable
                disabled={busy}
                onPress={() => {
                  setPhotoUri(null);
                  setCameraReady(false);
                }}
                style={styles.secondaryButton}
              >
                <Text style={styles.secondaryText}>Chụp lại</Text>
              </Pressable>
              <Pressable
                disabled={busy}
                onPress={() => void submitRemoteAttendance()}
                style={styles.primaryButtonFlex}
              >
                <Text style={styles.primaryText}>{busy ? 'Đang gửi...' : 'Gửi và chấm công'}</Text>
              </Pressable>
            </View>
          </View>
        ) : null}

        {successMessage ? (
          <View style={styles.messageCard}>
            <Text style={styles.messageTitle}>Đã xác nhận</Text>
            <Text style={styles.messageText}>{successMessage}</Text>
          </View>
        ) : null}

        {diagnostic ? (
          <View style={styles.messageCard}>
            <Text style={styles.messageCode}>{diagnostic.code}</Text>
            <Text style={styles.messageTitle}>{diagnostic.title}</Text>
            <Text style={styles.messageText}>{diagnostic.description}</Text>
            {diagnostic.action ? (
              <Text style={styles.messageAction}>{diagnostic.action}</Text>
            ) : null}
          </View>
        ) : null}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  root: { backgroundColor: colors.canvas, flex: 1 },
  loading: {
    alignItems: 'center',
    backgroundColor: colors.canvas,
    flex: 1,
    justifyContent: 'center',
  },
  container: { gap: spacing.md, paddingHorizontal: layout.mobileWorkspacePadding },
  back: { color: colors.accent, fontSize: typography.fontSize.label, fontWeight: '600' },
  eyebrow: {
    color: colors.accent,
    fontSize: typography.fontSize.caption,
    fontWeight: '700',
    letterSpacing: 0.8,
    marginTop: 20,
  },
  title: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.title,
    fontWeight: '700',
  },
  body: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.body,
    lineHeight: typography.lineHeight.body,
  },
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    gap: 12,
    marginTop: 6,
    padding: 16,
  },
  cardTitle: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.bodyLarge,
    fontWeight: '700',
  },
  cardBody: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.label,
    lineHeight: typography.lineHeight.body,
  },
  cameraCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    gap: 12,
    overflow: 'hidden',
    paddingBottom: 16,
  },
  camera: { aspectRatio: 3 / 4, width: '100%' },
  cameraHint: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.label,
    paddingHorizontal: 16,
    textAlign: 'center',
  },
  preview: { aspectRatio: 3 / 4, borderRadius: radii.md, width: '100%' },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.md,
    justifyContent: 'center',
    minHeight: controls.mobileFieldHeight,
    paddingHorizontal: 14,
  },
  primaryButtonFlex: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.md,
    flex: 1,
    justifyContent: 'center',
    minHeight: controls.mobileFieldHeight,
    paddingHorizontal: 12,
  },
  primaryText: { color: colors.surface, fontSize: typography.fontSize.body, fontWeight: '700' },
  disabledButton: {
    alignItems: 'center',
    backgroundColor: '#e7e9ed',
    borderRadius: radii.md,
    justifyContent: 'center',
    minHeight: controls.mobileFieldHeight,
    paddingHorizontal: 14,
  },
  disabledText: { color: colors.textMuted, fontSize: typography.fontSize.body, fontWeight: '700' },
  secondaryButton: {
    alignItems: 'center',
    borderColor: colors.border,
    borderRadius: radii.md,
    borderWidth: 1,
    flex: 1,
    justifyContent: 'center',
    minHeight: controls.mobileFieldHeight,
    paddingHorizontal: 12,
  },
  secondaryText: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.body,
    fontWeight: '700',
  },
  buttonRow: { flexDirection: 'row', gap: 10 },
  messageCard: {
    backgroundColor: colors.surfaceInset,
    borderColor: colors.border,
    borderRadius: radii.md,
    borderWidth: 1,
    padding: 12,
  },
  messageCode: {
    color: colors.accent,
    fontSize: typography.fontSize.caption,
    fontWeight: '700',
    letterSpacing: 0.6,
  },
  messageTitle: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.label,
    fontWeight: '700',
    marginTop: 4,
  },
  messageText: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.label,
    lineHeight: typography.lineHeight.body,
    marginTop: 4,
  },
  messageAction: {
    color: colors.accent,
    fontSize: typography.fontSize.label,
    fontWeight: '600',
    marginTop: 8,
  },
});
