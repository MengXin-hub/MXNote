import { FileManager } from '../core/FileManager'
import { NoteFile, formatTime } from '../model/NoteFile'

@Entry
@Component
struct FileListPage {
  @State files: NoteFile[] = []
  @State loading: boolean = true
  @State showNewDialog: boolean = false
  @State newFileName: string = ''
  @State showRenameDialog: boolean = false
  @State renameFileId: string = ''
  @State renameFileName: string = ''
  @State showDeleteConfirm: boolean = false
  @State deleteFileId: string = ''
  @State deleteFileName: string = ''
  @State statusText: string = '笔记列表'

  private fileManager: FileManager | null = null

  aboutToAppear(): void {
    const uiCtx: UIContext | undefined = this.getUIContext()
    const ctx: Context | undefined = uiCtx ? uiCtx.getHostContext() : undefined
    if (ctx) {
      this.fileManager = new FileManager(ctx)
      this.loadFiles()
    } else {
      this.statusText = '初始化失败'
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
      }
    }
    this.loading = false
  }

  onPageShow(): void {
    this.loadFiles()
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
        this.openEditor(file.id)
      }
    }
  }

  openEditor(noteId: string): void {
    const uiCtx: UIContext | undefined = this.getUIContext()
    if (uiCtx) {
      try {
        uiCtx.getRouter().pushUrl({ url: 'pages/Index', params: { noteId: noteId } })
      } catch (e) {
        // router push failed
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

  build() {
    Stack() {
      Column() {
        this.Header()
        if (this.loading) {
          this.LoadingView()
        } else if (this.files.length === 0) {
          this.EmptyView()
        } else {
          this.FileListView()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#1e1e1e')

      if (this.showNewDialog) {
        this.NewFileOverlay()
      }
      if (this.showRenameDialog) {
        this.RenameOverlay()
      }
      if (this.showDeleteConfirm) {
        this.DeleteConfirmOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder Header() {
    Row() {
      Text('MXNote')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
      Blank()
      Button() {
        Text('+').fontSize(22).fontColor('#ffffff')
      }
      .width(40).height(40).borderRadius(20).backgroundColor('#007AFF')
      .onClick(() => { this.openCreateDialog() })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 8 })
  }

  @Builder LoadingView() {
    Column() {
      LoadingProgress().width(36).height(36).color('#007AFF')
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder EmptyView() {
    Column() {
      Text('📝').fontSize(48).margin({ bottom: 16 })
      Text('还没有笔记').fontSize(16).fontColor('#888888')
      Text('点击右上角 + 创建第一篇笔记').fontSize(13).fontColor('#666666').margin({ top: 8 })
    }
    .width('100%').height('80%').justifyContent(FlexAlign.Center)
  }

  @Builder FileListView() {
    List({ space: 1 }) {
      ForEach(this.files, (file: NoteFile, index: number) => {
        ListItem() {
          Row() {
            Column() {
              Text(file.title || '未命名笔记')
                .fontSize(16).fontWeight(FontWeight.Medium).fontColor('#e0e0e0')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Row() {
                Text('创建: ' + formatTime(file.createdAt))
                  .fontSize(11).fontColor('#666666')
                Text('  |  ')
                  .fontSize(11).fontColor('#555555')
                Text('修改: ' + formatTime(file.modifiedAt))
                  .fontSize(11).fontColor('#666666')
              }
              .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(20).height(20).fillColor('#666666')
          }
          .width('100%')
          .padding({ left: 20, right: 16, top: 14, bottom: 14 })
          .onClick(() => { this.openEditor(file.id) })
        }
        .swipeAction({
          end: {
            builder: (): void => { this.SwipeActions(file.id, file.title) },
            actionAreaDistance: 160
          }
        })
      }, (file: NoteFile, index: number): string => file.id)
    }
    .width('100%').height('100%').padding({ top: 4 })
  }

  @Builder SwipeActions(id: string, title: string) {
    Row() {
      Button('重命名')
        .fontSize(12).backgroundColor('#007AFF').fontColor('#ffffff')
        .onClick(() => { this.openRenameDialog(id, title) })
      Button('删除')
        .fontSize(12).backgroundColor('#f44336').fontColor('#ffffff')
        .margin({ left: 4 })
        .onClick(() => { this.openDeleteConfirm(id, title) })
    }
    .padding({ left: 12, right: 12 })
  }

  @Builder NewFileOverlay() {
    Column() {
      Column() {
        Text('新建笔记').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ffffff')
          .margin({ bottom: 16 })
        TextInput({ text: this.newFileName, placeholder: '输入笔记标题' })
          .fontSize(15).fontColor('#e0e0e0').backgroundColor('#333333').borderRadius(8).padding(12)
          .onChange((value: string) => { this.newFileName = value })
        Row() {
          Button('取消')
            .fontSize(14).backgroundColor('#444444').fontColor('#cccccc')
            .onClick(() => { this.showNewDialog = false })
          Button('创建')
            .fontSize(14).backgroundColor('#007AFF').fontColor('#ffffff')
            .margin({ left: 12 })
            .onClick(() => { this.doCreateFile() })
        }
        .width('100%').justifyContent(FlexAlign.End).margin({ top: 20 })
      }
      .padding(24).backgroundColor('#2a2a2a').borderRadius(12).width('85%')
    }
    .width('100%').height('100%').backgroundColor('#1a1a1abb')
    .justifyContent(FlexAlign.Center)
    .onClick(() => { this.showNewDialog = false })
  }

  @Builder RenameOverlay() {
    Column() {
      Column() {
        Text('重命名笔记').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ffffff')
          .margin({ bottom: 16 })
        TextInput({ text: this.renameFileName, placeholder: '输入新标题' })
          .fontSize(15).fontColor('#e0e0e0').backgroundColor('#333333').borderRadius(8).padding(12)
          .onChange((value: string) => { this.renameFileName = value })
        Row() {
          Button('取消')
            .fontSize(14).backgroundColor('#444444').fontColor('#cccccc')
            .onClick(() => { this.showRenameDialog = false })
          Button('确认')
            .fontSize(14).backgroundColor('#007AFF').fontColor('#ffffff')
            .margin({ left: 12 })
            .onClick(() => { this.doRenameFile() })
        }
        .width('100%').justifyContent(FlexAlign.End).margin({ top: 20 })
      }
      .padding(24).backgroundColor('#2a2a2a').borderRadius(12).width('85%')
    }
    .width('100%').height('100%').backgroundColor('#1a1a1abb')
    .justifyContent(FlexAlign.Center)
    .onClick(() => { this.showRenameDialog = false })
  }

  @Builder DeleteConfirmOverlay() {
    Column() {
      Column() {
        Text('确认删除').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ffffff')
          .margin({ bottom: 8 })
        Text('删除 "' + this.deleteFileName + '" ？此操作不可撤销。')
          .fontSize(14).fontColor('#aaaaaa').margin({ bottom: 20 })
        Row() {
          Button('取消')
            .fontSize(14).backgroundColor('#444444').fontColor('#cccccc')
            .onClick(() => { this.showDeleteConfirm = false })
          Button('删除')
            .fontSize(14).backgroundColor('#f44336').fontColor('#ffffff')
            .margin({ left: 12 })
            .onClick(() => { this.doDeleteFile() })
        }
        .width('100%').justifyContent(FlexAlign.End)
      }
      .padding(24).backgroundColor('#2a2a2a').borderRadius(12).width('85%')
    }
    .width('100%').height('100%').backgroundColor('#1a1a1abb')
    .justifyContent(FlexAlign.Center)
    .onClick(() => { this.showDeleteConfirm = false })
  }
}
