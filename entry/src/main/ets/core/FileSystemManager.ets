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
      this.ensureDir('mxnote/images')
      return ok(undefined)
    } catch (e) {
      return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED,
        'Failed to init filesystem: ' + (e as Error).message))
    }
  }

  getBasePath(): string {
    return this.basePath
  }

  getImagesDir(): string {
    return this.basePath + '/mxnote/images'
  }

  /** 检查图片文件是否存在于沙箱中 */
  imagePathExists(relativePath: string): boolean {
    try {
      fs.statSync(this.basePath + '/' + relativePath)
      return true
    } catch (e) {
      return false
    }
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

    // 根据 folderId 构造正确的 .md 文件路径
    let mdPath: string
    if (entry.folderId) {
      mdPath = NOTES_DIR + '/' + entry.folderId + '/' + id + '.md'
    } else {
      mdPath = NOTES_DIR + '/' + id + '.md'
    }

    const contentResult: Result<string, AppError> = this.readTextFile(mdPath)
    if (!contentResult.isOk()) {
      // 回退: 尝试根目录路径 (兼容旧数据)
      const fallbackResult: Result<string, AppError> = this.readTextFile(NOTES_DIR + '/' + id + '.md')
      if (!fallbackResult.isOk()) {
        return err(contentResult.getError()!)
      }
      return ok(new NoteFile(
        entry.id, entry.title, fallbackResult.getValue()!,
        entry.createdAt, entry.modifiedAt, entry.folderId
      ))
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

    // 从 index 中查找 folderId 以确定正确路径
    let mdPath: string = NOTES_DIR + '/' + id + '.md'
    const idxCheck: Result<IndexEntry[], AppError> = this.readIndex()
    if (idxCheck.isOk()) {
      const idxEntries: IndexEntry[] = idxCheck.getValue()!
      for (let i: number = 0; i < idxEntries.length; i++) {
        if (idxEntries[i].id === id && idxEntries[i].folderId) {
          mdPath = NOTES_DIR + '/' + idxEntries[i].folderId + '/' + id + '.md'
          break
        }
      }
    }

    const writeResult: Result<void, AppError> = this.writeTextFileWithRetry(mdPath, content)
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

  /**
   * 创建文件夹: 创建物理目录 + 写入 .name 元数据文件。
   */
  createFolder(name: string, parentId: string | null = null): Result<Folder, AppError> {
    const id: string = 'folder_' + generateId()
    const now: number = Date.now()

    let dirRelativePath: string
    if (parentId) {
      dirRelativePath = NOTES_DIR + '/' + parentId + '/' + id
    } else {
      dirRelativePath = NOTES_DIR + '/' + id
    }

    const mkResult: Result<void, AppError> = this.mkdirRecursive(dirRelativePath)
    if (!mkResult.isOk()) {
      return err(mkResult.getError()!)
    }

    // 写入 .name 文件 —— 文件夹显示名唯一持久化来源
    const nameFile: string = dirRelativePath + '/.name'
    const wResult: Result<void, AppError> = this.writeTextFile(nameFile, name)
    if (!wResult.isOk()) {
      // 回滚
      try { fs.rmdirSync(this.basePath + '/' + dirRelativePath) } catch (e) {}
      return err(wResult.getError()!)
    }

    return ok(new Folder(id, name, parentId, now))
  }

  /**
   * 重命名文件夹: 更新 .name 文件内容。
   */
  renameFolder(id: string, newName: string): Result<void, AppError> {
    const nameFile: string = NOTES_DIR + '/' + id + '/.name'
    return this.writeTextFileWithRetry(nameFile, newName)
  }

  /**
   * 删除文件夹: 递归删除目录内容 + 将子文件 folderId 置 null。
   */
  deleteFolder(id: string): Result<void, AppError> {
    const fdPath: string = NOTES_DIR + '/' + id
    const fullPath: string = this.basePath + '/' + fdPath
    try {
      this.removeDirRecursive(fullPath)
    } catch (e) {
      return err(new AppError(ErrorCode.STORAGE_WRITE_FAILED, 'Failed to delete folder'))
    }
    // 将文件夹内的文件移出文件夹
    const idxResult: Result<IndexEntry[], AppError> = this.readIndex()
    if (idxResult.isOk()) {
      const index: IndexEntry[] = idxResult.getValue()!
      let changed: boolean = false
      for (let i: number = 0; i < index.length; i++) {
        if (index[i].folderId === id) { index[i].folderId = null; changed = true }
      }
      if (changed) this.writeIndexWithRetry(index)
    }
    return ok(undefined)
  }

  /**
   * 列出所有文件夹，从 .name 文件读取显示名称。
   */
  listFolders(): Result<Folder[], AppError> {
    try {
      const folders: Folder[] = []
      const notesPath: string = this.basePath + '/' + NOTES_DIR
      try { fs.statSync(notesPath) } catch (e) { return ok([]) }

      const dir: string[] = fs.listFileSync(notesPath)
      for (let i: number = 0; i < dir.length; i++) {
        const dirName: string = dir[i]
        const fullPath: string = notesPath + '/' + dirName
        try {
          const stat: fs.Stat = fs.statSync(fullPath)
          if (!stat.isDirectory()) continue
          // 读取 .name 文件获取显示名
          const nameFile: string = fullPath + '/.name'
          let displayName: string = dirName
          try {
            displayName = fs.readTextSync(nameFile).trim()
          } catch (e) {
            // .name 缺失时回退到目录名
          }
          folders.push(new Folder(dirName, displayName, null, 0))
        } catch (e) { /* skip */ }
      }
      return ok(folders)
    } catch (e) {
      return ok([])
    }
  }

  /**
   * 将文件移动到指定文件夹。
   */
  moveFileToFolder(fileId: string, targetFolderId: string | null): Result<void, AppError> {
    const idxResult: Result<IndexEntry[], AppError> = this.readIndex()
    if (!idxResult.isOk()) return err(idxResult.getError()!)
    const index: IndexEntry[] = idxResult.getValue()!
    let found: boolean = false
    for (let i: number = 0; i < index.length; i++) {
      if (index[i].id === fileId) { index[i].folderId = targetFolderId; found = true; break }
    }
    if (!found) {
      return err(new AppError(ErrorCode.STORAGE_READ_FAILED, 'File not found: ' + fileId))
    }
    // 移动 .md 文件
    const srcPath: string = NOTES_DIR + '/' + fileId + '.md'
    let dstPath: string
    if (targetFolderId) {
      this.mkdirRecursive(NOTES_DIR + '/' + targetFolderId)
      dstPath = NOTES_DIR + '/' + targetFolderId + '/' + fileId + '.md'
    } else {
      dstPath = NOTES_DIR + '/' + fileId + '.md'
    }
    if (srcPath !== dstPath) {
      try {
        fs.renameSync(this.basePath + '/' + srcPath, this.basePath + '/' + dstPath)
      } catch (e) { /* 文件可能不在原位置，忽略 */ }
    }
    return this.writeIndexWithRetry(index)
  }

  /** 递归删除目录及其内容 */
  private removeDirRecursive(fullPath: string): void {
    try {
      const entries: string[] = fs.listFileSync(fullPath)
      for (let i: number = 0; i < entries.length; i++) {
        const entryPath: string = fullPath + '/' + entries[i]
        try {
          const stat: fs.Stat = fs.statSync(entryPath)
          if (stat.isDirectory()) { this.removeDirRecursive(entryPath) }
          else { fs.unlinkSync(entryPath) }
        } catch (e) { try { fs.unlinkSync(entryPath) } catch (e2) {} }
      }
      fs.rmdirSync(fullPath)
    } catch (e) { try { fs.rmdirSync(fullPath) } catch (e2) {} }
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
