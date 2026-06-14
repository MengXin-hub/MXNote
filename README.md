# MXNote

> 鸿蒙原生 Markdown 笔记应用，为研究者打造的简洁写作工具。

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-NEXT-blue)](https://developer.huawei.com/consumer/cn/harmonyos/)
[![ArkTS](https://img.shields.io/badge/ArkTS-API12+-orange)](https://developer.huawei.com/consumer/cn/arkts/)

---

## 📸 概览

```
┌──────────────────────────────────────────────────────────┐
│ [📝][💾][↩][↪][✎][🗑]  ┃  🔍 搜索...  ┃  [☰][◫]     │ ← 工具栏
├──────────┬────────────────────────────┬──────────────────┤
│ 笔记A     │                            │                  │
│ 06-14     │  # 一级标题                │  一级标题        │
│ 笔记B     │  ## 二级标题               │  二级标题        │
│ 06-13     │  **加粗** *斜体* `code`    │  加粗 斜体 code  │ ← 三面板可拖拽
│           │  > 引用 `code`             │  | 引用          │
│           │  - 列表项                  │  • 列表项        │
│           │                            │                  │
│◄── 可拖拽 ──►│                            │◄── 可拖拽 ──►│
├──────────┴────────────────────────────┴──────────────────┤
│ 3 篇                    编辑中 · 234字 · 大纲 · 设置 · ⌨  │ ← 底部栏
└──────────────────────────────────────────────────────────┘
```

---

## 🚀 功能

### 编辑器
- **三面板可拖拽**: 分隔条支持水平拖动，左侧栏 180-480px，右侧栏 180-480px
- **纯 Markdown 编辑**: 严格遵循 Markdown 语法，无格式按钮，纯键盘输入
- **实时预览**: 右侧面板 350ms 去抖自动解析，从左到右、从上到下依次渲染
- **大纲面板**: 自动解析 H1-H3 标题，层级缩进显示，右下角"大纲"切换
- **设置面板**: 右下角"设置"→ 编辑器字号可调 (10-28px)，修改即时生效

### 文件管理
- 新建 / 保存 / 重命名 / 删除 — Preferences 持久化
- 实时搜索过滤（按标题）
- 创建时间 + 修改时间显示
- 按修改时间降序排列

### 键盘快捷键
| 快捷键 | 功能 |
|--------|------|
| `Ctrl+S` | 保存笔记 |
| `Ctrl+Z` | 撤销 |
| `Ctrl+Y` | 重做 |

### 撤销/重做
- 编辑快照栈，最大 100 步
- 工具栏 ↩↪ 按钮 + 键盘 Ctrl+Z/Y

### Markdown 语法支持
| 语法 | 预览效果 |
|------|---------|
| `# ~ ######` | H1-H6 标题 |
| `**text**` / `*text*` | **加粗** / *斜体* |
| `` `code` `` / ` ```block``` ` | 行内代码 / 代码块 |
| `> text` | 引用块 |
| `- ` / `1. ` | 无序/有序列表 |
| `---` | 分割线 |

---

## 📁 工程结构

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets          # 应用入口
├── pages/
│   ├── Index.ets                 # 主编辑器 (三面板可拖拽布局)
│   └── FileListPage.ets          # 文件列表页 (备用)
├── core/
│   ├── MarkdownParser.ets        # 单遍扫描 O(n) 解析器, 全部 class 构造
│   ├── FileManager.ets           # Preferences CRUD 文件管理
│   ├── SessionEngine.ets         # distributedDataObject 分布式同步 (预留)
│   └── SyncManager.ets           # LWW 冲突裁决 + 分块协议 (预留)
├── model/
│   ├── NoteFile.ets              # 笔记文件数据模型
│   ├── Result.ets                # Rust 风格 Result<T,E>
│   └── Session.ets               # 跨设备会话模型 (预留)
└── utils/
    └── ThrottleUtil.ets          # 去抖/节流工具

entry/src/ohosTest/ets/test/
├── MarkdownParser.test.ets       # 解析器测试
└── SyncManager.test.ets          # 同步测试
```

---

## 🔧 技术栈

| 层 | 技术 |
|----|------|
| **UI** | ArkUI (ArkTS strict mode, API 12+) |
| **存储** | Preferences (key-value) |
| **解析器** | 自研 O(n) 单遍扫描, `new` 显式构造, 60KB 上限 |
| **键盘** | `KeyCode` + `onKeyEvent` (Ctrl+S/Z/Y) |
| **手势** | `PanGesture` (分隔条拖拽) |
| **测试** | ohosTest + Hypium |
| **构建** | DevEco Studio + hvigor |

---

## 🏗️ 设计参考

- **[note-gen](https://github.com/codexu/note-gen)** (11.8k⭐) — 三面板布局、快捷键系统、底部状态栏、大纲面板
- **[notes1.0.4](https://gitee.com/mengxin-xixi/notes1.0.4)** — HarmonyOS Preferences 持久化、多模块架构

---

## 🏃 快速开始

1. 用 DevEco Studio 打开本项目
2. Build → Build HAP(s)
3. 部署到 HarmonyOS 设备或模拟器

---

## 📋 版本计划

| 版本 | 内容 | 状态 |
|------|------|------|
| **V1** | 三面板可拖拽 + 纯Markdown编辑 + 实时预览 + 文件管理 + 快捷键 | ✅ 完成 |
| **V2** | 跨设备接力编辑 (distributedDataObject) | 🔲 计划中 |
| **V3** | LLM 集成 (华为小艺 + 自定义模型) | 🔲 计划中 |

---

## 📄 许可证

MIT
