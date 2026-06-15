/**
 * FileSystemManager 核心回归测试。
 *
 * 覆盖: CRUD 操作、错误处理、文件夹操作、索引持久化。
 */
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium'
import { FileSystemManager } from '../../../main/ets/core/FileSystemManager'
import { NoteFile, Folder } from '../../../main/ets/model/NoteFile'
import { Result, AppError } from '../../../main/ets/model/Result'
import { fileIo as fs } from '@kit.CoreFileKit'

export default function fileSystemManagerTest() {
  describe('FileSystemManager', () => {
    let fsm: FileSystemManager
    let testDir: string

    beforeAll(() => {
      fsm = new FileSystemManager()
      // 使用 /tmp 作为测试根目录（模拟 filesDir）
      testDir = '/tmp/mxnote_test_' + Date.now().toString()
      const result = fsm.init(testDir)
      expect(result.isOk()).assertTrue()
    })

    afterAll(() => {
      // 清理测试目录
      try {
        const list: string[] = fs.listFileSync(testDir)
        for (let i: number = 0; i < list.length; i++) {
          try { fs.unlinkSync(testDir + '/' + list[i]) } catch (e) {}
        }
        fs.rmdirSync(testDir)
      } catch (e) {}
    })

    // ══════════════════════════════════════════════
    // CRUD Tests
    // ══════════════════════════════════════════════

    it('createFile_returns_valid_note', 0, () => {
      const result: Result<NoteFile, AppError> = fsm.createFile('测试笔记', '# Hello')
      expect(result.isOk()).assertTrue()
      const file: NoteFile = result.getValue()!
      expect(file.title).assertEqual('测试笔记')
      expect(file.id.length).assertLarger(0)
    })

    it('readFile_returns_saved_content', 0, () => {
      const created: Result<NoteFile, AppError> = fsm.createFile('读取测试', '内容123')
      expect(created.isOk()).assertTrue()
      const id: string = created.getValue()!.id

      const read: Result<NoteFile, AppError> = fsm.readFile(id)
      expect(read.isOk()).assertTrue()
      expect(read.getValue()!.content).assertEqual('内容123')
    })

    it('saveFile_persists_updated_content', 0, () => {
      const created: Result<NoteFile, AppError> = fsm.createFile('保存测试', '旧内容')
      expect(created.isOk()).assertTrue()
      const id: string = created.getValue()!.id

      const saved: Result<void, AppError> = fsm.saveFile(id, '保存测试_已改', '新内容')
      expect(saved.isOk()).assertTrue()

      const read: Result<NoteFile, AppError> = fsm.readFile(id)
      expect(read.getValue()!.content).assertEqual('新内容')
      expect(read.getValue()!.title).assertEqual('保存测试_已改')
    })

    it('deleteFile_removes_from_index', 0, () => {
      const created: Result<NoteFile, AppError> = fsm.createFile('删除测试', '待删除')
      expect(created.isOk()).assertTrue()
      const id: string = created.getValue()!.id

      const deleted: Result<void, AppError> = fsm.deleteFile(id)
      expect(deleted.isOk()).assertTrue()

      const read: Result<NoteFile, AppError> = fsm.readFile(id)
      expect(read.isOk()).assertFalse()
    })

    it('renameFile_updates_title_in_index', 0, () => {
      const created: Result<NoteFile, AppError> = fsm.createFile('旧标题', '内容')
      expect(created.isOk()).assertTrue()
      const id: string = created.getValue()!.id

      const renamed: Result<void, AppError> = fsm.renameFile(id, '新标题')
      expect(renamed.isOk()).assertTrue()

      const read: Result<NoteFile, AppError> = fsm.readFile(id)
      expect(read.getValue()!.title).assertEqual('新标题')
    })

    // ══════════════════════════════════════════════
    // Error Handling Tests
    // ══════════════════════════════════════════════

    it('readFile_nonexistent_returns_error', 0, () => {
      const result: Result<NoteFile, AppError> = fsm.readFile('不存在的id')
      expect(result.isOk()).assertFalse()
    })

    it('saveFile_nonexistent_returns_error', 0, () => {
      const result: Result<void, AppError> = fsm.saveFile('不存在的id', '标题', '内容')
      expect(result.isOk()).assertFalse()
    })

    it('createFile_empty_title_still_succeeds', 0, () => {
      // 空标题不应崩溃——使用默认值或空标题创建
      const result: Result<NoteFile, AppError> = fsm.createFile('', '内容')
      expect(result.isOk()).assertTrue()
    })

    it('createFile_with_guid_filename_handles_special_chars', 0, () => {
      // 标题含非法字符 '测试/笔记:test*\"<>|'
      const result: Result<NoteFile, AppError> = fsm.createFile('测试/笔记:test*"<>|', '内容')
      expect(result.isOk()).assertTrue()
      // 文件以 GUID 命名，标题保留原样
      const file: NoteFile = result.getValue()!
      expect(file.title).assertEqual('测试/笔记:test*"<>|')
    })

    // ══════════════════════════════════════════════
    // Folder Tests
    // ══════════════════════════════════════════════

    it('createFolder_creates_directory', 0, () => {
      const result: Result<Folder, AppError> = fsm.createFolder('我的文件夹')
      expect(result.isOk()).assertTrue()
      const folder: Folder = result.getValue()!
      expect(folder.name).assertEqual('我的文件夹')
    })

    // ══════════════════════════════════════════════
    // Config Tests
    // ══════════════════════════════════════════════

    it('loadConfig_returns_defaults_when_no_config', 0, () => {
      const result = fsm.loadConfig()
      expect(result.isOk()).assertTrue()
      const config = result.getValue()!
      expect(config.layout.leftWidth).assertEqual(240)
    })

    it('saveConfig_and_loadConfig_persists', 0, () => {
      const saved = fsm.saveConfig({
        layout: { leftWidth: 300, rightWidth: 400, leftVisible: false, rightVisible: true }
      })
      expect(saved.isOk()).assertTrue()

      const loaded = fsm.loadConfig()
      expect(loaded.getValue()!.layout.leftWidth).assertEqual(300)
      expect(loaded.getValue()!.layout.rightVisible).assertTrue()
    })
  })
}
