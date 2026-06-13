# TODOS — MXNote

## 小艺AI API能力调研

**What:** 阅读华为小艺AI开放平台文档，确认API规格——是否支持自定义Prompt注入、多轮对话上下文、Token流式输出。

**Why:** 设计文档将小艺+自定义模型双轨列为核心差异化价值（前提3），但API能力是开放问题。若小艺API不支持自定义Prompt注入，V3需切换DeepSeek为主力模型。

**Pros:** 避免V3启动后发现技术不可行。提前调整架构决策。

**Cons:** 依赖华为文档发布进度，可能API尚未完全公开。

**Context:** 必须在V3开发启动前（约16周后）完成。应急预案已存在（切换OpenAI兼容接口+DeepSeek）。调研结果直接决定V3的LLM Provider实现范围。

**Depends on:** 华为小艺AI开放平台文档公开。不阻塞V1-V2。
