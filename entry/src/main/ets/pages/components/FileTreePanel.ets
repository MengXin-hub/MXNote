/**
 * FileTreePanel — 文件/文件夹列表。
 *
 * PC: 右键操作 | 移动端: 长按/双击
 * 文件可拖拽到文件夹中
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

  // 上下文菜单
  @State ctxVisible: boolean = false
  @State ctxType: string = ''   // 'file' | 'folder'
  @State ctxId: string = ''
  @State ctxName: string = ''

  // 拖拽状态
  @State dragFileId: string = ''
  @State dragOverFolderId: string = ''

  onFileOpen?: (id: string) => void
  onFileRename?: (id: string, title: string) => void
  onFileDelete?: (id: string, title: string) => void
  onFolderRename?: (id: string, name: string) => void
  onFolderDelete?: (id: string, name: string) => void
  onNewClick?: (folderId: string | null) => void
  onNewFolderClick?: () => void
  onImportClick?: () => void
  onFileMove?: (fileId: string, targetFolderId: string | null) => void

  private filesInFolder(folderId: string | null): NoteFile[] {
    const r: NoteFile[] = []
    for (let i: number = 0; i < this.files.length; i++) {
      if (this.files[i].folderId === folderId) r.push(this.files[i])
    }
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
    const d: number = Date.now() - ms
    if (d < 60000) return '刚刚'
    if (d < 3600000) return Math.floor(d / 60000) + ' 分钟前'
    if (d < 86400000) return Math.floor(d / 3600000) + ' 小时前'
    return formatTime(ms)
  }

  // 菜单
  private showFileMenu(f: NoteFile): void { this.ctxType = 'file'; this.ctxId = f.id; this.ctxName = f.title; this.ctxVisible = true }
  private showFolderMenu(folder: Folder): void { this.ctxType = 'folder'; this.ctxId = folder.id; this.ctxName = folder.name; this.ctxVisible = true }
  private closeMenu(): void { this.ctxVisible = false }
  private doRename(): void { this.ctxVisible = false; if (this.ctxType === 'file' && this.onFileRename) this.onFileRename(this.ctxId, this.ctxName); else if (this.ctxType === 'folder' && this.onFolderRename) this.onFolderRename(this.ctxId, this.ctxName) }
  private doDelete(): void { this.ctxVisible = false; if (this.ctxType === 'file' && this.onFileDelete) this.onFileDelete(this.ctxId, this.ctxName); else if (this.ctxType === 'folder' && this.onFolderDelete) this.onFolderDelete(this.ctxId, this.ctxName) }
  private doMoveTo(folderId: string | null): void { this.ctxVisible = false; if (this.ctxType === 'file' && this.onFileMove) this.onFileMove(this.ctxId, folderId) }
  private doNewInFolder(): void { this.ctxVisible = false; if (this.onNewClick) this.onNewClick(this.ctxId) }

  // 拖拽
  private onFileDragStart(f: NoteFile): void { this.dragFileId = f.id }
  private onFileDragEnd(): void { this.dragFileId = ''; this.dragOverFolderId = '' }
  private onFolderDragEnter(folderId: string): void { if (this.dragFileId) this.dragOverFolderId = folderId }
  private onFolderDragLeave(): void { this.dragOverFolderId = '' }
  private onFolderDrop(folderId: string | null): void {
    if (this.dragFileId && this.onFileMove) this.onFileMove(this.dragFileId, folderId)
    this.dragFileId = ''; this.dragOverFolderId = ''
  }

  // ══ PC/移动端触发 ═════════════════════════════
  private triggerFileMenu(f: NoteFile): void { this.showFileMenu(f) }
  private triggerFolderMenu(folder: Folder): void { this.showFolderMenu(folder) }

  build() {
    Stack() {
      Column() {
        // ── 操作按钮 ──
        Row({ space: 6 }) {
          this.Btn('新建', IconConstants.IC_NOTE, (): void => { if (this.onNewClick) this.onNewClick(null) })
          this.Btn('文件夹', IconConstants.IC_FOLDER_NEW, (): void => { if (this.onNewFolderClick) this.onNewFolderClick() })
          this.Btn('导入', IconConstants.IC_TEXT, (): void => { if (this.onImportClick) this.onImportClick() })
        }
        .width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })

        Divider().color(ThemeColors.colorBorderSubtle)

        if (this.loading) {
          Column() { LoadingProgress().width(22).height(22).color(ThemeColors.colorAccentBlue) }
            .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.files.length === 0 && this.folders.length === 0) {
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
                    Image(IconConstants.IC_FOLDER).width(16).height(16)
                      .fillColor(ThemeColors.colorTextSecondary).margin({ right: 6 })
                    Text(folder.name).fontSize(13).fontWeight(FontWeight.Medium)
                      .fontColor(ThemeColors.colorTextPrimary).layoutWeight(1)
                    Text(this.isCollapsed(folder.id) ? '▶' : '▼').fontSize(10)
                      .fontColor(ThemeColors.colorTextTertiary)
                  }
                  .width('100%').padding({ left: 12, right: 10, top: 8, bottom: 8 })
                  .backgroundColor(this.dragOverFolderId === folder.id ? ThemeColors.colorBgSelected : '#00000000')
                  .onClick(() => { this.toggleFolder(folder.id) })
                  .gesture(GestureGroup(GestureMode.Parallel,
                    LongPressGesture({ repeat: false }).onAction(() => { this.triggerFolderMenu(folder) }),
                    TapGesture({ count: 2 }).onAction(() => { this.triggerFolderMenu(folder) })
                  ))
                  .onMouse((event: MouseEvent) => {
                    if (event.button === MouseButton.Right && event.action === MouseAction.Release) {
                      this.triggerFolderMenu(folder)
                    }
                  })
                  .onDragEnter(() => { this.onFolderDragEnter(folder.id) })
                  .onDragLeave(() => { this.onFolderDragLeave() })
                  .onDrop(() => { this.onFolderDrop(folder.id) })

                  if (!this.isCollapsed(folder.id)) {
                    ForEach(this.filesInFolder(folder.id), (f: NoteFile) => {
                      this.FileRow(f)
                    }, (f: NoteFile): string => 'sub_' + f.id)
                  }
                }
              }
            }, (folder: Folder): string => 'gfx_' + folder.id)

            ForEach(this.rootFiles(), (f: NoteFile) => {
              ListItem() { this.FileRow(f) }
            }, (f: NoteFile): string => 'rootf_' + f.id)
          }
          .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
        }
      }
      .width('100%').height('100%').backgroundColor(ThemeColors.colorBgSurface)

      // ══ 上下文菜单 ═════════════════════════════════
      if (this.ctxVisible) {
        Column() {
          Column() {
            Text(this.ctxName).fontSize(13).fontWeight(FontWeight.Medium)
              .fontColor(ThemeColors.colorTextPrimary).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%').padding({ left: 14, right: 14, top: 12, bottom: 4 })

            Divider().color(ThemeColors.colorBorderSubtle)

            // 文件夹: 新建文件于此
            if (this.ctxType === 'folder') {
              Row() {
                Image(IconConstants.IC_NOTE).width(14).height(14)
                  .fillColor(ThemeColors.colorTextSecondary).margin({ right: 6 })
                Text('新建文件于此').fontSize(13).fontColor(ThemeColors.colorTextPrimary)
              }
              .width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .onClick(() => { this.doNewInFolder() })
            }

            // 重命名
            Row() {
              Text('✎ 重命名').fontSize(13).fontColor(ThemeColors.colorTextPrimary)
            }
            .width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .onClick(() => { this.doRename() })

            // 删除
            Row() {
              Text('🗑 删除').fontSize(13).fontColor(ThemeColors.colorAccentRed)
            }
            .width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .onClick(() => { this.doDelete() })

            // 文件: 移动选项
            if (this.ctxType === 'file') {
              Divider().color(ThemeColors.colorBorderSubtle)
              Text('移动至...').fontSize(11).fontColor(ThemeColors.colorTextTertiary)
                .width('100%').padding({ left: 14, right: 14, top: 8, bottom: 2 })

              Row() {
                Text('📂 根目录').fontSize(12).fontColor(ThemeColors.colorTextSecondary)
              }
              .width('100%').padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .onClick(() => { this.doMoveTo(null) })

              ForEach(this.folders, (folder: Folder) => {
                Row() {
                  Text('  📁 ' + folder.name).fontSize(12).fontColor(ThemeColors.colorTextSecondary)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%').padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .onClick(() => { this.doMoveTo(folder.id) })
              }, (folder: Folder): string => 'ctx_move_' + folder.id)
            }

            Divider().color(ThemeColors.colorBorderSubtle)

            Row() {
              Text('取消').fontSize(12).fontColor(ThemeColors.colorTextTertiary)
            }
            .width('100%').padding({ left: 14, right: 14, top: 10, bottom: 12 })
            .onClick(() => { this.closeMenu() })
          }
          .backgroundColor('#ffffff').borderRadius(ThemeRadius.xl)
          .width('85%').shadow({ radius: 20, color: '#00000022' })
        }
        .width('100%').height('100%')
        .backgroundColor('#00000022')
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.closeMenu() })
      }
    }
    .width('100%').height('100%')
  }

  @Builder Btn(label: string, icon: Resource, cb: () => void) {
    Row() {
      Image(icon).width(14).height(14).fillColor(ThemeColors.colorTextPrimary)
      Text(label).fontSize(11).fontColor(ThemeColors.colorTextPrimary).margin({ left: 3 })
    }
    .backgroundColor(ThemeColors.colorBgHover).borderRadius(4)
    .padding({ left: 8, right: 8, top: 5, bottom: 5 }).onClick(cb)
  }

  @Builder FileRow(f: NoteFile) {
    Row() {
      Image(IconConstants.IC_NOTE).width(16).height(16)
        .fillColor(this.activeId === f.id ? ThemeColors.colorAccentBlue : ThemeColors.colorTextSecondary)
        .margin({ right: 8 })
      Column() {
        Text(f.title || '未命名').fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor(this.activeId === f.id ? ThemeColors.colorAccentBlue : ThemeColors.colorTextPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.fmtRel(f.modifiedAt)).fontSize(10).fontColor(ThemeColors.colorTextTertiary).margin({ top: 1 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%').padding({ left: 14, right: 10, top: 9, bottom: 9 })
    .backgroundColor(this.activeId === f.id ? ThemeColors.colorBgSelected : '#00000000')
    .border({ width: { left: this.activeId === f.id ? 3 : 0 }, color: ThemeColors.colorAccentBlue })
    .onClick(() => { if (this.onFileOpen) this.onFileOpen(f.id) })
    .gesture(GestureGroup(GestureMode.Parallel,
      LongPressGesture({ repeat: false }).onAction(() => { this.triggerFileMenu(f) }),
      TapGesture({ count: 2 }).onAction(() => { this.triggerFileMenu(f) })
    ))
    .onMouse((event: MouseEvent) => {
      if (event.button === MouseButton.Right && event.action === MouseAction.Release) {
        this.triggerFileMenu(f)
      }
    })
    .draggable(true)
    .onDragStart(() => { this.onFileDragStart(f) })
    .onDragEnd(() => { this.onFileDragEnd() })
  }
}
