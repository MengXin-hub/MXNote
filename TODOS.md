# TODOS — MXNote

> 最后更新: 2026-06-16

---

## ✅ 已完成

### v0.0.1 — 基础框架
- [x] 三面板可拖拽布局 (PanGesture 分隔条)
- [x] 纯文本 Markdown 编辑器 (TextArea + monospace)
- [x] 文件 CRUD (Preferences → 沙箱文件系统迁移)
- [x] 自研 Markdown 解析器 (O(n) 单遍扫描)

### v0.0.2 — 核心功能
- [x] 文件夹管理 (创建/重命名/删除/展开折叠)
- [x] 多标签编辑器 (脏标记 + 内联重命名)
- [x] 上下文菜单 (长按/右键 → 重命名/删除/移动)
- [x] 拖拽移动文件到文件夹
- [x] 批量删除模式
- [x] 搜索过滤 (标题即时 + 内容异步懒加载)
- [x] 导入/导出 .md 文件
- [x] 数据迁移 (Preferences → 沙箱文件系统)
- [x] 布局持久化 (config.json)

### 2026-06-16 — UI 优化
- [x] 预览面板加宽 (MAX_PANEL 600→900, RIGHT_DEFAULT 500→700)
- [x] 分隔条悬停颜色反馈 (灰色→蓝色)
- [x] 启动默认仅编辑界面 (左右面板隐藏)
- [x] 预览区 Markdown 内链跳转 (mdRegister.HandleHyperlink)

### Phase 2 — 服务与组件
- [x] ExportService — 导出 .md 到沙箱
- [x] ImportService — 导入 .md 文件选择器
- [x] FileTreePanel — 文件夹展开/折叠+文件分组
- [x] Index.ets — 全功能集成重写
- [x] 原生 Markdown 渲染 (@luvi/lv-markdown-in)

---

## 🔲 待接入（Build Cache 中存在源码，未集成到主界面）

### RichEditor 富文本编辑
- [ ] **RichEditorArea** — StyledString 富文本组件（替代 TextArea）
- [ ] **RichEditorController** — 格式状态管理 + 撤销/重做历史栈
- [ ] **RichEditorConstants** — 调色盘 + 图标滤镜

### 格式工具栏
- [ ] **FormatToolbar** — 8 个格式按钮 (B/I/U/S/代码/引用/链接/图片/对齐)
- [ ] **EditorToolbar** — 编辑器工具栏组件
- [ ] **EditorFooter** — 底部统计栏组件
- [ ] **EditorTabBar** — 多标签栏组件

### 其他组件
- [ ] **ImageInserter** — 图片选择+复制+插入 ![]()
- [ ] **MarkdownService** — TaskPool Worker 异步解析
- [ ] **SearchDialog** — 搜索替换对话框
- [ ] **LeftSidebar** — 替代侧边栏实现
- [ ] **MarkListView** — Mark 列表视图

---

## 📋 待开发

### 🔴 高优先级
- [ ] **大纲点击跳转** — 点击大纲标题滚动预览到对应位置
- [ ] **RichEditor 集成** — 从 build cache 接入 RichEditorArea 代替 TextArea
- [ ] **FormatToolbar 集成** — 接入格式工具栏
- [ ] **自动保存** — 编辑停顿后自动保存
- [ ] **键盘快捷键真实绑定** — Ctrl+B/I/U via keyboardShortcut API

### 🟡 中优先级
- [ ] **手机竖屏适配** — 三面板 → 单面板响应式布局
- [ ] **代码语法高亮** — lv-markdown-in 主题配置
- [ ] **MarkdownService 接入** — TaskPool 异步解析解决长文档卡顿
- [ ] **图片内嵌预览** — 粘贴/拖入图片自动保存并内嵌渲染

### 🟢 远期规划
- [ ] **AI 对话面板** — 华为小艺/DeepSeek API 集成
- [ ] **跨设备接力编辑** — distributedDataObject 分布式同步
- [ ] **暗色主题** — 深色模式切换
- [ ] **PDF 导出** — Markdown → PDF 渲染
- [ ] **笔记标签/分类** — 标签系统
- [ ] **版本历史** — 修改历史 + diff 对比
- [ ] **云同步** — 远端备份
- [ ] **图标清理** — 28 个注册图标清理至 12 个实际使用

---

## 🔧 技术债务

- [ ] Preferences 旧存储已迁移但代码引用未完全清除
- [ ] FileListPage.ets 已弃用但文件仍存在
- [ ] ImageInserter 源码缺失（仅有 TODOS 引用）
- [ ] MarkdownParser 链接/图片解析为 Paragraph 中的 inline span，未使用 TokenType.LINK/IMG
- [ ] 多标签关闭时索引修正逻辑复杂，边界有潜在 bug
- [ ] 保存操作无 loading/error toast 反馈
- [ ] 文件重命名无同名冲突检测
