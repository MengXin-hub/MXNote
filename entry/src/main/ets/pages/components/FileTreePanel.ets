/**
 * FileTreePanel — 文件/文件夹列表 (VS Code 风格)。
 *
 * 行内创建: 点击新建/文件夹 → 列表顶部出现 TextInput, 回车创建
 * 双击 → 行内重命名, 回车/✓ 保存
 */
import { ThemeColors, ThemeRadius } from '../../constants/ThemeConstants'
import { IconConstants } from '../../constants/IconConstants'
import { NoteFile, Folder, formatTime } from '../../model/NoteFile'

@Component
export struct FileTreePanel {
  @Link files: NoteFile[]
  @Link folders: Folder[]
  @Link activeId: string
  @Link loading: boolean
  @Link searchQuery: string
  @State collapsedFolders: Set<string> = new Set()

  // 内联新建
  @State newItemText: string = ''
  @State isNewFile: boolean = false   // true=新建文件, false=新建文件夹
  @State showNewInput: boolean = false

  // 上下文菜单
  @State ctxVisible: boolean = false
  @State ctxType: string = ''
  @State ctxId: string = ''
  @State ctxName: string = ''

  // 行内重命名
  @State renameId: string = ''
  @State renameText: string = ''
  @State renameIsFolder: boolean = false

  // 批量删除
  @State selectMode: boolean = false
  @State selectedIds: Set<string> = new Set()

  onFileOpen?: (id: string) => void
  onFileRename?: (id: string, newTitle: string) => void
  onFileDelete?: (id: string, title: string) => void
  onFileBatchDelete?: (ids: string[]) => void
  onFileCreate?: (name: string, folderId: string | null) => void
  onFolderCreate?: (name: string) => void
  onFolderRename?: (id: string, newName: string) => void
  onFolderDelete?: (id: string, name: string) => void
  onImportClick?: () => void
  onFileMove?: (fileId: string, folderId: string | null) => void

  private filesInFolder(folderId: string | null): NoteFile[] {
    const r: NoteFile[] = []
    for (let i: number = 0; i < this.files.length; i++) { if (this.files[i].folderId === folderId) r.push(this.files[i]) }
    return r
  }
  private rootFiles(): NoteFile[] { return this.filesInFolder(null) }
  private isCollapsed(folderId: string): boolean { return this.collapsedFolders.has(folderId) }
  private toggleFolder(folderId: string): void {
    if (this.isCollapsed(folderId)) this.collapsedFolders.delete(folderId)
    else this.collapsedFolders.add(folderId)
    this.collapsedFolders = new Set(this.collapsedFolders)
  }
  private fmtRel(ms: number): string {
    const d: number = Date.now() - ms; if (d < 60000) return '刚刚'
    if (d < 3600000) return Math.floor(d / 60000) + ' 分钟前'
    if (d < 86400000) return Math.floor(d / 3600000) + ' 小时前'; return formatTime(ms)
  }

  // 内联新建
  private showNewFileInput(): void { this.isNewFile = true; this.newItemText = ''; this.showNewInput = true }
  private showNewFolderInput(): void { this.isNewFile = false; this.newItemText = ''; this.showNewInput = true }
  private closeNewInput(): void { this.showNewInput = false; this.newItemText = '' }
  private commitNewItem(): void {
    const nm: string = this.newItemText.trim()
    if (nm.length === 0) { this.closeNewInput(); return }
    if (this.isNewFile && this.onFileCreate) this.onFileCreate(nm, null)
    else if (!this.isNewFile && this.onFolderCreate) this.onFolderCreate(nm)
    this.closeNewInput()
  }

  // 菜单
  private showFileMenu(f: NoteFile): void { if (this.selectMode) return; this.ctxType = 'file'; this.ctxId = f.id; this.ctxName = f.title; this.ctxVisible = true }
  private showFolderMenu(folder: Folder): void { if (this.selectMode) return; this.ctxType = 'folder'; this.ctxId = folder.id; this.ctxName = folder.name; this.ctxVisible = true }
  private closeMenu(): void { this.ctxVisible = false }
  private doRenameMenu(): void { this.ctxVisible = false; this.startInlineRename(this.ctxId, this.ctxName, this.ctxType === 'folder') }
  private doDeleteMenu(): void { this.ctxVisible = false; if (this.ctxType === 'file' && this.onFileDelete) this.onFileDelete(this.ctxId, this.ctxName); else if (this.ctxType === 'folder' && this.onFolderDelete) this.onFolderDelete(this.ctxId, this.ctxName) }
  private doMoveTo(folderId: string | null): void { this.ctxVisible = false; if (this.ctxType === 'file' && this.onFileMove) this.onFileMove(this.ctxId, folderId) }
  private doNewInFolder(): void { this.ctxVisible = false; this.isNewFile = true; this.newItemText = ''; this.showNewInput = true }

  // 行内重命名
  private startInlineRename(id: string, curName: string, isFolder: boolean): void {
    this.renameId = id; this.renameText = curName; this.renameIsFolder = isFolder
  }
  private commitRename(): void {
    const nt: string = this.renameText.trim()
    if (nt.length > 0) {
      if (this.renameIsFolder && this.onFolderRename) this.onFolderRename(this.renameId, nt)
      else if (!this.renameIsFolder && this.onFileRename) this.onFileRename(this.renameId, nt)
    }
    this.renameId = ''
  }

  // 批量
  private toggleSelect(fileId: string): void { if (this.selectedIds.has(fileId)) this.selectedIds.delete(fileId); else this.selectedIds.add(fileId); this.selectedIds = new Set(this.selectedIds) }
  private exitSelectMode(): void { this.selectMode = false; this.selectedIds = new Set() }
  private doBatchDelete(): void { if (this.selectedIds.size === 0) return; const ids: string[] = []; this.selectedIds.forEach((id: string) => { ids.push(id) }); this.selectedIds = new Set(); this.selectMode = false; if (this.onFileBatchDelete) this.onFileBatchDelete(ids) }

  // 拖拽
  @State dragFileId: string = ''; @State dragOverFolderId: string = ''
  private onFileDragStart(f: NoteFile): void { this.dragFileId = f.id }
  private onFileDragEnd(): void { this.dragFileId = ''; this.dragOverFolderId = '' }
  private onFolderDrop(folderId: string | null): void { if (this.dragFileId && this.onFileMove) this.onFileMove(this.dragFileId, folderId); this.dragFileId = ''; this.dragOverFolderId = '' }

  build() {
    Stack() {
      Column() {
        // 操作按钮行
        Row({ space: 6 }) {
          this.Btn('新建', IconConstants.IC_NOTE, (): void => { this.showNewFileInput() })
          this.Btn('文件夹', IconConstants.IC_FOLDER_NEW, (): void => { this.showNewFolderInput() })
          this.Btn('导入', IconConstants.IC_TEXT, (): void => { if (this.onImportClick) this.onImportClick() })
          Blank()
          if (this.selectMode) {
            Text('取消').fontSize(11).fontColor(ThemeColors.colorAccentBlue).onClick(() => { this.exitSelectMode() })
            Text('  ').fontSize(11)
            Text('删除选中(' + this.selectedIds.size.toString() + ')').fontSize(11).fontColor(ThemeColors.colorAccentRed).onClick(() => { this.doBatchDelete() })
          } else {
            Text('多选').fontSize(11).fontColor(ThemeColors.colorTextTertiary).onClick(() => { this.selectMode = true })
          }
        }
        .width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })

        Divider().color(ThemeColors.colorBorderSubtle)

        // ── 内联新建输入行 (VS Code 风格) ──
        if (this.showNewInput) {
          Row() {
            Image(this.isNewFile ? IconConstants.IC_NOTE : IconConstants.IC_FOLDER)
              .width(16).height(16).fillColor(ThemeColors.colorAccentBlue).margin({ right: 8 })
            TextInput({ text: $$this.newItemText, placeholder: this.isNewFile ? '文件名' : '文件夹名' })
              .fontSize(13).fontColor(ThemeColors.colorTextPrimary).height(32).layoutWeight(1)
              .placeholderColor(ThemeColors.colorTextTertiary)
              .onSubmit(() => { this.commitNewItem() })
            Text('✕').fontSize(13).fontColor(ThemeColors.colorTextTertiary).padding(6).onClick(() => { this.closeNewInput() })
          }
          .width('100%').padding({ left: 14, right: 10, top: 6, bottom: 6 })
          .backgroundColor(ThemeColors.colorBgSelected)
          Divider().color(ThemeColors.colorBorderSubtle)
        }

        if (this.loading) {
          Column() { LoadingProgress().width(22).height(22).color(ThemeColors.colorAccentBlue) }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.files.length === 0 && this.folders.length === 0 && !this.showNewInput) {
          Column() {
            Image(IconConstants.IC_NOTE).width(36).height(36).fillColor(ThemeColors.colorBorderDefault).margin({ bottom: 10 })
            Text(this.searchQuery ? '无匹配' : '暂无笔记').fontSize(12).fontColor(ThemeColors.colorTextTertiary)
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.folders, (folder: Folder) => {
              ListItem() {
                Column() {
                  Row() {
                    if (this.renameId === folder.id) {
                      TextInput({ text: $$this.renameText, placeholder: '' })
                        .fontSize(13).fontColor(ThemeColors.colorTextPrimary).height(28).layoutWeight(1)
                        .onSubmit(() => { this.commitRename() })
                      Text('确定').fontSize(14).fontColor(ThemeColors.colorAccentGreen).padding(6).onClick(() => { this.commitRename() })
                    } else {
                      Image(IconConstants.IC_FOLDER).width(16).height(16).fillColor(ThemeColors.colorTextSecondary).margin({ right: 6 })
                      Text(folder.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor(ThemeColors.colorTextPrimary).layoutWeight(1)
                      Text(this.isCollapsed(folder.id) ? '>' : 'x').fontSize(10).fontColor(ThemeColors.colorTextTertiary)
                    }
                  }
                  .width('100%').padding({ left: 12, right: 10, top: 8, bottom: 8 })
                  .onClick(() => { if (this.renameId !== folder.id) this.toggleFolder(folder.id) })
                  .gesture(GestureGroup(GestureMode.Parallel,
                    LongPressGesture({ repeat: false }).onAction(() => { this.showFolderMenu(folder) }),
                    TapGesture({ count: 2 }).onAction(() => { this.startInlineRename(folder.id, folder.name, true) })
                  ))
                  .onMouse((event: MouseEvent) => { if (event.button === MouseButton.Right && event.action === MouseAction.Release) this.showFolderMenu(folder) })
                  .onDrop(() => { this.onFolderDrop(folder.id) })
                  if (!this.isCollapsed(folder.id)) {
                    ForEach(this.filesInFolder(folder.id), (f: NoteFile) => { this.FileRow(f) }, (f: NoteFile): string => 'sub_' + f.id)
                  }
                }
              }
            }, (folder: Folder): string => 'gfx_' + folder.id)
            ForEach(this.rootFiles(), (f: NoteFile) => { ListItem() { this.FileRow(f) } }, (f: NoteFile): string => 'rootf_' + f.id)
          }
          .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
        }
      }
      .width('100%').height('100%').backgroundColor(ThemeColors.colorBgSurface)

      // 上下文菜单覆盖层
      if (this.ctxVisible) {
        Column() {
          Column() {
            Text(this.ctxName).fontSize(13).fontWeight(FontWeight.Medium).fontColor(ThemeColors.colorTextPrimary).maxLines(1).width('100%').padding({ left: 14, right: 14, top: 12, bottom: 4 })
            Divider().color(ThemeColors.colorBorderSubtle)
            if (this.ctxType === 'folder') {
              Row() { Image(IconConstants.IC_NOTE).width(14).height(14).fillColor(ThemeColors.colorTextSecondary).margin({ right: 6 }); Text('新建文件于此').fontSize(13).fontColor(ThemeColors.colorTextPrimary) }
              .width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 }).onClick(() => { this.doNewInFolder() })
            }
            Row() { Text('重命名').fontSize(13).fontColor(ThemeColors.colorTextPrimary) }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 }).onClick(() => { this.doRenameMenu() })
            Row() { Text('删除').fontSize(13).fontColor(ThemeColors.colorAccentRed) }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 }).onClick(() => { this.doDeleteMenu() })
            if (this.ctxType === 'file') {
              Divider().color(ThemeColors.colorBorderSubtle); Text('移动至...').fontSize(11).fontColor(ThemeColors.colorTextTertiary).width('100%').padding({ left: 14, right: 14, top: 8, bottom: 2 })
              Row() { Text('根目录').fontSize(12).fontColor(ThemeColors.colorTextSecondary) }.width('100%').padding({ left: 14, right: 14, top: 6, bottom: 6 }).onClick(() => { this.doMoveTo(null) })
              ForEach(this.folders, (folder: Folder) => { Row() { Text('文件夹' + folder.name).fontSize(12).fontColor(ThemeColors.colorTextSecondary).maxLines(1) }.width('100%').padding({ left: 14, right: 14, top: 6, bottom: 6 }).onClick(() => { this.doMoveTo(folder.id) }) }, (folder: Folder): string => 'ctx_move_' + folder.id)
            }
            Divider().color(ThemeColors.colorBorderSubtle)
            Row() { Text('取消').fontSize(12).fontColor(ThemeColors.colorTextTertiary) }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 12 }).onClick(() => { this.closeMenu() })
          }
          .backgroundColor('#ffffff').borderRadius(ThemeRadius.xl).width('85%').shadow({ radius: 20, color: '#00000022' })
        }
        .width('100%').height('100%').backgroundColor('#00000022').justifyContent(FlexAlign.Center).onClick(() => { this.closeMenu() })
      }
    }
    .width('100%').height('100%')
  }

  @Builder Btn(label: string, icon: Resource, cb: () => void) {   // 列表栏图标
    Row() { 
      // Image(icon)
      //   .width(16)
      //   .height(16)
      //   .fillColor(ThemeColors.colorTextPrimary); 
      Text(label)
        .fontSize(11)
        .fontColor(ThemeColors.colorTextPrimary)
        .margin({ left: 3 })
    }
    .backgroundColor(ThemeColors.colorBgHover)
    .borderRadius(4)
    .padding({ left: 8, right: 8, top: 5, bottom: 5 }).onClick(cb)
  }

  @Builder FileRow(f: NoteFile) {
    Row() {
      if (this.selectMode) {
        Text(this.selectedIds.has(f.id) ? '确定' : '☐').fontSize(16).fontColor(this.selectedIds.has(f.id) ? ThemeColors.colorAccentBlue : ThemeColors.colorTextTertiary).margin({ right: 6 })
        .onClick(() => { this.toggleSelect(f.id) })
      }
      if (this.renameId === f.id) {
        TextInput({ text: $$this.renameText, placeholder: '' }).fontSize(13).fontColor(ThemeColors.colorTextPrimary).height(28).layoutWeight(1)
          .onSubmit(() => { this.commitRename() })
        Text('确定').fontSize(14).fontColor(ThemeColors.colorAccentGreen).padding(6).onClick(() => { this.commitRename() })
      } else {
        Image(IconConstants.IC_NOTE).width(16).height(16).fillColor(this.activeId === f.id ? ThemeColors.colorAccentBlue : ThemeColors.colorTextSecondary).margin({ right: 8 })
        Column() {
          Text(f.title || '未命名').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.activeId === f.id ? ThemeColors.colorAccentBlue : ThemeColors.colorTextPrimary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.fmtRel(f.modifiedAt)).fontSize(10).fontColor(ThemeColors.colorTextTertiary).margin({ top: 1 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
    }
    .width('100%').padding({ left: this.selectMode ? 10 : 14, right: 10, top: 9, bottom: 9 })
    .backgroundColor(this.activeId === f.id ? ThemeColors.colorBgSelected : '#00000000').border({ width: { left: this.activeId === f.id ? 3 : 0 }, color: ThemeColors.colorAccentBlue })
    .onClick(() => { if (this.selectMode) { this.toggleSelect(f.id) } else if (this.renameId !== f.id && this.onFileOpen) this.onFileOpen(f.id) })
    .gesture(GestureGroup(GestureMode.Parallel,
      LongPressGesture({ repeat: false }).onAction(() => { this.showFileMenu(f) }),
      TapGesture({ count: 2 }).onAction(() => { this.startInlineRename(f.id, f.title, false) })
    ))
    .onMouse((event: MouseEvent) => { if (event.button === MouseButton.Right && event.action === MouseAction.Release) this.showFileMenu(f) })
    .draggable(true).onDragStart(() => { this.onFileDragStart(f) }).onDragEnd(() => { this.onFileDragEnd() })
  }
}
