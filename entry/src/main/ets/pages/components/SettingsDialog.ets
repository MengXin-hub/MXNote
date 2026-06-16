/**
 * ┌─────────────────────────────────────────────────────────────┐
 * │  SettingsDialog — 设置弹窗                                   │
 * │                                                             │
 * │  字体大小 A⁻/A⁺ + 快捷键一览表 + 用户登录入口                  │
 * │  统一样式: borderRadius=24, width=340vp                      │
 * └─────────────────────────────────────────────────────────────┘
 */
import { ThemeColors, ThemeFontSize, ThemeRadius } from '../../constants/ThemeConstants'

@Component
export struct SettingsDialog {
  @Link fontSize: number
  @Link showLogin: boolean
  onClose?: () => void
  onFontPlus?: () => void
  onFontMinus?: () => void

  build() {
    Column() {
      Column() {
        Text('设置').fontSize(ThemeFontSize.title).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.colorTextPrimary).width('100%').margin({ bottom: 20 })

        // ── 字体大小 ──
        Text('字体大小').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.colorTextSecondary).width('100%').padding({ top: 8 })
        Row() {
          Text('正文字号').fontSize(ThemeFontSize.body).fontColor(ThemeColors.colorTextPrimary).layoutWeight(1)
          Row({ space: 8 }) {
            Text('A⁻').fontSize(14).fontColor(ThemeColors.colorAccentBlue)
              .width(32).height(32).textAlign(TextAlign.Center).borderRadius(16)
              .backgroundColor(ThemeColors.colorBgHover).onClick(() => { if (this.onFontMinus) this.onFontMinus() })
            Text(this.fontSize.toString()).fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(ThemeColors.colorTextPrimary).width(30).textAlign(TextAlign.Center)
            Text('A⁺').fontSize(14).fontColor(ThemeColors.colorAccentBlue)
              .width(32).height(32).textAlign(TextAlign.Center).borderRadius(16)
              .backgroundColor(ThemeColors.colorBgHover).onClick(() => { if (this.onFontPlus) this.onFontPlus() })
          }
        }.width('100%').padding({ top: 8, bottom: 16 })

        Divider().color(ThemeColors.colorBorderSubtle)

        // ── 快捷键一览 ──
        Text('快捷键一览').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.colorTextSecondary).width('100%').padding({ top: 12 })
        Column() {
          this.Shortcut('Ctrl+Z', '撤销')
          this.Shortcut('Ctrl+Y', '重做')
          this.Shortcut('Ctrl+S', '保存')
        }.width('100%').padding({ top: 8, bottom: 16 })

        Divider().color(ThemeColors.colorBorderSubtle)

        // ── 账户 ──
        Text('账户').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.colorTextSecondary).width('100%').padding({ top: 12 })
        Row() {
          Text('用户登录').fontSize(ThemeFontSize.body).fontColor(ThemeColors.colorTextPrimary).layoutWeight(1)
          Text('登录').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
            .fontColor(ThemeColors.colorAccentBlue)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 }).borderRadius(ThemeRadius.md)
            .border({ width: 1, color: ThemeColors.colorAccentBlue })
            .onClick(() => { this.showLogin = true })
        }.width('100%').padding({ top: 8, bottom: 8 })
      }
      .padding(24).backgroundColor('#ffffff').borderRadius(24).width(340)
      .shadow({ radius: 32, color: '#0000001A', offsetY: 8 })
    }
    .width('100%').height('100%').backgroundColor('#00000033').justifyContent(FlexAlign.Center)
    .onClick(() => { if (this.onClose) this.onClose() })
  }

  @Builder Shortcut(keys: string, desc: string) {
    Row() {
      Text(keys)
        .fontSize(12)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColors.colorAccentBlue)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(ThemeColors.colorBgSelected)
        .borderRadius(4)
        .width(100)
      Text(desc)
        .fontSize(ThemeFontSize.body)
        .fontColor(ThemeColors.colorTextSecondary)
        .margin({ left: 16 })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }
}

/** ══════════════════ 登录占位弹窗 ═══════════════════════════════ */
@Component
export struct LoginDialog {
  @State username: string = ''
  @State password: string = ''
  onClose?: () => void

  build() {
    Column() {
      Column() {
        Text('用户登录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.colorTextPrimary)
          .width('100%')
          .margin({ bottom: 20 })
        Text('手机号/邮箱').fontSize(12).fontColor(ThemeColors.colorTextSecondary).width('100%').margin({ bottom: 6 })
        TextInput({ text: $$this.username, placeholder: '请输入手机号或邮箱' })
          .fontSize(14).fontColor(ThemeColors.colorTextPrimary).placeholderColor(ThemeColors.colorTextTertiary)
          .backgroundColor(ThemeColors.colorBgHover).borderRadius(12).padding(12).width('100%')
        Text('密码').fontSize(12).fontColor(ThemeColors.colorTextSecondary).width('100%').margin({ top: 16, bottom: 6 })
        TextInput({ text: $$this.password, placeholder: '请输入密码' })
          .type(InputType.Password).fontSize(14).fontColor(ThemeColors.colorTextPrimary)
          .placeholderColor(ThemeColors.colorTextTertiary).backgroundColor(ThemeColors.colorBgHover)
          .borderRadius(12).padding(12).width('100%')
        Button('登 录').fontSize(14).fontColor('#ffffff').backgroundColor(ThemeColors.colorAccentBlue)
          .borderRadius(12).width('100%').height(44).margin({ top: 24 })
        Text('此功能即将上线').fontSize(11).fontColor(ThemeColors.colorTextTertiary).margin({ top: 8 })
      }
      .padding(24).backgroundColor('#ffffff').borderRadius(24).width(340)
      .shadow({ radius: 32, color: '#0000001A', offsetY: 8 })
    }
    .width('100%').height('100%').backgroundColor('#00000033').justifyContent(FlexAlign.Center)
    .onClick(() => { if (this.onClose) this.onClose() })
  }
}
