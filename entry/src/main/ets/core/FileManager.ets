/**
 * FileManager — 纯委托层。
 *
 * 所有文件 CRUD 委托给 FileSystemManager。
 * 保留原有公开 API 以兼容现有调用方 (Index.ets, FileListPage.ets)。
 * 不再维护内部 Preferences 逻辑。
 */
import { ok, err, Result, AppError, ErrorCode } from '../model/Result'
import { NoteFile, Folder, generateId } from '../model/NoteFile'
import { FileSystemManager } from './FileSystemManager'

export class FileManager {
  private fsm: FileSystemManager

  constructor(context: Context) {
    this.fsm = new FileSystemManager()
    const filesDir: string = context.filesDir
    this.fsm.init(filesDir)
  }

  // 将 FileSystemManager 实例暴露给 EntryAbility 等需要迁移的调用方
  getFileSystemManager(): FileSystemManager {
    return this.fsm
  }

  /** @deprecated 使用 init(filesDir) 替代，保留兼容 */
  async init(): Promise<void> {
    // no-op — initialization is done in constructor
  }

  async listFiles(): Promise<Result<NoteFile[], AppError>> {
    return Promise.resolve(this.fsm.listFiles())
  }

  async createFile(
    title: string,
    content: string,
    folderId: string | null = null
  ): Promise<Result<NoteFile, AppError>> {
    return Promise.resolve(this.fsm.createFile(title, content, folderId))
  }

  async readFile(id: string): Promise<Result<NoteFile, AppError>> {
    return Promise.resolve(this.fsm.readFile(id))
  }

  async saveFile(id: string, title: string, content: string): Promise<Result<void, AppError>> {
    return Promise.resolve(this.fsm.saveFile(id, title, content))
  }

  async deleteFile(id: string): Promise<Result<void, AppError>> {
    return Promise.resolve(this.fsm.deleteFile(id))
  }

  async renameFile(id: string, newTitle: string): Promise<Result<void, AppError>> {
    return Promise.resolve(this.fsm.renameFile(id, newTitle))
  }

  // ══ 文件夹操作 ═════════════════════════════════════

  async createFolder(name: string, parentId: string | null = null): Promise<Result<Folder, AppError>> {
    return Promise.resolve(this.fsm.createFolder(name, parentId))
  }

  async listFolders(): Promise<Result<Folder[], AppError>> {
    return Promise.resolve(this.fsm.listFolders())
  }
}
