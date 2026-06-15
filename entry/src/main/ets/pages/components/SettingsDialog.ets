/**
 * SettingsDialog — 设置弹窗（字体大小/快捷键/登录）。
 */
import { ThemeColors, ThemeFontSize, ThemeSpacing, ThemeRadius } from '../../constants/ThemeConstants'

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

        // 字体大小
        Text('字体大小').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.colorTextSecondary).width('100%')
        Row() {
          Text('正文字号').fontSize(ThemeFontSize.body).fontColor(ThemeColors.colorTextPrimary).layoutWeight(1)
          Row({ space: 8 }) {
            Text('A⁻').fontSize(14).fontColor(ThemeColors.colorAccentBlue)
              .width(32).height(32).textAlign(TextAlign.Center).borderRadius(16)
              .backgroundColor(ThemeColors.colorBgHover)
              .onClick(() => { if (this.onFontMinus) this.onFontMinus() })
            Text(this.fontSize.toString()).fontSize(ThemeFontSize.subtitle).fontWeight(FontWeight.Bold)
              .fontColor(ThemeColors.colorTextPrimary).width(30).textAlign(TextAlign.Center)
            Text('A⁺').fontSize(14).fontColor(ThemeColors.colorAccentBlue)
              .width(32).height(32).textAlign(TextAlign.Center).borderRadius(16)
              .backgroundColor(ThemeColors.colorBgHover)
              .onClick(() => { if (this.onFontPlus) this.onFontPlus() })
          }
        }.width('100%').padding({ top: 8, bottom: 16 })

        Divider().color(ThemeColors.colorBorderSubtle)

        // 快捷键一览
        Text('快捷键一览').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.colorTextSecondary).width('100%').padding({ top: 12 })
        Column() {
          this.ShortcutRow('Ctrl+B', '加粗')
          this.ShortcutRow('Ctrl+I', '斜体')
          this.ShortcutRow('Ctrl+U', '下划线')
          this.ShortcutRow('Ctrl+Z', '撤销')
          this.ShortcutRow('Ctrl+Y', '重做')
          this.ShortcutRow('Ctrl+S', '保存')
        }.width('100%').padding({ top: 8, bottom: 16 })

        Divider().color(ThemeColors.colorBorderSubtle)

        // 账户
        Text('账户').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.colorTextSecondary).width('100%').padding({ top: 12 })
        Row() {
          Text('用户登录').fontSize(ThemeFontSize.body).fontColor(ThemeColors.colorTextPrimary).layoutWeight(1)
          Text('登录').fontSize(ThemeFontSize.bodySmall).fontWeight(FontWeight.Medium)
            .fontColor(ThemeColors.colorAccentBlue)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .borderRadius(ThemeRadius.md).border({ width: 1, color: ThemeColors.colorAccentBlue })
            .onClick(() => { this.showLogin = true })
        }.width('100%').padding({ top: 8, bottom: 8 })
      }
      .padding(24).backgroundColor('#ffffff').borderRadius(ThemeRadius.xl).width('88%')
      .shadow({ radius: 24, color: '#00000018' })
    }
    .width('100%').height('100%')
    .backgroundColor(ThemeColors.colorBgOverlay)
    .justifyContent(FlexAlign.Center)
    .onClick(() => { if (this.onClose) this.onClose() })
  }

  @Builder ShortcutRow(keys: string, desc: string) {
    Row() {
      Text(keys).fontSize(12).fontFamily('monospace').fontWeight(FontWeight.Bold)
        .fontColor(ThemeColors.colorAccentBlue)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(ThemeColors.colorBgSelected).borderRadius(4)
      Text(desc).fontSize(ThemeFontSize.body).fontColor(ThemeColors.colorTextSecondary)
        .margin({ left: 16 })
    }.width('100%').padding({ top: 4, bottom: 4 })
  }
}

@Component
export struct LoginDialog {
  @State username: string = ''
  @State password: string = ''
  onClose?: () => void

  build() {
    Column() {
      Column() {
        Text('用户登录').fontSize(ThemeFontSize.title).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.colorTextPrimary).width('100%').margin({ bottom: 20 })

        Text('手机号/邮箱').fontSize(ThemeFontSize.bodySmall)
          .fontColor(ThemeColors.colorTextSecondary).width('100%').margin({ bottom: 6 })
        TextInput({ text: $$this.username, placeholder: '请输入手机号或邮箱' })
          .fontSize(ThemeFontSize.body).fontColor(ThemeColors.colorTextPrimary)
          .placeholderColor(ThemeColors.colorTextTertiary)
          .backgroundColor(ThemeColors.colorBgHover).borderRadius(ThemeRadius.md).padding(12).width('100%')

        Text('密码').fontSize(ThemeFontSize.bodySmall)
          .fontColor(ThemeColors.colorTextSecondary).width('100%').margin({ top: 16, bottom: 6 })
        TextInput({ text: $$this.password, placeholder: '请输入密码' })
          .type(InputType.Password).fontSize(ThemeFontSize.body).fontColor(ThemeColors.colorTextPrimary)
          .placeholderColor(ThemeColors.colorTextTertiary)
          .backgroundColor(ThemeColors.colorBgHover).borderRadius(ThemeRadius.md).padding(12).width('100%')

        Button('登 录').fontSize(ThemeFontSize.body).fontColor('#ffffff')
          .backgroundColor(ThemeColors.colorAccentBlue).borderRadius(ThemeRadius.md)
          .width('100%').height(44).margin({ top: 24 })

        Text('此功能即将上线').fontSize(ThemeFontSize.caption)
          .fontColor(ThemeColors.colorTextTertiary).margin({ top: 8 })
      }
      .padding(24).backgroundColor('#ffffff').borderRadius(ThemeRadius.xl).width('88%')
      .shadow({ radius: 24, color: '#00000018' })
    }
    .width('100%').height('100%')
    .backgroundColor(ThemeColors.colorBgOverlay)
    .justifyContent(FlexAlign.Center)
    .onClick(() => { if (this.onClose) this.onClose() })
  }
}
