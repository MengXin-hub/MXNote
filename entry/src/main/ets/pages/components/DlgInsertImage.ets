/**
 * ┌─────────────────────────────────────────────────────────────┐
 * │  DlgInsertImage — 插入图片弹窗                               │
 * │                                                             │
 * │  两种模式: 输入 URL / 从相册选择                              │
 * │  URL 模式: 直接生成 ![alt](url) Markdown                      │
 * │  相册模式: 触发 PhotoViewPicker（父组件处理），复制到沙箱后插入  │
 * │  统一样式: borderRadius=24, width=340vp                      │
 * └─────────────────────────────────────────────────────────────┘
 */
import { ThemeColors, ThemeFontSize } from '../../constants/ThemeConstants'
import { IconConstants } from '../../constants/IconConstants'

@Component
export struct DlgInsertImage {
  @State urlText: string = ''
  @State altText: string = ''
  @State mode: string = 'url'   // 'url' | 'gallery'
  @State picking: boolean = false
  onInsert?: (markdown: string) => void
  onPickFromGallery?: () => void
  onCancel?: () => void

  build() {
    Column() {
      Column() {
        // ── 标题行 ──
        Row() {
          Text('插入图片').fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.colorTextPrimary)
          Blank()
          Image(IconConstants.IC_CLOSE).width(20).height(20)
            .fillColor(ThemeColors.colorTextTertiary)
            .onClick(() => { if (this.onCancel) this.onCancel() })
        }.width('100%').margin({ bottom: 18 })

        // ── 模式切换标签 ──
        Row() {
          Text('输入URL').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.mode === 'url' ? ThemeColors.colorAccentBlue : ThemeColors.colorTextSecondary)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .borderRadius(8)
            .backgroundColor(this.mode === 'url' ? ThemeColors.colorBgSelected : ThemeColors.colorBgHover)
            .onClick(() => { this.mode = 'url' })
          Text('从相册').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.mode === 'gallery' ? ThemeColors.colorAccentBlue : ThemeColors.colorTextSecondary)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .borderRadius(8)
            .backgroundColor(this.mode === 'gallery' ? ThemeColors.colorBgSelected : ThemeColors.colorBgHover)
            .margin({ left: 8 })
            .onClick(() => { this.mode = 'gallery' })
        }.width('100%').margin({ bottom: 16 })

        // ── URL 输入模式 ──
        if (this.mode === 'url') {
          Text('图片链接').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
            .fontColor(ThemeColors.colorTextSecondary).width('100%').margin({ bottom: 6 })
          TextInput({ text: $$this.urlText, placeholder: 'https://example.com/image.jpg' })
            .fontSize(14).fontColor(ThemeColors.colorTextPrimary)
            .placeholderColor(ThemeColors.colorTextTertiary)
            .backgroundColor(ThemeColors.colorBgHover).borderRadius(12).padding(12).width('100%')
            .margin({ bottom: 14 })

          Text('描述文字（可选）').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
            .fontColor(ThemeColors.colorTextSecondary).width('100%').margin({ bottom: 6 })
          TextInput({ text: $$this.altText, placeholder: '图片描述' })
            .fontSize(14).fontColor(ThemeColors.colorTextPrimary)
            .placeholderColor(ThemeColors.colorTextTertiary)
            .backgroundColor(ThemeColors.colorBgHover).borderRadius(12).padding(12).width('100%')
        }

        // ── 相册选择模式 ──
        if (this.mode === 'gallery') {
          Column() {
            Image(IconConstants.IC_IMAGE)
              .width(48).height(48)
              .fillColor(this.picking ? ThemeColors.colorAccentBlue : ThemeColors.colorBorderDefault)
              .margin({ bottom: 10 })
            Text(this.picking ? '正在处理...' : '点击选择图片')
              .fontSize(14).fontColor(ThemeColors.colorTextSecondary)
            Text('支持 JPG、PNG、GIF、WebP 等格式')
              .fontSize(11).fontColor(ThemeColors.colorTextTertiary).margin({ top: 4 })
          }
          .width('100%').padding({ top: 16, bottom: 16 })
          .backgroundColor(ThemeColors.colorBgHover).borderRadius(12)
          .onClick(() => {
            if (!this.picking && this.onPickFromGallery) {
              this.onPickFromGallery()
            }
          })
        }

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
              if (this.mode === 'url') {
                const url: string = this.urlText.trim()
                if (url.length === 0) return
                const alt: string = this.altText.trim() || 'image'
                const md: string = '![' + alt + '](' + url + ')'
                if (this.onInsert) this.onInsert(md)
              }
              // 相册模式由父组件在复制完成后调用 onInsert
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
