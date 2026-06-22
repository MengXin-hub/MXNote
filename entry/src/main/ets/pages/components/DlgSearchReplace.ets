/**
 * ┌─────────────────────────────────────────────────────────────┐
 * │  DlgSearchReplace — 搜索替换面板                               │
 * │                                                             │
 * │  从 note-gen 迁移：支持查找上一个/下一个、替换当前、替换全部、   │
 * │  区分大小写。统一样式遵循 MXNote 胶囊式弹窗。                   │
 * └─────────────────────────────────────────────────────────────┘
 */
import { ThemeColors, ThemeFontSize } from '../../constants/ThemeConstants'

/** 搜索结果项 */
class SearchResult {
  line: number = 0     // 行号 (1-based)
  start: number = 0    // 在行内的起始字符位置
  end: number = 0      // 在行内的结束字符位置
  constructor(line: number, start: number, end: number) {
    this.line = line; this.start = start; this.end = end
  }
}

@Component
export struct DlgSearchReplace {
  @Prop content: string = ''           // 当前编辑内容
  @State searchText: string = ''
  @State replaceText: string = ''
  @State caseSensitive: boolean = false
  @State results: SearchResult[] = []
  @State resultIndex: number = -1      // 当前高亮的搜索结果索引
  @State resultCount: number = 0
  @State showReplace: boolean = false  // 展开替换行
  onNavigate?: (line: number, start: number, end: number) => void
  onReplace?: (line: number, start: number, end: number, newText: string) => void
  onReplaceAll?: (search: string, replace: string, caseSensitive: boolean) => string
  onClose?: () => void

  /**
   * 执行全文搜索，记录所有匹配位置。
   */
  doSearch(): void {
    this.results = []
    this.resultIndex = -1; this.resultCount = 0
    const st: string = this.searchText
    if (!st || !this.content) return

    const source: string = this.caseSensitive ? this.content : this.content.toLowerCase()
    const target: string = this.caseSensitive ? st : st.toLowerCase()
    const lines: string[] = this.content.split('\n')
    let absPos: number = 0

    for (let i: number = 0; i < lines.length; i++) {
      const lineSource: string = this.caseSensitive ? lines[i] : lines[i].toLowerCase()
      let col: number = 0
      while (col < lineSource.length) {
        const found: number = lineSource.indexOf(target, col)
        if (found < 0) break
        this.results.push(new SearchResult(i, found, found + target.length))
        col = found + 1
      }
      absPos += lines[i].length + 1
    }
    this.resultCount = this.results.length
    if (this.resultCount > 0) {
      this.resultIndex = 0
      this.navigateTo(0)
    }
  }

  /** 定位到指定搜索结果 */
  navigateTo(idx: number): void {
    if (idx < 0 || idx >= this.results.length) return
    this.resultIndex = idx
    const r: SearchResult = this.results[idx]
    if (this.onNavigate) {
      this.onNavigate(r.line, r.start, r.end)
    }
  }

  nextResult(): void {
    if (this.resultCount === 0) return
    const next: number = (this.resultIndex + 1) % this.resultCount
    this.navigateTo(next)
  }

  prevResult(): void {
    if (this.resultCount === 0) return
    const prev: number = (this.resultIndex - 1 + this.resultCount) % this.resultCount
    this.navigateTo(prev)
  }

  doReplaceCurrent(): void {
    if (this.resultIndex < 0 || this.resultIndex >= this.results.length) return
    const r: SearchResult = this.results[this.resultIndex]
    if (this.onReplace) {
      this.onReplace(r.line, r.start, r.end, this.replaceText)
    }
    // 替换后重新搜索
    this.doSearch()
  }

  doReplaceAll(): void {
    if (this.resultCount === 0 || !this.searchText) return
    if (this.onReplaceAll) {
      const newContent: string = this.onReplaceAll(
        this.searchText, this.replaceText, this.caseSensitive
      )
      // 由父组件处理内容更新
    }
  }

  build() {
    Column() {
      Column() {
        // ── 标题 ──
        Row() {
          Text('搜索替换').fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.colorTextPrimary)
          Blank()
          Text('✕').fontSize(18).fontColor(ThemeColors.colorTextTertiary)
            .onClick(() => { if (this.onClose) this.onClose() })
        }.width('100%').margin({ bottom: 14 })

        // ── 搜索行 ──
        Row() {
          TextInput({ text: $$this.searchText, placeholder: '搜索...' })
            .fontSize(14).fontColor(ThemeColors.colorTextPrimary)
            .placeholderColor(ThemeColors.colorTextTertiary)
            .backgroundColor(ThemeColors.colorBgHover).borderRadius(12).padding(10)
            .layoutWeight(1).height(40)
            .onSubmit(() => { this.doSearch() })
          if (this.resultCount > 0) {
            Text((this.resultIndex + 1).toString() + '/' + this.resultCount.toString())
              .fontSize(12).fontColor(ThemeColors.colorTextSecondary)
              .margin({ left: 6, right: 4 })
          }
          // 上一个/下一个
          Text('▲').fontSize(16).fontColor(this.resultCount > 0 ? ThemeColors.colorAccentBlue : ThemeColors.colorTextTertiary)
            .width(30).height(30).textAlign(TextAlign.Center)
            .onClick(() => { this.prevResult() })
          Text('▼').fontSize(16).fontColor(this.resultCount > 0 ? ThemeColors.colorAccentBlue : ThemeColors.colorTextTertiary)
            .width(30).height(30).textAlign(TextAlign.Center)
            .onClick(() => { this.nextResult() })
        }.width('100%')

        // ── 展开替换行 ──
        if (this.showReplace) {
          Row() {
            TextInput({ text: $$this.replaceText, placeholder: '替换为...' })
              .fontSize(14).fontColor(ThemeColors.colorTextPrimary)
              .placeholderColor(ThemeColors.colorTextTertiary)
              .backgroundColor(ThemeColors.colorBgHover).borderRadius(12).padding(10)
              .layoutWeight(1).height(40)
          }.width('100%').margin({ top: 10 })

          Row() {
            Text('替换当前').fontSize(13).fontColor(ThemeColors.colorAccentBlue)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(8).border({ width: 1, color: ThemeColors.colorAccentBlue })
              .onClick(() => { this.doReplaceCurrent() })
            Text('全部替换').fontSize(13).fontColor('#ffffff')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(8).backgroundColor(ThemeColors.colorAccentBlue)
              .margin({ left: 8 })
              .onClick(() => { this.doReplaceAll() })
          }.width('100%').margin({ top: 8 })
        }

        // ── 操作行 ──
        Row() {
          // 区分大小写
          Row() {
            Text(this.caseSensitive ? 'Aa' : 'aa').fontSize(11)
              .fontColor(this.caseSensitive ? ThemeColors.colorAccentBlue : ThemeColors.colorTextTertiary)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(6)
              .backgroundColor(this.caseSensitive ? ThemeColors.colorBgSelected : ThemeColors.colorBgHover)
              .onClick(() => { this.caseSensitive = !this.caseSensitive })
          }
          Blank()
          // 展开替换
          Text(this.showReplace ? '收起替换' : '展开替换').fontSize(12)
            .fontColor(ThemeColors.colorAccentBlue)
            .onClick(() => { this.showReplace = !this.showReplace })
          Text('搜索').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor('#ffffff').padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .borderRadius(8).backgroundColor(ThemeColors.colorAccentBlue)
            .margin({ left: 10 })
            .onClick(() => { this.doSearch() })
        }.width('100%').margin({ top: 14 })
      }
      .padding(20).backgroundColor(Color.White).borderRadius(24).width(380)
      .shadow({ radius: 32, color: '#0000001A', offsetY: 8 })
    }
    .width('100%').height('100%').backgroundColor('#00000033').justifyContent(FlexAlign.Center)
    .onClick(() => { if (this.onClose) this.onClose() })
  }
}
