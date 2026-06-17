# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

MXNote — HarmonyOS NEXT native Markdown note editor. Built with ArkTS strict mode (API 12+), deployed via DevEco Studio. The primary distribution target is phone + tablet + 2in1.

## Build & Test

- **Build**: Open in DevEco Studio → Build → Build HAP(s). No CLI build.
- **Lint**: `code-linter.json5` applies `@performance/recommended` and `@typescript-eslint/recommended` to all `**/*.ets` files (DevEco Studio runs this automatically).
- **Test**: `entry/src/ohosTest/` is a Hypium test module. Run via DevEco Studio test runner. Test runner entry: `entry/src/ohosTest/ets/test/List.test.ets` which imports individual test suites.

## Architecture

```
entry/src/main/ets/
├── entryability/EntryAbility.ets     # UIAbility entry, window config (light mode forced, titlebar)
├── pages/
│   ├── Index.ets                     # Main page (~820 lines): all top-level @State, event handlers, build()
│   └── components/
│       ├── TitleBar.ets              # Logo, sidebar toggle, AI button, search box
│       ├── FileTreePanel.ets         # VS Code-style file tree with inline rename/create, context menu, drag-drop
│       ├── EditorArea.ets            # Thin TextArea wrapper isolating keystroke updates from parent
│       ├── Dialogs.ets               # DlgConfirm + DlgMigrationError reusable dialogs
│       └── SettingsDialog.ets        # Font size sliders, keyboard shortcuts reference, login placeholder
├── core/
│   ├── FileSystemManager.ets         # Sandbox FS engine: GUID .md files + index.json index. All I/O returns Result<T,E>
│   ├── FileManager.ets               # Thin async delegation wrapper around FileSystemManager
│   └── MarkdownParser.ets            # Single-pass O(n) Markdown→Token[] parser (60KB content cap)
├── model/
│   ├── NoteFile.ets                  # NoteFile + Folder classes, generateId(), formatTime()
│   └── Result.ets                    # Rust-style Result<T,E> with ok()/err() factories — pattern for all failure paths
├── services/
│   ├── ExportService.ets             # Write .md to mxnote/exports/ in app sandbox
│   └── ImportService.ets             # DocumentViewPicker → read .md content
├── constants/
│   ├── ThemeConstants.ets            # Semantic design tokens (colors, spacing, font sizes, radii, layout limits)
│   └── IconConstants.ets             # Icon resource ID map
└── utils/                            # ThrottleUtil (referenced in TODOS but may not exist on disk yet)
```

## Key Design Patterns

### Error handling: `Result<T, E>` monad

All filesystem I/O returns `Result<T, AppError>`. Callers must branch on `isOk()`/`isErr()` — no throwing. Found in [model/Result.ets](entry/src/main/ets/model/Result.ets). `AppError` carries a `code: ErrorCode` enum and a `message: string`.

### Storage: sandbox filesystem with index.json

Notes are stored as `mxnote/notes/{id}.md` with metadata in `mxnote/notes/index.json`. Folders are physical directories named by folder ID, with a `.name` file storing the display name. No database — everything is flat JSON + files. Migration from the old Preferences-based scheme is gated by `.migrated_v1` flag file.

### Reactive state in Index.ets

Nearly all UI state lives as `@State` properties on the `Index` struct. Child components receive data via `@Link`/`@Prop` and emit events through callbacks (`onFileOpen`, `onFileRename`, etc.). The `EditorArea` component uses `@Prop @Watch` to decouple keystroke updates from full-tree re-renders — the local TextArea text is synced to parent only via the `onChange` callback.

### Panel layout

Three resizable panels via `PanGesture` on divider columns. Layout config (widths + visibility) is persisted to `config.json` on every drag update. Default on cold start: left and right panels hidden (clean editing view).

## Dependencies

- `@luvi/lv-markdown-in` 2.0.15 — native Markdown rendering engine, used in the preview panel via `LvMarkdownIn({ text })`. Hyperlink interception is wired through `mdRegister.HandleHyperlink` in [Index.ets](entry/src/main/ets/pages/Index.ets#L122-L143).
- `@ohos/hypium` 1.0.19 — test framework (dev)
- `@ohos/hamock` 1.0.0 — mocking utilities (dev)
- Package manager: ohpm, lockfile at `oh_modules/`

## TODOS Reference

[TODOS.md](TODOS.md) is the living task list. High-priority upcoming work: outline click-to-jump, RichEditor integration (build cache source exists but isn't wired in), format toolbar integration, auto-save, and real keyboard shortcut bindings. Technical debt includes stale Preferences references, a deprecated FileListPage.ets, and missing ImageInserter source.

## Notes for Commits

- The repo follows `v0.0.X` versioning with semantic-ish commits
- MIT licensed
- Design references: [note-gen](https://github.com/codexu/note-gen) (layout/inspiration) and a predecessor HarmonyOS notes app
