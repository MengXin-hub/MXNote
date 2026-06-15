# TODOS — MXNote

## 小艺AI API能力调研

**What:** 阅读华为小艺AI开放平台文档，确认API规格——是否支持自定义Prompt注入、多轮对话上下文、Token流式输出。

**Why:** 设计文档将小艺+自定义模型双轨列为核心差异化价值（前提3），但API能力是开放问题。若小艺API不支持自定义Prompt注入，V3需切换DeepSeek为主力模型。

**Pros:** 避免V3启动后发现技术不可行。提前调整架构决策。

**Cons:** 依赖华为文档发布进度，可能API尚未完全公开。

**Context:** 必须在V3开发启动前（约16周后）完成。应急预案已存在（切换OpenAI兼容接口+DeepSeek）。调研结果直接决定V3的LLM Provider实现范围。

**Depends on:** 华为小艺AI开放平台文档公开。不阻塞V1-V2。

## BubbleMenu 选中文本屏幕坐标获取

**What:** Phase 1 Markdown 编辑器的 BubbleMenu 需要知道选中文本在屏幕上的像素坐标。鸿蒙 RichEditor.getSelection() 仅返回字符偏移量，尚无文档确认是否能获取对应的屏幕坐标（类似 Web 的 getBoundingClientRect）。

**Why:** BubbleMenu 是编辑器核心交互——选中文本后弹出加粗/斜体/代码/链接工具栏。若定位不可行，需降级为底部固定工具栏。

**Pros:** 提前确认技术可行性，避免 Step 4 开发时才发现阻塞。

**Cons:** 若降级为底部工具栏，体验略差但功能完整。

**Context:** 在 Step 0 RichEditor 原型验证时一并测试。备选方案: 底部固定 `Row` 工具栏，按钮: 加粗 / 斜体 / 代码 / 链接。功能等价，仅位置从浮层改固定。

**Depends on:** Step 0 原型验证。不阻塞 Step 1-3。
