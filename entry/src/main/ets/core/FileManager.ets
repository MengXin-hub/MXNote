import { preferences } from '@kit.ArkData'
import { ok, err, Result, AppError, ErrorCode } from '../model/Result'
import { NoteFile, generateId } from '../model/NoteFile'

/**
 * FileManager — 笔记文件的 CRUD 管理器。
 *
 * V1 使用 Preferences (key-value) 做轻量持久化。
 * 文件索引存储在单个 key 下 (JSON 数组)，每个文件内容存储在独立 key 下。
 *
 * 存储布局:
 *   mxnote_file_index → JSON<{id,title,createdAt,modifiedAt}[]>  (不含 content)
 *   mxnote_file_{id}  → content 字符串
 */
const PREF_NAME: string = 'mxnote_file_store'
const INDEX_KEY: string = 'mxnote_file_index'

export class FileManager {
  private context: Context
  private pref: preferences.Preferences | null = null

  constructor(context: Context) {
    this.context = context
  }

  /**
   * 初始化 Preferences 存储。
   */
  async init(): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(this.context, PREF_NAME)
    } catch (e) {
      this.pref = null
    }
  }

  /**
   * 获取所有笔记文件的元数据列表（不含 content）。
   * 按 modifiedAt 降序排列。
   */
  async listFiles(): Promise<Result<NoteFile[], AppError>> {
    if (!this.pref) {
      await this.init()
    }
    try {
      const raw: string | null = this.pref!.getSync(INDEX_KEY, '[]') as string
      const list: NoteFile[] = JSON.parse(raw)

      // 按修改时间降序排序
      list.sort((a: NoteFile, b: NoteFile): number => b.modifiedAt - a.modifiedAt)

      return ok<NoteFile[], AppError>(list)
    } catch (e) {
      return err<NoteFile[], AppError>(
        new AppError(ErrorCode.STORAGE_READ_FAILED, 'Failed to list files')
      )
    }
  }

  /**
   * 创建新笔记文件。
   */
  async createFile(
    title: string,
    content: string,
  ): Promise<Result<NoteFile, AppError>> {
    if (!this.pref) {
      await this.init()
    }
    try {
      const id: string = generateId()
      const now: number = Date.now()
      const file: NoteFile = new NoteFile(id, title, content, now, now)

      // 保存 content
      this.pref!.putSync(`mxnote_file_${id}`, content)

      // 更新索引
      const index: NoteFile[] = await this.readIndex()
      index.push(new NoteFile(file.id, file.title, '', file.createdAt, file.modifiedAt))
      await this.writeIndex(index)

      return ok<NoteFile, AppError>(file)
    } catch (e) {
      return err<NoteFile, AppError>(
        new AppError(ErrorCode.STORAGE_WRITE_FAILED, 'Failed to create file')
      )
    }
  }

  /**
   * 读取笔记文件的完整内容。
   */
  async readFile(id: string): Promise<Result<NoteFile, AppError>> {
    if (!this.pref) {
      await this.init()
    }
    try {
      const content: string = this.pref!.getSync(`mxnote_file_${id}`, '') as string
      const index: NoteFile[] = await this.readIndex()
      const meta: NoteFile | undefined = index.find(
        (f: NoteFile): boolean => f.id === id,
      )

      if (!meta) {
        return err<NoteFile, AppError>(
          new AppError(ErrorCode.STORAGE_READ_FAILED, 'File not found')
        )
      }

      return ok<NoteFile, AppError>(
        new NoteFile(meta.id, meta.title, content, meta.createdAt, meta.modifiedAt),
      )
    } catch (e) {
      return err<NoteFile, AppError>(
        new AppError(ErrorCode.STORAGE_READ_FAILED, 'Failed to read file')
      )
    }
  }

  /**
   * 保存笔记文件的内容和标题。
   */
  async saveFile(id: string, title: string, content: string): Promise<Result<void, AppError>> {
    if (!this.pref) {
      await this.init()
    }
    try {
      const now: number = Date.now()
      this.pref!.putSync(`mxnote_file_${id}`, content)

      // 更新索引中的标题和修改时间
      const index: NoteFile[] = await this.readIndex()
      const file: NoteFile | undefined = index.find(
        (f: NoteFile): boolean => f.id === id,
      )
      if (file) {
        file.title = title
        file.modifiedAt = now
        await this.writeIndex(index)
      }

      return ok<void, AppError>(undefined)
    } catch (e) {
      return err<void, AppError>(
        new AppError(ErrorCode.STORAGE_WRITE_FAILED, 'Failed to save file')
      )
    }
  }

  /**
   * 删除笔记文件。
   */
  async deleteFile(id: string): Promise<Result<void, AppError>> {
    if (!this.pref) {
      await this.init()
    }
    try {
      this.pref!.deleteSync(`mxnote_file_${id}`)

      const index: NoteFile[] = await this.readIndex()
      const filtered: NoteFile[] = index.filter(
        (f: NoteFile): boolean => f.id !== id,
      )
      await this.writeIndex(filtered)

      return ok<void, AppError>(undefined)
    } catch (e) {
      return err<void, AppError>(
        new AppError(ErrorCode.STORAGE_WRITE_FAILED, 'Failed to delete file')
      )
    }
  }

  /**
   * 重命名笔记文件。
   */
  async renameFile(id: string, newTitle: string): Promise<Result<void, AppError>> {
    return this.saveFile(id, newTitle, '')
  }

  // ─── Private ─────────────────────────────────────────────

  private async readIndex(): Promise<NoteFile[]> {
    try {
      const raw: string = this.pref!.getSync(INDEX_KEY, '[]') as string
      return JSON.parse(raw)
    } catch (e) {
      return []
    }
  }

  private async writeIndex(index: NoteFile[]): Promise<void> {
    try {
      const json: string = JSON.stringify(index)
      this.pref!.putSync(INDEX_KEY, json)
      await this.pref!.flush()
    } catch (e) {
      // storage write failed silently — data will be retried on next save
    }
  }
}
