/**
 * Index — MXNote 主页面。
 * TextArea 编辑器, 预览通过 MarkdownParser, 设置弹窗。
 */
import { ThemeColors, ThemeFontSize } from '../constants/ThemeConstants'
import { IconConstants } from '../constants/IconConstants'
import { FileManager } from '../core/FileManager'
import { FileSystemManager } from '../core/FileSystemManager'
import { NoteFile, Folder, formatTime } from '../model/NoteFile'
import { MarkdownParser, MarkdownToken, TokenType, InlineSpan } from '../core/MarkdownParser'
import { Result, AppError } from '../model/Result'
import { preferences } from '@kit.ArkData'
import { TitleBar } from './components/TitleBar'
import { DlgInput, DlgConfirm, DlgMigrationError } from './components/Dialogs'
import { SettingsDialog, LoginDialog } from './components/SettingsDialog'

namespace LAYOUT {
  export const MIN_PANEL: number = 100
  export const MAX_PANEL: number = 600
  export const LEFT_DEFAULT: number = 260
  export const RIGHT_DEFAULT: number = 320
  export const DIVIDER_W: number = 3
  export const FILE_ROW_PAD_V: number = 9
  export const FILE_ROW_PAD_H: number = 12
  export const ACTION_BTN_H: number = 50
  export const FOOTER_H: number = 30
  export const SEARCH_DEBOUNCE: number = 300
}

interface LayoutCfg { leftWidth: number; rightWidth: number; leftVisible: boolean; rightVisible: boolean }
interface AppCfg { layout: LayoutCfg }
interface OldIdx { id: string; title: string; createdAt: number; modifiedAt: number }
class OItem { text: string = ''; lv: number = 0; constructor(t: string, l: number) { this.text = t; this.lv = l } }

@Entry
@Component
struct Index {
  @State files: NoteFile[] = []
  @State folders: Folder[] = []
  @State loading: boolean = true
  @State searchQuery: string = ''
  @State filteredFiles: NoteFile[] = []
  private contentCache: Map<string, string> = new Map()
  private searchTimer: number = -1

  @State activeId: string = ''
  @State activeTitle: string = ''
  @State activeContent: string = ''
  @State modifiedAt: number = 0
  @State charCount: number = 0
  @State fontSize: number = 18
  @State isDirty: boolean = false

  @State tokens: MarkdownToken[] = []
  @State oitems: OItem[] = []
  @State previewReady: boolean = false

  @State leftVisible: boolean = true
  @State rightVisible: boolean = true
  @State rightPanel: string = 'preview'
  @State leftWidth: number = LAYOUT.LEFT_DEFAULT
  @State rightWidth: number = LAYOUT.RIGHT_DEFAULT
  private dragBaseLeft: number = 0
  private dragBaseRight: number = 0

  @State dlgNew: boolean = false
  @State dlgNewFolder: boolean = false
  @State dlgRename: boolean = false
  @State dlgDelete: boolean = false
  @State dlgSettings: boolean = false
  @State dlgLogin: boolean = false
  @State dlgMigErr: boolean = false
  @State dlgText: string = ''
  @State dlgId: string = ''
  @State dlgTitle: string = ''

  @State needMig: boolean = false
  @State migrating: boolean = false

  private fm: FileManager | null = null
  private fsm: FileSystemManager | null = null
  private ps: MarkdownParser = new MarkdownParser()

  aboutToAppear(): void {
    const c: UIContext | undefined = this.getUIContext()
    const h: Context | undefined = c ? c.getHostContext() : undefined
    if (h) { this.fm = new FileManager(h); this.fsm = this.fm.getFileSystemManager(); this.initApp() }
  }
  onPageShow(): void { this.reloadFiles() }

  private async initApp(): Promise<void> {
    const f: FileSystemManager | null = this.fsm; if (!f) return
    if (f.needsMigration()) this.needMig = true
    const cr = f.loadConfig(); if (cr.isOk() && cr.getValue()) {
      const c: AppCfg = cr.getValue()! as AppCfg; const l: LayoutCfg = c.layout
      if (l) { this.leftWidth = l.leftWidth || LAYOUT.LEFT_DEFAULT; this.rightWidth = l.rightWidth || LAYOUT.RIGHT_DEFAULT; this.leftVisible = l.leftVisible !== false; this.rightVisible = l.rightVisible !== false }
    }
    await this.reloadFiles()
  }
  private saveLayout(): void {
    const f: FileSystemManager | null = this.fsm; if (!f) return
    f.saveConfig({ layout: { leftWidth: this.leftWidth, rightWidth: this.rightWidth, leftVisible: this.leftVisible, rightVisible: this.rightVisible } })
  }

  async reloadFiles(): Promise<void> {
    const m: FileManager | null = this.fm; if (!m) return
    this.loading = true
    const fr = await m.listFiles(); if (fr.isOk()) { const fl: NoteFile[] = fr.getValue()!; fl.sort((a: NoteFile, b: NoteFile) => b.modifiedAt - a.modifiedAt); this.files = fl }
    const dr = await m.listFolders(); if (dr.isOk() && dr.getValue()) this.folders = dr.getValue()!
    this.applyFilter(); this.loading = false
  }

  applyFilter(): void {
    const q: string = this.searchQuery.trim().toLowerCase()
    if (!q) { this.filteredFiles = this.files; return }
    const r: NoteFile[] = []; const need: NoteFile[] = []
    for (let i: number = 0; i < this.files.length; i++) {
      if (this.files[i].title.toLowerCase().indexOf(q) >= 0) r.push(this.files[i]); else need.push(this.files[i])
    }
    const remain: NoteFile[] = []
    for (let i: number = 0; i < need.length; i++) {
      const c: string | undefined = this.contentCache.get(need[i].id)
      if (c !== undefined && c.toLowerCase().indexOf(q) >= 0) r.push(need[i])
      else if (c === undefined) remain.push(need[i])
    }
    this.filteredFiles = r
    if (remain.length > 0) this.asyncContentSearch(remain, q)
  }

  private async asyncContentSearch(files: NoteFile[], q: string): Promise<void> {
    for (let i: number = 0; i < files.length; i++) {
      const f: NoteFile = files[i]; if (this.contentCache.has(f.id)) continue
      try {
        const m: FileManager | null = this.fm; if (!m) continue
        const r: Result<NoteFile, AppError> = await m.readFile(f.id)
        if (r.isOk() && r.getValue()) {
          const c: string = r.getValue()!.content; this.contentCache.set(f.id, c)
          if (c.toLowerCase().indexOf(q) >= 0) {
            const cur: NoteFile[] = this.filteredFiles
            if (!cur.some((x: NoteFile): boolean => x.id === f.id)) this.filteredFiles = cur.concat([f])
          }
        }
      } catch (e) { /* skip */ }
    }
  }

  onSearch(v: string): void {
    this.searchQuery = v
    if (this.searchTimer >= 0) clearTimeout(this.searchTimer)
    this.searchTimer = setTimeout(() => { this.applyFilter() }, LAYOUT.SEARCH_DEBOUNCE)
  }

  // ═══════════ 文件操作 ═══════════
  async openFile(id: string): Promise<void> {
    const m: FileManager | null = this.fm; if (!m) return
    const r: Result<NoteFile, AppError> = await m.readFile(id); if (!r.isOk() || !r.getValue()) return
    const d: NoteFile = r.getValue()!
    this.activeId = d.id; this.activeTitle = d.title; this.activeContent = d.content
    this.modifiedAt = d.modifiedAt; this.charCount = d.content.length
    this.isDirty = false; this.previewReady = false
    this.contentCache.set(d.id, d.content)
  }

  async saveFile(): Promise<void> {
    const m: FileManager | null = this.fm; if (!m || !this.activeId) return
    await m.saveFile(this.activeId, this.activeTitle, this.activeContent)
    this.modifiedAt = Date.now(); this.charCount = this.activeContent.length
    this.isDirty = false
    this.contentCache.set(this.activeId, this.activeContent)
    this.renderPreview()
  }

  private renderPreview(): void {
    const r: Result<MarkdownToken[], Object> = this.ps.parse(this.activeContent)
    this.tokens = (r.isOk() && r.getValue()) ? r.getValue()! : []; this.previewReady = true
    const oi: OItem[] = []
    for (let i: number = 0; i < this.tokens.length; i++) { const tk = this.tokens[i]; if (tk.type === TokenType.H) { let tx: string = ''; for (let j: number = 0; j < tk.kids.length; j++) tx += tk.kids[j].t; oi.push(new OItem(tx || ' ', tk.lv)) } }
    this.oitems = oi
  }

  async doNew(): Promise<void> { const m: FileManager | null = this.fm; const nm: string = this.dlgText.trim(); if (!m || !nm) return; const r: Result<NoteFile, AppError> = await m.createFile(nm, ''); this.dlgNew = false; if (r.isOk() && r.getValue()) { await this.reloadFiles(); this.openFile(r.getValue()!.id) } }
  async doNewFolder(): Promise<void> { const m: FileManager | null = this.fm; const nm: string = this.dlgText.trim(); if (!m || !nm) return; await m.createFolder(nm); this.dlgNewFolder = false; await this.reloadFiles() }
  async doDelete(): Promise<void> { const m: FileManager | null = this.fm; if (!m || !this.dlgId) return; await m.deleteFile(this.dlgId); this.dlgDelete = false; if (this.activeId === this.dlgId) { this.activeId = ''; this.activeContent = ''; this.activeTitle = ''; this.charCount = 0; this.previewReady = false }; await this.reloadFiles() }
  async doRename(): Promise<void> { const m: FileManager | null = this.fm; const nt: string = this.dlgText.trim(); if (!m || !this.dlgId || !nt) return; await m.renameFile(this.dlgId, nt); this.dlgRename = false; if (this.activeId === this.dlgId) this.activeTitle = nt; await this.reloadFiles() }

  // 面板
  tgRight(panel: string): void {
    if (this.rightPanel === panel && this.rightVisible) { this.rightVisible = false; return }
    this.rightPanel = panel; this.rightVisible = true
    if (panel === 'preview' && !this.previewReady && this.activeId) { this.renderPreview() }
  }

  // 迁移
  async doMigration(): Promise<void> {
    this.migrating = true; const f: FileSystemManager | null = this.fsm; if (!f) return
    try {
      const ctx: Context | undefined = this.getUIContext()?.getHostContext(); if (!ctx) return
      const pref: preferences.Preferences = await preferences.getPreferences(ctx, 'mxnote_file_store')
      const ij: string = pref.getSync('mxnote_file_index', '[]') as string
      const oi: OldIdx[] = JSON.parse(ij) as OldIdx[]
      const ent: Map<string, string> = new Map(); for (let i: number = 0; i < oi.length; i++) ent.set(oi[i].id, pref.getSync('mxnote_file_' + oi[i].id, '') as string)
      const r: Result<number, AppError> = f.migrateFromPreferences(ij, ent)
      if (r.isOk()) { this.needMig = false; await this.reloadFiles() } else { this.dlgMigErr = true }
    } catch (e) { this.dlgMigErr = true }
    this.migrating = false
  }

  // 拖拽
  leftDragStart(): void { this.dragBaseLeft = this.leftWidth }
  leftDragUpdate(ev: GestureEvent): void { this.leftWidth = Math.max(LAYOUT.MIN_PANEL, Math.min(LAYOUT.MAX_PANEL, this.dragBaseLeft + ev.offsetX)); this.saveLayout() }
  rightDragStart(): void { this.dragBaseRight = this.rightWidth }
  rightDragUpdate(ev: GestureEvent): void { this.rightWidth = Math.max(LAYOUT.MIN_PANEL, Math.min(LAYOUT.MAX_PANEL, this.dragBaseRight - ev.offsetX)); this.saveLayout() }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  build() {
    Stack() {
      Column() {
        TitleBar({
          searchQuery: $searchQuery,
          leftVisible: this.leftVisible,
          rightVisible: this.rightVisible,
          onSearchChange: (v: string): void => { this.onSearch(v) },
          onLeftToggle: (): void => { this.leftVisible = !this.leftVisible; this.saveLayout() },
          onRightToggle: (): void => { this.rightVisible = !this.rightVisible; this.saveLayout() },
          onSettingsClick: (): void => { this.dlgSettings = true }
        })

        Divider().color(ThemeColors.colorBorderSubtle).height(1)

        Row() {
          // ══ 左面板 ════════════════════════════════════════════
          if (this.leftVisible) {
            Column() {
              Row({ space: 6 }) {
                this.ActionBtn('新建文件', IconConstants.IC_NOTE, (): void => { this.dlgText = ''; this.dlgNew = true })
                this.ActionBtn('新建文件夹', IconConstants.IC_FOLDER_NEW, (): void => { this.dlgText = ''; this.dlgNewFolder = true })
                this.ActionBtn('导入文件', IconConstants.IC_TEXT, (): void => { })
              }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })

              Divider().color(ThemeColors.colorBorderSubtle)

              if (this.loading) {
                Column() { LoadingProgress().width(22).height(22).color(ThemeColors.colorAccentBlue) }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
              } else if (this.filteredFiles.length === 0) {
                Column() {
                  Image(IconConstants.IC_NOTE).width(36).height(36).fillColor(ThemeColors.colorBorderDefault).margin({ bottom: 10 })
                  Text(this.searchQuery ? '无匹配结果' : '暂无笔记').fontSize(12).fontColor(ThemeColors.colorTextTertiary)
                }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
              } else {
                List() {
                  ForEach(this.filteredFiles, (f: NoteFile) => {
                    ListItem() {
                      Row() {
                        Image(IconConstants.IC_NOTE).width(16).height(16)
                          .fillColor(this.activeId === f.id ? ThemeColors.colorAccentBlue : ThemeColors.colorTextSecondary).margin({ right: 8 })
                        Column() {
                          Text(f.title || '未命名').fontSize(13).fontWeight(FontWeight.Medium)
                            .fontColor(this.activeId === f.id ? ThemeColors.colorAccentBlue : ThemeColors.colorTextPrimary)
                            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                          if (this.searchQuery.length > 0) {
                            Text(this.getSnippet(f.id, this.searchQuery)).fontSize(10)
                              .fontColor(ThemeColors.colorTextTertiary).maxLines(1).margin({ top: 1 })
                          }
                          Text(this.fmtRel(f.modifiedAt)).fontSize(10).fontColor(ThemeColors.colorTextTertiary).margin({ top: 1 })
                        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                      }
                      .width('100%').padding({ left: LAYOUT.FILE_ROW_PAD_H, right: LAYOUT.FILE_ROW_PAD_H, top: LAYOUT.FILE_ROW_PAD_V, bottom: LAYOUT.FILE_ROW_PAD_V })
                      .backgroundColor(this.activeId === f.id ? ThemeColors.colorBgSelected : '#00000000')
                      .border({ width: { left: this.activeId === f.id ? 3 : 0 }, color: ThemeColors.colorAccentBlue })
                      .onClick(() => { this.openFile(f.id) })
                      .gesture(LongPressGesture().onAction(() => { this.dlgId = f.id; this.dlgTitle = f.title; this.dlgText = f.title }))
                    }
                  }, (f: NoteFile): string => 'f_' + f.id)
                }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
              }
            }
            .width(this.leftWidth).height('100%').backgroundColor(ThemeColors.colorBgSurface)
            .border({ width: { right: 1 }, color: ThemeColors.colorBorderSubtle })
          }

          if (this.leftVisible) {
            Column().width(LAYOUT.DIVIDER_W).height('100%').backgroundColor('#d0d0d0')
              .gesture(PanGesture({ direction: PanDirection.Horizontal })
                .onActionStart((): void => { this.leftDragStart() })
                .onActionUpdate((ev: GestureEvent): void => { this.leftDragUpdate(ev) }))
          }

          // ══ 中间编辑区 ═══════════════════════════════════════
          Column() {
            if (this.activeId) {
              TextArea({ text: $$this.activeContent, placeholder: '# Markdown\n\n写完点击预览查看效果' })
                .width('100%').layoutWeight(1).backgroundColor(ThemeColors.colorBgCanvas)
                .fontSize(this.fontSize).fontColor(ThemeColors.colorTextPrimary)
                .fontFamily('monospace').padding(14).borderRadius(0)
                .caretColor(ThemeColors.colorAccentBlue).placeholderColor(ThemeColors.colorTextTertiary)
                .onChange((v: string) => {
                  this.charCount = v.length; this.isDirty = true; this.previewReady = false
                })

              Row() {
                Text(this.charCount.toString() + ' 字').fontSize(11).fontColor(ThemeColors.colorTextTertiary)
                Text('  ·  ').fontSize(11).fontColor(ThemeColors.colorBorderDefault)
                Text(this.isDirty ? '已修改' : '已保存').fontSize(11).fontColor(this.isDirty ? ThemeColors.colorAccentYellow : ThemeColors.colorAccentGreen)
                Text('  ·  ').fontSize(11).fontColor(ThemeColors.colorBorderDefault)
                Text('保存 Ctrl+S').fontSize(11).fontColor(ThemeColors.colorAccentBlue).onClick(() => { this.saveFile() })
                Blank()
                Text('导出').fontSize(11).fontColor(ThemeColors.colorTextSecondary)
                Text('  ·  ').fontSize(11).fontColor(ThemeColors.colorBorderDefault)
                Text('大纲').fontSize(11).fontColor(ThemeColors.colorAccentBlue).onClick(() => { this.tgRight('preview') })
              }.width('100%').height(LAYOUT.FOOTER_H).padding({ left: 16, right: 16 })
              .backgroundColor(ThemeColors.colorBgSurface).border({ width: { top: 1 }, color: ThemeColors.colorBorderSubtle })
            } else {
              Column() {
                Image(IconConstants.IC_NOTE).width(48).height(48).fillColor(ThemeColors.colorBorderDefault).margin({ bottom: 12 })
                Text('选择或新建笔记开始编辑').fontSize(13).fontColor(ThemeColors.colorTextSecondary)
              }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).backgroundColor(ThemeColors.colorBgCanvas)
            }
          }.layoutWeight(1).height('100%').backgroundColor(ThemeColors.colorBgCanvas)

          if (this.rightVisible) {
            Column().width(LAYOUT.DIVIDER_W).height('100%').backgroundColor('#d0d0d0')
              .gesture(PanGesture({ direction: PanDirection.Horizontal })
                .onActionStart((): void => { this.rightDragStart() })
                .onActionUpdate((ev: GestureEvent): void => { this.rightDragUpdate(ev) }))
          }

          if (this.rightVisible) {
            if (this.rightPanel === 'preview') { this.BuildPreview() }
            else { this.BuildAi() }
          }
        }.width('100%').layoutWeight(1)
      }.width('100%').height('100%').backgroundColor(ThemeColors.colorBgCanvas)

      // 对话框
      if (this.dlgNew) { DlgInput({ title: '新建文件', textValue: $dlgText, placeholder: '输入文件名', confirmLabel: '创建', onConfirm: (): void => { this.doNew() }, onCancel: (): void => { this.dlgNew = false } }) }
      if (this.dlgNewFolder) { DlgInput({ title: '新建文件夹', textValue: $dlgText, placeholder: '输入文件夹名', confirmLabel: '创建', onConfirm: (): void => { this.doNewFolder() }, onCancel: (): void => { this.dlgNewFolder = false } }) }
      if (this.dlgRename) { DlgInput({ title: '重命名', textValue: $dlgText, placeholder: '输入新名称', confirmLabel: '确认', onConfirm: (): void => { this.doRename() }, onCancel: (): void => { this.dlgRename = false } }) }
      if (this.dlgDelete) { DlgConfirm({ title: '确认删除', message: '"' + this.dlgTitle + '" 将被永久删除', confirmLabel: '删除', confirmColor: ThemeColors.colorAccentRed, onConfirm: (): void => { this.doDelete() }, onCancel: (): void => { this.dlgDelete = false } }) }
      if (this.dlgMigErr) { DlgMigrationError({ onRetry: (): void => { this.dlgMigErr = false; this.doMigration() }, onSkip: (): void => { this.dlgMigErr = false; this.needMig = false } }) }
      if (this.migrating) { Column() { LoadingProgress().width(28).height(28).color(ThemeColors.colorAccentBlue); Text('迁移中...').fontSize(13).fontColor(ThemeColors.colorTextSecondary).margin({ top: 10 }) }.width('100%').height('100%').backgroundColor(ThemeColors.colorBgOverlay).justifyContent(FlexAlign.Center) }

      if (this.dlgSettings) {
        SettingsDialog({
          fontSize: $fontSize,
          showLogin: $dlgLogin,
          onClose: (): void => { this.dlgSettings = false },
          onFontPlus: (): void => { if (this.fontSize < 32) this.fontSize += 1 },
          onFontMinus: (): void => { if (this.fontSize > 10) this.fontSize -= 1 }
        })
      }
      if (this.dlgLogin) { LoginDialog({ onClose: (): void => { this.dlgLogin = false } }) }
    }.width('100%').height('100%')
  }

  @Builder ActionBtn(label: string, icon: Resource, cb: () => void) {
    Row({ space: 3 }) {
      Image(icon).width(14).height(14).fillColor(ThemeColors.colorTextPrimary)
      Text(label).fontSize(11).fontColor(ThemeColors.colorTextPrimary)
    }.height(LAYOUT.ACTION_BTN_H).padding({ left: 10, right: 10 })
    .backgroundColor(ThemeColors.colorBgHover).borderRadius(6).onClick(cb)
  }

  @Builder BuildPreview() {
    Column() {
      Row() {
        Text('预览').fontSize(12).fontWeight(FontWeight.Bold).fontColor(ThemeColors.colorTextPrimary); Blank()
        Text('✕').fontSize(14).fontColor(ThemeColors.colorTextTertiary).onClick(() => { this.rightVisible = false; this.saveLayout() })
      }.width('100%').padding({ left: 10, right: 6, top: 8, bottom: 5 }).border({ width: { bottom: 1 }, color: ThemeColors.colorBorderSubtle })
      Scroll() {
        Column() {
          if (!this.previewReady || this.tokens.length === 0) { Text('保存后自动生成预览').fontSize(11).fontColor(ThemeColors.colorTextTertiary).width('100%').padding(10) }
          else { ForEach(this.tokens, (t: MarkdownToken, i: number) => { this.Block(t, i) }, (t: MarkdownToken, i: number): string => 'b_' + i.toString()) }
        }.width('100%').padding(10)
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
    }.width(this.rightWidth).height('100%').backgroundColor('#fafbfc').border({ width: { left: 1 }, color: ThemeColors.colorBorderSubtle })
  }

  @Builder Block(t: MarkdownToken, i: number) {
    if (t.type === TokenType.H) { Text(t.kids.map((s: InlineSpan): string => s.t).join('')).fontSize(Math.max(14,28-t.lv*3)).fontWeight(FontWeight.Bold).fontColor(ThemeColors.colorTextPrimary).padding({ top:10, bottom:2 }).width('100%') }
    else if (t.type === TokenType.C) { Text(t.raw).fontSize(12).fontColor(ThemeColors.colorTextSecondary).fontFamily('monospace').padding(10).width('100%').backgroundColor('#f1f3f4').borderRadius(6).margin({ top:6, bottom:6 }) }
    else if (t.type === TokenType.Q) { Text(t.raw).fontSize(13).fontColor(ThemeColors.colorTextSecondary).fontStyle(FontStyle.Italic).width('100%').border({ width:{left:3}, color:ThemeColors.colorAccentGreen }).padding({ left:10 }).margin({ top:5, bottom:5 }) }
    else if (t.type === TokenType.HR) { Divider().color(ThemeColors.colorBorderSubtle).margin({ top:12, bottom:12 }).width('100%') }
    else if (t.type === TokenType.UL || t.type === TokenType.OL) { Column() { ForEach(t.kids, (it: InlineSpan, j: number) => { Row() { Text(t.type===TokenType.OL?(j+1).toString()+'.':'•').fontSize(13).fontColor(ThemeColors.colorTextTertiary).width(22); Text(it.t).fontSize(13).fontColor(ThemeColors.colorTextSecondary) }.width('100%').padding({ top:1, bottom:1 }) }, (it: InlineSpan, j: number): string => 'li_'+i.toString()+'_'+j.toString()) }.width('100%').margin({ top:3, bottom:3 }) }
    else { Row() { ForEach(t.kids, (s: InlineSpan, idx: number) => {
      if (s.c) { Text(s.t).fontSize(13).fontColor('#7c3aed').fontFamily('monospace').backgroundColor('#f1f3f4').borderRadius(3).padding({ left:3, right:3, top:1, bottom:1 }) }
      else if (s.b&&s.i) { Text(s.t).fontSize(13).fontColor(ThemeColors.colorTextPrimary).fontWeight(FontWeight.Bold).fontStyle(FontStyle.Italic) }
      else if (s.b) { Text(s.t).fontSize(13).fontColor(ThemeColors.colorTextPrimary).fontWeight(FontWeight.Bold) }
      else if (s.i) { Text(s.t).fontSize(13).fontColor(ThemeColors.colorTextSecondary).fontStyle(FontStyle.Italic) }
      else { Text(s.t).fontSize(13).fontColor(ThemeColors.colorTextSecondary) }
    }, (s: InlineSpan, idx: number): string => 'is_'+i.toString()+'_'+idx.toString()) }.width('100%').padding({ top:3, bottom:3 }) }
  }

  @Builder BuildAi() {
    Column() {
      Row() { Text('AI 对话').fontSize(12).fontWeight(FontWeight.Bold).fontColor(ThemeColors.colorTextPrimary); Blank(); Text('✕').fontSize(14).fontColor(ThemeColors.colorTextTertiary).onClick(() => { this.rightVisible = false; this.saveLayout() }) }
        .width('100%').padding({ left: 10, right: 6, top: 8, bottom: 5 }).border({ width: { bottom: 1 }, color: ThemeColors.colorBorderSubtle })
      Column() {
        Image(IconConstants.IC_CHAT).width(42).height(42).fillColor(ThemeColors.colorBorderDefault).margin({ bottom: 14 })
        Text('AI 对话 · 即将上线').fontSize(14).fontWeight(FontWeight.Medium).fontColor(ThemeColors.colorTextSecondary)
        Text('基于笔记内容的智能助手').fontSize(11).fontColor(ThemeColors.colorTextTertiary).margin({ top: 4 })
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    }.width(this.rightWidth).height('100%').backgroundColor('#fafbfc').border({ width: { left: 1 }, color: ThemeColors.colorBorderSubtle })
  }

  private fmtRel(ms: number): string { const d: number = Date.now() - ms; if (d < 60000) return '刚刚'; if (d < 3600000) return Math.floor(d/60000)+' 分钟前'; if (d < 86400000) return Math.floor(d/3600000)+' 小时前'; return formatTime(ms) }

  private getSnippet(fileId: string, query: string): string {
    const c: string | undefined = this.contentCache.get(fileId); if (!c || c.length === 0) return ''
    const q: string = query.trim().toLowerCase(); const idx: number = c.toLowerCase().indexOf(q)
    if (idx < 0) return ''; const s: number = Math.max(0, idx - 30); const e: number = Math.min(c.length, idx + q.length + 30)
    let snip: string = c.slice(s, e); if (s > 0) snip = '...' + snip; if (e < c.length) snip = snip + '...'; return snip
  }
}
