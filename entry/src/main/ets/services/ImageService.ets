/**
 * ImageService — 图片文件管理服务。
 *
 * 将用户选择的图片复制到应用沙箱 mxnote/images/ 目录，
 * 返回可嵌入 Markdown 的绝对路径。
 * 遵循 ExportService / ImportService 的静态方法模式。
 */
import { ok, err, Result, AppError, ErrorCode } from '../model/Result'
import { fileIo as fs } from '@kit.CoreFileKit'

const IMAGES_DIR: string = 'mxnote/images'

export interface ImageCopyResult {
  absolutePath: string   // 完整沙箱路径，用于 Markdown 嵌入
  fileName: string       // 纯文件名（含扩展名）
}

export class ImageService {
  /**
   * 将图片从源 URI 复制到沙箱 mxnote/images/ 目录。
   * @param sourceUri  — PhotoViewPicker / DocumentViewPicker 返回的 URI
   * @param filesDir   — 应用沙箱 filesDir
   * @returns ImageCopyResult (absolutePath, fileName) 或 AppError
   */
  static async copyImageToSandbox(
    sourceUri: string,
    filesDir: string
  ): Promise<Result<ImageCopyResult, AppError>> {
    try {
      // 1. 确保目标目录存在
      const imagesDir: string = filesDir + '/' + IMAGES_DIR
      try {
        fs.statSync(imagesDir)
      } catch (e) {
        fs.mkdirSync(imagesDir, true)
      }

      // 2. 提取文件扩展名
      const ext: string = ImageService.extractExtension(sourceUri)

      // 3. 生成唯一文件名
      const ts: string = Date.now().toString(36)
      const rand: string = Math.floor(Math.random() * 10000).toString(36)
      const fileName: string = 'img_' + ts + '_' + rand + ext
      const destPath: string = imagesDir + '/' + fileName

      // 4. 复制文件内容
      const srcFile: fs.File = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY)
      const stat: fs.Stat = fs.statSync(sourceUri)
      const bufSize: number = stat.size > 0 ? stat.size : 1048576  // 最大 1MB
      const buf: ArrayBuffer = new ArrayBuffer(bufSize)
      const readLen: number = fs.readSync(srcFile.fd, buf)
      fs.closeSync(srcFile)

      // 将读取到的内容写入目标文件
      const dstFile: fs.File = fs.openSync(
        destPath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC
      )
      // 截取实际读取的长度
      const data: ArrayBuffer = new ArrayBuffer(readLen)
      const srcView: Uint8Array = new Uint8Array(buf, 0, readLen)
      const dstView: Uint8Array = new Uint8Array(data)
      for (let i: number = 0; i < readLen; i++) {
        dstView[i] = srcView[i]
      }
      fs.writeSync(dstFile.fd, data)
      fs.closeSync(dstFile)

      const result: ImageCopyResult = { absolutePath: 'file://' + destPath, fileName: fileName }
      return ok(result)
    } catch (e) {
      return err(new AppError(
        ErrorCode.STORAGE_WRITE_FAILED,
        'Failed to copy image: ' + (e as Error).message
      ))
    }
  }

  /**
   * 从 URI 中提取文件扩展名（含点号，如 .jpg）。
   * URI 示例: file://media/Photo/1/IMG_20250101_123456.jpg
   *           或 /data/storage/.../photo.png
   */
  private static extractExtension(uri: string): string {
    // 去掉查询参数和 fragment
    const clean: string = uri.split('?')[0].split('#')[0]
    const segments: string[] = clean.split('/')
    const last: string = segments.length > 0 ? segments[segments.length - 1] : clean
    const dotIdx: number = last.lastIndexOf('.')
    if (dotIdx >= 0) {
      const ext: string = last.substring(dotIdx).toLowerCase()
      // 只接受常见图片扩展名
      if (ext === '.jpg' || ext === '.jpeg' || ext === '.png' ||
          ext === '.gif' || ext === '.bmp' || ext === '.webp' ||
          ext === '.svg') {
        return ext
      }
      return '.jpg' // 未知扩展名默认 jpg
    }
    return '.jpg' // 无扩展名默认 jpg
  }
}
