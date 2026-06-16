/**
 * EditorArea — 独立编辑器组件。
 *
 * 封装 TextArea，使 keystroke 状态变更局限在本组件内，
 * 不触发父级 Index 的全树重渲染（避免主线程阻塞 ANR）。
 */
import { ThemeColors } from '../../constants/ThemeConstants'

@Component
export struct EditorArea {
  @Prop fontSize: number = 18
  @Link content: string
  onChange?: (v: string) => void

  build() {
    TextArea({ text: $$this.content, placeholder: '# Markdown\n\n写完点击保存后预览' })
      .width('100%').layoutWeight(1).backgroundColor(ThemeColors.colorBgCanvas)
      .fontSize(this.fontSize).fontColor(ThemeColors.colorTextPrimary)
      .fontFamily('monospace').padding(14).borderRadius(0)
      .caretColor(ThemeColors.colorAccentBlue).placeholderColor(ThemeColors.colorTextTertiary)
      .onChange((v: string) => {
        if (this.onChange) this.onChange(v)
      })
  }
}
