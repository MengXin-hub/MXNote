import { FileManager } from '../core/FileManager'
import { NoteFile, formatTime } from '../model/NoteFile'

/**
 * FileListPage — 受 note-gen 启发的侧边栏式文件浏览器。
 *
 * 设计参考:
 * - 搜索栏置顶, 支持文件名过滤
 * - 文件列表带图标, 选中状态高亮
 * - 分组显示: 最近修改 > 更早
 * - 底部新建按钮
 * - 左滑操作: 重命名/删除
 */
@Entry
@Component
struct FileListPage {
  @State files: NoteFile[] = []
  @State filteredFiles: NoteFile[] = []
  @State loading: boolean = true
  @State searchQuery: string = ''
  @State showNewDialog: boolean = false
  @State newFileName: string = ''
  @State showRenameDialog: boolean = false
  @State renameFileId: string = ''
  @State renameFileName: string = ''
  @State showDeleteConfirm: boolean = false
  @State deleteFileId: string = ''
  @State deleteFileName: string = ''
  @State selectedId: string = ''

  private fileManager: FileManager | null = null
  private readonly RECENT_DAYS: number = 7

  aboutToAppear(): void {
    const uiCtx: UIContext | undefined = this.getUIContext()
    const ctx: Context | undefined = uiCtx ? uiCtx.getHostContext() : undefined
    if (ctx) {
      this.fileManager = new FileManager(ctx)
      this.loadFiles()
    }
  }

  async loadFiles(): Promise<void> {
    const fm: FileManager | null = this.fileManager
    if (!fm) {
      return
    }
    this.loading = true
    await fm.init()
    const result = await fm.listFiles()
    if (result.isOk()) {
      const list: NoteFile[] | null = result.getValue()
      if (list) {
        this.files = list
        this.applyFilter()
      }
    }
    this.loading = false
  }

  onPageShow(): void {
    this.loadFiles()
  }

  applyFilter(): void {
    const q: string = this.searchQuery.trim().toLowerCase()
    if (!q) {
      this.filteredFiles = this.files
    } else {
      const filtered: NoteFile[] = []
      for (let i: number = 0; i < this.files.length; i++) {
        const f: NoteFile = this.files[i]
        if (f.title.toLowerCase().indexOf(q) >= 0 || f.content.toLowerCase().indexOf(q) >= 0) {
          filtered.push(f)
        }
      }
      this.filteredFiles = filtered
    }
  }

  onSearchChange(value: string): void {
    this.searchQuery = value
    this.applyFilter()
  }

  isRecent(ms: number): boolean {
    return (Date.now() - ms) < this.RECENT_DAYS * 86400000
  }

  openCreateDialog(): void {
    this.newFileName = ''
    this.showNewDialog = true
  }

  async doCreateFile(): Promise<void> {
    const fm: FileManager | null = this.fileManager
    const name: string = this.newFileName.trim()
    if (!fm || name.length === 0) {
      return
    }
    const result = await fm.createFile(name, '')
    this.showNewDialog = false
    if (result.isOk()) {
      const file: NoteFile | null = result.getValue()
      if (file) {
        this.selectedId = file.id
        this.openEditor(file.id)
      }
    }
  }

  openEditor(noteId: string): void {
    this.selectedId = noteId
    const uiCtx: UIContext | undefined = this.getUIContext()
    if (uiCtx) {
      try {
        uiCtx.getRouter().pushUrl({ url: 'pages/Index', params: { noteId: noteId } })
      } catch (e) {
        // push failed
      }
    }
  }

  openRenameDialog(id: string, currentTitle: string): void {
    this.renameFileId = id
    this.renameFileName = currentTitle
    this.showRenameDialog = true
  }

  async doRenameFile(): Promise<void> {
    const fm: FileManager | null = this.fileManager
    const name: string = this.renameFileName.trim()
    if (!fm || name.length === 0) {
      return
    }
    await fm.renameFile(this.renameFileId, name)
    this.showRenameDialog = false
    await this.loadFiles()
  }

  openDeleteConfirm(id: string, title: string): void {
    this.deleteFileId = id
    this.deleteFileName = title
    this.showDeleteConfirm = true
  }

  async doDeleteFile(): Promise<void> {
    const fm: FileManager | null = this.fileManager
    if (!fm) {
      return
    }
    await fm.deleteFile(this.deleteFileId)
    this.showDeleteConfirm = false
    await this.loadFiles()
  }

  formatShortTime(ms: number): string {
    const now: number = Date.now()
    const diff: number = now - ms
    if (diff < 60000) {
      return '刚刚'
    }
    if (diff < 3600000) {
      return Math.floor(diff / 60000) + ' 分钟前'
    }
    if (diff < 86400000) {
      return Math.floor(diff / 3600000) + ' 小时前'
    }
    return formatTime(ms)
  }

  build() {
    Stack() {
      Column() {
        this.Header()
        this.SearchBar()
        if (this.loading) {
          this.LoadingView()
        } else if (this.files.length === 0) {
          this.EmptyView()
        } else {
          this.FileListSection()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#0d1117')

      // 新建按钮
      Button() {
        Text('+').fontSize(26).fontColor('#ffffff')
      }
      .width(56).height(56).borderRadius(28)
      .backgroundColor('#1f6feb')
      .shadow({ radius: 12, color: '#1f6feb44' })
      .position({ x: '85%', y: '88%' })
      .onClick(() => { this.openCreateDialog() })

      if (this.showNewDialog) {
        this.DialogOverlay('新建笔记', this.newFileName, '输入标题', '创建',
          (v: string): void => { this.newFileName = v },
          (): void => { this.doCreateFile() },
          (): void => { this.showNewDialog = false })
      }
      if (this.showRenameDialog) {
        this.DialogOverlay('重命名', this.renameFileName, '输入新标题', '确认',
          (v: string): void => { this.renameFileName = v },
          (): void => { this.doRenameFile() },
          (): void => { this.showRenameDialog = false })
      }
      if (this.showDeleteConfirm) {
        this.DeleteOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder Header() {
    Row() {
      Text('笔记')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#e6edf3')
      Blank()
      Text(String(this.files.length) + ' 篇')
        .fontSize(13)
        .fontColor('#484f58')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 12 })
  }

  @Builder SearchBar() {
    Row() {
      TextInput({ placeholder: '搜索笔记...' })
        .fontSize(14)
        .fontColor('#e6edf3')
        .placeholderColor('#484f58')
        .backgroundColor('#161b22')
        .borderRadius(10)
        .height(40)
        .layoutWeight(1)
        .padding({ left: 12 })
        .onChange((value: string) => { this.onSearchChange(value) })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }

  @Builder LoadingView() {
    Column() {
      LoadingProgress().width(32).height(32).color('#1f6feb')
    }
    .width('100%').height('70%').justifyContent(FlexAlign.Center)
  }

  @Builder EmptyView() {
    Column() {
      Text('📄').fontSize(56).margin({ bottom: 16 })
      Text('还没有笔记').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#8b949e')
      Text('点击右下角 + 开始记录').fontSize(14).fontColor('#484f58').margin({ top: 8 })
    }
    .width('100%').height('70%').justifyContent(FlexAlign.Center)
  }

  @Builder FileListSection() {
    Column() {
      // 最近修改
      if (this.getRecentFiles().length > 0 && this.searchQuery.length === 0) {
        this.SectionLabel('最近')
        ForEach(this.getRecentFiles(), (f: NoteFile) => {
          ListItem() { this.FileRow(f) }
          .swipeAction({ end: { builder: (): void => { this.SwipeActions(f.id, f.title) }, actionAreaDistance: 160 } })
        }, (f: NoteFile): string => 'recent_' + f.id)
      }

      // 更早
      if (this.getOlderFiles().length > 0 && this.searchQuery.length === 0) {
        this.SectionLabel('更早')
        ForEach(this.getOlderFiles(), (f: NoteFile) => {
          ListItem() { this.FileRow(f) }
          .swipeAction({ end: { builder: (): void => { this.SwipeActions(f.id, f.title) }, actionAreaDistance: 160 } })
        }, (f: NoteFile): string => 'older_' + f.id)
      }

      // 搜索结果
      if (this.searchQuery.length > 0) {
        this.SectionLabel('搜索结果')
        ForEach(this.filteredFiles, (f: NoteFile) => {
          ListItem() { this.FileRow(f) }
          .swipeAction({ end: { builder: (): void => { this.SwipeActions(f.id, f.title) }, actionAreaDistance: 160 } })
        }, (f: NoteFile): string => 'search_' + f.id)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder SectionLabel(label: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#484f58')
        .padding({ left: 20, top: 8, bottom: 4 })
    }
    .width('100%')
  }

  @Builder FileRow(f: NoteFile) {
    Row() {
      // 文件图标
      Text('📝')
        .fontSize(20)
        .margin({ right: 12 })

      Column() {
        Text(f.title || '未命名')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#e6edf3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text(this.formatShortTime(f.modifiedAt))
            .fontSize(11)
            .fontColor('#484f58')
          if (f.content && f.content.length > 0) {
            Text(' · ')
              .fontSize(11)
              .fontColor('#30363d')
            Text(String(f.content.length) + ' 字')
              .fontSize(11)
              .fontColor('#484f58')
          }
        }
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(16)
        .height(16)
        .fillColor('#30363d')
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.selectedId === f.id ? '#1c2533' : '#00000000')
    .border({ width: { left: this.selectedId === f.id ? 3 : 0 }, color: '#1f6feb' })
    .onClick(() => { this.openEditor(f.id) })
  }

  @Builder SwipeActions(id: string, title: string) {
    Row() {
      Button('重命名')
        .fontSize(11)
        .backgroundColor('#1f6feb')
        .fontColor('#ffffff')
        .borderRadius(4)
        .onClick(() => { this.openRenameDialog(id, title) })
      Button('删除')
        .fontSize(11)
        .backgroundColor('#da3633')
        .fontColor('#ffffff')
        .borderRadius(4)
        .margin({ left: 4 })
        .onClick(() => { this.openDeleteConfirm(id, title) })
    }
    .padding({ left: 12, right: 12 })
  }

  @Builder DeleteOverlay() {
    Column() {
      Column() {
        Text('确认删除')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#e6edf3')
          .margin({ bottom: 6 })
        Text('"' + this.deleteFileName + '" 将被永久删除')
          .fontSize(14)
          .fontColor('#8b949e')
          .margin({ bottom: 24 })
        Row() {
          Button('取消')
            .fontSize(14)
            .backgroundColor('#21262d')
            .fontColor('#c9d1d9')
            .border({ width: 1, color: '#30363d' })
            .borderRadius(8)
            .width('45%')
            .onClick(() => { this.showDeleteConfirm = false })
          Button('删除')
            .fontSize(14)
            .backgroundColor('#da3633')
            .fontColor('#ffffff')
            .borderRadius(8)
            .width('45%')
            .margin({ left: 12 })
            .onClick(() => { this.doDeleteFile() })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .padding(28)
      .backgroundColor('#161b22')
      .border({ width: 1, color: '#30363d', radius: 16 })
      .width('85%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0d1117cc')
    .justifyContent(FlexAlign.Center)
    .onClick(() => { this.showDeleteConfirm = false })
  }

  @Builder DialogOverlay(
    title: string,
    textValue: string,
    placeholder: string,
    confirmLabel: string,
    onChange: (v: string) => void,
    onConfirm: () => void,
    onCancel: () => void
  ) {
    Column() {
      Column() {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#e6edf3')
          .margin({ bottom: 16 })

        TextInput({ text: textValue, placeholder: placeholder })
          .fontSize(15)
          .fontColor('#e6edf3')
          .placeholderColor('#484f58')
          .backgroundColor('#0d1117')
          .border({ width: 1, color: '#30363d', radius: 8 })
          .padding(12)
          .onChange(onChange)

        Row() {
          Button('取消')
            .fontSize(14)
            .backgroundColor('#21262d')
            .fontColor('#c9d1d9')
            .border({ width: 1, color: '#30363d' })
            .borderRadius(8)
            .width('45%')
            .onClick(onCancel)

          Button(confirmLabel)
            .fontSize(14)
            .backgroundColor('#1f6feb')
            .fontColor('#ffffff')
            .borderRadius(8)
            .width('45%')
            .margin({ left: 12 })
            .onClick(onConfirm)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 20 })
      }
      .padding(28)
      .backgroundColor('#161b22')
      .border({ width: 1, color: '#30363d', radius: 16 })
      .width('85%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0d1117cc')
    .justifyContent(FlexAlign.Center)
    .onClick(onCancel)
  }

  private getRecentFiles(): NoteFile[] {
    const result: NoteFile[] = []
    for (let i: number = 0; i < this.filteredFiles.length; i++) {
      if (this.isRecent(this.filteredFiles[i].modifiedAt)) {
        result.push(this.filteredFiles[i])
      }
    }
    return result
  }

  private getOlderFiles(): NoteFile[] {
    const result: NoteFile[] = []
    for (let i: number = 0; i < this.filteredFiles.length; i++) {
      if (!this.isRecent(this.filteredFiles[i].modifiedAt)) {
        result.push(this.filteredFiles[i])
      }
    }
    return result
  }
}
