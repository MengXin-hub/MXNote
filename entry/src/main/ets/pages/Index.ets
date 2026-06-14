/**
 * MXNote — 纯 Markdown 笔记, 可拖拽分栏。
 * 三面板: 左列表 | 中编辑 | 右预览(可拖拽调整宽度)
 */
import { KeyCode } from '@kit.InputKit'
import { FileManager } from '../core/FileManager'
import { NoteFile, formatTime } from '../model/NoteFile'
import { MarkdownParser, MarkdownToken, TokenType, InlineSpan } from '../core/MarkdownParser'

class Snap { text: string = ''; constructor(t: string) { this.text = t } }
class OItem { text: string = ''; lv: number = 0; constructor(t: string, l: number) { this.text = t; this.lv = l } }

const MIN_PX: number = 180
const MAX_PX: number = 480

@Entry
@Component
struct Index {
  @State files: NoteFile[] = []
  @State query: string = ''
  @State flt: NoteFile[] = []
  @State aid: string = ''
  @State atitle: string = ''
  @State modT: number = 0
  @State loading: boolean = true

  @State text: string = ''
  @State tk: MarkdownToken[] = []
  @State wc: number = 0

  @State sw: number = 240       // sidebar width px
  @State rw: number = 300       // right panel width px
  @State sideOn: boolean = true // sidebar visible
  @State previewOn: boolean = true // preview visible
  @State outlineOn: boolean = false // outline mode
  @State oitems: OItem[] = []
  @State msg: string = ''
  @State dlgNew: boolean = false
  @State dlgRename: boolean = false
  @State dlgDelete: boolean = false
  @State dlgSettings: boolean = false
  @State dlgKeys: boolean = false
  @State fontSize: number = 15

  private fm: FileManager | null = null
  private ps: MarkdownParser = new MarkdownParser()
  private un: Snap[] = []
  private re: Snap[] = []
  private tmpNew: string = ''
  private tmpRen: string = ''
  private delTgt: NoteFile | null = null
  private renTgt: NoteFile | null = null
  private parseTmr: number = -1
  private dragW0: number = 0

  aboutToAppear(): void {
    const c: UIContext | undefined = this.getUIContext()
    const h: Context | undefined = c ? c.getHostContext() : undefined
    if (h) { this.fm = new FileManager(h); this.loadList() }
  }
  aboutToDisappear(): void { if (this.parseTmr !== -1) clearTimeout(this.parseTmr) }
  onPageShow(): void { this.loadList() }

  async loadList(): Promise<void> {
    const m: FileManager | null = this.fm; if (!m) return
    this.loading = true; await m.init()
    const r = await m.listFiles()
    if (r.isOk() && r.getValue()) { this.files = r.getValue()!; this.doFl() }
    this.loading = false
  }

  doFl(): void {
    const q: string = this.query.trim().toLowerCase()
    if (!q) { this.flt = this.files; return }
    const o: NoteFile[] = []
    for (let i: number = 0; i < this.files.length; i++) {
      if (this.files[i].title.toLowerCase().indexOf(q) >= 0) o.push(this.files[i])
    }
    this.flt = o
  }

  onQ(v: string): void { this.query = v; this.doFl() }

  async openNote(f: NoteFile): Promise<void> {
    const m: FileManager | null = this.fm; if (!m) return
    const r = await m.readFile(f.id)
    if (r.isOk() && r.getValue()) {
      const d: NoteFile = r.getValue()!
      this.aid = d.id; this.atitle = d.title; this.modT = d.modifiedAt
      this.text = d.content; this.wc = d.content.length
      this.un = []; this.re = []; this.doParse()
    }
  }

  // ══ editor ═══════════════════════════════════════

  onChange(v: string): void {
    if (v !== this.text) { this.un.push(new Snap(this.text)); if (this.un.length > 100) this.un.splice(0, 1); this.re = [] }
    this.text = v; this.wc = v.length; this.scheduleParse()
  }

  scheduleParse(): void {
    if (this.parseTmr !== -1) clearTimeout(this.parseTmr)
    this.parseTmr = setTimeout((): void => { this.parseTmr = -1; this.doParse() }, 350)
  }

  doParse(): void {
    const r = this.ps.parse(this.text)
    this.tk = (r.isOk() && r.getValue()) ? r.getValue()! : []
  }

  doOutline(): void {
    const its: OItem[] = []
    const r = this.ps.parse(this.text)
    if (r.isOk() && r.getValue()) {
      const ts: MarkdownToken[] = r.getValue()!
      for (let i: number = 0; i < ts.length; i++) {
        const t: MarkdownToken = ts[i]
        if (t.type === TokenType.H) {
          let tx: string = ''
          for (let j: number = 0; j < t.kids.length; j++) tx += t.kids[j].t
          its.push(new OItem(tx || ' ', t.lv))
        }
      }
    }
    this.oitems = its
  }

  doUndo(): void {
    if (this.un.length === 0) return
    this.re.push(new Snap(this.text)); const s: Snap = this.un.pop()!; this.text = s.text; this.wc = s.text.length; this.doParse()
  }
  doRedo(): void {
    if (this.re.length === 0) return
    this.un.push(new Snap(this.text)); const s: Snap = this.re.pop()!; this.text = s.text; this.wc = s.text.length; this.doParse()
  }

  // ══ keyboard ══════════════════════════════════════

  onKey(e: KeyEvent): void {
    if (e.keyCode === KeyCode.KEYCODE_S) { this.save() }
    if (e.keyCode === KeyCode.KEYCODE_Z) { this.doUndo() }
    if (e.keyCode === KeyCode.KEYCODE_Y) { this.doRedo() }
  }

  // ══ actions ═══════════════════════════════════════

  async save(): Promise<void> {
    const m: FileManager | null = this.fm; if (!m || !this.aid) return
    await m.saveFile(this.aid, this.atitle, this.text); this.modT = Date.now(); this.msg = '已保存'
    setTimeout((): void => { this.msg = '' }, 2000); this.loadList()
  }

  async doNew(): Promise<void> {
    const m: FileManager | null = this.fm; if (!m || this.tmpNew.trim().length === 0) return
    const r = await m.createFile(this.tmpNew.trim(), ''); this.dlgNew = false
    if (r.isOk() && r.getValue()) { const f: NoteFile = r.getValue()!; this.aid = f.id; this.atitle = f.title; this.modT = f.modifiedAt; this.text = ''; this.tk = []; this.wc = 0; this.un = []; this.re = []; await this.loadList() }
  }

  async doRename(): Promise<void> {
    const m: FileManager | null = this.fm; const t: NoteFile | null = this.renTgt
    if (!m || !t || this.tmpRen.trim().length === 0) return
    await m.renameFile(t.id, this.tmpRen.trim()); this.dlgRename = false
    if (this.aid === t.id) this.atitle = this.tmpRen.trim()
    await this.loadList()
  }

  async doDelete(): Promise<void> {
    const m: FileManager | null = this.fm; const t: NoteFile | null = this.delTgt
    if (!m || !t) return; await m.deleteFile(t.id); this.dlgDelete = false; this.delTgt = null
    if (this.aid === t.id) { this.aid = ''; this.text = ''; this.tk = [] }
    await this.loadList()
  }

  // ══ drag ══════════════════════════════════════════

  onDragLeft(ev: GestureEvent): void { const w: number = this.dragW0 + ev.offsetX; this.sw = Math.max(MIN_PX, Math.min(MAX_PX, w)) }
  onDragRight(ev: GestureEvent): void { const w: number = this.dragW0 - ev.offsetX; this.rw = Math.max(MIN_PX, Math.min(MAX_PX, w)) }

  // ══ build ═════════════════════════════════════════

  build() {
    Stack() {
      Column() {
        this.Toolbar()
        Divider().color('#e5e7eb')
        this.Main()
        Divider().color('#e5e7eb')
        this.Footer()
      }.width('100%').height('100%').backgroundColor('#ffffff')

      if (this.dlgNew) this.Dialog('新建笔记', this.tmpNew, '标题', (v: string): void => { this.tmpNew = v }, (): void => { this.doNew() }, (): void => { this.dlgNew = false })
      if (this.dlgRename) this.Dialog('重命名', this.tmpRen, '新标题', (v: string): void => { this.tmpRen = v }, (): void => { this.doRename() }, (): void => { this.dlgRename = false })
      if (this.dlgDelete) this.DlgDelete()
      if (this.dlgSettings) this.DlgSettings()
      if (this.dlgKeys) this.DlgKeys()
    }.width('100%').height('100%')
  }

  @Builder Toolbar() {
    Row() {
      this.Btn('📝', '新建', (): void => { this.tmpNew = ''; this.dlgNew = true })
      this.Btn('💾', '保存', (): void => { this.save() })
      if (this.aid) {
        this.Btn('↩', '撤销', (): void => { this.doUndo() })
        this.Btn('↪', '重做', (): void => { this.doRedo() })
        this.Btn('✎', '重命名', (): void => { this.renTgt = new NoteFile(this.aid, this.atitle, '', 0, 0); this.tmpRen = this.atitle; this.dlgRename = true })
        this.Btn('🗑', '删除', (): void => { this.delTgt = new NoteFile(this.aid, this.atitle, '', 0, 0); this.dlgDelete = true })
      }
      TextInput({ placeholder: '搜索...' }).fontSize(13).fontColor('#111827').placeholderColor('#9ca3af').backgroundColor('#f3f4f6').borderRadius(10).height(38).layoutWeight(1).padding({ left: 12 }).onChange((v: string): void => { this.onQ(v) })
      this.Btn('☰', '列表', (): void => { this.sideOn = !this.sideOn })
      this.Btn('◫', '预览', (): void => { this.previewOn = !this.previewOn; if (this.previewOn) { this.outlineOn = false; this.doParse() } })
    }.width('100%').padding({ left: 4, right: 4, top: 8, bottom: 6 })
  }

  @Builder Btn(icon: string, label: string, cb: () => void) {
    Button() { Column() { Text(icon).fontSize(17); Text(label).fontSize(9).fontColor('#6b7280').margin({ top: 1 }) } }
      .backgroundColor('#00000000').borderRadius(8).padding({ left: 6, right: 6 }).height(46).onClick(cb).margin({ left: 2, right: 2 })
  }

  @Builder Main() {
    Row() {
      if (this.sideOn) {
        this.LeftSidebar()
        Column().width(6).height('100%').backgroundColor('#e5e7eb')
          .gesture(PanGesture({ direction: PanDirection.Horizontal })
            .onActionStart((ev: GestureEvent): void => { this.dragW0 = this.sw })
            .onActionUpdate((ev: GestureEvent): void => { this.onDragLeft(ev) }))
      }
      this.CenterEditor()
      if (this.previewOn) {
        Column().width(6).height('100%').backgroundColor('#e5e7eb')
          .gesture(PanGesture({ direction: PanDirection.Horizontal })
            .onActionStart((ev: GestureEvent): void => { this.dragW0 = this.rw })
            .onActionUpdate((ev: GestureEvent): void => { this.onDragRight(ev) }))
        if (this.outlineOn) { this.OutlinePanel() } else { this.RightPanel() }
      }
    }.width('100%').layoutWeight(1)
  }

  @Builder LeftSidebar() {
    Column() {
      if (this.loading) { Column() { LoadingProgress().width(24).height(24).color('#3b82f6') }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center) }
      else if (this.flt.length === 0) { Column() { Text('无笔记').fontSize(13).fontColor('#9ca3af') }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center) }
      else {
        List() {
          ForEach(this.flt, (f: NoteFile) => {
            ListItem() {
              Row() {
                Column() { Text(f.title || '未命名').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.aid === f.id ? '#3b82f6' : '#111827').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); Text(formatTime(f.modifiedAt)).fontSize(10).fontColor('#9ca3af').margin({ top: 2 }) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%').padding({ left: 14, right: 10, top: 10, bottom: 10 }).backgroundColor(this.aid === f.id ? '#eff6ff' : '#00000000').border({ width: { left: this.aid === f.id ? 3 : 0 }, color: '#3b82f6' })
              .onClick((): void => { this.openNote(f) })
            }
          }, (f: NoteFile): string => f.id)
        }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
      }
    }.width(this.sw).height('100%').backgroundColor('#f9fafb').clip(true)
  }

  @Builder CenterEditor() {
    Column() {
      if (this.aid) { Row() { Text(this.atitle).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#111827').maxLines(1).layoutWeight(1) }.width('100%').padding({ left: 12, right: 12, top: 6, bottom: 4 }); Divider().color('#f3f4f6') }
      TextArea({ text: this.text, placeholder: '# Markdown\n\n写作...' }).width('100%').layoutWeight(1).backgroundColor('#ffffff').fontSize(this.fontSize).fontColor('#111827').fontFamily('monospace').padding(16).borderRadius(0).caretColor('#3b82f6').onChange((v: string): void => { this.onChange(v) }).onKeyEvent((e: KeyEvent): void => { this.onKey(e) })
    }.layoutWeight(1).height('100%').backgroundColor('#ffffff')
  }

  // ══ preview ════════════════════════════════════════

  @Builder RightPanel() {
    Column() {
      Row() { Text('预览').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#111827'); Blank(); Text(this.wc.toString() + ' 字').fontSize(11).fontColor('#9ca3af') }.width('100%').padding({ left: 12, right: 10, top: 8, bottom: 6 }).border({ width: { bottom: 1 }, color: '#e5e7eb' })
      Scroll() {
        Column() {
          if (this.tk.length === 0) { Text('输入 Markdown 自动预览').fontSize(12).fontColor('#9ca3af').width('100%').padding(12) }
          else { ForEach(this.tk, (t: MarkdownToken, i: number) => { this.Block(t, i) }, (t: MarkdownToken, i: number): string => 'b_' + i.toString()) }
        }.width('100%').padding(12)
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
    }.width(this.rw).height('100%').backgroundColor('#fafbfc').clip(true)
  }

  @Builder Block(t: MarkdownToken, i: number) {
    if (t.type === TokenType.H) { Text(t.kids.map((s: InlineSpan): string => s.t).join('')).fontSize(Math.max(14, 26 - t.lv * 3)).fontWeight(FontWeight.Bold).fontColor('#111827').padding({ top: 10, bottom: 2 }).width('100%') }
    else if (t.type === TokenType.C) { Text(t.raw).fontSize(12).fontColor('#374151').fontFamily('monospace').padding(12).width('100%').backgroundColor('#f1f5f9').borderRadius(6).margin({ top: 6, bottom: 6 }) }
    else if (t.type === TokenType.Q) { Text(t.raw).fontSize(14).fontColor('#6b7280').fontStyle(FontStyle.Italic).width('100%').border({ width: { left: 3 }, color: '#10b981' }).padding({ left: 12 }).margin({ top: 6, bottom: 6 }) }
    else if (t.type === TokenType.HR) { Divider().color('#e5e7eb').margin({ top: 14, bottom: 14 }).width('100%') }
    else if (t.type === TokenType.UL || t.type === TokenType.OL) { Column() { ForEach(t.kids, (it: InlineSpan, j: number) => { Row() { Text(t.type === TokenType.OL ? (j + 1).toString() + '.' : '•').fontSize(14).fontColor('#6b7280').width(24); Text(it.t).fontSize(14).fontColor('#374151') }.width('100%').padding({ top: 2, bottom: 2 }) }, (it: InlineSpan, j: number): string => 'li_' + i.toString() + '_' + j.toString()) }.width('100%').margin({ top: 4, bottom: 4 }) }
    else { Row() { ForEach(t.kids, (s: InlineSpan, idx: number) => { if (s.c) { Text(s.t).fontSize(14).fontColor('#7c3aed').fontFamily('monospace').backgroundColor('#f1f5f9').borderRadius(3).padding({ left: 4, right: 4, top: 2, bottom: 2 }) } else if (s.b && s.i) { Text(s.t).fontSize(14).fontColor('#111827').fontWeight(FontWeight.Bold).fontStyle(FontStyle.Italic) } else if (s.b) { Text(s.t).fontSize(14).fontColor('#111827').fontWeight(FontWeight.Bold) } else if (s.i) { Text(s.t).fontSize(14).fontColor('#374151').fontStyle(FontStyle.Italic) } else { Text(s.t).fontSize(14).fontColor('#374151') } }, (s: InlineSpan, idx: number): string => 'is_' + i.toString() + '_' + idx.toString()) }.width('100%').padding({ top: 4, bottom: 4 }) }
  }

  // ══ outline ═══════════════════════════════════════

  @Builder OutlinePanel() {
    Column() {
      Row() { Text('大纲').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#111827'); Blank(); Button('×').fontSize(14).fontColor('#6b7280').backgroundColor('#00000000').width(28).height(28).onClick((): void => { this.outlineOn = false }) }.width('100%').padding({ left: 12, right: 8, top: 8, bottom: 6 }).border({ width: { bottom: 1 }, color: '#e5e7eb' })
      Scroll() {
        Column() {
          if (this.oitems.length === 0) { Text('点击底部"大纲"按钮生成').fontSize(12).fontColor('#9ca3af').width('100%').padding(12) }
          else { ForEach(this.oitems, (it: OItem) => { Text(it.text).fontSize(13).fontColor('#374151').padding({ left: (it.lv - 1) * 14 + 8, top: 4, bottom: 4 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%') }, (it: OItem): string => 'oi_' + it.text + '_' + it.lv.toString()) }
        }.width('100%').padding(8)
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
    }.width(this.rw).height('100%').backgroundColor('#fafbfc').clip(true)
  }

  // ══ footer ════════════════════════════════════════

  @Builder Footer() {
    Row() {
      Text(String(this.files.length) + ' 篇').fontSize(11).fontColor('#6b7280')
      Blank()
      if (this.aid) { Text(this.msg || '编辑中').fontSize(11).fontColor(this.msg ? '#3b82f6' : '#9ca3af'); Text('  ·  ').fontSize(11).fontColor('#d1d5db') }
      Text(this.wc.toString() + ' 字').fontSize(11).fontColor('#6b7280')
      Text('  ·  ').fontSize(11).fontColor('#d1d5db')
      Text('大纲').fontSize(11).fontColor('#3b82f6').onClick((): void => { this.outlineOn = !this.outlineOn; this.previewOn = true; if (this.outlineOn) this.doOutline() })
      Text('  ·  ').fontSize(11).fontColor('#d1d5db')
      Text('设置').fontSize(11).fontColor('#3b82f6').onClick((): void => { this.dlgSettings = true })
      Text('  ·  ').fontSize(11).fontColor('#d1d5db')
      Text('快捷键').fontSize(11).fontColor('#3b82f6').onClick((): void => { this.dlgKeys = true })
    }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 }).backgroundColor('#f3f4f6')
  }

  // ══ dialogs ═══════════════════════════════════════

  @Builder Dialog(title: string, txt: string, ph: string, ch: (v: string) => void, ok: () => void, cancel: () => void) {
    Column() {
      Column() {
        Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827').margin({ bottom: 14 })
        TextInput({ text: txt, placeholder: ph }).fontSize(14).fontColor('#111827').placeholderColor('#9ca3af').backgroundColor('#fff').border({ width: 1, color: '#d1d5db', radius: 8 }).padding(12).onChange(ch)
        Row() { Button('取消').fontSize(13).backgroundColor('#e5e7eb').fontColor('#374151').borderRadius(8).width('48%').onClick(cancel); Button('确认').fontSize(13).backgroundColor('#3b82f6').fontColor('#fff').borderRadius(8).width('48%').margin({ left: 12 }).onClick(ok) }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 18 })
      }.padding(24).backgroundColor('#fff').borderRadius(14).width('85%').border({ width: 1, color: '#e5e7eb' }).shadow({ radius: 16, color: '#00000010' })
    }.width('100%').height('100%').backgroundColor('#00000030').justifyContent(FlexAlign.Center).onClick(cancel)
  }

  @Builder DlgDelete() {
    Column() {
      Column() {
        Text('删除').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827').margin({ bottom: 6 }); Text(this.delTgt ? '"' + this.delTgt.title + '" 将被永久删除' : '').fontSize(13).fontColor('#6b7280').margin({ bottom: 18 })
        Row() { Button('取消').fontSize(13).backgroundColor('#e5e7eb').fontColor('#374151').borderRadius(8).width('48%').onClick((): void => { this.dlgDelete = false }); Button('删除').fontSize(13).backgroundColor('#ef4444').fontColor('#fff').borderRadius(8).width('48%').margin({ left: 12 }).onClick((): void => { this.doDelete() }) }.width('100%').justifyContent(FlexAlign.Center)
      }.padding(24).backgroundColor('#fff').borderRadius(14).width('85%').border({ width: 1, color: '#e5e7eb' }).shadow({ radius: 16, color: '#00000010' })
    }.width('100%').height('100%').backgroundColor('#00000030').justifyContent(FlexAlign.Center).onClick((): void => { this.dlgDelete = false })
  }

  @Builder DlgSettings() {
    Column() {
      Column() {
        Row() { Text('设置').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827'); Blank(); Button('×').fontSize(18).fontColor('#6b7280').backgroundColor('#00000000').width(32).height(32).onClick((): void => { this.dlgSettings = false }) }.width('100%').margin({ bottom: 16 })
        Text('编辑器字体大小').fontSize(13).fontColor('#6b7280').margin({ bottom: 8 }).width('100%')
        Row() { Button('-').fontSize(14).backgroundColor('#e5e7eb').fontColor('#374151').borderRadius(6).width(36).height(36).onClick((): void => { if (this.fontSize > 10) this.fontSize = this.fontSize - 1 }); Text(this.fontSize.toString()).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111827').margin({ left: 12, right: 12 }); Button('+').fontSize(14).backgroundColor('#e5e7eb').fontColor('#374151').borderRadius(6).width(36).height(36).onClick((): void => { if (this.fontSize < 28) this.fontSize = this.fontSize + 1 }) }.width('100%').justifyContent(FlexAlign.Center)
        Text('调整编辑区字号 (10~28). 修改后立即生效.').fontSize(11).fontColor('#9ca3af').margin({ top: 8 })
        Divider().color('#e5e7eb').margin({ top: 14, bottom: 14 })
        Button('关闭').fontSize(13).backgroundColor('#e5e7eb').fontColor('#374151').borderRadius(8).width('100%').height(40).onClick((): void => { this.dlgSettings = false })
      }.padding(24).backgroundColor('#fff').borderRadius(14).width('85%').border({ width: 1, color: '#e5e7eb' }).shadow({ radius: 16, color: '#00000010' })
    }.width('100%').height('100%').backgroundColor('#00000030').justifyContent(FlexAlign.Center).onClick((): void => { this.dlgSettings = false })
  }

  @Builder DlgKeys() {
    Column() {
      Column() {
        Row() { Text('键盘快捷键').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827'); Blank(); Button('×').fontSize(18).fontColor('#6b7280').backgroundColor('#00000000').width(32).height(32).onClick((): void => { this.dlgKeys = false }) }.width('100%').margin({ bottom: 16 })
        this.KR('Ctrl+S', '保存笔记'); this.KR('Ctrl+Z', '撤销'); this.KR('Ctrl+Y', '重做')
        Divider().color('#e5e7eb').margin({ top: 8, bottom: 8 })
        Text('编辑区纯 Markdown 语法输入, 实时预览自动更新').fontSize(11).fontColor('#9ca3af')
      }.padding(24).backgroundColor('#fff').borderRadius(14).width('85%').border({ width: 1, color: '#e5e7eb' }).shadow({ radius: 16, color: '#00000010' })
    }.width('100%').height('100%').backgroundColor('#00000030').justifyContent(FlexAlign.Center).onClick((): void => { this.dlgKeys = false })
  }

  @Builder KR(k: string, d: string) { Row() { Text(k).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#3b82f6').fontFamily('monospace').backgroundColor('#eff6ff').borderRadius(4).padding({ left: 8, right: 8, top: 2, bottom: 2 }).width(100); Text(d).fontSize(13).fontColor('#374151').margin({ left: 12 }) }.width('100%').padding({ top: 3, bottom: 3 }) }
}
