/**
 * Dialogs — 统一对话框组件集。
 *
 * 使用 DialogShell 插槽模式消除 Index.ets 中的重复 @Builder 代码。
 * 所有对话框共享遮罩 + 卡片 + 按钮布局，仅标题/内容/操作不同。
 */
import { ThemeColors } from '../../constants/ThemeConstants'

/**
 * DialogShell — 可复用对话框外壳。
 *
 * @BuilderParam title: 标题区域
 * @BuilderParam body: 内容区域
 * @BuilderParam actions: 按钮区域
 */
@Component
export struct DialogShell {
  @BuilderParam titleSlot: () => void = this.DefaultTitle
  @BuilderParam bodySlot: () => void = this.DefaultBody
  @BuilderParam actionsSlot: () => void = this.DefaultActions
  onOverlayClick?: () => void

  @Builder DefaultTitle() {
    Text('').fontSize(18).fontWeight(FontWeight.Bold).fontColor(ThemeColors.colorTextPrimary)
  }

  @Builder DefaultBody() {
    Text('').fontSize(14).fontColor(ThemeColors.colorTextSecondary)
  }

  @Builder DefaultActions() {
    Row() {
      Button('取消').fontSize(14).backgroundColor(ThemeColors.colorBgSurface)
        .fontColor(ThemeColors.colorTextSecondary)
        .border({ width: 1, color: ThemeColors.colorBorderDefault, radius: 8 })
        .width('45%')
      Button('确认').fontSize(14).backgroundColor(ThemeColors.colorAccentBlue)
        .fontColor('#ffffff').borderRadius(8).width('45%').margin({ left: 12 })
    }.width('100%').justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Column() {
        this.titleSlot()
        this.bodySlot()
        this.actionsSlot()
      }
      .padding(28)
      .backgroundColor(ThemeColors.colorBgSurface)
      .border({ width: 1, color: ThemeColors.colorBorderDefault, radius: 16 })
      .width('85%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.colorBgOverlay)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.onOverlayClick) {
        this.onOverlayClick()
      }
    })
  }
}

/**
 * DlgInput — 输入对话框（新建 / 重命名）。
 */
@Component
export struct DlgInput {
  @Prop title: string = ''
  @Link textValue: string
  @Prop placeholder: string = ''
  confirmLabel: string = '确认'
  onConfirm?: () => void
  onCancel?: () => void

  build() {
    DialogShell({
      titleSlot: (): void => {
        this.TitleBuilder()
      },
      bodySlot: (): void => {
        this.BodyBuilder()
      },
      actionsSlot: (): void => {
        this.ActionsBuilder()
      },
      onOverlayClick: (): void => {
        if (this.onCancel) { this.onCancel() }
      }
    })
  }

  @Builder TitleBuilder() {
    Text(this.title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor(ThemeColors.colorTextPrimary)
      .margin({ bottom: 16 })
  }

  @Builder BodyBuilder() {
    TextInput({ text: $$this.textValue, placeholder: this.placeholder })
      .fontSize(15)
      .fontColor(ThemeColors.colorTextPrimary)
      .placeholderColor(ThemeColors.colorTextTertiary)
      .backgroundColor(ThemeColors.colorBgCanvas)
      .border({ width: 1, color: ThemeColors.colorBorderDefault, radius: 8 })
      .padding(12)
  }

  @Builder ActionsBuilder() {
    Row() {
      Button('取消')
        .fontSize(14)
        .backgroundColor(ThemeColors.colorBgSelected)
        .fontColor(ThemeColors.colorTextSecondary)
        .border({ width: 1, color: ThemeColors.colorBorderDefault, radius: 8 })
        .width('45%')
        .onClick(() => { if (this.onCancel) { this.onCancel() } })

      Button(this.confirmLabel)
        .fontSize(14)
        .backgroundColor(ThemeColors.colorAccentBlue)
        .fontColor('#ffffff')
        .borderRadius(8)
        .width('45%')
        .margin({ left: 12 })
        .onClick(() => { if (this.onConfirm) { this.onConfirm() } })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: 20 })
  }
}

/**
 * DlgConfirm — 确认对话框（删除确认等）。
 */
@Component
export struct DlgConfirm {
  @Prop title: string = ''
  @Prop message: string = ''
  @Prop confirmLabel: string = '确认'
  @Prop confirmColor: string = ThemeColors.colorAccentRed
  onConfirm?: () => void
  onCancel?: () => void

  build() {
    DialogShell({
      titleSlot: (): void => {
        this.TitleBuilder()
      },
      bodySlot: (): void => {
        this.BodyBuilder()
      },
      actionsSlot: (): void => {
        this.ActionsBuilder()
      },
      onOverlayClick: (): void => {
        if (this.onCancel) { this.onCancel() }
      }
    })
  }

  @Builder TitleBuilder() {
    Text(this.title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor(ThemeColors.colorTextPrimary)
      .margin({ bottom: 6 })
  }

  @Builder BodyBuilder() {
    Text(this.message)
      .fontSize(14)
      .fontColor(ThemeColors.colorTextSecondary)
      .margin({ bottom: 24 })
  }

  @Builder ActionsBuilder() {
    Row() {
      Button('取消')
        .fontSize(14)
        .backgroundColor(ThemeColors.colorBgSelected)
        .fontColor(ThemeColors.colorTextSecondary)
        .border({ width: 1, color: ThemeColors.colorBorderDefault, radius: 8 })
        .width('45%')
        .onClick(() => { if (this.onCancel) { this.onCancel() } })

      Button(this.confirmLabel)
        .fontSize(14)
        .backgroundColor(this.confirmColor)
        .fontColor('#ffffff')
        .borderRadius(8)
        .width('45%')
        .margin({ left: 12 })
        .onClick(() => { if (this.onConfirm) { this.onConfirm() } })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}

/**
 * DlgMigrationError — 数据迁移失败对话框。
 */
@Component
export struct DlgMigrationError {
  onRetry?: () => void
  onSkip?: () => void

  build() {
    DialogShell({
      titleSlot: (): void => {
        this.TitleBuilder()
      },
      bodySlot: (): void => {
        this.BodyBuilder()
      },
      actionsSlot: (): void => {
        this.ActionsBuilder()
      }
    })
  }

  @Builder TitleBuilder() {
    Text('数据迁移失败')
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor(ThemeColors.colorTextPrimary)
      .margin({ bottom: 6 })
  }

  @Builder BodyBuilder() {
    Text('您的旧笔记数据仍然保留，请尝试重新启动应用。若问题持续，请联系开发者。')
      .fontSize(14)
      .fontColor(ThemeColors.colorTextSecondary)
      .margin({ bottom: 24 })
  }

  @Builder ActionsBuilder() {
    Row() {
      Button('跳过')
        .fontSize(14)
        .backgroundColor(ThemeColors.colorBgSelected)
        .fontColor(ThemeColors.colorTextSecondary)
        .border({ width: 1, color: ThemeColors.colorBorderDefault, radius: 8 })
        .width('45%')
        .onClick(() => { if (this.onSkip) { this.onSkip() } })

      Button('重试')
        .fontSize(14)
        .backgroundColor(ThemeColors.colorAccentBlue)
        .fontColor('#ffffff')
        .borderRadius(8)
        .width('45%')
        .margin({ left: 12 })
        .onClick(() => { if (this.onRetry) { this.onRetry() } })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}
