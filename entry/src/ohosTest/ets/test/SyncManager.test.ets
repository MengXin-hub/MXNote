import { describe, it, expect } from '@ohos/hypium'
import { SyncManager, ConflictResult, ConflictResolution } from '../../main/ets/core/SyncManager'
import { Session } from '../../main/ets/model/Session'

function makeSession(overrides: Partial<Session>): Session {
  const base: Session = {
    noteId: 'test-note-1',
    content: 'test content',
    cursorOffset: 0,
    scrollY: 0,
    lastModified: 1000000,
    deviceId: 'device-A',
    chunkIndex: -1,
    chunkCount: 0,
    chunkId: '',
  }
  // Manually merge overrides (ArkTS strict mode: no spread)
  const result: Session = {
    noteId: overrides.noteId !== undefined ? overrides.noteId : base.noteId,
    content: overrides.content !== undefined ? overrides.content : base.content,
    cursorOffset: overrides.cursorOffset !== undefined ? overrides.cursorOffset : base.cursorOffset,
    scrollY: overrides.scrollY !== undefined ? overrides.scrollY : base.scrollY,
    lastModified: overrides.lastModified !== undefined ? overrides.lastModified : base.lastModified,
    deviceId: overrides.deviceId !== undefined ? overrides.deviceId : base.deviceId,
    chunkIndex: overrides.chunkIndex !== undefined ? overrides.chunkIndex : base.chunkIndex,
    chunkCount: overrides.chunkCount !== undefined ? overrides.chunkCount : base.chunkCount,
    chunkId: overrides.chunkId !== undefined ? overrides.chunkId : base.chunkId,
  }
  return result
}

export default function SyncManagerTest() {
  describe('SyncManager', () => {

    describe('resolveConflict', () => {
      // LWW: remote is newer (outside 30s skew window)
      it('should accept remote when remote is clearly newer', () => {
        const sm: SyncManager = new SyncManager()
        const local: Session = makeSession({ lastModified: 1000000, content: 'local', deviceId: 'A' })

        const remote: Session = makeSession({
          lastModified: 1000000 + 60000,
          content: 'remote',
          deviceId: 'B',
        })

        const result: ConflictResult = sm.resolveConflict(local, remote)
        expect(result.resolution).assertEqual(ConflictResolution.ACCEPT_REMOTE)
        expect(result.winningSession.content).assertEqual('remote')
        expect(result.conflictCopy).assertNull()
      })

      // LWW: local is newer (outside 30s skew window)
      it('should keep local when local is clearly newer', () => {
        const sm: SyncManager = new SyncManager()
        const local: Session = makeSession({ lastModified: 1000000 + 60000, content: 'local', deviceId: 'A' })

        const remote: Session = makeSession({
          lastModified: 1000000,
          content: 'remote',
          deviceId: 'B',
        })

        const result: ConflictResult = sm.resolveConflict(local, remote)
        expect(result.resolution).assertEqual(ConflictResolution.KEEP_LOCAL)
        expect(result.winningSession.content).assertEqual('local')
        expect(result.conflictCopy).assertNull()
      })

      // Clock-skew protection: both edits within 30s → CONFLICT_BOTH
      it('should preserve both versions within 30s skew window', () => {
        const sm: SyncManager = new SyncManager()
        const local: Session = makeSession({ lastModified: 1000000, content: 'local edit', deviceId: 'A' })

        const remote: Session = makeSession({
          lastModified: 1000000 + 15000, // 15s later — within 30s window
          content: 'remote edit',
          deviceId: 'B',
        })

        const result: ConflictResult = sm.resolveConflict(local, remote)
        expect(result.resolution).assertEqual(ConflictResolution.CONFLICT_BOTH)
        expect(result.conflictCopy).assertNotNull()
        if (result.conflictCopy) {
          expect(result.conflictCopy.content).assertEqual('local edit')
        }
      })

      // Exact same timestamp → CONFLICT_BOTH
      it('should treat identical timestamps as conflict', () => {
        const sm: SyncManager = new SyncManager()
        const local: Session = makeSession({ lastModified: 1000000, content: 'same time local', deviceId: 'A' })

        const remote: Session = makeSession({
          lastModified: 1000000,
          content: 'same time remote',
          deviceId: 'B',
        })

        const result: ConflictResult = sm.resolveConflict(local, remote)
        expect(result.resolution).assertEqual(ConflictResolution.CONFLICT_BOTH)
      })

      // Exactly at 30s boundary → included in skew window
      it('should include exactly 30s boundary in skew window', () => {
        const sm: SyncManager = new SyncManager()
        const local: Session = makeSession({ lastModified: 1000000, content: 'local', deviceId: 'A' })

        const remote: Session = makeSession({
          lastModified: 1000000 + 30000, // exactly 30s
          content: 'remote',
          deviceId: 'B',
        })

        const result: ConflictResult = sm.resolveConflict(local, remote)
        expect(result.resolution).assertEqual(ConflictResolution.CONFLICT_BOTH)
      })

      // At 30s+1ms → outside skew window, LWW applies
      it('should apply pure LWW just outside 30s skew window', () => {
        const sm: SyncManager = new SyncManager()
        const local: Session = makeSession({ lastModified: 1000000, content: 'local', deviceId: 'A' })

        const remote: Session = makeSession({
          lastModified: 1000000 + 30001,
          content: 'remote',
          deviceId: 'B',
        })

        const result: ConflictResult = sm.resolveConflict(local, remote)
        expect(result.resolution).assertEqual(ConflictResolution.ACCEPT_REMOTE)
      })
    })

    describe('chunkContent', () => {
      it('should return single chunk for content under 500KB', () => {
        const sm: SyncManager = new SyncManager()
        const shortContent: string = 'Hello, this is a short note.'
        const chunks: string[] = sm.chunkContent(shortContent, 'chunk-1')

        expect(chunks.length).assertEqual(1)
        expect(chunks[0]).assertEqual(shortContent)
      })

      it('should split extremely long content into multiple chunks', () => {
        const sm: SyncManager = new SyncManager()
        // ~600K chars = ~1.8MB worst-case — should require multiple chunks
        const longContent: string = '中'.repeat(600000)
        const chunks: string[] = sm.chunkContent(longContent, 'chunk-2')

        expect(chunks.length).assertGreater(1)
        // Assembled chunks should equal original content
        const assembled: string = chunks.join('')
        expect(assembled).assertEqual(longContent)
      })

      it('should handle empty content', () => {
        const sm: SyncManager = new SyncManager()
        const chunks: string[] = sm.chunkContent('', 'chunk-3')
        expect(chunks.length).assertEqual(1)
        expect(chunks[0]).assertEqual('')
      })
    })

    describe('handleInboundChunk', () => {
      it('should return content directly when not chunked', () => {
        const sm: SyncManager = new SyncManager()
        const session: Session = makeSession({
          content: 'direct content',
          chunkIndex: -1,
          chunkCount: 0,
        })

        const result = sm.handleInboundChunk(session)
        expect(result.isOk()).assertTrue()
        const assembled: string | null = result.getValue()
        expect(assembled).assertEqual('direct content')
      })

      it('should return null when waiting for more chunks', () => {
        const sm: SyncManager = new SyncManager()
        const session: Session = makeSession({
          content: 'Part 1',
          chunkIndex: 0,
          chunkCount: 3,
          chunkId: 'assembly-1',
        })

        const result = sm.handleInboundChunk(session)
        expect(result.isOk()).assertTrue()
        const assembled: string | null = result.getValue()
        expect(assembled).assertNull() // waiting for chunks 1 and 2
      })

      it('should assemble complete content when all chunks arrive', () => {
        const sm: SyncManager = new SyncManager()

        const chunk0: Session = makeSession({
          content: 'AAA',
          chunkIndex: 0,
          chunkCount: 3,
          chunkId: 'assembly-2',
        })
        const chunk1: Session = makeSession({
          content: 'BBB',
          chunkIndex: 1,
          chunkCount: 3,
          chunkId: 'assembly-2',
        })
        const chunk2: Session = makeSession({
          content: 'CCC',
          chunkIndex: 2,
          chunkCount: 3,
          chunkId: 'assembly-2',
        })

        let result = sm.handleInboundChunk(chunk0)
        expect(result.getValue()).assertNull()
        result = sm.handleInboundChunk(chunk1)
        expect(result.getValue()).assertNull()
        result = sm.handleInboundChunk(chunk2)
        expect(result.getValue()).assertEqual('AAABBBCCC')
      })
    })

  })
}
