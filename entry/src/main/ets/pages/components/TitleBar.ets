/**
 * ┌─────────────────────────────────────────────────────────────┐
 * │  TitleBar — 应用顶部工具栏（系统标题栏正下方 44vp）          │
 * │                                                             │
 * │  [Logo] [☰] [AI] ··· [🔍 Search 居中] ···                  │
 * │                                                             │
 * │  Logo → 设置弹窗        ☰ → 左面板开/关                     │
 * │  AI  → 右侧 AI 面板     Search → 标题+内容全局过滤           │
 * └─────────────────────────────────────────────────────────────┘
 */
import { ThemeColors } from '../../constants/ThemeConstants'
import { IconConstants } from '../../constants/IconConstants'

@Component
export struct TitleBar {
  // ── Props: 父组件驱动 ──
  @Link searchQuery: string
  @Prop leftVisible: boolean = true

  // ── 回调 ──
  onSearchChange?: (v: string) => void
  onLeftToggle?: () => void
  onAiClick?: () => void
  onLogoSettings?: () => void

  build() {
    Row() {
      // Logo（点击进设置）
      Image($r('app.media.startIcon')).width(22).height(22).borderRadius(4).margin({ right: 6 })
        .onClick(() => { if (this.onLogoSettings) this.onLogoSettings() })

      // 左边栏切换
      Image(IconConstants.IC_SIDEBAR)
        .width(18)
        .height(18)
        .fillColor(this.leftVisible ? ThemeColors.colorAccentBlue : ThemeColors.colorTextSecondary)
        .padding(5).onClick(() => { if (this.onLeftToggle) this.onLeftToggle() })

      // AI 面板入口
      Text('AI')
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColors.colorTextSecondary)
        .padding({ left: 6, right: 6, top: 4, bottom: 4 })
        .borderRadius(4)
        .backgroundColor(ThemeColors.colorBgHover)
        .onClick(() => { if (this.onAiClick) this.onAiClick() })

      Blank()

      // 居中搜索框（官方 Search 组件）
      Search({ value: $$this.searchQuery, placeholder: '搜索标题或内容...' })
        .width(340)
        .height(34)
        .borderRadius(17)
        .onChange((v: string) => { this.searchQuery = v; if (this.onSearchChange) this.onSearchChange(v) })
        .onSubmit((v: string) => { if (this.onSearchChange) this.onSearchChange(v) })

      Blank()
    }
    .width('100%').height(44).padding({ left: 12, right: 12 })
    .backgroundColor(ThemeColors.colorBgCanvas)
    .border({ width: { bottom: 1 }, color: ThemeColors.colorBorderSubtle })
  }
}
