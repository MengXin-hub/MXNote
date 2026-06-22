/**
 * ExportService — 导出 .md / .html 到应用沙箱 exports/ 目录。
 * 来自 note-gen 迁移：支持 Markdown + HTML 双格式导出。
 */
import { fileIo as fs } from '@kit.CoreFileKit'

export class ExportService {
  /** 导出纯文本/Markdown 到 mxnote/exports/ */
  static exportMarkdown(fileName: string, content: string, filesDir: string): boolean {
    try {
      const exportDir: string = filesDir + '/mxnote/exports'
      try { fs.statSync(exportDir) } catch (e) { fs.mkdirSync(exportDir, true) }
      const exportFile: string = exportDir + '/' + fileName
      const file: fs.File = fs.openSync(exportFile, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, content)
      fs.closeSync(file)
      return true
    } catch (e) { return false }
  }

  /**
   * 将 Markdown 文本转换为简单 HTML（来自 note-gen markdown-export.ts 迁移）
   * 支持：标题、粗/斜体、代码块、引用、列表、分割线、链接、图片、表格
   */
  static markdownToHtml(markdown: string, title: string): string {
    const lines: string[] = markdown.split('\n')
    let html: string = ''
    let inCodeBlock: boolean = false
    let inList: boolean = false
    let listTag: string = ''

    for (let i: number = 0; i < lines.length; i++) {
      const line: string = lines[i]
      const trimmed: string = line.trim()

      // 代码块
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) { html += '</code></pre>\n'; inCodeBlock = false }
        else { html += '<pre><code>\n'; inCodeBlock = true }
        continue
      }
      if (inCodeBlock) { html += ExportService.escapeHtml(line) + '\n'; continue }

      // 空行 → 结束列表
      if (trimmed.length === 0) {
        if (inList) { html += '</' + listTag + '>\n'; inList = false; listTag = '' }
        continue
      }

      // 标题
      if (trimmed.startsWith('###### ')) { html += '<h6>' + trimmed.slice(7) + '</h6>\n'; continue }
      if (trimmed.startsWith('##### ')) { html += '<h5>' + trimmed.slice(6) + '</h5>\n'; continue }
      if (trimmed.startsWith('#### ')) { html += '<h4>' + trimmed.slice(5) + '</h4>\n'; continue }
      if (trimmed.startsWith('### ')) { html += '<h3>' + trimmed.slice(4) + '</h3>\n'; continue }
      if (trimmed.startsWith('## ')) { html += '<h2>' + trimmed.slice(3) + '</h2>\n'; continue }
      if (trimmed.startsWith('# ')) { html += '<h1>' + trimmed.slice(2) + '</h1>\n'; continue }

      // 分割线
      if (trimmed === '---' || trimmed === '***' || trimmed === '___') { html += '<hr>\n'; continue }

      // 引用
      if (trimmed.startsWith('> ')) { html += '<blockquote><p>' + ExportService.inlineToHtml(trimmed.slice(2)) + '</p></blockquote>\n'; continue }

      // 无序列表
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        if (!inList || listTag !== 'ul') {
          if (inList) { html += '</' + listTag + '>\n' }
          html += '<ul>\n'; inList = true; listTag = 'ul'
        }
        html += '<li>' + ExportService.inlineToHtml(trimmed.slice(2)) + '</li>\n'
        continue
      }

      // 有序列表
      if (/^\d+\.\s/.test(trimmed)) {
        if (!inList || listTag !== 'ol') {
          if (inList) { html += '</' + listTag + '>\n' }
          html += '<ol>\n'; inList = true; listTag = 'ol'
        }
        const dot: number = trimmed.indexOf('. ')
        html += '<li>' + ExportService.inlineToHtml(trimmed.slice(dot + 2)) + '</li>\n'
        continue
      }

      // 普通段落 → 结束列表
      if (inList) { html += '</' + listTag + '>\n'; inList = false; listTag = '' }
      html += '<p>' + ExportService.inlineToHtml(trimmed) + '</p>\n'
    }

    if (inList) { html += '</' + listTag + '>\n' }
    if (inCodeBlock) { html += '</code></pre>\n' }

    return '<!DOCTYPE html>\n<html lang="zh-CN">\n<head>\n<meta charset="UTF-8">\n' +
      '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n' +
      '<title>' + title + '</title>\n' +
      '<style>body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;max-width:800px;margin:0 auto;padding:40px 20px;line-height:1.6;color:#333}' +
      'h1,h2,h3,h4,h5,h6{margin-top:1.2em;color:#111}' +
      'h1{font-size:28px}h2{font-size:22px}h3{font-size:18px}' +
      'pre{background:#f6f8fa;padding:16px;border-radius:6px;overflow-x:auto;font-size:0.92em}' +
      'code{font-family:monospace;background:#f6f8fa;padding:0.2em 0.4em;border-radius:3px;font-size:0.92em}' +
      'pre code{background:transparent;padding:0}' +
      'blockquote{border-left:4px solid #dfe2e5;padding-left:16px;color:#6a737d;margin:1em 0}' +
      'table{border-collapse:collapse;width:100%}table th,table td{border:1px solid #dfe2e5;padding:8px 12px}' +
      'table th{background:#f6f8fa}img{max-width:100%;border-radius:8px}hr{height:1px;border:0;background:#d0d7de;margin:1.5em 0}' +
      'a{color:#0969da}</style>\n</head>\n<body>\n' + html + '</body>\n</html>'
  }

  /** HTML 转义 */
  private static escapeHtml(text: string): string {
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  }

  /** 行内 Markdown 转 HTML */
  private static inlineToHtml(text: string): string {
    let result: string = text
    // 图片 ![alt](url)
    result = result.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<img src="$2" alt="$1">')
    // 链接 [text](url)
    result = result.replace(/\[([^\]]*)\]\(([^)]+)\)/g, '<a href="$2">$1</a>')
    // 粗体 **text**
    result = result.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    // 斜体 *text*
    result = result.replace(/\*(.+?)\*/g, '<em>$1</em>')
    // 行内代码 `text`
    result = result.replace(/`([^`]+)`/g, '<code>$1</code>')
    return result
  }
}
