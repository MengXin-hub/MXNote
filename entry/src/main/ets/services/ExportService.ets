/**
 * ExportService — 导出 .md 到应用沙箱 exports/ 目录。
 * Phase 3 计划: 使用 filePicker.save() 让用户选择保存位置。
 */
import { fileIo as fs } from '@kit.CoreFileKit'

export class ExportService {
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
}
