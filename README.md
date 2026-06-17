# MXNote

> 鸿蒙原生 Markdown 笔记应用，为研究者打造的简洁写作工具。

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-NEXT-blue)](https://developer.huawei.com/consumer/cn/harmonyos/)
[![ArkTS](https://img.shields.io/badge/ArkTS-API12+-orange)](https://developer.huawei.com/consumer/cn/arkts/)

---

## 📸 概览

```
┌────────────────────────────────────────────────────────────────┐
│ [📝] [☰] [AI]    🔍 搜索标题或内容...               [搜索]    │ ← 顶部栏
├──────────┬──────────────────────────────────┬──────────────────┤
│ [新建][文件夹][导入]                        │  预览         ✕  │
│ ─────────────────                          │                  │
│ 📁 研究笔记 ▶                              │  # Hello World   │
│   📄 量子计算    06-15                      │                  │
│   📄 AI论文      06-14                      │  这是渲染后的    │
│ 📄 日记        06-15                        │  Markdown 内容  │
│ 📄 待办事项    06-13                        │                  │
│                                            │                  │
│◄── 左分隔可拖拽 ──►│                    │◄── 右分隔可拖拽 ──►│
├──────────┴──────────────────────────────────┴──────────────────┤
│ 标签1 ✕ │ 标签2 ✕ │                   234 字 · 已保存 · 保存  │
│────────────────────────────────────────────────────────────────│
│ # Hello World                                                 │
│ ## 第一节                                                      │
│ 这是正文内容...                                                │
├────────────────────────────────────────────────────────────────┤
│ 234 字 · 已保存 · 保存  ··  导出 · 预览 · 大纲                │
└────────────────────────────────────────────────────────────────┘
```

---

## 🚀 功能

### ✅ 已实现

#### 编辑器
- **三面板可拖拽布局**: 左侧文件树 100~900px，右侧预览 100~900px，分隔悬停变色反馈
- **多标签编辑器**: 支持同时打开多个笔记，脏文件标记 (●)，双击标题内联重命名
- **纯 Markdown 编辑**: 等宽字体 (monospace)，可调字号 (10~32px)
- **实时预览**: 使用 @luvi/lv-markdown-in 原生渲染引擎，支持完整 Markdown 语法
- **大纲面板**: 自动提取 H1-H6 标题，层级缩进显示
- **AI 对话面板**: 界面入口已就绪（功能待实现）
- **启动仅编辑界面**: 打开/重启时默认隐藏左右面板，干净的写作环境

#### 文件管理
- **沙箱文件系统**: GUID 命名 .md 文件 + index.json 索引，写入失败自动重试
- **文件夹管理**: 创建/重命名/删除文件夹，.name 文件存储显示名
- **文件 CRUD**: 新建/保存/重命名/删除，支持批量删除模式
- **拖拽移动**: 文件可拖拽到文件夹中
- **导入/导出**: 支持从文件选择器导入 .md，导出到沙箱 exports/ 目录
- **搜索过滤**: 标题即时匹配 + 内容异步懒加载搜索，300ms 去抖
- **内容预加载**: 启动后自动缓存所有文件内容用于搜索

#### Markdown 预览
- `# ~ ######` — H1-H6 标题
- `**bold**` / `*italic*` — 粗体/斜体
- `` `code` `` / ` ```block``` ` — 行内代码 / 代码块（暗夜主题）
- `> text` — 引用块
- `- ` / `1. ` — 无序/有序列表
- `---` — 分割线
- `[text](url)` — 超链接（支持笔记内链跳转）
- `![alt](url)` — 图片
- `| a | b |` — 表格
- ` ```mermaid ``` ` — Mermaid 流程图

#### 其他
- **设置面板**: 字号调节 (A⁻/A⁺)，快捷键一览，用户登录入口（占位）
- **数据迁移**: 从旧版 Preferences 自动迁移到沙箱文件系统
- **布局持久化**: 面板宽度保存到 config.json，跨启动恢复
- **上下文菜单**: 长按/右键弹出重命名/删除/移动操作
- **文件夹折叠/展开**: 点击文件夹名切换

#### Markdown 语法支持
| 语法 | 预览效果 |
|------|---------|
| `# ~ ######` | H1-H6 标题 |
| `**text**` / `*text*` | **加粗** / *斜体* |
| `` `code` `` / ` ```block``` ` | 行内代码 / 代码块 |
| `> text` | 引用块 |
| `- ` / `1. ` | 无序/有序列表 |
| `---` | 分割线 |
| `[text](url)` | 超链接 |
| `![alt](url)` | 图片 |
| `| a \| b |` | 表格 |
| ` ```mermaid ``` ` | Mermaid 流程图 |

---

## 📋 下一步开发计划

### 🔴 高优先级 (近期)

| 序号 | 功能 | 说明 |
|------|------|------|
| 1 | **大纲点击跳转** | 点击大纲标题自动滚动预览到对应位置 |
| 2 | **RichEditor 集成** | 将 build cache 中的 RichEditorArea + RichEditorController 接入主界面，支持富文本编辑、撤销重做历史栈、段落对齐 |
| 3 | **FormatToolbar 集成** | 接入 build cache 中的格式工具栏 (B/I/U/S/代码/引用/链接/图片) |
| 4 | **搜索替换** | 编辑器内查找+替换，支持正则 |
| 5 | **图片插入** | ImageInserter 集成，支持选择+复制图片到笔记目录 |

### 🟡 中优先级

| 序号 | 功能 | 说明 |
|------|------|------|
| 6 | **自动保存** | 编辑停顿 N 秒后自动保存，不再依赖手动保存 |
| 7 | **键盘快捷键** | Ctrl+B/I/U 格式化快捷键真实绑定 (keyboardShortcut API) |
| 8 | **MarkdownService 异步解析** | 将 TaskPool Worker 解析器接入预览，解决长文档解析卡顿 |
| 9 | **代码语法高亮** | lv-markdown-in 已支持，需配置 lvCode.setTheme() |
| 10 | **手机竖屏适配** | 三面板 → 单面板响应式布局 |

### 🟢 低优先级 / 远期

| 序号 | 功能 | 说明 |
|------|------|------|
| 11 | **AI 对话面板** | 接入华为小艺或 DeepSeek API，基于笔记内容对话 |
| 12 | **跨设备接力编辑** | distributedDataObject 分布式同步 (SessionEngine + SyncManager 已预留) |
| 13 | **暗色主题** | 深色模式主题切换 |
| 14 | **PDF 导出** | 将 Markdown 渲染为 PDF |
| 15 | **笔记标签/分类** | 标签系统，多维分类 |
| 16 | **版本历史** | 笔记修改历史 + diff 对比 |
| 17 | **云同步** | 远端备份与多端同步 |
| 18 | **图标清理** | 28 个注册图标中约 12 个实际使用，清理冗余 |

---

## 📁 工程结构

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets              # 应用入口，窗口配置
├── pages/
│   ├── Index.ets                     # 主页面：三面板布局 + 多标签 + 对话框
│   └── components/
│       ├── TitleBar.ets              # 顶部栏：Logo/侧栏切换/AI/搜索
│       ├── FileTreePanel.ets         # VS Code 风格文件树：文件夹/文件/右键菜单/拖拽
│       ├── EditorArea.ets            # 纯文本编辑器 (TextArea)
│       ├── Dialogs.ets               # 确认对话框 + 迁移失败提示
│       └── SettingsDialog.ets        # 设置弹窗：字号/快捷键/登录
├── core/
│   ├── FileSystemManager.ets         # 沙箱文件系统：index.json/CRUD/迁移/配置
│   ├── FileManager.ets               # 委托层，包装 FileSystemManager
│   ├── MarkdownParser.ets            # O(n) 单遍扫描解析器：完整行内语法
│   ├── SessionEngine.ets             # distributedDataObject 会话管理 (预留)
│   └── SyncManager.ets               # LWW 冲突裁决 + 分块协议 (预留)
├── model/
│   ├── NoteFile.ets                  # NoteFile + Folder 数据模型 + ID生成
│   ├── Result.ets                    # Rust 风格 Result<T,E>
│   └── Session.ets                   # 跨设备同步会话模型 (预留)
├── services/
│   ├── ExportService.ets             # .md 导出到沙箱 exports/
│   ├── ImportService.ets             # 文件选择器导入 .md
│   └── MarkdownService.ets           # TaskPool Worker 异步解析 (未接入)
├── constants/
│   ├── ThemeConstants.ets            # 语义化设计令牌：颜色/间距/字号/圆角
│   └── IconConstants.ets             # 图标资源映射 (28 个)
├── utils/
│   └── ThrottleUtil.ets              # Debouncer + Throttler 工具
└── richeditor/                        # RichEditor 架构（build cache 中，待接入）
    ├── components/
    │   └── RichEditorArea.ts         # StyledString RichEditor 组件
    ├── controller/
    │   └── RichEditorController.ts   # 格式状态管理 + 撤销重做
    └── common/
        └── RichEditorConstants.ts    # 调色盘 + 滤镜常量

entry/src/ohosTest/ets/test/
├── MarkdownParser.test.ets           # 解析器测试
└── SyncManager.test.ets              # 同步测试
```

---

## 🔧 技术栈

| 层 | 技术 |
|----|------|
| **UI** | ArkUI (ArkTS strict mode, API 12+) |
| **存储** | 沙箱文件系统 (index.json + .md 文件) |
| **预览** | @luvi/lv-markdown-in 2.0.15 原生渲染引擎 |
| **解析器** | 自研 O(n) 单遍扫描, 60KB 上限 |
| **手势** | PanGesture (分隔条拖拽) + LongPressGesture (上下文菜单) + TapGesture (双击重命名) |
| **测试** | ohosTest + Hypium |
| **构建** | DevEco Studio + hvigor |
| **分布式** | distributedDataObject (架构已预留, 功能待实现) |

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

## 📄 许可证

MIT
