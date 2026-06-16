/**
 * ┌─────────────────────────────────────────────────────────────┐
 * │  EditorArea — Markdown 编辑器组件                            │
 * │                                                             │
 * │  封装 TextArea，keystroke 变更隔离在本组件内，               │
 * │  不触发父级 Index 全树重渲染。                               │
 * │                                                             │
 * │  @Prop content: 父级传纯文本 → @Watch 同步到 @State         │
 * │  onChange: 击键回调（字数统计 + dirty 标记）                 │
 * └─────────────────────────────────────────────────────────────┘
 */
import { ThemeColors } from '../../constants/ThemeConstants'

@Component
export struct EditorArea {
  @Prop fontSize: number = 18
  @Prop @Watch('onContentPropChange') content: string = ''
  @State localText: string = ''
  onChange?: (v: string) => void

  aboutToAppear(): void { this.localText = this.content }
  onContentPropChange(): void { this.localText = this.content }

  build() {
    TextArea({
      text: $$this.localText,
      placeholder: '# Markdown\n\n写完点击保存后预览'
    })
      .width('100%').layoutWeight(1).backgroundColor(ThemeColors.colorBgCanvas)
      .fontSize(this.fontSize).fontColor(ThemeColors.colorTextPrimary)
      .fontFamily('monospace').padding(14).borderRadius(0)
      .caretColor(ThemeColors.colorAccentBlue).placeholderColor(ThemeColors.colorTextTertiary)
      .onChange((v: string) => {
        this.localText = v
        if (this.onChange) this.onChange(v)
      })
  }
}
