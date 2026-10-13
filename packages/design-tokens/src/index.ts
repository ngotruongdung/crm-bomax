export const colors = {
  canvas: '#f7f8fa',
  sidebar: '#f5f6f8',
  surfaceInset: '#f5f6f8',
  surface: '#ffffff',
  surfaceMuted: '#f8f9fb',
  surfaceHover: '#f0f1f4',
  border: '#eceef2',
  inputBorder: '#dfe2e7',
  inputPlaceholder: '#9a9eaa',
  textPrimary: '#202124',
  textSecondary: '#5f6368',
  textMuted: '#8a9099',
  primary: '#202124',
  accent: '#6c5ce7',
  accentSoft: '#f0eeff',
  success: '#23764b',
  successSoft: '#edf7f0',
  warning: '#8a5b12',
  danger: '#b93838',
  dangerSoft: '#fff5f5',
  dangerBorder: '#f0d4d4',
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  '2xl': 24,
  '3xl': 28,
  '4xl': 40,
  '5xl': 64,
} as const;

export const radii = {
  xs: 4,
  sm: 6,
  compact: 8,
  control: 9,
  md: 10,
  lg: 14,
  xl: 14,
  full: 999,
} as const;

export const typography = {
  fontFamily: 'Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
  fontSize: {
    caption: 12,
    label: 13,
    body: 14,
    bodyLarge: 16,
    brand: 17,
    title: 24,
  },
  fontWeight: {
    regular: '400',
    medium: '500',
    semibold: '600',
    bold: '700',
  },
  lineHeight: {
    caption: 18,
    body: 19,
    bodyLarge: 24,
  },
} as const;

export const layout = {
  desktopSidebarWidth: 240,
  compactSidebarWidth: 216,
  tabletRailWidth: 64,
  topbarHeight: 52,
  desktopPagePadding: 28,
  tabletPagePadding: 20,
  mobilePagePadding: 18,
  mobileAuthPadding: 28,
  mobileWorkspacePadding: 24,
  mobileBottomInset: 24,
  iconSize: 18,
  rowHeight: 44,
  tableCellPaddingX: 16,
  tableCellPaddingY: 12,
} as const;

export const controls = {
  desktopButtonHeight: 36,
  desktopFieldHeight: 36,
  mobileTouchTarget: 44,
  mobileFieldHeight: 48,
} as const;

export const breakpoints = {
  xs: 480,
  sm: 768,
  md: 1024,
  lg: 1280,
  xl: 1440,
} as const;

export const bootstrapStatus = {
  code: 'DESIGN_TOKENS_READY',
  label: 'Design tokens đã sẵn sàng',
} as const;
