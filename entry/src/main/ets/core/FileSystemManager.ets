/**
 * FileSystemManager — 沙箱文件系统管理器。
 *
 * 替代 Preferences 存储方案。所有笔记以 GUID 命名的 .md 文件存储，
 * 元数据索引保存在 notes/index.json 中。
 * 写入失败时自动重试一次，所有 I/O 返回 Result<T, AppError>。
 */
import { ok, err, Result, AppError, ErrorCode } from '../model/Result'
import { NoteFile, Folder, generateId } from '../model/NoteFile'
import { fileIo as fs } from '@kit.CoreFileKit'

const BASE_DIR: string = 'mxnote'
const NOTES_DIR: string = 'mxnote/notes'
const INDEX_FILE: string = 'mxnote/notes/index.json'
const CONFIG_FILE: string = 'mxnote/config.json'
const MIGRATED_FLAG: string = 'mxnote/.migrated_v1'
const MIGRATION_FAILED_FLAG: string = 'mxnote/.migration_failed'

/** 文件索引条目 (JSON 序列化格式) */
interface IndexEntry {
  id: string
  title: string
  createdAt: number
  modifiedAt: number
  folderId: string | null
}

/** 布局配置 (JSON 序列化格式) */
interface LayoutConfig {
  leftWidth: number
  rightWidth: number
  leftVisible: boolean
  rightVisible: boolean
}

/** 应用配置 (JSON 序列化格式) */
interface AppConfig {
  layout: LayoutConfig
}

const DEFAULT_CONFIG: AppConfig = {
  layout: {
    leftWidth: 240,
    rightWidth: 300,
    leftVisible: true,
    rightVisible: false
  }
}

/** Preferences 迁移 - 旧索引条目类型 */
interface OldIndexEntry {
  id: string
  title: string
  createdAt: number
  modifiedAt: number
}

export class FileSystemManager {
  private basePath: string = ''

  constructor() {}

  /**
   * 初始化: 创建必要的目录结构。
   */
  init(filesDir: string): Result<void, AppError> {
    try {
      this.basePath = filesDir
      this.ensureDir(BASE_DIR)
      this.ensureDir(NOTES_DIR)
      return ok(undefined)
    } catch (e) {
      return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED,
        'Failed to init filesystem: ' + (e as Error).message))
    }
  }

  getBasePath(): string {
    return this.basePath
  }

  // ═══════════════════════════════════════════════════════
  // 笔记 CRUD
  // ═══════════════════════════════════════════════════════

  createFile(title: string, content: string, folderId: string | null = null): Result<NoteFile, AppError> {
    const id: string = generateId()
    const now: number = Date.now()
    const file: NoteFile = new NoteFile(id, title, content, now, now, folderId)

    const writeResult: Result<void, AppError> = this.writeTextFile('mxnote/notes/' + id + '.md', content)
    if (!writeResult.isOk()) {
      return err(writeResult.getError()!)
    }

    const indexResult: Result<IndexEntry[], AppError> = this.readIndex()
    if (!indexResult.isOk()) {
      this.deleteFileIfExists('mxnote/notes/' + id + '.md')
      return err(indexResult.getError()!)
    }

    const index: IndexEntry[] = indexResult.getValue()!
    const newEntry: IndexEntry = {
      id: file.id,
      title: file.title,
      createdAt: file.createdAt,
      modifiedAt: file.modifiedAt,
      folderId: file.folderId
    }
    index.push(newEntry)

    const idxWriteResult: Result<void, AppError> = this.writeIndexWithRetry(index)
    if (!idxWriteResult.isOk()) {
      this.deleteFileIfExists('mxnote/notes/' + id + '.md')
      return err(idxWriteResult.getError()!)
    }

    return ok(file)
  }

  readFile(id: string): Result<NoteFile, AppError> {
    const idxResult: Result<IndexEntry[], AppError> = this.readIndex()
    if (!idxResult.isOk()) {
      return err(idxResult.getError()!)
    }

    const index: IndexEntry[] = idxResult.getValue()!
    let entry: IndexEntry | undefined = undefined
    for (let i: number = 0; i < index.length; i++) {
      if (index[i].id === id) {
        entry = index[i]
        break
      }
    }
    if (!entry) {
      return err(new AppError(ErrorCode.STORAGE_READ_FAILED, 'File not found: ' + id))
    }

    const contentResult: Result<string, AppError> = this.readTextFile('mxnote/notes/' + id + '.md')
    if (!contentResult.isOk()) {
      return err(contentResult.getError()!)
    }

    return ok(new NoteFile(
      entry.id,
      entry.title,
      contentResult.getValue()!,
      entry.createdAt,
      entry.modifiedAt,
      entry.folderId
    ))
  }

  saveFile(id: string, title: string, content: string): Result<void, AppError> {
    const now: number = Date.now()

    const writeResult: Result<void, AppError> =
      this.writeTextFileWithRetry('mxnote/notes/' + id + '.md', content)
    if (!writeResult.isOk()) {
      return err(writeResult.getError()!)
    }

    const idxResult: Result<IndexEntry[], AppError> = this.readIndex()
    if (!idxResult.isOk()) {
      return err(idxResult.getError()!)
    }

    const index: IndexEntry[] = idxResult.getValue()!
    let found: boolean = false
    for (let i: number = 0; i < index.length; i++) {
      if (index[i].id === id) {
        index[i].title = title
        index[i].modifiedAt = now
        found = true
        break
      }
    }
    if (!found) {
      return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED, 'File not found in index: ' + id))
    }

    return this.writeIndexWithRetry(index)
  }

  deleteFile(id: string): Result<void, AppError> {
    const path: string = 'mxnote/notes/' + id + '.md'
    this.deleteFileIfExists(path)

    const idxResult: Result<IndexEntry[], AppError> = this.readIndex()
    if (!idxResult.isOk()) {
      return err(idxResult.getError()!)
    }

    const index: IndexEntry[] = idxResult.getValue()!
    const filtered: IndexEntry[] = []
    for (let i: number = 0; i < index.length; i++) {
      if (index[i].id !== id) {
        filtered.push(index[i])
      }
    }
    if (filtered.length === index.length) {
      return ok(undefined) // already gone
    }

    return this.writeIndexWithRetry(filtered)
  }

  renameFile(id: string, newTitle: string): Result<void, AppError> {
    const idxResult: Result<IndexEntry[], AppError> = this.readIndex()
    if (!idxResult.isOk()) {
      return err(idxResult.getError()!)
    }

    const index: IndexEntry[] = idxResult.getValue()!
    let found: boolean = false
    for (let i: number = 0; i < index.length; i++) {
      if (index[i].id === id) {
        index[i].title = newTitle
        index[i].modifiedAt = Date.now()
        found = true
        break
      }
    }
    if (!found) {
      return err(new AppError(ErrorCode.STORAGE_READ_FAILED, 'File not found: ' + id))
    }

    return this.writeIndexWithRetry(index)
  }

  listFiles(): Result<NoteFile[], AppError> {
    const idxResult: Result<IndexEntry[], AppError> = this.readIndex()
    if (!idxResult.isOk()) {
      return err(idxResult.getError()!)
    }

    const index: IndexEntry[] = idxResult.getValue()!
    // sort by modifiedAt descending
    for (let i: number = 0; i < index.length; i++) {
      for (let j: number = i + 1; j < index.length; j++) {
        if (index[j].modifiedAt > index[i].modifiedAt) {
          const tmp: IndexEntry = index[i]
          index[i] = index[j]
          index[j] = tmp
        }
      }
    }

    const files: NoteFile[] = []
    for (let i: number = 0; i < index.length; i++) {
      const e: IndexEntry = index[i]
      files.push(new NoteFile(e.id, e.title, '', e.createdAt, e.modifiedAt, e.folderId))
    }

    return ok(files)
  }

  // ═══════════════════════════════════════════════════════
  // 文件夹操作
  // ═══════════════════════════════════════════════════════

  createFolder(name: string, parentId: string | null = null): Result<Folder, AppError> {
    const id: string = 'folder_' + generateId()
    const now: number = Date.now()

    let dirRelativePath: string
    if (parentId) {
      dirRelativePath = NOTES_DIR + '/' + parentId + '/' + id
    } else {
      dirRelativePath = NOTES_DIR + '/' + id
    }

    // 递归创建目录
    const mkResult: Result<void, AppError> = this.mkdirRecursive(dirRelativePath)
    if (!mkResult.isOk()) {
      return err(mkResult.getError()!)
    }

    return ok(new Folder(id, name, parentId, now))
  }

  listFolders(): Result<Folder[], AppError> {
    try {
      const folders: Folder[] = []
      const notesPath: string = this.basePath + '/' + NOTES_DIR
      // ensure notes dir exists
      try { fs.statSync(notesPath) } catch (e) { return ok([]) }

      const dir: string[] = fs.listFileSync(notesPath)
      for (let i: number = 0; i < dir.length; i++) {
        const name: string = dir[i]
        const fullPath: string = notesPath + '/' + name
        try {
          const stat: fs.Stat = fs.statSync(fullPath)
          if (stat.isDirectory()) {
            folders.push(new Folder(name, name, null, 0))
          }
        } catch (e) {
          // skip
        }
      }
      return ok(folders)
    } catch (e) {
      return ok([])
    }
  }

  /** 递归创建目录: 从根开始逐级创建 */
  private mkdirRecursive(relativePath: string): Result<void, AppError> {
    try {
      const parts: string[] = relativePath.split('/')
      let currentPath: string = this.basePath
      for (let i: number = 0; i < parts.length; i++) {
        if (parts[i].length === 0) continue
        currentPath += '/' + parts[i]
        try {
          fs.statSync(currentPath)
        } catch (e) {
          try {
            fs.mkdirSync(currentPath)
          } catch (e2) {
            return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED,
              'Failed to create directory: ' + currentPath))
          }
        }
      }
      return ok(undefined)
    } catch (e) {
      return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED, 'mkdirRecursive failed'))
    }
  }

  // ═══════════════════════════════════════════════════════
  // 配置管理 (config.json)
  // ═══════════════════════════════════════════════════════

  loadConfig(): Result<AppConfig, AppError> {
    try {
      const raw: string = this.readRawTextFile(CONFIG_FILE)
      if (!raw) {
        return ok(DEFAULT_CONFIG)
      }
      const cfg: AppConfig = JSON.parse(raw) as AppConfig
      if (!cfg.layout) {
        cfg.layout = DEFAULT_CONFIG.layout
      }
      return ok(cfg)
    } catch (e) {
      return ok(DEFAULT_CONFIG)
    }
  }

  saveConfig(config: AppConfig): Result<void, AppError> {
    try {
      const json: string = JSON.stringify(config)
      return this.writeTextFileWithRetry(CONFIG_FILE, json)
    } catch (e) {
      return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED, 'Failed to serialize config'))
    }
  }

  // ═══════════════════════════════════════════════════════
  // 数据迁移 — Preferences → filesystem
  // ═══════════════════════════════════════════════════════

  needsMigration(): boolean {
    try {
      const flagPath: string = this.basePath + '/' + MIGRATED_FLAG
      try {
        fs.statSync(flagPath)
        return false
      } catch (e) {
        // marker doesn't exist — needs migration
        return true
      }
    } catch (e) {
      return false
    }
  }

  /** 迁移条目类型 (Preferences 旧格式) */
  migrateFromPreferences(indexJson: string, entries: Map<string, string>): Result<number, AppError> {
    try {
      const oldIndex: OldIndexEntry[] = JSON.parse(indexJson) as OldIndexEntry[]

      const newIndex: IndexEntry[] = []
      let migratedCount: number = 0

      for (let i: number = 0; i < oldIndex.length; i++) {
        const item: OldIndexEntry = oldIndex[i]
        const content: string | undefined = entries.get(item.id)
        if (content === undefined && content !== '') {
          continue
        }

        const writeResult: Result<void, AppError> = this.writeTextFile(
          'mxnote/notes/' + item.id + '.md',
          content ?? ''
        )
        if (!writeResult.isOk()) {
          this.writeMigrationFailedFlag()
          return err(new AppError(
            ErrorCode.STORAGE_WRITE_FAILED,
            'Migration failed at file ' + (i + 1).toString() + '/' + oldIndex.length.toString() + ': ' + item.title
          ))
        }

        const newEntry: IndexEntry = {
          id: item.id,
          title: item.title,
          createdAt: item.createdAt,
          modifiedAt: item.modifiedAt,
          folderId: null
        }
        newIndex.push(newEntry)
        migratedCount++
      }

      const idxResult: Result<void, AppError> = this.writeIndexWithRetry(newIndex)
      if (!idxResult.isOk()) {
        this.writeMigrationFailedFlag()
        return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED, 'Migration failed: could not write index'))
      }

      this.writeMigratedFlag()
      return ok(migratedCount)
    } catch (e) {
      this.writeMigrationFailedFlag()
      return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED,
        'Migration failed: ' + (e as Error).message))
    }
  }

  writeMigratedFlag(): void {
    try {
      const flagPath: string = this.basePath + '/' + MIGRATED_FLAG
      const file: fs.File = fs.openSync(flagPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
      fs.writeSync(file.fd, '1')
      fs.closeSync(file)
    } catch (e) {
      // non-blocking
    }
  }

  writeMigrationFailedFlag(): void {
    try {
      const flagPath: string = this.basePath + '/' + MIGRATION_FAILED_FLAG
      const file: fs.File = fs.openSync(flagPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
      fs.writeSync(file.fd, '1')
      fs.closeSync(file)
    } catch (e) {
      // non-blocking
    }
  }

  hasMigrationFailed(): boolean {
    try {
      fs.statSync(this.basePath + '/' + MIGRATION_FAILED_FLAG)
      return true
    } catch (e) {
      return false
    }
  }

  // ═══════════════════════════════════════════════════════
  // Private helpers
  // ═══════════════════════════════════════════════════════

  private readIndex(): Result<IndexEntry[], AppError> {
    try {
      const raw: string = this.readRawTextFile(INDEX_FILE)
      if (!raw) {
        return ok([])
      }
      return ok(JSON.parse(raw) as IndexEntry[])
    } catch (e) {
      return ok([])
    }
  }

  private writeIndexWithRetry(index: IndexEntry[]): Result<void, AppError> {
    try {
      const json: string = JSON.stringify(index)
      const result: Result<void, AppError> = this.writeTextFileWithRetry(INDEX_FILE, json)
      return result
    } catch (e) {
      return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED, 'Failed to serialize index'))
    }
  }

  private writeTextFileWithRetry(relativePath: string, content: string): Result<void, AppError> {
    const firstAttempt: Result<void, AppError> = this.writeTextFile(relativePath, content)
    if (firstAttempt.isOk()) {
      return firstAttempt
    }
    return this.writeTextFile(relativePath, content)
  }

  private writeTextFile(relativePath: string, content: string): Result<void, AppError> {
    try {
      const fullPath: string = this.basePath + '/' + relativePath
      const file: fs.File = fs.openSync(fullPath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, content)
      fs.closeSync(file)
      return ok(undefined)
    } catch (e) {
      return err(new AppError(
        ErrorCode.STORAGE_WRITE_FAILED,
        'Write failed: ' + relativePath + ' — ' + (e as Error).message
      ))
    }
  }

  private readTextFile(relativePath: string): Result<string, AppError> {
    try {
      const fullPath: string = this.basePath + '/' + relativePath
      const raw: string = fs.readTextSync(fullPath)
      return ok(raw)
    } catch (e) {
      return err(new AppError(
        ErrorCode.STORAGE_READ_FAILED,
        'Read failed: ' + relativePath + ' — ' + (e as Error).message
      ))
    }
  }

  private readRawTextFile(relativePath: string): string {
    try {
      const fullPath: string = this.basePath + '/' + relativePath
      return fs.readTextSync(fullPath)
    } catch (e) {
      return ''
    }
  }

  private ensureDir(relativePath: string): void {
    const fullPath: string = this.basePath + '/' + relativePath
    try {
      fs.statSync(fullPath)
    } catch (e) {
      // 递归创建
      const parts: string[] = relativePath.split('/')
      let currentPath: string = this.basePath
      for (let i: number = 0; i < parts.length; i++) {
        if (parts[i].length === 0) continue
        currentPath += '/' + parts[i]
        try { fs.statSync(currentPath) } catch (e2) {
          try { fs.mkdirSync(currentPath) } catch (e3) { /* best effort */ }
        }
      }
    }
  }

  private deleteFileIfExists(relativePath: string): void {
    try {
      const fullPath: string = this.basePath + '/' + relativePath
      fs.unlinkSync(fullPath)
    } catch (e) {
      // silent
    }
  }
}
