# TODOS — MXNote

## Phase 2 已完成 (2026-06-15)
- [x] MarkdownUtils — 光标插入标记对工具
- [x] ImageInserter — 图片选择+复制+插入 `![]()`
- [x] ExportService — 导出 .md 到沙箱
- [x] ImportService — 导入 .md 文件
- [x] FormatToolbar — 8个Markdown格式按钮 (B/I/U/S/<>/"/🔗/🖼/≡)
- [x] FileTreePanel — 文件夹展开/折叠+文件分组
- [x] Index.ets — 全功能集成重写

---

## Phase 3 预期 (待设计确认)

### 小艺AI API能力调研

**What:** 阅读华为小艺AI开放平台文档，确认API规格——是否支持自定义Prompt注入、多轮对话上下文、Token流式输出。

**Why:** 设计文档将小艺+自定义模型双轨列为核心差异化价值（前提3），但API能力是开放问题。若小艺API不支持自定义Prompt注入，V3需切换DeepSeek为主力模型。

**Depends on:** 华为小艺AI开放平台文档公开。不阻塞当前版本。

### Phase 3 技术债务

- `InsertImage` 图片预览内嵌渲染（当前仅路径引用）
- 键盘快捷键真实绑定（Ctrl+B/I/U/S/Z/Y 通过 keyboardShortcut API）
- FileTreePanel 拖拽移动文件到文件夹
- 手机竖屏适配
- 图标清理（28个SVG仅用12个）

### 技术债务

#### BubbleMenu 选中文本屏幕坐标获取

**What:** Phase 1 Markdown 编辑器的 BubbleMenu 需要知道选中文本在屏幕上的像素坐标。鸿蒙 RichEditor.getSelection() 仅返回字符偏移量，尚无文档确认是否能获取对应的屏幕坐标（类似 Web 的 getBoundingClientRect）。

**Why:** BubbleMenu 是编辑器核心交互——选中文本后弹出加粗/斜体/代码/链接工具栏。若定位不可行，需降级为底部固定工具栏。**Note: RichEditor 已弃用（API 12 401 错误），此需求改用 FormatToolbar 替代。**

**Status:** Deferred — FormatToolbar 提供等价的格式操作入口，无需浮动菜单。
