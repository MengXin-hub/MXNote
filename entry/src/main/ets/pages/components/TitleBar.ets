/**
 * TitleBar — 顶部全局栏。
 *
 * 布局（从左到右）:
 *   搜索框(居中) · 显示左面板 · 显示右面板 · 设置
 *
 * 所有尺寸/间距通过本文件顶部的常量统一控制，可直接修改。
 */
import { ThemeColors, ThemeFontSize } from '../../constants/ThemeConstants'
import { IconConstants } from '../../constants/IconConstants'

// ── 可调整布局参数 ──
const SEARCH_WIDTH: number = 360    // 搜索框最大宽度 vp
const SEARCH_HEIGHT: number = 34    // 搜索框高度 vp
const BTN_GAP: number = 2           // 按钮间隔
const BTN_PADDING: number = 6       // 按钮内边距
const ICON_SIZE: number = 18        // 图标尺寸 vp
const BAR_PADDING_V: number = 5     // 垂直内边距
const BAR_PADDING_H: number = 10    // 水平内边距

@Component
export struct TitleBar {
  @Link searchQuery: string
  @Prop leftVisible: boolean = true
  @Prop rightVisible: boolean = true
  onSearchChange?: (v: string) => void
  onLeftToggle?: () => void
  onRightToggle?: () => void
  onSettingsClick?: () => void

  build() {
    Row() {
      Blank()

      // ══ 居中搜索框 ════════════════════════════
      Row() {
        Image(IconConstants.IC_SEARCH).width(14).height(14)
          .fillColor(ThemeColors.colorTextTertiary).margin({ left: 10, right: 6 })
        TextInput({ text: $$this.searchQuery, placeholder: '搜索笔记...' })
          .fontSize(ThemeFontSize.bodySmall).fontColor(ThemeColors.colorTextPrimary)
          .placeholderColor(ThemeColors.colorTextTertiary).backgroundColor('#00000000')
          .height(SEARCH_HEIGHT).layoutWeight(1).borderRadius(0)
          .onChange((v: string) => {
            this.searchQuery = v
            if (this.onSearchChange) this.onSearchChange(v)
          })
        if (this.searchQuery.length > 0) {
          Image(IconConstants.IC_CLOSE).width(12).height(12)
            .fillColor(ThemeColors.colorTextTertiary).margin({ right: 8 })
            .onClick(() => {
              this.searchQuery = ''
              if (this.onSearchChange) this.onSearchChange('')
            })
        }
      }
      .width(SEARCH_WIDTH).height(SEARCH_HEIGHT)
      .backgroundColor(ThemeColors.colorBgHover)
      .borderRadius(17).border({ width: 1, color: ThemeColors.colorBorderSubtle })

      Blank()

      // ══ 右侧按钮 ════════════════════════════
      Row({ space: BTN_GAP }) {
        Image(IconConstants.IC_SIDEBAR).width(ICON_SIZE).height(ICON_SIZE)
          .fillColor(this.leftVisible ? ThemeColors.colorAccentBlue : ThemeColors.colorTextSecondary)
          .padding(BTN_PADDING)
          .onClick(() => { if (this.onLeftToggle) this.onLeftToggle() })

        Image(IconConstants.IC_SIDEBAR).width(ICON_SIZE).height(ICON_SIZE)
          .fillColor(this.rightVisible ? ThemeColors.colorAccentBlue : ThemeColors.colorTextSecondary)
          .padding(BTN_PADDING)
          .onClick(() => { if (this.onRightToggle) this.onRightToggle() })

        Image(IconConstants.IC_SETTINGS).width(ICON_SIZE).height(ICON_SIZE)
          .fillColor(ThemeColors.colorTextSecondary)
          .padding(BTN_PADDING)
          .onClick(() => { if (this.onSettingsClick) this.onSettingsClick() })
      }
    }
    .width('100%')
    .padding({ left: BAR_PADDING_H, right: BAR_PADDING_H, top: BAR_PADDING_V, bottom: BAR_PADDING_V })
    .backgroundColor(ThemeColors.colorBgCanvas)
    .border({ width: { bottom: 1 }, color: ThemeColors.colorBorderSubtle })
  }
}
