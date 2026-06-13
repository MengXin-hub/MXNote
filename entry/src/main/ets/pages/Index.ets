import { FileManager } from '../core/FileManager'
import { NoteFile, formatTime } from '../model/NoteFile'
import { MarkdownParser, MarkdownToken, TokenType, InlineSpan } from '../core/MarkdownParser'

enum BlockType {
  PARAGRAPH = 'paragraph',
  HEADING_1 = 'heading1',
  HEADING_2 = 'heading2',
  HEADING_3 = 'heading3',
  HEADING_4 = 'heading4',
  CODE = 'code',
  QUOTE = 'quote',
  UNORDERED_LIST = 'unordered_list',
  ORDERED_LIST = 'ordered_list',
}

class EditorBlock {
  id: string = ''
  blockType: BlockType = BlockType.PARAGRAPH
  content: string = ''
  language: string = ''
  headingLevel: number = 0

  constructor(
    id: string,
    blockType: BlockType,
    content: string,
    language: string,
    headingLevel: number,
  ) {
    this.id = id
    this.blockType = blockType
    this.content = content
    this.language = language
    this.headingLevel = headingLevel
  }

  toMarkdown(): string {
    switch (this.blockType) {
      case BlockType.HEADING_1:
        return '# ' + this.content
      case BlockType.HEADING_2:
        return '## ' + this.content
      case BlockType.HEADING_3:
        return '### ' + this.content
      case BlockType.HEADING_4:
        return '#### ' + this.content
      case BlockType.CODE:
        if (this.language) {
          return '```' + this.language + '\n' + this.content + '\n```'
        }
        return '```\n' + this.content + '\n```'
      case BlockType.QUOTE:
        if (!this.content) {
          return '> '
        }
        return this.content.split('\n')
          .map((line: string): string => '> ' + line)
          .join('\n')
      case BlockType.UNORDERED_LIST:
        if (!this.content) {
          return '- '
        }
        return this.content.split('\n')
          .map((line: string): string => '- ' + line)
          .join('\n')
      case BlockType.ORDERED_LIST:
        if (!this.content) {
          return '1. '
        }
        let idx: number = 1
        return this.content.split('\n')
          .map((line: string): string => {
            const r: string = String(idx) + '. ' + line
            idx = idx + 1
            return r
          })
          .join('\n')
      default:
        return this.content
    }
  }

  typeLabel(): string {
    switch (this.blockType) {
      case BlockType.HEADING_1:
        return 'H1'
      case BlockType.HEADING_2:
        return 'H2'
      case BlockType.HEADING_3:
        return 'H3'
      case BlockType.HEADING_4:
        return 'H4'
      case BlockType.CODE:
        return '</>'
      case BlockType.QUOTE:
        return '"'
      case BlockType.UNORDERED_LIST:
        return '•'
      case BlockType.ORDERED_LIST:
        return '1.'
      default:
        return '¶'
    }
  }
}

function blockId(): string {
  return 'b_' + Date.now().toString(36) + Math.floor(Math.random() * 1000).toString(36)
}

/**
 * 将 Markdown 文本按块类型拆分，返回原始内容（去除标记符）。
 */
function parseContentToBlocks(markdown: string): EditorBlock[] {
  if (!markdown || markdown.trim().length === 0) {
    return [new EditorBlock(blockId(), BlockType.PARAGRAPH, '', '', 0)]
  }
  const rawBlocks: string[] = markdown.split('\n\n')
  const result: EditorBlock[] = []
  for (let i: number = 0; i < rawBlocks.length; i++) {
    const chunk: string = rawBlocks[i]
    if (chunk.trim().length === 0) {
      continue
    }
    result.push(detectBlockType(chunk))
  }
  if (result.length === 0) {
    result.push(new EditorBlock(blockId(), BlockType.PARAGRAPH, '', '', 0))
  }
  return result
}

function detectBlockType(chunk: string): EditorBlock {
  const text: string = chunk.trim()

  // heading
  const hMatch: RegExpMatchArray | null = text.match(/^(#{1,4})\s+(.+)/s)
  if (hMatch) {
    const level: number = hMatch[1].length
    let bType: BlockType
    if (level === 1) {
      bType = BlockType.HEADING_1
    } else if (level === 2) {
      bType = BlockType.HEADING_2
    } else if (level === 3) {
      bType = BlockType.HEADING_3
    } else {
      bType = BlockType.HEADING_4
    }
    return new EditorBlock(blockId(), bType, hMatch[2].trim(), '', level)
  }

  // code block
  if (text.startsWith('```')) {
    const lines: string[] = text.split('\n')
    const lang: string = lines[0].slice(3).trim()
    let endIdx: number = -1
    for (let j: number = 1; j < lines.length; j++) {
      if (lines[j].trim() === '```') {
        endIdx = j
        break
      }
    }
    const content: string = endIdx > 1 ? lines.slice(1, endIdx).join('\n') : lines.slice(1).join('\n')
    return new EditorBlock(blockId(), BlockType.CODE, content, lang, 0)
  }

  // quote
  if (text.startsWith('>')) {
    const content: string = text.split('\n')
      .map((line: string): string => line.replace(/^>\s?/, ''))
      .join('\n')
    return new EditorBlock(blockId(), BlockType.QUOTE, content, '', 0)
  }

  // lists
  const lines: string[] = text.split('\n')
  if (lines.length > 0 && /^[\s]*[-*+]\s+/.test(lines[0])) {
    const content: string = lines
      .map((line: string): string => line.replace(/^[\s]*[-*+]\s+/, ''))
      .join('\n')
    return new EditorBlock(blockId(), BlockType.UNORDERED_LIST, content, '', 0)
  }
  if (lines.length > 0 && /^[\s]*\d+\.\s+/.test(lines[0])) {
    let itemIdx: number = 1
    const content: string = lines
      .map((line: string): string => {
        const replaced: string = line.replace(/^[\s]*\d+\.\s+/, '')
        itemIdx = itemIdx + 1
        return replaced
      })
      .join('\n')
    return new EditorBlock(blockId(), BlockType.ORDERED_LIST, content, '', 0)
  }

  return new EditorBlock(blockId(), BlockType.PARAGRAPH, text, '', 0)
}

// ─── component ─────────────────────────────────────────

@Entry
@Component
struct Index {
  @State noteId: string = ''
  @State noteTitle: string = ''
  @State blocks: EditorBlock[] = []
  @State statusText: string = '就绪'
  @State modifiedAt: number = 0
  @State createdAt: number = 0
  @State showTypeMenu: boolean = false
  @State typeMenuBlockId: string = ''
  @State showTitleEdit: boolean = false
  @State editTitle: string = ''

  private fileManager: FileManager | null = null
  private parser: MarkdownParser = new MarkdownParser()

  aboutToAppear(): void {
    const uiCtx: UIContext | undefined = this.getUIContext()
    const ctx: Context | undefined = uiCtx ? uiCtx.getHostContext() : undefined
    if (!ctx) {
      this.statusText = '初始化失败'
      return
    }
    this.fileManager = new FileManager(ctx)

    let rawParams: Object | undefined
    try {
      const routerInstance = uiCtx.getRouter()
      rawParams = routerInstance.getParams()
    } catch (e) {
      rawParams = undefined
    }
    if (rawParams) {
      const params: Record<string, Object> = rawParams as Record<string, Object>
      const rawId: Object | undefined = params['noteId']
      if (rawId) {
        this.noteId = rawId as string
      }
    }
    this.loadNote()
  }

  async loadNote(): Promise<void> {
    const fm: FileManager | null = this.fileManager
    if (!fm) {
      return
    }
    await fm.init()

    if (this.noteId) {
      const result = await fm.readFile(this.noteId)
      if (result.isOk()) {
        const file: NoteFile | null = result.getValue()
        if (file) {
          this.noteTitle = file.title
          this.createdAt = file.createdAt
          this.modifiedAt = file.modifiedAt
          this.blocks = parseContentToBlocks(file.content)
          this.statusText = '已加载'
        }
      }
    } else {
      this.noteTitle = '未命名笔记'
      this.createdAt = Date.now()
      this.modifiedAt = Date.now()
      this.blocks = [new EditorBlock(blockId(), BlockType.PARAGRAPH, '', '', 0)]
      this.statusText = '新笔记'
    }
  }

  async saveNote(): Promise<void> {
    const fm: FileManager | null = this.fileManager
    if (!fm) {
      return
    }

    const parts: string[] = []
    for (let i: number = 0; i < this.blocks.length; i++) {
      parts.push(this.blocks[i].toMarkdown())
    }
    const markdown: string = parts.join('\n\n')

    if (!this.noteId) {
      const result = await fm.createFile(this.noteTitle, markdown)
      if (result.isOk()) {
        const file: NoteFile | null = result.getValue()
        if (file) {
          this.noteId = file.id
          this.modifiedAt = file.modifiedAt
          this.createdAt = file.createdAt
          this.statusText = '已保存 ' + formatTime(file.modifiedAt)
        }
      } else {
        this.statusText = '保存失败'
      }
    } else {
      const result = await fm.saveFile(this.noteId, this.noteTitle, markdown)
      if (result.isOk()) {
        this.modifiedAt = Date.now()
        this.statusText = '已保存 ' + formatTime(this.modifiedAt)
      } else {
        this.statusText = '保存失败'
      }
    }
  }

  async deleteCurrentNote(): Promise<void> {
    const fm: FileManager | null = this.fileManager
    if (!fm || !this.noteId) {
      return
    }
    await fm.deleteFile(this.noteId)
    this.goBack()
  }

  goBack(): void {
    const uiCtx: UIContext | undefined = this.getUIContext()
    if (uiCtx) {
      try {
        uiCtx.getRouter().back()
      } catch (e) {
        // router back failed
      }
    }
  }

  addBlock(index: number): void {
    const newBlock: EditorBlock = new EditorBlock(blockId(), BlockType.PARAGRAPH, '', '', 0)
    const newBlocks: EditorBlock[] = []
    for (let i: number = 0; i < this.blocks.length; i++) {
      newBlocks.push(this.blocks[i])
      if (i === index) {
        newBlocks.push(newBlock)
      }
    }
    this.blocks = newBlocks
  }

  updateBlockContent(id: string, newContent: string): void {
    const updated: EditorBlock[] = []
    for (let i: number = 0; i < this.blocks.length; i++) {
      const b: EditorBlock = this.blocks[i]
      if (b.id === id) {
        updated.push(new EditorBlock(b.id, b.blockType, newContent, b.language, b.headingLevel))
      } else {
        updated.push(b)
      }
    }
    this.blocks = updated
  }

  changeBlockType(id: string, newType: BlockType): void {
    const updated: EditorBlock[] = []
    for (let i: number = 0; i < this.blocks.length; i++) {
      const b: EditorBlock = this.blocks[i]
      if (b.id === id) {
        let level: number = 0
        if (newType === BlockType.HEADING_1) {
          level = 1
        } else if (newType === BlockType.HEADING_2) {
          level = 2
        } else if (newType === BlockType.HEADING_3) {
          level = 3
        } else if (newType === BlockType.HEADING_4) {
          level = 4
        }
        updated.push(new EditorBlock(b.id, newType, b.content, b.language, level))
      } else {
        updated.push(b)
      }
    }
    this.blocks = updated
    this.showTypeMenu = false
  }

  removeBlock(id: string): void {
    if (this.blocks.length <= 1) {
      return
    }
    const filtered: EditorBlock[] = []
    for (let i: number = 0; i < this.blocks.length; i++) {
      if (this.blocks[i].id !== id) {
        filtered.push(this.blocks[i])
      }
    }
    this.blocks = filtered
  }

  showTypeMenuFor(id: string): void {
    this.typeMenuBlockId = id
    this.showTypeMenu = true
  }

  // ─── 预览：将块转为 Markdown 再解析（在 @State 驱动下调用）──

  getPreviewTokens(block: EditorBlock): MarkdownToken[] {
    const md: string = block.toMarkdown()
    if (!md || md.trim().length === 0) {
      return []
    }
    const result = this.parser.parse(md)
    if (result.isOk()) {
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        return tokens
      }
    }
    return []
  }

  // ─── 辅助 ────────────────────────────────────────────

  getPlaceholder(type: BlockType): string {
    switch (type) {
      case BlockType.HEADING_1:
        return '输入一级标题...'
      case BlockType.HEADING_2:
        return '输入二级标题...'
      case BlockType.HEADING_3:
        return '输入三级标题...'
      case BlockType.HEADING_4:
        return '输入四级标题...'
      case BlockType.CODE:
        return '输入代码...'
      case BlockType.QUOTE:
        return '输入引用内容...'
      default:
        return '输入内容...'
    }
  }

  getBlockFontSize(block: EditorBlock): number {
    if (block.blockType === BlockType.HEADING_1) {
      return 22
    }
    if (block.blockType === BlockType.HEADING_2) {
      return 18
    }
    if (block.blockType === BlockType.HEADING_3) {
      return 16
    }
    if (block.blockType === BlockType.HEADING_4) {
      return 14
    }
    if (block.blockType === BlockType.CODE) {
      return 13
    }
    return 15
  }

  isHeading(block: EditorBlock): boolean {
    if (block.blockType === BlockType.HEADING_1) {
      return true
    }
    if (block.blockType === BlockType.HEADING_2) {
      return true
    }
    if (block.blockType === BlockType.HEADING_3) {
      return true
    }
    if (block.blockType === BlockType.HEADING_4) {
      return true
    }
    return false
  }

  getBlockHeight(block: EditorBlock): number {
    const lines: number = block.content.split('\n').length
    const trueLines: number = Math.max(1, lines)
    const lineH: number = block.blockType === BlockType.CODE ? 16 : 22
    const extra: number = block.blockType === BlockType.CODE ? 24 : 16
    return Math.min(trueLines * lineH + extra, 300)
  }

  // ─── build ────────────────────────────────────────────

  build() {
    Stack() {
      Column() {
        this.Toolbar()
        if (this.showTitleEdit) {
          this.TitleEditor()
        }
        this.MetaBar()
        Scroll() {
          Column() {
            this.InsertButton(-1)
            ForEach(this.blocks, (block: EditorBlock, idx: number) => {
              Column() {
                this.BlockView(block)
              }
              .width('100%')
              this.InsertButton(idx)
            }, (block: EditorBlock): string => block.id)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 80 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#1e1e1e')

      if (this.showTypeMenu) {
        this.TypeMenuOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder Toolbar() {
    Row() {
      Button() {
        Text('←').fontSize(18).fontColor('#cccccc')
      }
      .width(32).height(32).backgroundColor('#00000000')
      .onClick(() => { this.goBack() })
      Blank()
      Button('保存')
        .fontSize(13).fontColor('#ffffff').backgroundColor('#007AFF').borderRadius(4)
        .padding({ left: 12, right: 12 })
        .onClick(() => { this.saveNote() })
      Button('删除')
        .fontSize(13).fontColor('#ff6b6b').backgroundColor('#00000000')
        .margin({ left: 8 })
        .onClick(() => { this.deleteCurrentNote() })
    }
    .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 4 })
  }

  @Builder TitleEditor() {
    Row() {
      TextInput({ text: this.noteTitle, placeholder: '笔记标题' })
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#ffffff')
        .backgroundColor('#00000000').layoutWeight(1)
        .onChange((value: string) => { this.noteTitle = value })
      Button('完成')
        .fontSize(12).fontColor('#007AFF').backgroundColor('#00000000')
        .onClick(() => { this.showTitleEdit = false })
    }
    .width('100%').padding({ left: 16, right: 12, top: 4, bottom: 8 })
  }

  @Builder MetaBar() {
    Column() {
      Row() {
        Text(this.noteTitle)
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#ffffff')
          .maxLines(1)
          .onClick(() => {
            this.editTitle = this.noteTitle
            this.showTitleEdit = true
          })
      }
      .width('100%').padding({ left: 16, right: 16, top: 4, bottom: 2 })

      Row() {
        Text('创建: ' + (this.createdAt > 0 ? formatTime(this.createdAt) : '—'))
          .fontSize(11).fontColor('#666666')
        Text('  |  ')
          .fontSize(11).fontColor('#555555')
        Text('修改: ' + (this.modifiedAt > 0 ? formatTime(this.modifiedAt) : '—'))
          .fontSize(11).fontColor('#666666')
        Blank()
        Text(this.statusText)
          .fontSize(11).fontColor('#888888')
      }
      .width('100%').padding({ left: 16, right: 16, top: 2, bottom: 12 })
    }
  }

  @Builder InsertButton(afterIndex: number) {
    Row() {
      Button() {
        Row() {
          Text('+').fontSize(14).fontColor('#888888')
          Text(' 插入').fontSize(10).fontColor('#666666')
        }
      }
      .height(26).backgroundColor('#00000000')
      .border({ width: 1, color: '#333333', style: BorderStyle.Dashed }).borderRadius(4)
      .padding({ left: 12, right: 12 })
      .onClick(() => { this.addBlock(afterIndex) })
      Blank()
    }
    .width('100%').padding({ left: 8, top: 4, bottom: 4 })
  }

  @Builder BlockView(block: EditorBlock) {
    Column() {
      // block toolbar
      Row() {
        Button(block.typeLabel())
          .fontSize(10).fontWeight(FontWeight.Bold)
          .fontColor('#007AFF').backgroundColor('#1a3a5c').borderRadius(3)
          .height(22).padding({ left: 8, right: 8 })
          .onClick(() => { this.showTypeMenuFor(block.id) })
        Blank()
        Button('×')
          .fontSize(14).fontColor('#666666').backgroundColor('#00000000')
          .width(24).height(24)
          .onClick(() => { this.removeBlock(block.id) })
      }
      .width('100%').padding({ left: 4, right: 4, top: 2, bottom: 4 })

      // textarea
      TextArea({ text: block.content, placeholder: this.getPlaceholder(block.blockType) })
        .width('100%')
        .height(this.getBlockHeight(block))
        .backgroundColor('#2a2a2a')
        .fontSize(this.getBlockFontSize(block))
        .fontColor('#d4d4d4')
        .fontFamily(block.blockType === BlockType.CODE ? 'monospace' : 'sans-serif')
        .fontWeight(this.isHeading(block) ? FontWeight.Bold : FontWeight.Normal)
        .padding(12).borderRadius(6)
        .border({ width: 1, color: '#333333' })
        .onChange((value: string) => { this.updateBlockContent(block.id, value) })

      // preview — 调用 getPreviewTokens 获取渲染数据
      this.PreviewContent(block)

      Divider().color('#2a2a2a').margin({ top: 8, bottom: 4 })
    }
    .width('100%').margin({ top: 4 })
  }

  @Builder PreviewContent(block: EditorBlock) {
    if (block.content && block.content.trim().length > 0) {
      Column() {
        Column() {
          ForEach(this.getPreviewTokens(block),
            (token: MarkdownToken, idx: number) => {
              this.RenderToken(token)
            },
            (token: MarkdownToken, idx: number): string => 'p_' + block.id + '_' + String(idx)
          )
        }
        .width('100%').padding({ left: 8, top: 6, bottom: 6 })
      }
      .width('100%').backgroundColor('#252526')
      .borderRadius({ bottomLeft: 6, bottomRight: 6 })
      .border({ width: { left: 3 }, color: '#444444' })
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
    }
  }

  @Builder RenderToken(token: MarkdownToken) {
    if (token.type === TokenType.HEADING) {
      Text(token.children.map((s: InlineSpan): string => s.text).join(''))
        .fontSize(Math.max(13, 22 - token.level * 2))
        .fontWeight(FontWeight.Bold).fontColor('#e0e0e0')
        .padding({ top: 2, bottom: 2 })
    } else if (token.type === TokenType.CODE_BLOCK) {
      Text(token.rawText)
        .fontSize(12).fontColor('#ce9178').fontFamily('monospace')
        .padding(8).backgroundColor('#1e1e1e').borderRadius(4)
    } else if (token.type === TokenType.BLOCKQUOTE) {
      Text(token.rawText)
        .fontSize(13).fontColor('#aaaaaa').fontStyle(FontStyle.Italic)
    } else if (token.type === TokenType.UNORDERED_LIST || token.type === TokenType.ORDERED_LIST) {
      Column() {
        ForEach(token.children, (item: InlineSpan, i: number) => {
          Text((token.type === TokenType.ORDERED_LIST ? String(i + 1) + '. ' : '• ') + item.text)
            .fontSize(13).fontColor('#d0d0d0').padding({ top: 1, bottom: 1 })
        }, (item: InlineSpan, i: number): string => 'li_' + String(i))
      }
    } else if (token.type === TokenType.HORIZONTAL_RULE) {
      Divider().color('#444444').margin({ top: 4, bottom: 4 })
    } else {
      Row() {
        ForEach(token.children, (span: InlineSpan) => {
          if (span.code) {
            Text(span.text)
              .fontSize(12).fontColor('#ce9178').fontFamily('monospace')
              .backgroundColor('#333333').borderRadius(3)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          } else {
            Text(span.text)
              .fontSize(13).fontColor('#d0d0d0')
              .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
              .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
          }
        })
      }
      .width('100%')
    }
  }

  @Builder TypeMenuOverlay() {
    Column() {
      Column() {
        Text('选择块类型')
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor('#ffffff')
          .margin({ bottom: 12 })
        this.TypeOption('¶ 段落', BlockType.PARAGRAPH)
        this.TypeOption('H1 一级标题', BlockType.HEADING_1)
        this.TypeOption('H2 二级标题', BlockType.HEADING_2)
        this.TypeOption('H3 三级标题', BlockType.HEADING_3)
        this.TypeOption('H4 四级标题', BlockType.HEADING_4)
        this.TypeOption('</> 代码块', BlockType.CODE)
        this.TypeOption('" 引用', BlockType.QUOTE)
        this.TypeOption('• 无序列表', BlockType.UNORDERED_LIST)
        this.TypeOption('1. 有序列表', BlockType.ORDERED_LIST)
        Button('取消')
          .fontSize(13).backgroundColor('#444444').fontColor('#cccccc')
          .margin({ top: 12 })
          .onClick(() => { this.showTypeMenu = false })
      }
      .padding(20).backgroundColor('#2a2a2a').borderRadius(12).width('80%')
    }
    .width('100%').height('100%').backgroundColor('#1a1a1aee')
    .justifyContent(FlexAlign.Center)
    .onClick(() => { this.showTypeMenu = false })
  }

  @Builder TypeOption(label: string, type: BlockType) {
    Button(label)
      .fontSize(14).fontColor('#e0e0e0').backgroundColor('#00000000')
      .width('100%').height(40)
      .border({ width: { bottom: 1 }, color: '#333333' })
      .onClick(() => { this.changeBlockType(this.typeMenuBlockId, type) })
  }
}
