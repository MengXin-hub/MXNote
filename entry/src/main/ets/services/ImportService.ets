/**
 * ImportService — 导入 .md 文件选择器 + 内容读取。
 */
import { picker } from '@kit.CoreFileKit'
import { fileIo as fs } from '@kit.CoreFileKit'

export interface ImportResult {
  success: boolean
  fileName: string
  content: string
}

export class ImportService {
  static async pickAndRead(): Promise<ImportResult> {
    try {
      const opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions()
      opts.maxSelectNumber = 1
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker()
      const uris: string[] = await docPicker.select(opts)

      if (!uris || uris.length === 0) {
        return { success: false, fileName: '', content: '' }
      }

      const uri: string = uris[0]
      const parts: string[] = uri.split('/')
      const fileName: string = parts.length > 0 ? parts[parts.length - 1] : 'imported.md'

      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      const stat: fs.Stat = fs.statSync(uri)
      const buf: ArrayBuffer = new ArrayBuffer(stat.size > 0 ? stat.size : 4096)
      const readLen: number = fs.readSync(file.fd, buf)
      fs.closeSync(file)

      const arr: Uint8Array = new Uint8Array(buf, 0, readLen)
      let content: string = ''
      for (let i: number = 0; i < arr.length; i++) { content += String.fromCharCode(arr[i]) }
      return { success: true, fileName: fileName, content: content }
    } catch (e) {
      return { success: false, fileName: '', content: '' }
    }
  }
}
