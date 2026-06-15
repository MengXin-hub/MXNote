/**
 * ThemeConstants — 白底主题语义化设计令牌。
 */
export class ThemeColors {
  static readonly colorBgCanvas: string = '#ffffff'
  static readonly colorBgSurface: string = '#f8f9fa'
  static readonly colorBgSelected: string = '#e8f0fe'
  static readonly colorBgHover: string = '#f1f3f4'
  static readonly colorBgOverlay: string = '#00000033'

  static readonly colorTextPrimary: string = '#202124'
  static readonly colorTextSecondary: string = '#5f6368'
  static readonly colorTextTertiary: string = '#9aa0a6'

  static readonly colorAccentBlue: string = '#1a73e8'
  static readonly colorAccentRed: string = '#ea4335'
  static readonly colorAccentGreen: string = '#34a853'
  static readonly colorAccentYellow: string = '#fbbc04'

  static readonly colorBorderDefault: string = '#dadce0'
  static readonly colorBorderSubtle: string = '#e8eaed'
}

export class ThemeSpacing {
  static readonly xs: number = 4
  static readonly sm: number = 8
  static readonly md: number = 12
  static readonly lg: number = 16
  static readonly xl: number = 20
  static readonly xxl: number = 24
}

export class ThemeFontSize {
  static readonly caption: number = 11
  static readonly bodySmall: number = 12
  static readonly body: number = 14
  static readonly bodyLarge: number = 15
  static readonly subtitle: number = 16
  static readonly title: number = 18
  static readonly heading: number = 22
  static readonly hero: number = 26
}

export class ThemeRadius {
  static readonly sm: number = 4
  static readonly md: number = 8
  static readonly lg: number = 12
  static readonly xl: number = 16
}

export class LayoutConstants {
  static readonly MIN_PANEL_WIDTH: number = 160
  static readonly MAX_PANEL_WIDTH: number = 500
  static readonly MIN_EDITOR_WIDTH: number = 280
  static readonly DEFAULT_LEFT_WIDTH: number = 260
  static readonly DEFAULT_RIGHT_WIDTH: number = 320
  static readonly DIVIDER_WIDTH: number = 4
  static readonly MAX_OPEN_TABS: number = 8
  static readonly MAX_FOLDER_DEPTH: number = 5
  static readonly MAX_CONTENT_LENGTH: number = 120000
  static readonly SEARCH_DEBOUNCE_MS: number = 300
  static readonly LAYOUT_SAVE_DEBOUNCE_MS: number = 500
}
