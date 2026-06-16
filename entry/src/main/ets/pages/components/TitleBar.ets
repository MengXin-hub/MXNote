/**
 * TitleBar — 紧接系统标题栏下方。
 *
 * 布局: [Logo] [☰]  ···  [Search居中]  ···
 * 高度 44vp, 与上方系统标题栏(56vp)共同组成100vp顶部区域
 *
 * MXNote 文字由系统标题栏 setWindowTitle('MXNote') 显示, 与三键同行
 */
import { ThemeColors } from '../../constants/ThemeConstants'
import { IconConstants } from '../../constants/IconConstants'

const BAR_HEIGHT: number = 44

@Component
export struct TitleBar {
  @Link searchQuery: string
  @Prop leftVisible: boolean = true
  onSearchChange?: (v: string) => void
  onLeftToggle?: () => void
  onLogoSettings?: () => void

  build() {
    Row() {
      Image($r('app.media.startIcon')).width(22).height(22).borderRadius(4).margin({ right: 6 })
        .onClick(() => { if (this.onLogoSettings) this.onLogoSettings() })
      Image(IconConstants.IC_SIDEBAR).width(18).height(18)
        .fillColor(this.leftVisible ? ThemeColors.colorAccentBlue : ThemeColors.colorTextSecondary)
        .padding(5).onClick(() => { if (this.onLeftToggle) this.onLeftToggle() })

      Blank()

      Search({ value: $$this.searchQuery, placeholder: '搜索笔记...' })
        .width(340).height(34).borderRadius(17)
        .onChange((v: string) => { this.searchQuery = v; if (this.onSearchChange) this.onSearchChange(v) })
        .onSubmit((v: string) => { if (this.onSearchChange) this.onSearchChange(v) })

      Blank()
    }
    .width('100%').height(BAR_HEIGHT).padding({ left: 12, right: 12 })
    .backgroundColor(ThemeColors.colorBgCanvas)
    .border({ width: { bottom: 1 }, color: ThemeColors.colorBorderSubtle })
  }
}
