/**
 * 数据迁移回归测试。
 *
 * 覆盖: 空数据迁移、有旧数据迁移、迁移失败恢复、重复迁移跳过。
 */
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium'
import { FileSystemManager } from '../../../main/ets/core/FileSystemManager'
import { Result, AppError } from '../../../main/ets/model/Result'
import { fileIo as fs } from '@kit.CoreFileKit'

export default function migrationTest() {
  describe('Data Migration', () => {
    let fsm: FileSystemManager
    let testDir: string

    beforeAll(() => {
      fsm = new FileSystemManager()
      testDir = '/tmp/mxnote_migrate_test_' + Date.now().toString()
      fsm.init(testDir)
    })

    afterAll(() => {
      try {
        const list: string[] = fs.listFileSync(testDir)
        for (let i: number = 0; i < list.length; i++) {
          try { fs.unlinkSync(testDir + '/' + list[i]) } catch (e) {}
        }
        fs.rmdirSync(testDir)
      } catch (e) {}
    })

    it('migrate_from_empty_preferences', 0, () => {
      // 空索引: 迁移应返回 0 条成功迁移
      const result: Result<number, AppError> = fsm.migrateFromPreferences('[]', new Map())
      expect(result.isOk()).assertTrue()
      expect(result.getValue()!).assertEqual(0)
    })

    it('migrate_with_valid_data', 0, () => {
      const noteId: string = 'note_test_001'
      const indexJson: string = JSON.stringify([
        { id: noteId, title: '测试笔记', createdAt: Date.now(), modifiedAt: Date.now() }
      ])
      const entries: Map<string, string> = new Map()
      entries.set(noteId, '# Hello World')

      const result: Result<number, AppError> = fsm.migrateFromPreferences(indexJson, entries)
      expect(result.isOk()).assertTrue()
      expect(result.getValue()!).assertEqual(1)

      // 验证迁移后的文件存在
      const readResult = fsm.readFile(noteId)
      expect(readResult.isOk()).assertTrue()
      expect(readResult.getValue()!.content).assertEqual('# Hello World')
      expect(readResult.getValue()!.title).assertEqual('测试笔记')
    })

    it('migrate_with_contentless_entry', 0, () => {
      // 标题存在但内容不存在: 应跳过该条目
      const noteId: string = 'note_missing_content'
      const indexJson: string = JSON.stringify([
        { id: noteId, title: '空内容笔记', createdAt: Date.now(), modifiedAt: Date.now() }
      ])
      const entries: Map<string, string> = new Map()
      // 不添加 noteId 的内容——模拟缺失

      const result: Result<number, AppError> = fsm.migrateFromPreferences(indexJson, entries)
      expect(result.isOk()).assertTrue()
      expect(result.getValue()!).assertEqual(0)
    })

    it('migrate_handles_corrupt_index_json', 0, () => {
      // 损坏的 JSON 索引: 应返回错误而非崩溃
      const result: Result<number, AppError> = fsm.migrateFromPreferences('这不是合法的JSON', new Map())
      expect(result.isOk()).assertFalse()
    })

    it('needsMigration_returns_false_after_migration', 0, () => {
      // 写入迁移标记后 needsMigration 返回 false
      fsm.writeMigratedFlag()
      expect(fsm.needsMigration()).assertFalse()
    })
  })
}
