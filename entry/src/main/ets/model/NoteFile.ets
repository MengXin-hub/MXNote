/**
 * NoteFile — 笔记文件的元数据模型。
 *
 * 每个 NoteFile 对应一个独立的 .md 笔记文档。
 * content 存储在 Preferences 中，id 为 GUID。
 */
export class NoteFile {
  id: string = ''
  title: string = ''
  content: string = ''
  createdAt: number = 0 // Unix ms
  modifiedAt: number = 0

  constructor(id: string, title: string, content: string, createdAt: number, modifiedAt: number) {
    this.id = id
    this.title = title
    this.content = content
    this.createdAt = createdAt
    this.modifiedAt = modifiedAt
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
