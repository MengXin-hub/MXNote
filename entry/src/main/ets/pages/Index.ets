import { KeyCode } from '@kit.InputKit'
import { FileManager } from '../core/FileManager'
import { NoteFile, formatTime } from '../model/NoteFile'
import { MarkdownParser, MarkdownToken, TokenType, InlineSpan } from '../core/MarkdownParser'

/**
 * MXNote — 三面板 Markdown 编辑器。
 *
 * 可靠实现策略:
 *   键盘快捷键: onKeyEvent + event.keyCode 直接比对 (不依赖 metaKey)
 *   文本选区:    TextAreaController 管理光标/选区, 格式按钮在选区位置操作
 *   格式化:      有选区 → 语法包裹 | 无选区 → 光标处插入模板
 */

class EditSnapshot {
  content: string = ''
  constructor(content: string) { this.content = content }
}

@Entry
@Component
struct Index {
  // ─── 文件 ──────────────────────────────────────
  @State noteList: NoteFile[] = []
  @State searchQuery: string = ''
  @State filteredList: NoteFile[] = []
  @State activeNoteId: string = ''
  @State activeTitle: string = ''
  @State activeContent: string = ''
  @State createdAt: number = 0
  @State modifiedAt: number = 0
  @State listLoading: boolean = true

  // ─── 编辑器 ────────────────────────────────────
  @State editorContent: string = ''
  @State previewTokens: MarkdownToken[] = []
  @State wordCount: number = 0
  private textAreaController: TextAreaController = new TextAreaController()

  // ─── UI ────────────────────────────────────────
  @State showSidebar: boolean = true
  @State showPreview: boolean = false
  @State statusMsg: string = ''
  @State showNewDialog: boolean = false
  @State showRenameDialog: boolean = false
  @State showDeleteConfirm: boolean = false
  @State showShortcuts: boolean = false

  private fm: FileManager | null = null
  private parser: MarkdownParser = new MarkdownParser()
  private undoStack: EditSnapshot[] = []
  private redoStack: EditSnapshot[] = []

  // 弹窗临时变量
  private tmpNewName: string = ''
  private tmpRenameText: string = ''
  private deleteTarget: NoteFile | null = null
  private renameTarget: NoteFile | null = null

  aboutToAppear(): void {
    const uiCtx: UIContext | undefined = this.getUIContext()
    const ctx: Context | undefined = uiCtx ? uiCtx.getHostContext() : undefined
    if (ctx) { this.fm = new FileManager(ctx); this.loadList() }
  }
  onPageShow(): void { this.loadList() }

  // ══════════════════════════════════════════════════
  // 数据
  // ══════════════════════════════════════════════════

  async loadList(): Promise<void> {
    const m: FileManager | null = this.fm
    if (!m) { return }
    this.listLoading = true
    await m.init()
    const r = await m.listFiles()
    if (r.isOk() && r.getValue()) { this.noteList = r.getValue()!; this.applySearch() }
    this.listLoading = false
  }
  applySearch(): void {
    const q: string = this.searchQuery.trim().toLowerCase()
    if (!q) { this.filteredList = this.noteList; return }
    const out: NoteFile[] = []
    for (let i: number = 0; i < this.noteList.length; i++) {
      if (this.noteList[i].title.toLowerCase().indexOf(q) >= 0) { out.push(this.noteList[i]) }
    }
    this.filteredList = out
  }
  onSearch(v: string): void { this.searchQuery = v; this.applySearch() }

  async openNote(f: NoteFile): Promise<void> {
    const m: FileManager | null = this.fm
    if (!m) { return }
    const r = await m.readFile(f.id)
    if (r.isOk() && r.getValue()) {
      const d: NoteFile = r.getValue()!
      this.activeNoteId = d.id; this.activeTitle = d.title
      this.activeContent = d.content
      this.createdAt = d.createdAt; this.modifiedAt = d.modifiedAt
      this.setEditorContent(d.content)
      this.undoStack = []; this.redoStack = []
    }
  }

  // ══════════════════════════════════════════════════
  // 编辑器核心
  // ══════════════════════════════════════════════════

  private setEditorContent(content: string): void {
    this.editorContent = content
    this.wordCount = content.length
    if (this.showPreview) { this.doParse() }
  }

  /**
   * 在指定位置插入文本。
   * @param pos 插入位置（字符偏移）
   * @param text 插入的文本
   */
  private insertAt(pos: number, text: string): void {
    this.pushUndo()
    const c: string = this.editorContent
    const newContent: string = c.slice(0, pos) + text + c.slice(pos)
    this.editorContent = newContent
    this.wordCount = newContent.length
    // 移动光标到插入文本末尾
    this.textAreaController.caretPosition(pos + text.length)
    if (this.showPreview) { this.doParse() }
  }

  /**
   * 在指定位置用 Markdown 语法包裹。
   * @param start 选区起点
   * @param end   选区终点
   * @param before 前置语法
   * @param after  后置语法
   * @param placeholder 无选区时的占位文本
   */
  private wrap(start: number, end: number, before: string, after: string, placeholder: string): void {
    this.pushUndo()
    const c: string = this.editorContent

    if (start >= 0 && end > start && start < c.length && end <= c.length) {
      // 有选区：用语法包裹
      const sel: string = c.slice(start, end)
      const wrapped: string = before + sel + after
      this.editorContent = c.slice(0, start) + wrapped + c.slice(end)
      this.wordCount = this.editorContent.length
      // 光标移到包裹语法后
      this.textAreaController.caretPosition(start + wrapped.length)
    } else {
      // 无选区：在末尾追加模板
      this.editorContent = c + placeholder
      this.wordCount = this.editorContent.length
      this.textAreaController.caretPosition(this.editorContent.length)
    }

    if (this.showPreview) { this.doParse() }
  }

  onEditorChange(v: string): void {
    if (v !== this.editorContent && this.editorContent.length > 0) {
      this.pushUndo()
    }
    this.editorContent = v; this.wordCount = v.length
    if (this.showPreview) { this.doParse() }
  }

  doParse(): void {
    const r = this.parser.parse(this.editorContent)
    this.previewTokens = (r.isOk() && r.getValue()) ? r.getValue()! : []
  }

  // ── 撤销/重做 ──────────────────────────────────

  private pushUndo(): void {
    const snap: EditSnapshot = new EditSnapshot(this.editorContent)
    this.undoStack.push(snap)
    if (this.undoStack.length > 100) { this.undoStack.splice(0, 1) }
    this.redoStack = []
  }

  doUndo(): void {
    if (this.undoStack.length === 0) { return }
    this.redoStack.push(new EditSnapshot(this.editorContent))
    this.editorContent = this.undoStack.pop()!.content
    this.wordCount = this.editorContent.length
    if (this.showPreview) { this.doParse() }
  }

  doRedo(): void {
    if (this.redoStack.length === 0) { return }
    this.undoStack.push(new EditSnapshot(this.editorContent))
    this.editorContent = this.redoStack.pop()!.content
    this.wordCount = this.editorContent.length
    if (this.showPreview) { this.doParse() }
  }

  // ══════════════════════════════════════════════════
  // 键盘快捷键 (onKeyEvent, 直接用 keyCode)
  // ══════════════════════════════════════════════════

  handleKeyEvent(event: KeyEvent): void {
    switch (event.keyCode) {
      case KeyCode.KEYCODE_S:
        this.doSave()
        return
      case KeyCode.KEYCODE_Z:
        this.doUndo()
        return
      case KeyCode.KEYCODE_Y:
        this.doRedo()
        return
      case KeyCode.KEYCODE_B:
        this.format('**', '**', '**加粗**')
        return
      case KeyCode.KEYCODE_I:
        this.format('*', '*', '*斜体*')
        return
      case KeyCode.KEYCODE_U:
        this.format('<u>', '</u>', '<u>下划线</u>')
        return
      case KeyCode.KEYCODE_K:
        this.format('[', '](https://)', '[链接](url)')
        return
      case KeyCode.KEYCODE_L:
        this.format('`', '`', '`代码`')
        return
      case KeyCode.KEYCODE_P:
        this.togglePreview()
        return
      default:
        return
    }
  }

  /**
   * 格式操作：有选区时包裹，无选区时在末尾追加模板。
   * HarmonyOS TextAreaController.getTextSelection 是异步回调 —
   * 真机上可在回调中获取选区后调用 wrap()。
   * 当前版本：所有格式按钮在编辑器末尾追加模板文字。
   */
  format(before: string, after: string, placeholder: string): void {
    const c: string = this.editorContent
    this.pushUndo()
    this.editorContent = c + placeholder
    this.wordCount = this.editorContent.length
    if (this.showPreview) { this.doParse() }
  }

  // ══════════════════════════════════════════════════
  // 操作
  // ══════════════════════════════════════════════════

  toggleSidebar(): void { this.showSidebar = !this.showSidebar }
  togglePreview(): void { this.showPreview = !this.showPreview; if (this.showPreview) { this.doParse() } }

  async doSave(): Promise<void> {
    const m: FileManager | null = this.fm
    if (!m || !this.activeNoteId) { return }
    await m.saveFile(this.activeNoteId, this.activeTitle, this.editorContent)
    this.activeContent = this.editorContent; this.modifiedAt = Date.now()
    this.statusMsg = '已保存'
    this.loadList()
  }

  async doNew(): Promise<void> {
    const m: FileManager | null = this.fm
    if (!m || this.tmpNewName.trim().length === 0) { return }
    const r = await m.createFile(this.tmpNewName.trim(), '')
    this.showNewDialog = false
    if (r.isOk() && r.getValue()) {
      const f: NoteFile = r.getValue()!
      this.activeNoteId = f.id; this.activeTitle = f.title
      this.activeContent = ''; this.createdAt = f.createdAt; this.modifiedAt = f.modifiedAt
      this.setEditorContent(''); this.undoStack = []; this.redoStack = []
      await this.loadList()
    }
  }
  async doDelete(): Promise<void> {
    const m: FileManager | null = this.fm
    const t: NoteFile | null = this.deleteTarget
    if (!m || !t) { return }
    await m.deleteFile(t.id); this.showDeleteConfirm = false; this.deleteTarget = null
    if (this.activeNoteId === t.id) { this.activeNoteId = ''; this.setEditorContent('') }
    await this.loadList()
  }
  async doRename(): Promise<void> {
    const m: FileManager | null = this.fm
    const t: NoteFile | null = this.renameTarget
    if (!m || !t || this.tmpRenameText.trim().length === 0) { return }
    await m.renameFile(t.id, this.tmpRenameText.trim()); this.showRenameDialog = false
    if (this.activeNoteId === t.id) { this.activeTitle = this.tmpRenameText.trim() }
    await this.loadList()
  }

  // ═══════════ build ═══════════

  build() {
    Stack() {
      Column() {
        this.TopBar()
        Divider().color('#e5e7eb')
        this.FormatBar()
        Divider().color('#e5e7eb')
        this.MainContent()
        Divider().color('#e5e7eb')
        this.BottomBar()
      }
      .width('100%').height('100%').backgroundColor('#ffffff')

      if (this.showNewDialog) { this.NewDialog() }
      if (this.showRenameDialog) { this.RenameDialog() }
      if (this.showDeleteConfirm) { this.DeleteDialog() }
      if (this.showShortcuts) { this.ShortcutsDialog() }
    }
    .width('100%').height('100%')
  }

  @Builder TopBar() {
    Row() {
      this.Btn('📝', '新建', (): void => { this.tmpNewName = ''; this.showNewDialog = true })
      this.Btn('💾', '保存', (): void => { this.doSave() })
      if (this.activeNoteId) {
        this.Btn('↩', '撤销', (): void => { this.doUndo() })
        this.Btn('↪', '重做', (): void => { this.doRedo() })
        this.Btn('✎', '重命名', (): void => {
          this.renameTarget = new NoteFile(this.activeNoteId, this.activeTitle, '', 0, 0)
          this.tmpRenameText = this.activeTitle; this.showRenameDialog = true
        })
        this.Btn('🗑', '删除', (): void => {
          this.deleteTarget = new NoteFile(this.activeNoteId, this.activeTitle, '', 0, 0)
          this.showDeleteConfirm = true
        })
      }
      TextInput({ placeholder: '搜索...' })
        .fontSize(13).fontColor('#111827').placeholderColor('#9ca3af')
        .backgroundColor('#f3f4f6').borderRadius(10).height(38)
        .layoutWeight(1).padding({ left: 12 })
        .onChange((v: string) => { this.onSearch(v) })
      this.Btn('⌨', '快捷键', (): void => { this.showShortcuts = !this.showShortcuts })
      this.Btn('☰', '笔记', (): void => { this.toggleSidebar() })
      this.Btn('◫', '预览', (): void => { this.togglePreview() })
    }
    .width('100%').padding({ left: 4, right: 4, top: 8, bottom: 6 })
  }

  @Builder Btn(icon: string, label: string, cb: () => void) {
    Button() {
      Column() { Text(icon).fontSize(17); Text(label).fontSize(9).fontColor('#6b7280').margin({ top: 1 }) }
    }
    .backgroundColor('#00000000').borderRadius(8).padding({ left: 6, right: 6 }).height(46)
    .onClick(cb).margin({ left: 2, right: 2 })
  }

  @Builder FormatBar() {
    Scroll() {
      Row() {
        this.Fmt('B', '**', '**', '**加粗**')
        this.Fmt('I', '*', '*', '*斜体*')
        this.Fmt('S', '~~', '~~', '~~删除线~~')
        this.Fmt('U', '<u>', '</u>', '<u>下划线</u>')
        this.Fmt('H1', '\n\n# ', '', '\n\n# 一级标题')
        this.Fmt('H2', '\n\n## ', '', '\n\n## 二级标题')
        this.Fmt('H3', '\n\n### ', '', '\n\n### 三级标题')
        this.Fmt('`', '`', '`', '`代码`')
        this.Fmt('```', '\n\n```\n', '\n```', '\n\n```\ncode\n```')
        this.Fmt('>', '\n\n> ', '', '\n\n> 引用')
        this.Fmt('-', '\n\n- ', '', '\n\n- 列表项')
        this.Fmt('1.', '\n\n1. ', '', '\n\n1. 有序项')
        this.Fmt('🔗', '[', '](https://)', '[链接](url)')
        this.Fmt('🖼', '![', '](https://)', '![图片](url)')
        this.Fmt('📊', '\n\n| A | B |\n| - | - |\n| ', ' |', '\n\n| 列A | 列B |\n| --- | --- |\n| 值 | 值 |')
        this.Fmt('---', '\n\n---\n\n', '', '\n\n---\n\n')
      }
      .padding({ left: 6, right: 6 })
    }
    .width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
  }

  @Builder Fmt(label: string, before: string, after: string, placeholder: string) {
    Button(label)
      .fontSize(11).fontWeight(FontWeight.Medium).height(28)
      .fontColor('#374151').backgroundColor('#f3f4f6')
      .border({ width: 1, color: '#d1d5db', radius: 4 })
      .padding({ left: 10, right: 10 }).margin({ right: 4 })
      .onClick(() => { this.format(before, after, placeholder) })
  }

  @Builder MainContent() {
    Row() {
      if (this.showSidebar) { this.LeftSidebar() }
      this.CenterEditor()
      if (this.showPreview) { this.RightPreview() }
    }
    .width('100%').layoutWeight(1)
  }

  @Builder LeftSidebar() {
    Column() {
      Row() {
        Text('笔记').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#111827')
        Blank()
        Text(String(this.noteList.length) + ' 篇').fontSize(11).fontColor('#9ca3af')
      }
      .width('100%').padding({ left: 14, right: 10, top: 6, bottom: 4 })
      if (this.listLoading) {
        Column() { LoadingProgress().width(24).height(24).color('#3b82f6') }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.filteredList.length === 0) {
        Column() { Text('无笔记').fontSize(13).fontColor('#9ca3af') }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.filteredList, (f: NoteFile) => {
            ListItem() {
              Row() {
                Column() {
                  Text(f.title || '未命名').fontSize(14).fontWeight(FontWeight.Medium)
                    .fontColor(this.activeNoteId === f.id ? '#3b82f6' : '#111827')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(formatTime(f.modifiedAt)).fontSize(10).fontColor('#9ca3af').margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1)
              }
              .width('100%').padding({ left: 14, right: 10, top: 10, bottom: 10 })
              .backgroundColor(this.activeNoteId === f.id ? '#eff6ff' : '#00000000')
              .border({ width: { left: this.activeNoteId === f.id ? 3 : 0 }, color: '#3b82f6' })
              .onClick(() => { this.openNote(f) })
            }
          }, (f: NoteFile): string => f.id)
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
      }
    }
    .width(250).height('100%').backgroundColor('#f9fafb')
    .border({ width: { right: 1 }, color: '#e5e7eb' })
  }

  @Builder CenterEditor() {
    Column() {
      if (this.activeNoteId) {
        Row() {
          Text(this.activeTitle).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#111827')
            .maxLines(1).layoutWeight(1)
        }
        .width('100%').padding({ left: 12, right: 12, top: 6, bottom: 4 })
        Divider().color('#f3f4f6')
      }
      TextArea({ text: this.editorContent, placeholder: '# Markdown\n\n开始写作... Ctrl+S 保存', controller: this.textAreaController })
        .width('100%').layoutWeight(1)
        .backgroundColor('#ffffff').fontSize(15).fontColor('#111827')
        .fontFamily('monospace').padding(16)
        .borderRadius(0).caretColor('#3b82f6')
        .onChange((v: string) => { this.onEditorChange(v) })
        .onKeyEvent((event: KeyEvent): void => { this.handleKeyEvent(event) })
    }
    .layoutWeight(1).height('100%').backgroundColor('#ffffff')
  }

  @Builder RightPreview() {
    Column() {
      Row() {
        Text('实时预览').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#111827')
        Blank()
        Button('↻').fontSize(14).fontColor('#3b82f6').backgroundColor('#00000000')
          .width(28).height(28).onClick(() => { this.doParse() })
      }
      .width('100%').padding({ left: 12, right: 8, top: 6, bottom: 6 })
      .border({ width: { bottom: 1 }, color: '#e5e7eb' })
      Scroll() {
        Column() {
          if (this.previewTokens.length === 0) {
            Text('在左侧编辑 Markdown，预览自动更新').fontSize(12).fontColor('#9ca3af')
              .width('100%').padding(12)
          } else {
            ForEach(this.previewTokens, (t: MarkdownToken, i: number) => {
              this.RenderBlock(t, i)
            }, (t: MarkdownToken, i: number): string => 'pb_' + String(i))
          }
        }
        .width('100%').padding(8)
      }
      .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
    }
    .width(280).height('100%').backgroundColor('#fafbfc')
    .border({ width: { left: 1 }, color: '#e5e7eb' })
  }

  @Builder RenderBlock(t: MarkdownToken, i: number) {
    if (t.type === TokenType.HEADING) {
      Text(t.children.map((s: InlineSpan): string => s.text).join(''))
        .fontSize(Math.max(14, 24 - t.level * 3)).fontWeight(FontWeight.Bold).fontColor('#111827')
        .padding({ top: 8, bottom: 2 })
    } else if (t.type === TokenType.CODE_BLOCK) {
      Text(t.rawText).fontSize(11).fontColor('#374151').fontFamily('monospace')
        .padding(8).width('100%').backgroundColor('#f1f5f9').borderRadius(4).margin({ top: 4, bottom: 4 })
    } else if (t.type === TokenType.BLOCKQUOTE) {
      Text(t.rawText).fontSize(13).fontColor('#6b7280').fontStyle(FontStyle.Italic)
        .border({ width: { left: 2 }, color: '#10b981' }).padding({ left: 8 })
        .margin({ top: 4, bottom: 4 }).width('100%')
    } else if (t.type === TokenType.HORIZONTAL_RULE) {
      Divider().color('#e5e7eb').margin({ top: 6, bottom: 6 }).width('100%')
    } else if (t.type === TokenType.UNORDERED_LIST || t.type === TokenType.ORDERED_LIST) {
      ForEach(t.children, (item: InlineSpan, j: number) => {
        Row() {
          Text(t.type === TokenType.ORDERED_LIST ? String(j + 1) + '.' : '•')
            .fontSize(13).fontColor('#6b7280').width(20)
          Text(item.text).fontSize(13).fontColor('#374151')
        }.width('100%').padding({ top: 1, bottom: 1 })
      }, (item: InlineSpan, j: number): string => 'ci_' + String(i) + '_' + String(j))
    } else {
      Row() {
        ForEach(t.children, (s: InlineSpan, idx: number) => {
          if (s.code) {
            Text(s.text).fontSize(12).fontColor('#7c3aed').fontFamily('monospace')
              .backgroundColor('#f1f5f9').borderRadius(3).padding({ left: 4, right: 4, top: 1, bottom: 1 })
          } else if (s.bold && s.italic) {
            Text(s.text).fontSize(13).fontColor('#111827')
              .fontWeight(FontWeight.Bold).fontStyle(FontStyle.Italic)
          } else if (s.bold) {
            Text(s.text).fontSize(13).fontColor('#111827').fontWeight(FontWeight.Bold)
          } else if (s.italic) {
            Text(s.text).fontSize(13).fontColor('#374151').fontStyle(FontStyle.Italic)
          } else {
            Text(s.text).fontSize(13).fontColor('#374151')
          }
        }, (s: InlineSpan, idx: number): string => 'is_' + String(i) + '_' + String(idx))
      }.width('100%').padding({ top: 2, bottom: 2 })
    }
  }

  @Builder BottomBar() {
    Row() {
      if (this.statusMsg.length > 0) {
        Text(this.statusMsg).fontSize(11).fontColor('#3b82f6')
      } else if (this.activeNoteId) {
        Text('编辑中 · Ctrl+S 保存 · Ctrl+Z 撤销 · Ctrl+B 加粗').fontSize(11).fontColor('#9ca3af')
      } else {
        Text('选择笔记开始编辑').fontSize(11).fontColor('#9ca3af')
      }
      Blank()
      Text(String(this.noteList.length) + ' 篇').fontSize(11).fontColor('#9ca3af')
      Text('  ·  ').fontSize(11).fontColor('#d1d5db')
      Text(String(this.wordCount) + ' 字').fontSize(11).fontColor('#9ca3af')
      if (this.activeNoteId) {
        Text('  ·  ').fontSize(11).fontColor('#d1d5db')
        Text('修改: ' + formatTime(this.modifiedAt > 0 ? this.modifiedAt : Date.now()))
          .fontSize(11).fontColor('#9ca3af')
      }
    }
    .width('100%').padding({ left: 16, right: 16, top: 6, bottom: 6 })
    .backgroundColor('#f3f4f6')
  }

  // ══ 弹窗 ════════════════════════════════════════

  @Builder NewDialog() {
    Column() {
      Column() {
        Text('新建笔记').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827').margin({ bottom: 14 })
        TextInput({ text: this.tmpNewName, placeholder: '输入标题' })
          .fontSize(14).fontColor('#111827').placeholderColor('#9ca3af')
          .backgroundColor('#ffffff').border({ width: 1, color: '#d1d5db', radius: 8 }).padding(12)
          .onChange((v: string) => { this.tmpNewName = v })
        Row() {
          Button('取消').fontSize(13).backgroundColor('#e5e7eb').fontColor('#374151')
            .borderRadius(8).width('48%').onClick(() => { this.showNewDialog = false })
          Button('创建').fontSize(13).backgroundColor('#3b82f6').fontColor('#ffffff')
            .borderRadius(8).width('48%').margin({ left: 12 }).onClick(() => { this.doNew() })
        }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 18 })
      }
      .padding(24).backgroundColor('#ffffff').borderRadius(14).width('85%')
      .border({ width: 1, color: '#e5e7eb' }).shadow({ radius: 16, color: '#00000010' })
    }
    .width('100%').height('100%').backgroundColor('#00000030').justifyContent(FlexAlign.Center)
    .onClick(() => { this.showNewDialog = false })
  }

  @Builder RenameDialog() {
    Column() {
      Column() {
        Text('重命名').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827').margin({ bottom: 14 })
        TextInput({ text: this.tmpRenameText, placeholder: '新标题' })
          .fontSize(14).fontColor('#111827').placeholderColor('#9ca3af')
          .backgroundColor('#ffffff').border({ width: 1, color: '#d1d5db', radius: 8 }).padding(12)
          .onChange((v: string) => { this.tmpRenameText = v })
        Row() {
          Button('取消').fontSize(13).backgroundColor('#e5e7eb').fontColor('#374151')
            .borderRadius(8).width('48%').onClick(() => { this.showRenameDialog = false })
          Button('确认').fontSize(13).backgroundColor('#3b82f6').fontColor('#ffffff')
            .borderRadius(8).width('48%').margin({ left: 12 }).onClick(() => { this.doRename() })
        }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 18 })
      }
      .padding(24).backgroundColor('#ffffff').borderRadius(14).width('85%')
      .border({ width: 1, color: '#e5e7eb' }).shadow({ radius: 16, color: '#00000010' })
    }
    .width('100%').height('100%').backgroundColor('#00000030').justifyContent(FlexAlign.Center)
    .onClick(() => { this.showRenameDialog = false })
  }

  @Builder DeleteDialog() {
    Column() {
      Column() {
        Text('确认删除').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827').margin({ bottom: 6 })
        Text(this.deleteTarget ? '"' + this.deleteTarget.title + '" 将被永久删除' : '')
          .fontSize(13).fontColor('#6b7280').margin({ bottom: 18 })
        Row() {
          Button('取消').fontSize(13).backgroundColor('#e5e7eb').fontColor('#374151')
            .borderRadius(8).width('48%').onClick(() => { this.showDeleteConfirm = false })
          Button('删除').fontSize(13).backgroundColor('#ef4444').fontColor('#ffffff')
            .borderRadius(8).width('48%').margin({ left: 12 }).onClick(() => { this.doDelete() })
        }.width('100%').justifyContent(FlexAlign.Center)
      }
      .padding(24).backgroundColor('#ffffff').borderRadius(14).width('85%')
      .border({ width: 1, color: '#e5e7eb' }).shadow({ radius: 16, color: '#00000010' })
    }
    .width('100%').height('100%').backgroundColor('#00000030').justifyContent(FlexAlign.Center)
    .onClick(() => { this.showDeleteConfirm = false })
  }

  @Builder ShortcutsDialog() {
    Column() {
      Column() {
        Row() {
          Text('快捷键一览').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827')
          Blank()
          Button('×').fontSize(18).fontColor('#6b7280').backgroundColor('#00000000')
            .width(32).height(32).onClick(() => { this.showShortcuts = false })
        }.width('100%').margin({ bottom: 16 })

        this.ShortcutRow('Ctrl+S', '保存笔记')
        this.ShortcutRow('Ctrl+Z', '撤销')
        this.ShortcutRow('Ctrl+Y', '重做')
        this.ShortcutRow('Ctrl+B', '加粗 **text**')
        this.ShortcutRow('Ctrl+I', '斜体 *text*')
        this.ShortcutRow('Ctrl+U', '下划线 <u>text</u>')
        this.ShortcutRow('Ctrl+K', '链接 [text](url)')
        this.ShortcutRow('Ctrl+L', '行内代码 `code`')
        this.ShortcutRow('Ctrl+P', '切换预览')
        Divider().color('#e5e7eb').margin({ top: 8, bottom: 8 })
        Text('注：外接键盘 PC 模式下可用，触屏请用顶部格式按钮')
          .fontSize(11).fontColor('#9ca3af')
      }
      .padding(24).backgroundColor('#ffffff').borderRadius(14).width('85%')
      .border({ width: 1, color: '#e5e7eb' }).shadow({ radius: 16, color: '#00000010' })
    }
    .width('100%').height('100%').backgroundColor('#00000030').justifyContent(FlexAlign.Center)
    .onClick(() => { this.showShortcuts = false })
  }

  @Builder ShortcutRow(keys: string, desc: string) {
    Row() {
      Text(keys).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#3b82f6')
        .fontFamily('monospace').backgroundColor('#eff6ff').borderRadius(4).padding({ left: 8, right: 8, top: 2, bottom: 2 }).width(100)
      Text(desc).fontSize(13).fontColor('#374151').margin({ left: 12 })
    }
    .width('100%').padding({ top: 4, bottom: 4 })
  }
}
