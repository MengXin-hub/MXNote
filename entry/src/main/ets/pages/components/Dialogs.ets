/**
 * ┌─────────────────────────────────────────────────────────────┐
 * │  Dialogs — 胶囊式弹窗组件集                                  │
 * │                                                             │
 * │  统一样式: borderRadius=24, width=340vp, shadow+半透明遮罩    │
 * │  DlgConfirm — 确认/取消选择                                 │
 * │  DlgMigrationError — 数据迁移失败提示                        │
 * └─────────────────────────────────────────────────────────────┘
 */
import { ThemeColors } from '../../constants/ThemeConstants'

/** ══════════════════ 确认对话框（删除等不可逆操作） ═══════════════ */
@Component
export struct DlgConfirm {
  @Prop title: string = ''
  @Prop message: string = ''
  @Prop confirmLabel: string = '确认'
  @Prop confirmColor: string = ThemeColors.colorAccentRed
  onConfirm?: () => void
  onCancel?: () => void

  build() {
    Column() {
      Column() {
        Text(this.title).fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.colorTextPrimary).margin({ bottom: 6 }).width('100%')
        Text(this.message).fontSize(14).fontColor(ThemeColors.colorTextSecondary)
          .margin({ bottom: 24 }).width('100%')

        Row() {
          Text('取消').fontSize(14).fontColor(ThemeColors.colorTextSecondary)
            .textAlign(TextAlign.Center).width('45%').height(44)
            .backgroundColor(ThemeColors.colorBgHover).borderRadius(20)
            .onClick(() => { if (this.onCancel) this.onCancel() })
          Text(this.confirmLabel).fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor('#ffffff').textAlign(TextAlign.Center).width('45%').height(44)
            .backgroundColor(this.confirmColor).borderRadius(20).margin({ left: 12 })
            .onClick(() => { if (this.onConfirm) this.onConfirm() })
        }.width('100%').justifyContent(FlexAlign.Center)
      }
      .padding(24).backgroundColor(Color.White).borderRadius(24).width(340)
      .shadow({ radius: 32, color: '#0000001A', offsetY: 8 })
    }
    .width('100%').height('100%').backgroundColor('#00000033').justifyContent(FlexAlign.Center)
    .onClick(() => { if (this.onCancel) this.onCancel() })
  }
}

/** ══════════════════ 迁移失败对话框 ══════════════════════════════ */
@Component
export struct DlgMigrationError {
  onRetry?: () => void
  onSkip?: () => void

  build() {
    Column() {
      Column() {
        Text('数据迁移失败').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.colorTextPrimary).margin({ bottom: 6 }).width('100%')
        Text('您的旧笔记数据仍然保留，请尝试重新启动应用。若问题持续，请联系开发者。')
          .fontSize(14).fontColor(ThemeColors.colorTextSecondary).margin({ bottom: 24 }).width('100%')

        Row() {
          Text('跳过').fontSize(14).fontColor(ThemeColors.colorTextSecondary)
            .textAlign(TextAlign.Center).width('45%').height(44)
            .backgroundColor(ThemeColors.colorBgHover).borderRadius(20)
            .onClick(() => { if (this.onSkip) this.onSkip() })
          Text('重试').fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor('#ffffff').textAlign(TextAlign.Center).width('45%').height(44)
            .backgroundColor(ThemeColors.colorAccentBlue).borderRadius(20).margin({ left: 12 })
            .onClick(() => { if (this.onRetry) this.onRetry() })
        }.width('100%').justifyContent(FlexAlign.Center)
      }
      .padding(24).backgroundColor(Color.White).borderRadius(24).width(340)
      .shadow({ radius: 32, color: '#0000001A', offsetY: 8 })
    }
    .width('100%').height('100%').backgroundColor('#00000033').justifyContent(FlexAlign.Center)
    .onClick(() => { if (this.onSkip) this.onSkip() })
  }
}
