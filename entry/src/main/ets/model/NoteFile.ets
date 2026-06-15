/**
 * NoteFile — 笔记文件的元数据模型。
 *
 * 每个 NoteFile 对应一个独立的 .md 笔记文档。
 * 文件以 GUID 命名存储在沙箱文件系统中。
 * folderId 为 null 表示根目录文件。
 */
export class NoteFile {
  id: string = ''
  title: string = ''
  content: string = ''
  createdAt: number = 0 // Unix ms
  modifiedAt: number = 0
  folderId: string | null = null

  constructor(
    id: string,
    title: string,
    content: string,
    createdAt: number,
    modifiedAt: number,
    folderId: string | null = null
  ) {
    this.id = id
    this.title = title
    this.content = content
    this.createdAt = createdAt
    this.modifiedAt = modifiedAt
    this.folderId = folderId
  }
}

/**
 * Folder — 文件夹模型。
 */
export class Folder {
  id: string = ''
  name: string = ''
  parentId: string | null = null
  createdAt: number = 0 // Unix ms

  constructor(id: string, name: string, parentId: string | null, createdAt: number) {
    this.id = id
    this.name = name
    this.parentId = parentId
    this.createdAt = createdAt
  }
}

/**
 * 生成简短的 GUID。
 */
export function generateId(): string {
  const ts: string = Date.now().toString(36)
  const rand: string = Math.floor(Math.random() * 100000).toString(36)
  return `note_${ts}_${rand}`
}

/**
 * 从格式化的时间戳生成可读日期字符串。
 */
export function formatTime(ms: number): string {
  const d: Date = new Date(ms)
  const y: number = d.getFullYear()
  const m: number = d.getMonth() + 1
  const day: number = d.getDate()
  const h: number = d.getHours()
  const min: number = d.getMinutes()

  const pad = (n: number): string => (n < 10 ? '0' + n : String(n))
  return `${y}-${pad(m)}-${pad(day)} ${pad(h)}:${pad(min)}`
}
