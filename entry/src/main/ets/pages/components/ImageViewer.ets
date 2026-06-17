/**
 * ┌─────────────────────────────────────────────────────────────┐
 * │  ImageViewer — 自定义图片查看器（旋转 + 缩放 + 漫游）         │
 * │                                                             │
 * │  接管库内 HandleImage，使用鸿蒙原生 Image 组件自由控制：       │
 * │  · 旋转 90°/180°/270° — 修正 EXIF 横竖翻转                   │
 * │  · 双指缩放 1×～5× — 细节放大查看                             │
 * │  · 单指拖拽漫游 — 缩放后平移图片                              │
 * │  · 自动保存旋转状态 — 关闭后记住，下次打开自动恢复              │
 * └─────────────────────────────────────────────────────────────┘
 */
import { ThemeColors } from '../../constants/ThemeConstants'
import { IconConstants } from '../../constants/IconConstants'
import { fileIo as fs } from '@kit.CoreFileKit'

/** 图片旋转状态存储文件 */
const ROTATIONS_FILE: string = 'mxnote/image_rotations.json'

@Component
export struct ImageViewer {
  @Prop imageUrl: string = ''
  @State rotation: number = 0      // 0 | 90 | 180 | 270
  @State zoom: number = 1          // 缩放比例 1～5
  @State panX: number = 0          // 水平偏移
  @State panY: number = 0          // 垂直偏移
  @State loading: boolean = true
  @State hasError: boolean = false
  onClose?: () => void

  /** 页面出现时加载已保存的旋转角度 */
  aboutToAppear(): void {
    this.rotation = this.loadRotation(this.imageUrl)
  }

  rotateLeft(): void {
    this.rotation = (this.rotation - 90 + 360) % 360
    this.saveRotation(this.imageUrl, this.rotation)
  }

  rotateRight(): void {
    this.rotation = (this.rotation + 90) % 360
    this.saveRotation(this.imageUrl, this.rotation)
  }

  resetView(): void {
    this.zoom = 1
    this.panX = 0
    this.panY = 0
  }

  build() {
    Column() {
      // ── 顶栏：文件名 + 操作按钮 ──
      Row() {
        Text(this.extractFileName(this.imageUrl))
          .fontSize(14).fontColor('#ffffff').maxLines(1).layoutWeight(1)
        Row({ space: 4 }) {
          // 旋转
          Text('↺').fontSize(18).fontColor('#cccccc').width(32).height(32)
            .textAlign(TextAlign.Center).onClick(() => { this.rotateLeft() })
          Text('↻').fontSize(18).fontColor('#cccccc').width(32).height(32)
            .textAlign(TextAlign.Center).onClick(() => { this.rotateRight() })
          // 缩放复位
          Text('⟲').fontSize(18).fontColor('#cccccc').width(32).height(32)
            .textAlign(TextAlign.Center).onClick(() => { this.resetView() })
          // 关闭
          Text('✕').fontSize(18).fontColor('#ffffff').width(36).height(36)
            .textAlign(TextAlign.Center).onClick(() => { this.close() })
        }
      }
      .width('100%').padding({ left: 16, right: 4, top: 40, bottom: 8 })
      .backgroundColor('#000000cc')

      // ── 加载状态 ──
      if (this.loading && !this.hasError) {
        Column() {
          LoadingProgress().width(32).height(32).color('#ffffff')
          Text('加载中...').fontSize(13).fontColor('#99aabb').margin({ top: 10 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }

      // ── 错误状态 ──
      if (this.hasError) {
        Column() {
          Image(IconConstants.IC_IMAGE).width(48).height(48).fillColor('#556677')
          Text('图片加载失败').fontSize(14).fontColor('#8899aa').margin({ top: 10 })
          Text(this.imageUrl).fontSize(11).fontColor('#556677').maxLines(2)
            .margin({ top: 4 }).padding({ left: 20, right: 20 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }

      // ── 图片主体（旋转 + 缩放 + 平移）──
      Image(this.imageUrl)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
        .rotate({ angle: this.rotation })
        .scale({ x: this.zoom, y: this.zoom })
        .offset({ x: this.panX, y: this.panY })
        .visibility(this.hasError ? Visibility.Hidden : Visibility.Visible)
        .onComplete(() => { this.loading = false })
        .onError(() => { this.loading = false; this.hasError = true })
        .onClick(() => { if (this.zoom >= 2) { this.resetView() } else { this.close() } })
        // ── 双指缩放 + 单指拖拽（GestureGroup 避免冲突）──
        .gesture(
          GestureGroup(GestureMode.Parallel,
            PinchGesture({ fingers: 2, distance: 5 })
              .onActionUpdate((ev: GestureEvent | undefined) => {
                if (!ev) return
                const s: number = Math.max(1, Math.min(5, ev.scale))
                this.zoom = s
                // 缩小到 1× 时复位平移
                if (s <= 1) { this.panX = 0; this.panY = 0 }
              }),
            PanGesture({ fingers: 1, distance: 5 })
              .onActionUpdate((ev: GestureEvent | undefined) => {
                if (!ev || this.zoom <= 1) return
                this.panX = this.panX + ev.offsetX
                this.panY = this.panY + ev.offsetY
              })
          )
        )
      .layoutWeight(1)

      // ── 底栏：状态信息 ──
      Row() {
        // 旋转角度
        Text(this.rotation === 0 ? '原始方向' : '已旋转 ' + this.rotation.toString() + '°')
          .fontSize(11).fontColor('#667788')
        Blank()
        // 缩放比例
        Text(this.zoom > 1 ? Math.round(this.zoom * 100).toString() + '%' : '')
          .fontSize(11).fontColor('#667788')
        Blank()
        // 操作提示
        Text(this.zoom > 1 ? '点击还原 · 双指缩放 · 拖动漫游' : '点击关闭 · 双指缩放 · ↺↻旋转')
          .fontSize(10).fontColor('#445566')
      }
      .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 30 })
      .backgroundColor('#000000cc')
    }
    .width('100%').height('100%').backgroundColor('#000000')
    // 半透明蒙层上的点击 → 关闭
  }

  /** 关闭前保存旋转状态 */
  private close(): void {
    if (this.onClose) this.onClose()
  }

  // ═══════════════════ 旋转状态持久化 ═══════════════════

  /** 从 mxnote/image_rotations.json 读取某 URL 的旋转角度 */
  private loadRotation(url: string): number {
    try {
      const ctx: Context | undefined = (this.getUIContext() as UIContext)?.getHostContext()
      if (!ctx) return 0
      const file: string = ctx.filesDir + '/' + ROTATIONS_FILE
      try { fs.statSync(file) } catch (e) { return 0 }
      const raw: string = fs.readTextSync(file)
      const map: Record<string, number> = JSON.parse(raw) as Record<string, number>
      return map[url] || 0
    } catch (e) {
      return 0
    }
  }

  /** 将某 URL 的旋转角度写入 mxnote/image_rotations.json */
  private saveRotation(url: string, angle: number): void {
    try {
      const ctx: Context | undefined = (this.getUIContext() as UIContext)?.getHostContext()
      if (!ctx) return
      const file: string = ctx.filesDir + '/' + ROTATIONS_FILE
      let map: Record<string, number> = {}
      try {
        const raw: string = fs.readTextSync(file)
        map = JSON.parse(raw) as Record<string, number>
      } catch (e) {
        // file doesn't exist yet
      }
      map[url] = angle
      const wf: fs.File = fs.openSync(file, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      fs.writeSync(wf.fd, JSON.stringify(map))
      fs.closeSync(wf)
    } catch (e) {
      // best effort — 静默失败
    }
  }

  // ═══════════════════ 工具 ═══════════════════

  private extractFileName(url: string): string {
    if (!url) return '图片'
    let path: string = url
    if (path.startsWith('file://')) path = path.slice(7)
    const idx: number = path.lastIndexOf('/')
    return idx >= 0 ? path.slice(idx + 1) : path
  }
}
