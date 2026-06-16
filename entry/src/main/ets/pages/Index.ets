/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  Index — MXNote 主页面                                        ║
 * ║                                                              ║
 * ║  布局: [TitleBar] [LeftPanel | Editor+Tabs | RightPanel]      ║
 * ║  三面板可拖拽 · 多标签编辑器                                     ║
 * ╚══════════════════════════════════════════════════════════════╝
 */
import { ThemeColors } from '../constants/ThemeConstants'
import { IconConstants } from '../constants/IconConstants'
import { FileManager } from '../core/FileManager'
import { FileSystemManager } from '../core/FileSystemManager'
import { NoteFile, Folder, formatTime } from '../model/NoteFile'
import { MarkdownToken, TokenType, InlineSpan } from '../core/MarkdownParser'
import { Result, AppError } from '../model/Result'
import { preferences } from '@kit.ArkData'
import { MarkdownParser } from '../core/MarkdownParser'
import { LvMarkdownIn, mdRegister } from '@luvi/lv-markdown-in'
import { ExportService } from '../services/ExportService'
import { ImportService, ImportResult } from '../services/ImportService'
import { TitleBar } from './components/TitleBar'
import { FileTreePanel } from './components/FileTreePanel'
import { DlgConfirm, DlgMigrationError } from './components/Dialogs'
import { SettingsDialog, LoginDialog } from './components/SettingsDialog'
import { EditorArea } from './components/EditorArea'

// ═══════════════════ 布局可调常量 ═══════════════════
namespace LAYOUT {
  export const MIN_PANEL: number = 100
  export const MAX_PANEL: number = 900
  export const LEFT_DEFAULT: number = 100
  export const RIGHT_DEFAULT: number = 700
  export const DIVIDER_W: number = 3
  export const FOOTER_H: number = 30  // 底部统计栏高度
  export const TAB_H: number = 30     // 多标签栏高度
  export const SEARCH_DEBOUNCE: number = 300
}

// ═══════════════════ 内部数据类型 ═══════════════════
interface TabInfo { id: string; title: string; content: string; modifiedAt: number; dirty: boolean }
interface LayoutCfg { leftWidth: number; rightWidth: number; leftVisible: boolean; rightVisible: boolean }
interface AppCfg { layout: LayoutCfg }
interface OldIdx { id: string; title: string; createdAt: number; modifiedAt: number }
class OItem { text: string = ''; lv: number = 0; constructor(t: string, l: number) { this.text = t; this.lv = l } }

@Entry
@Component
struct Index {
  // ─────────── 文件列表状态 ───────────
  @State files: NoteFile[] = []
  @State folders: Folder[] = []
  @State loading: boolean = true
  @State searchQuery: string = ''
  @State filteredFiles: NoteFile[] = []
  private contentCache: Map<string, string> = new Map()
  private searchTimer: number = -1

  // ─────────── 多标签编辑器状态 ───────────
  @State tabs: TabInfo[] = []
  @State activeTabIdx: number = -1
  @State activeId: string = ''  // sidebar 高亮同步用
  @State fontSize: number = 18
  @State charCount: number = 0
  @State editorDirty: boolean = false

  // ─────────── 标签内联重命名状态 ───────────
  @State renameTabId: string = ''
  @State renameTabText: string = ''

  // ─────────── 预览/大纲状态 ───────────
  @State tokens: MarkdownToken[] = []
  @State oitems: OItem[] = []
  @State previewReady: boolean = false

  // ─────────── 面板状态 ───────────
  @State leftVisible: boolean = false
  @State rightVisible: boolean = false
  @State rightPanel: string = 'preview'  // 'preview' | 'outline' | 'ai'
  @State leftWidth: number = LAYOUT.LEFT_DEFAULT
  @State rightWidth: number = LAYOUT.RIGHT_DEFAULT

  // ─────────── 对话框状态 ───────────
  @State dlgDelete: boolean = false
  @State dlgDeleteFolder: boolean = false
  @State dlgSettings: boolean = false
  @State dlgLogin: boolean = false
  @State dlgMigErr: boolean = false
  @State dlgId: string = ''
  @State dlgTitle: string = ''
  @State dlgIsFolder: boolean = false

  // ─────────── 迁移状态 ───────────
  @State needMig: boolean = false
  @State migrating: boolean = false

  // ─────────── 私有服务实例 ───────────
  private fm: FileManager | null = null
  private fsm: FileSystemManager | null = null
  private ps: MarkdownParser = new MarkdownParser()
  private isReady: boolean = false

  // ─────────── 拖拽状态 ───────────
  private dragBaseLeft: number = 0
  private dragBaseRight: number = 0
  @State leftDividerHover: boolean = false
  @State rightDividerHover: boolean = false

  // ═══════════════════════════════════════════════════════
  //  §1 生命周期
  // ═══════════════════════════════════════════════════════

  aboutToAppear(): void {
    const c: UIContext | undefined = this.getUIContext()
    const h: Context | undefined = c ? c.getHostContext() : undefined
    if (h && !this.isReady) {
      this.fm = new FileManager(h)
      this.fsm = this.fm.getFileSystemManager()
      this.isReady = true

      // 注册预览区超链接点击拦截 — 实现笔记内链跳转
      const self: Index = this
      mdRegister.HandleHyperlink = (url: string): boolean => {
        if (!url || url.length === 0) return true
        // 外部链接交给浏览器处理
        if (url.startsWith('http://') || url.startsWith('https://')) return true
        // 去掉 .md 后缀，尝试按标题匹配笔记文件
        const target: string = url.endsWith('.md') ? url.slice(0, -3) : url
        for (let i: number = 0; i < self.files.length; i++) {
          if (self.files[i].title === target || self.files[i].title === url) {
            self.openFile(self.files[i].id)
            return false  // 已拦截
          }
        }
        // 未匹配到笔记，尝试按 ID 直接打开
        for (let i: number = 0; i < self.files.length; i++) {
          if (self.files[i].id === target) {
            self.openFile(self.files[i].id)
            return false
          }
        }
        return true  // 无匹配，走默认行为
      }

      setTimeout(() => { this.initApp() }, 0)  // 延迟加载让首帧渲染
    }
  }
  onPageShow(): void { if (this.isReady) this.reloadFiles() }

  private async initApp(): Promise<void> {
    const f: FileSystemManager | null = this.fsm; if (!f) return
    if (f.needsMigration()) this.needMig = true
    const cr: Result<AppCfg, AppError> = f.loadConfig()
    if (cr.isOk() && cr.getValue()) {
      const c: AppCfg = cr.getValue()! as AppCfg
      const l: LayoutCfg = c.layout
      if (l) {
        this.leftWidth = l.leftWidth || LAYOUT.LEFT_DEFAULT
        this.rightWidth = l.rightWidth || LAYOUT.RIGHT_DEFAULT
      }
    }
    await this.reloadFiles()
  }

  // ═══════════════════════════════════════════════════════
  //  §2 文件列表 + 搜索
  // ═══════════════════════════════════════════════════════

  async reloadFiles(): Promise<void> {
    const m: FileManager | null = this.fm; if (!m) return
    this.loading = true
    const fr: Result<NoteFile[], AppError> = await m.listFiles()
    if (fr.isOk()) {
      const fl: NoteFile[] = fr.getValue()!
      fl.sort((a: NoteFile, b: NoteFile) => b.modifiedAt - a.modifiedAt)
      this.files = fl
    }
    const dr: Result<Folder[], AppError> = await m.listFolders()
    if (dr.isOk() && dr.getValue()) this.folders = dr.getValue()!
    this.applyFilter()
    this.loading = false
    setTimeout(() => { this.preloadAllContents() }, 500)
  }

  /** 搜索过滤: 标题即时 + 缓存内容 + 异步懒加载 */
  applyFilter(): void {
    const q: string = this.searchQuery.trim().toLowerCase()
    if (!q) { this.filteredFiles = this.files; return }
    const r: NoteFile[] = []
    const need: NoteFile[] = []
    for (let i: number = 0; i < this.files.length; i++) {
      if (this.files[i].title.toLowerCase().indexOf(q) >= 0) r.push(this.files[i])
      else need.push(this.files[i])
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
      const f: NoteFile = files[i]
      if (this.contentCache.has(f.id)) continue
      try {
        const m: FileManager | null = this.fm; if (!m) continue
        const r: Result<NoteFile, AppError> = await m.readFile(f.id)
        if (r.isOk() && r.getValue()) {
          const c: string = r.getValue()!.content
          this.contentCache.set(f.id, c)
          if (c.toLowerCase().indexOf(q) >= 0) {
            const cur: NoteFile[] = this.filteredFiles
            if (!cur.some((x: NoteFile): boolean => x.id === f.id)) {
              this.filteredFiles = cur.concat([f])
            }
          }
        }
      } catch (e) { /* skip */ }
    }
  }

  private async preloadAllContents(): Promise<void> {
    const m: FileManager | null = this.fm; if (!m) return
    for (let i: number = 0; i < this.files.length; i++) {
      const f: NoteFile = this.files[i]; if (this.contentCache.has(f.id)) continue
      try {
        const r: Result<NoteFile, AppError> = await m.readFile(f.id)
        if (r.isOk() && r.getValue()) this.contentCache.set(f.id, r.getValue()!.content)
      } catch (e) { /* skip */ }
    }
  }

  // ═══════════════════════════════════════════════════════
  //  §3 多标签操作
  // ═══════════════════════════════════════════════════════

  /** 切换标签前自动保存当前脏标签 */
  private autoSaveCurrent(): void {
    if (this.activeTabIdx < 0) return
    const t: TabInfo = this.tabs[this.activeTabIdx]
    if (!t.dirty) return
    const m: FileManager | null = this.fm; if (!m) return
    t.dirty = false; this.editorDirty = false
    this.contentCache.set(t.id, t.content)
    m.saveFile(t.id, t.title, t.content)
  }

  /** 切换到指定标签（统一入口：更新所有状态 + 触发预览） */
  private switchTab(idx: number, id: string, title: string, dirty: boolean, len: number): void {
    this.autoSaveCurrent()
    this.activeTabIdx = idx; this.activeId = id
    this.editorDirty = dirty; this.charCount = len; this.previewReady = false
    this.renderPreview()
  }

  /** 打开文件: 已打开则切换，否则加载 */
  async openFile(id: string): Promise<void> {
    const m: FileManager | null = this.fm; if (!m) return
    for (let i: number = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].id === id) {
        this.switchTab(i, id, this.tabs[i].title, this.tabs[i].dirty, this.tabs[i].content.length)
        return
      }
    }
    const r: Result<NoteFile, AppError> = await m.readFile(id)
    if (!r.isOk() || !r.getValue()) return
    const d: NoteFile = r.getValue()!
    this.contentCache.set(d.id, d.content)
    this.tabs = this.tabs.concat([{
      id: d.id, title: d.title, content: d.content,
      modifiedAt: d.modifiedAt, dirty: false
    }])
    this.switchTab(this.tabs.length - 1, d.id, d.title, false, d.content.length)
  }

  /** 关闭标签: 先保存→修正索引→删标签 */
  closeTab(idx: number): void {
    if (idx < 0 || idx >= this.tabs.length) return
    this.autoSaveCurrent()
    if (this.activeTabIdx >= idx) {
      if (this.tabs.length <= 1) {
        this.activeTabIdx = -1; this.activeId = ''; this.editorDirty = false
        this.charCount = 0; this.previewReady = false; this.tokens = []; this.tabs = []
        return
      }
      this.activeTabIdx = Math.min(this.activeTabIdx, this.tabs.length - 2)
      if (this.activeTabIdx >= idx && this.activeTabIdx > 0) this.activeTabIdx--
    }
    const newTabs: TabInfo[] = []
    for (let i: number = 0; i < this.tabs.length; i++) { if (i !== idx) newTabs.push(this.tabs[i]) }
    this.tabs = newTabs
    if (this.activeTabIdx >= 0) {
      const t: TabInfo = this.tabs[this.activeTabIdx]
      this.activeId = t.id; this.charCount = t.content.length
      this.editorDirty = t.dirty; this.renderPreview()
    }
  }

  /** TextArea onChange 回调 */
  onEditorChange(v: string): void {
    if (this.activeTabIdx < 0) return
    this.tabs[this.activeTabIdx].content = v; this.tabs[this.activeTabIdx].dirty = true
    this.charCount = v.length; this.editorDirty = true; this.previewReady = false
    this.tabs = this.tabs  // 触发 @State 更新
  }

  /** 保存当前标签 */
  saveCurrentTab(): void {
    if (this.activeTabIdx < 0) return
    const tab: TabInfo = this.tabs[this.activeTabIdx]
    const m: FileManager | null = this.fm; if (!m) return
    m.saveFile(tab.id, tab.title, tab.content).then(() => {
      tab.dirty = false; this.editorDirty = false
      this.charCount = tab.content.length; this.contentCache.set(tab.id, tab.content)
      this.tabs = this.tabs; this.renderPreview()
    })
  }

  /** 标签内联重命名: 提交后同步 tabs + files + 磁盘 */
  commitTabRename(): void {
    const nt: string = this.renameTabText.trim()
    if (nt.length === 0 || this.renameTabId.length === 0) { this.renameTabId = ''; return }
    // 更新 tabs
    for (let i: number = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].id === this.renameTabId) { this.tabs[i].title = nt; break }
    }
    this.tabs = this.tabs
    // 同步 files 数组（sidebar 实时刷新）
    const updatedFiles: NoteFile[] = []
    for (let i: number = 0; i < this.files.length; i++) {
      updatedFiles.push(new NoteFile(
        this.files[i].id, this.files[i].id === this.renameTabId ? nt : this.files[i].title,
        this.files[i].content, this.files[i].createdAt, this.files[i].modifiedAt, this.files[i].folderId
      ))
    }
    this.files = updatedFiles; this.applyFilter()
    // 异步持久化
    const m: FileManager | null = this.fm; if (m) m.renameFile(this.renameTabId, nt)
    this.renameTabId = ''
  }

  // ═══════════════════════════════════════════════════════
  //  §4 文件操作
  // ═══════════════════════════════════════════════════════

  /** 行内重命名回调（sidebar → 实时刷新 UI） */
  onFileRename(id: string, newTitle: string): void {
    const updatedFiles: NoteFile[] = []
    for (let i: number = 0; i < this.files.length; i++) {
      updatedFiles.push(new NoteFile(
        this.files[i].id, this.files[i].id === id ? newTitle : this.files[i].title,
        this.files[i].content, this.files[i].createdAt, this.files[i].modifiedAt, this.files[i].folderId
      ))
    }
    this.files = updatedFiles
    // 同步 tabs
    for (let i: number = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].id === id) { this.tabs[i].title = newTitle; break }
    }
    this.tabs = this.tabs
    const m: FileManager | null = this.fm; if (m) m.renameFile(id, newTitle)
  }

  onFolderRename(id: string, newName: string): void {
    const updatedFolders: Folder[] = []
    for (let i: number = 0; i < this.folders.length; i++) {
      updatedFolders.push(new Folder(
        this.folders[i].id, this.folders[i].id === id ? newName : this.folders[i].name,
        this.folders[i].parentId, this.folders[i].createdAt
      ))
    }
    this.folders = updatedFolders
    const m: FileManager | null = this.fm; if (m) m.renameFolder(id, newName)
  }

  onFileDelete(id: string, title: string): void { this.dlgId = id; this.dlgTitle = title; this.dlgIsFolder = false; this.dlgDelete = true }
  onFolderDelete(id: string, title: string): void { this.dlgId = id; this.dlgTitle = title; this.dlgIsFolder = true; this.dlgDeleteFolder = true }
  onBatchDelete(ids: string[]): void { const m: FileManager | null = this.fm; if (!m) return; for (let i: number = 0; i < ids.length; i++) m.deleteFile(ids[i]); this.reloadFiles() }

  doDelete(): void {
    const m: FileManager | null = this.fm; if (!m || !this.dlgId) return
    this.dlgDelete = false
    m.deleteFile(this.dlgId).then(() => {
      for (let i: number = this.tabs.length - 1; i >= 0; i--) {
        if (this.tabs[i].id === this.dlgId) { this.closeTab(i); break }
      }
      this.reloadFiles()
    })
  }

  doDeleteFolder(keepFiles: boolean): void {
    const m: FileManager | null = this.fm; if (!m || !this.dlgId) return
    this.dlgDeleteFolder = false
    m.deleteFolder(this.dlgId).then(() => {
      if (!keepFiles) { this.reloadFiles(); return }
      m.listFiles().then((fr: Result<NoteFile[], AppError>) => {
        if (!fr.isOk() || !fr.getValue()) return
        const fl: NoteFile[] = fr.getValue()!
        for (let i: number = 0; i < fl.length; i++) {
          if (fl[i].folderId === this.dlgId) m.moveFileToFolder(fl[i].id, null)
        }
        this.reloadFiles()
      })
    })
  }

  doCreateFile(name: string, folderId: string | null): void {
    const m: FileManager | null = this.fm; if (!m || !name) return
    m.createFile(name, '', folderId).then((r: Result<NoteFile, AppError>) => {
      if (r.isOk() && r.getValue()) { this.reloadFiles(); this.openFile(r.getValue()!.id) }
    })
  }
  doCreateFolder(name: string): void {
    const m: FileManager | null = this.fm; if (!m || !name) return
    m.createFolder(name).then(() => { this.reloadFiles() })
  }
  doMoveFile(fileId: string, folderId: string | null): void {
    const m: FileManager | null = this.fm; if (!m) return
    m.moveFileToFolder(fileId, folderId).then(() => { this.reloadFiles() })
  }
  doExport(): void {
    if (this.activeTabIdx < 0) return
    const tab: TabInfo = this.tabs[this.activeTabIdx]
    const ctx: Context | undefined = this.getUIContext()?.getHostContext()
    if (!ctx) return
    ExportService.exportMarkdown((tab.title || '未命名') + '.md', tab.content, ctx.filesDir)
  }
  doImport(): void {
    ImportService.pickAndRead().then((result: ImportResult) => {
      if (!result.success) return
      const m: FileManager | null = this.fm; if (!m) return
      m.createFile(result.fileName, result.content).then((r: Result<NoteFile, AppError>) => {
        if (r.isOk() && r.getValue()) { this.reloadFiles(); this.openFile(r.getValue()!.id) }
      })
    })
  }

  // ═══════════════════════════════════════════════════════
  //  §5 Markdown 预览 / 大纲
  // ═══════════════════════════════════════════════════════

  renderPreview(): void {
    if (this.activeTabIdx < 0) { this.tokens = []; this.previewReady = false; return }
    const tab: TabInfo = this.tabs[this.activeTabIdx]
    const r: Result<MarkdownToken[], Object> = this.ps.parse(tab.content)
    this.tokens = (r.isOk() && r.getValue()) ? r.getValue()! : []
    this.previewReady = true
    // 大纲: 提取所有 H 类型 token
    const oi: OItem[] = []
    for (let i: number = 0; i < this.tokens.length; i++) {
      if (this.tokens[i].type === TokenType.H) {
        let tx: string = ''
        for (let j: number = 0; j < this.tokens[i].kids.length; j++) tx += this.tokens[i].kids[j].t
        oi.push(new OItem(tx || ' ', this.tokens[i].lv))
      }
    }
    this.oitems = oi
  }

  toggleRight(panel: string): void {
    if (this.rightPanel === panel && this.rightVisible) { this.rightVisible = false; return }
    this.rightPanel = panel; this.rightVisible = true
    if (panel === 'preview' && !this.previewReady && this.activeTabIdx >= 0) this.renderPreview()
  }

  saveAndShow(panel: string): void {
    if (this.editorDirty && this.activeTabIdx >= 0) { this.saveCurrentTab() }
    else if (!this.previewReady && this.activeTabIdx >= 0) this.renderPreview()
    this.toggleRight(panel)
  }

  // ═══════════════════════════════════════════════════════
  //  §6 数据迁移
  // ═══════════════════════════════════════════════════════

  doMigration(): void {
    this.migrating = true
    const f: FileSystemManager | null = this.fsm; if (!f) return
    try {
      const ctx: Context | undefined = this.getUIContext()?.getHostContext()
      if (!ctx) return
      preferences.getPreferences(ctx, 'mxnote_file_store').then((pref: preferences.Preferences) => {
        const ij: string = pref.getSync('mxnote_file_index', '[]') as string
        const oi: OldIdx[] = JSON.parse(ij) as OldIdx[]
        const ent: Map<string, string> = new Map()
        for (let i: number = 0; i < oi.length; i++) {
          ent.set(oi[i].id, pref.getSync('mxnote_file_' + oi[i].id, '') as string)
        }
        const r: Result<number, AppError> = f.migrateFromPreferences(ij, ent)
        if (r.isOk()) { this.needMig = false; this.reloadFiles() } else { this.dlgMigErr = true }
        this.migrating = false
      })
    } catch (e) { this.dlgMigErr = true; this.migrating = false }
  }

  // ═══════════════════════════════════════════════════════
  //  §7 布局 + 拖拽
  // ═══════════════════════════════════════════════════════

  saveLayout(): void {
    const f: FileSystemManager | null = this.fsm; if (!f) return
    f.saveConfig({
      layout: {
        leftWidth: this.leftWidth, rightWidth: this.rightWidth,
        leftVisible: this.leftVisible, rightVisible: this.rightVisible
      }
    })
  }

  onLeftDragStart(): void { this.dragBaseLeft = this.leftWidth }
  onLeftDragUpdate(ev: GestureEvent): void {
    this.leftWidth = Math.max(LAYOUT.MIN_PANEL, Math.min(LAYOUT.MAX_PANEL, this.dragBaseLeft + ev.offsetX))
    this.saveLayout()
  }
  onRightDragStart(): void { this.dragBaseRight = this.rightWidth }
  onRightDragUpdate(ev: GestureEvent): void {
    this.rightWidth = Math.max(LAYOUT.MIN_PANEL, Math.min(LAYOUT.MAX_PANEL, this.dragBaseRight - ev.offsetX))
    this.saveLayout()
  }

  // ═══════════════════════════════════════════════════════
  //  §8 BUILD — 主界面渲染
  // ═══════════════════════════════════════════════════════

  build() {
    Stack() {
      Column() {
        // ── 顶部栏 ──
        TitleBar({
          searchQuery: $searchQuery,
          leftVisible: this.leftVisible,
          onSearchChange: (v: string): void => {
            this.searchQuery = v
            if (this.searchTimer >= 0) clearTimeout(this.searchTimer)
            this.searchTimer = setTimeout(() => { this.applyFilter() }, LAYOUT.SEARCH_DEBOUNCE)
          },
          onLeftToggle: (): void => { this.leftVisible = !this.leftVisible; this.saveLayout() },
          onAiClick: (): void => { this.toggleRight('ai') },
          onLogoSettings: (): void => { this.dlgSettings = true }
        })

        Divider().color(ThemeColors.colorBorderSubtle).height(1)

        // ── 三面板主区域 ──
        Row() {
          // ══ 左面板 ═════════════════════════════════════
          if (this.leftVisible) {
            FileTreePanel({
              files: $filteredFiles, folders: $folders, activeId: $activeId,
              loading: $loading, searchQuery: $searchQuery,
              onFileOpen: (id: string): void => { this.openFile(id) },
              onFileRename: (id: string, newTitle: string): void => { this.onFileRename(id, newTitle) },
              onFileDelete: (id: string, title: string): void => { this.onFileDelete(id, title) },
              onFileBatchDelete: (ids: string[]): void => { this.onBatchDelete(ids) },
              onFolderRename: (id: string, newName: string): void => { this.onFolderRename(id, newName) },
              onFolderDelete: (id: string, name: string): void => { this.onFolderDelete(id, name) },
              onFileMove: (fileId: string, folderId: string | null): void => { this.doMoveFile(fileId, folderId) },
              onFileCreate: (name: string, folderId: string | null): void => { this.doCreateFile(name, folderId) },
              onFolderCreate: (name: string): void => { this.doCreateFolder(name) },
              onImportClick: (): void => { this.doImport() }
            })
            .width(this.leftWidth).height('100%')
            .border({ width: { right: 1 }, color: ThemeColors.colorBorderSubtle })
          }

          // 左分隔条
          if (this.leftVisible) {
            Column().width(LAYOUT.DIVIDER_W).height('100%')
              .backgroundColor(this.leftDividerHover ? ThemeColors.colorAccentBlue : '#d0d0d0')
              .onHover((isHover: boolean) => { this.leftDividerHover = isHover })
              .gesture(PanGesture({ direction: PanDirection.Horizontal })
                .onActionStart((): void => { this.onLeftDragStart() })
                .onActionUpdate((ev: GestureEvent): void => { this.onLeftDragUpdate(ev) }))
          }

          // ══ 中编辑区 ═══════════════════════════════════
          Column() {
            if (this.activeTabIdx >= 0 && this.tabs.length > 0 && this.activeTabIdx < this.tabs.length) {
              // ── 多标签栏（双击内联重命名） ──
              Scroll() {
                Row({ space: 0 }) {
                  ForEach(this.tabs, (t: TabInfo, idx: number) => {
                    Row() {
                      if (this.renameTabId === t.id) {
                        TextInput({ text: $$this.renameTabText, placeholder: '' })
                          .fontSize(12).fontColor(ThemeColors.colorTextPrimary).height(28).width(100)
                          .onSubmit(() => { this.commitTabRename() })
                        Text('✓').fontSize(12).fontColor(ThemeColors.colorAccentGreen)
                          .padding({ left: 4, right: 4 }).onClick(() => { this.commitTabRename() })
                      } else {
                        if (t.dirty) {
                          Text('●').fontSize(8).fontColor(ThemeColors.colorAccentYellow).margin({ right: 4 })
                        }
                        Text(t.title).fontSize(12)
                          .fontColor(idx === this.activeTabIdx ? ThemeColors.colorTextPrimary : ThemeColors.colorTextSecondary)
                          .maxLines(1).constraintSize({ maxWidth: 140 })
                        Text(' ✕').fontSize(10).fontColor(ThemeColors.colorTextTertiary).margin({ left: 4 })
                          .onClick(() => { this.closeTab(idx) })
                      }
                    }
                    .padding({ left: 12, right: 8, top: 8, bottom: 8 })
                    .backgroundColor(idx === this.activeTabIdx ? ThemeColors.colorBgCanvas : '#00000000')
                    .border({ width: { bottom: idx === this.activeTabIdx ? 2 : 0 }, color: ThemeColors.colorAccentBlue })
                    .onClick(() => {
                      if (this.renameTabId === t.id) return
                      this.switchTab(idx, t.id, t.title, t.dirty, t.content.length)
                    })
                    .gesture(TapGesture({ count: 2 }).onAction(() => {
                      if (this.renameTabId !== t.id) {
                        this.renameTabId = t.id; this.renameTabText = t.title
                      }
                    }))
                  }, (t: TabInfo, idx: number): string => 'tab_' + t.id)
                }.height(LAYOUT.TAB_H)
              }
              .width('100%')
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .backgroundColor(ThemeColors.colorBgSurface)
              .border({ width: { bottom: 1 }, color: ThemeColors.colorBorderSubtle })
              .align(Alignment.Start)

              // ── 编辑器 ──
              if (this.tabs[this.activeTabIdx]) {
                EditorArea({
                  fontSize: this.fontSize,
                  content: this.tabs[this.activeTabIdx].content,
                  onChange: (v: string): void => { this.onEditorChange(v) }
                })
              }

              // ── 底部统计栏 ──
              Row() {
                Text(this.charCount.toString() + ' 字').fontSize(11).fontColor(ThemeColors.colorTextTertiary)
                Text(' · ').fontSize(11).fontColor(ThemeColors.colorBorderDefault)
                Text(this.editorDirty ? '已修改' : '已保存').fontSize(11)
                  .fontColor(this.editorDirty ? ThemeColors.colorAccentYellow : ThemeColors.colorAccentGreen)
                Text(' · ').fontSize(11).fontColor(ThemeColors.colorBorderDefault)
                Text('保存').fontSize(11).fontColor(ThemeColors.colorAccentBlue)
                  .onClick(() => { this.saveCurrentTab() })
                Blank()
                Text('导出').fontSize(11).fontColor(ThemeColors.colorTextSecondary).onClick(() => { this.doExport() })
                Text(' · ').fontSize(11).fontColor(ThemeColors.colorBorderDefault)
                Text('预览').fontSize(11).fontColor(ThemeColors.colorAccentBlue).onClick(() => { this.saveAndShow('preview') })
                Text(' · ').fontSize(11).fontColor(ThemeColors.colorBorderDefault)
                Text('大纲').fontSize(11).fontColor(ThemeColors.colorAccentBlue).onClick(() => { this.saveAndShow('outline') })
              }
              .width('100%')
              .height(LAYOUT.FOOTER_H)
              .padding({ left: 16, right: 16 })
              .backgroundColor(ThemeColors.colorBgSurface)
              .border({ width: { top: 1 }, color: ThemeColors.colorBorderSubtle })
            } else {
              // 空状态
              Column() {
                Image(IconConstants.IC_NOTE).width(48).height(48)
                  .fillColor(ThemeColors.colorBorderDefault).margin({ bottom: 12 })
                Text('选择或新建笔记开始编辑').fontSize(13).fontColor(ThemeColors.colorTextSecondary)
              }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
              .backgroundColor(ThemeColors.colorBgCanvas)
            }
          }.layoutWeight(1).height('100%').backgroundColor(ThemeColors.colorBgCanvas)

          // 右分隔条
          if (this.rightVisible) {
            Column().width(LAYOUT.DIVIDER_W).height('100%')
              .backgroundColor(this.rightDividerHover ? ThemeColors.colorAccentBlue : '#d0d0d0')
              .onHover((isHover: boolean) => { this.rightDividerHover = isHover })
              .gesture(PanGesture({ direction: PanDirection.Horizontal })
                .onActionStart((): void => { this.onRightDragStart() })
                .onActionUpdate((ev: GestureEvent): void => { this.onRightDragUpdate(ev) }))
          }

          // ══ 右面板: 预览 / 大纲 / AI ═══════════════════════
          if (this.rightVisible) {
            if (this.rightPanel === 'outline') { this.BuildOutline() }
            else if (this.rightPanel === 'preview') { this.BuildPreview() }
            else { this.BuildAi() }
          }
        }.width('100%').layoutWeight(1)
      }.width('100%').height('100%').backgroundColor(ThemeColors.colorBgCanvas)

      // ══ 对话框层 ═══════════════════════════════════════
      if (this.dlgDelete) {
        DlgConfirm({
          title: '确认删除', message: '"' + this.dlgTitle + '" 将被永久删除',
          confirmLabel: '删除', confirmColor: ThemeColors.colorAccentRed,
          onConfirm: (): void => { this.doDelete() },
          onCancel: (): void => { this.dlgDelete = false }
        })
      }
      if (this.dlgDeleteFolder) {
        Column() {
          Column() {
            Text('删除文件夹').fontSize(18).fontWeight(FontWeight.Bold)
              .fontColor(ThemeColors.colorTextPrimary).margin({ bottom: 6 }).width('100%')
            Text('文件夹"' + this.dlgTitle + '"中的文件如何处理？')
              .fontSize(14).fontColor(ThemeColors.colorTextSecondary).margin({ bottom: 20 }).width('100%')
            Row() {
              Text('保留文件').fontSize(14).fontColor(ThemeColors.colorAccentBlue).textAlign(TextAlign.Center)
                .width('45%').height(44).backgroundColor(ThemeColors.colorBgHover).borderRadius(20)
                .onClick(() => { this.doDeleteFolder(true) })
              Text('全部删除').fontSize(14).fontColor('#ffffff').textAlign(TextAlign.Center)
                .width('45%').height(44).backgroundColor(ThemeColors.colorAccentRed).borderRadius(20).margin({ left: 12 })
                .onClick(() => { this.doDeleteFolder(false) })
            }.width('100%').justifyContent(FlexAlign.Center)
            Text('取消').fontSize(14).fontColor(ThemeColors.colorTextTertiary).textAlign(TextAlign.Center).margin({ top: 12 })
              .onClick(() => { this.dlgDeleteFolder = false })
          }.padding(24).backgroundColor(Color.White).borderRadius(24).width(340)
          .shadow({ radius: 32, color: '#0000001A', offsetY: 8 })
        }.width('100%').height('100%').backgroundColor('#00000033').justifyContent(FlexAlign.Center)
        .onClick(() => { this.dlgDeleteFolder = false })
      }
      if (this.dlgMigErr) {
        DlgMigrationError({
          onRetry: (): void => { this.dlgMigErr = false; this.doMigration() },
          onSkip: (): void => { this.dlgMigErr = false; this.needMig = false }
        })
      }
      if (this.migrating) {
        Column() {
          LoadingProgress().width(28).height(28).color(ThemeColors.colorAccentBlue)
          Text('迁移中...').fontSize(13).fontColor(ThemeColors.colorTextSecondary).margin({ top: 10 })
        }.width('100%').height('100%').backgroundColor(ThemeColors.colorBgOverlay).justifyContent(FlexAlign.Center)
      }
      if (this.dlgSettings) {
        SettingsDialog({
          fontSize: $fontSize, showLogin: $dlgLogin,
          onClose: (): void => { this.dlgSettings = false },
          onFontPlus: (): void => { if (this.fontSize < 32) this.fontSize += 1 },
          onFontMinus: (): void => { if (this.fontSize > 10) this.fontSize -= 1 }
        })
      }
      if (this.dlgLogin) { LoginDialog({ onClose: (): void => { this.dlgLogin = false } }) }
    }.width('100%').height('100%')
  }

  // ═══════════════════════════════════════════════════════
  //  §9 @Builder — 预览 / 表格 / 大纲 / AI
  // ═══════════════════════════════════════════════════════

  @Builder BuildPreview() {
    Column() {
      Row() {
        Text('预览').fontSize(12).fontWeight(FontWeight.Bold).fontColor(ThemeColors.colorTextPrimary)
        Blank()
        Text('✕').fontSize(14).fontColor(ThemeColors.colorTextTertiary)
          .onClick(() => { this.rightVisible = false; this.saveLayout() })
      }.width('100%').padding({ left: 10, right: 6, top: 8, bottom: 5 })
      .border({ width: { bottom: 1 }, color: ThemeColors.colorBorderSubtle })

      if (this.activeTabIdx >= 0 && this.tabs.length > 0 && this.activeTabIdx < this.tabs.length) {
        // ── @luvi/lv-markdown-in 原生渲染引擎 ──
        LvMarkdownIn({ text: this.tabs[this.activeTabIdx].content })
          .width('100%').layoutWeight(1)
      } else {
        Text('打开文件后自动预览').fontSize(11).fontColor(ThemeColors.colorTextTertiary)
          .width('100%').padding(10)
      }
    }.width(this.rightWidth).height('100%').backgroundColor('#fafbfc')
    .border({ width: { left: 1 }, color: ThemeColors.colorBorderSubtle })
  }


  @Builder BuildOutline() {
    Column() {
      Row() {
        Text('大纲').fontSize(12).fontWeight(FontWeight.Bold).fontColor(ThemeColors.colorTextPrimary)
        Blank()
        Text('✕').fontSize(14).fontColor(ThemeColors.colorTextTertiary)
          .onClick(() => { this.rightVisible = false; this.saveLayout() })
      }.width('100%').padding({ left: 10, right: 6, top: 8, bottom: 5 })
      .border({ width: { bottom: 1 }, color: ThemeColors.colorBorderSubtle })
      Scroll() {
        Column() {
          if (this.oitems.length === 0) {
            Text('暂无标题').fontSize(11).fontColor(ThemeColors.colorTextTertiary).width('100%').padding(10)
          } else {
            ForEach(this.oitems, (it: OItem) => {
              Text(it.text).fontSize(13).fontColor(ThemeColors.colorTextSecondary)
                .padding({ left: (it.lv - 1) * 14 + 10, top: 5, bottom: 5 }).maxLines(1).width('100%')
            }, (it: OItem): string => 'oi_' + it.text + '_' + it.lv.toString())
          }
        }.width('100%').padding(10)
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
    }.width(this.rightWidth).height('100%').backgroundColor('#fafbfc')
    .border({ width: { left: 1 }, color: ThemeColors.colorBorderSubtle })
  }

  @Builder BuildAi() {
    Column() {
      Row() {
        Text('AI 对话').fontSize(12).fontWeight(FontWeight.Bold).fontColor(ThemeColors.colorTextPrimary)
        Blank()
        Text('✕').fontSize(14).fontColor(ThemeColors.colorTextTertiary)
          .onClick(() => { this.rightVisible = false; this.saveLayout() })
      }.width('100%').padding({ left: 10, right: 6, top: 8, bottom: 5 })
      .border({ width: { bottom: 1 }, color: ThemeColors.colorBorderSubtle })
      Column() {
        Image(IconConstants.IC_CHAT).width(42).height(42).fillColor(ThemeColors.colorBorderDefault).margin({ bottom: 14 })
        Text('AI 对话 · 即将上线').fontSize(14).fontWeight(FontWeight.Medium).fontColor(ThemeColors.colorTextSecondary)
        Text('基于笔记内容的智能助手').fontSize(11).fontColor(ThemeColors.colorTextTertiary).margin({ top: 4 })
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    }.width(this.rightWidth).height('100%').backgroundColor('#fafbfc')
    .border({ width: { left: 1 }, color: ThemeColors.colorBorderSubtle })
  }

  // ═══════════════════════════════════════════════════════
  //  §10 工具函数
  // ═══════════════════════════════════════════════════════

  fmtRel(ms: number): string {
    const d: number = Date.now() - ms
    if (d < 60000) return '刚刚'
    if (d < 3600000) return Math.floor(d / 60000) + ' 分钟前'
    if (d < 86400000) return Math.floor(d / 3600000) + ' 小时前'
    return formatTime(ms)
  }
}
