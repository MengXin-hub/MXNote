/**
 * ┌─────────────────────────────────────────────────────────────┐
 * │  DlgInsertLink — 插入链接弹窗                                │
 * │                                                             │
 * │  输入 URL 和显示文字，生成 [文字](URL) Markdown 后回调        │
 * │  统一样式: borderRadius=24, width=340vp                      │
 * └─────────────────────────────────────────────────────────────┘
 */
import { ThemeColors, ThemeFontSize } from '../../constants/ThemeConstants'
import { IconConstants } from '../../constants/IconConstants'

@Component
export struct DlgInsertLink {
  @State urlText: string = ''
  @State displayText: string = ''
  onInsert?: (markdown: string) => void
  onCancel?: () => void

  build() {
    Column() {
      Column() {
        // ── 标题行 ──
        Row() {
          Text('插入链接').fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.colorTextPrimary)
          Blank()
          Image(IconConstants.IC_CLOSE).width(20).height(20)
            .fillColor(ThemeColors.colorTextTertiary)
            .onClick(() => { if (this.onCancel) this.onCancel() })
        }.width('100%').margin({ bottom: 18 })

        // ── URL 输入 ──
        Text('链接地址').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.colorTextSecondary).width('100%').margin({ bottom: 6 })
        TextInput({ text: $$this.urlText, placeholder: 'https://example.com 或笔记标题' })
          .fontSize(14).fontColor(ThemeColors.colorTextPrimary)
          .placeholderColor(ThemeColors.colorTextTertiary)
          .backgroundColor(ThemeColors.colorBgHover).borderRadius(12).padding(12).width('100%')
          .margin({ bottom: 14 })

        // ── 显示文字输入 ──
        Text('显示文字（可选，默认使用链接）').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.colorTextSecondary).width('100%').margin({ bottom: 6 })
        TextInput({ text: $$this.displayText, placeholder: '链接文字' })
          .fontSize(14).fontColor(ThemeColors.colorTextPrimary)
          .placeholderColor(ThemeColors.colorTextTertiary)
          .backgroundColor(ThemeColors.colorBgHover).borderRadius(12).padding(12).width('100%')

        // ── 按钮行 ──
        Row() {
          Text('取消').fontSize(14).fontColor(ThemeColors.colorTextSecondary)
            .textAlign(TextAlign.Center).width('45%').height(44)
            .backgroundColor(ThemeColors.colorBgHover).borderRadius(20)
            .onClick(() => { if (this.onCancel) this.onCancel() })
          Text('插入').fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor('#ffffff').textAlign(TextAlign.Center).width('45%').height(44)
            .backgroundColor(ThemeColors.colorAccentBlue).borderRadius(20).margin({ left: 12 })
            .onClick(() => {
              const url: string = this.urlText.trim()
              if (url.length === 0) return
              const display: string = this.displayText.trim() || url
              const md: string = '[' + display + '](' + url + ')'
              if (this.onInsert) this.onInsert(md)
            })
        }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 22 })
      }
      .padding(24).backgroundColor(Color.White).borderRadius(24).width(340)
      .shadow({ radius: 32, color: '#0000001A', offsetY: 8 })
    }
    .width('100%').height('100%').backgroundColor('#00000033').justifyContent(FlexAlign.Center)
    .onClick(() => { if (this.onCancel) this.onCancel() })
  }
}
