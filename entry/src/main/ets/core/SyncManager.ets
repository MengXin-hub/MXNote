import { ok, err, Result, AppError, ErrorCode } from '../model/Result'
import { Session } from '../model/Session'
import { Debouncer, Throttler } from '../utils/ThrottleUtil'

/**
 * Conflict resolution outcome.
 */
export enum ConflictResolution {
  ACCEPT_REMOTE = 'ACCEPT_REMOTE', // remote write wins
  KEEP_LOCAL = 'KEEP_LOCAL', // local write wins
  CONFLICT_BOTH = 'CONFLICT_BOTH', // true conflict — both versions preserved
}

/**
 * Result of resolving a conflict between local and remote Session.
 */
export class ConflictResult {
  readonly resolution: ConflictResolution
  readonly winningSession: Session
  readonly conflictCopy: Session | null // non-null only for CONFLICT_BOTH

  constructor(
    resolution: ConflictResolution,
    winningSession: Session,
    conflictCopy: Session | null,
  ) {
    this.resolution = resolution
    this.winningSession = winningSession
    this.conflictCopy = conflictCopy
  }
}

/**
 * Chunk assembly state for inbound chunked sync.
 */
class InboundChunkState {
  readonly chunkId: string
  readonly totalCount: number
  readonly chunks: Map<number, string> = new Map()
  readonly createdAt: number = Date.now()
  timeoutHandle: number = -1

  constructor(chunkId: string, totalCount: number) {
    this.chunkId = chunkId
    this.totalCount = totalCount
  }

  isComplete(): boolean {
    return this.chunks.size === this.totalCount
  }

  assemble(): string {
    const result: string[] = []
    for (let i: number = 0; i < this.totalCount; i++) {
      const chunk: string | undefined = this.chunks.get(i)
      if (chunk !== undefined) {
        result.push(chunk)
      }
    }
    return result.join('')
  }
}

/**
 * SyncManager — coordinates distributed sync for a single Session.
 *
 * Responsibilities:
 * - Conflict resolution (LWW + 30s clock-skew window)
 * - Content chunking for >500KB notes (chunk_count protocol)
 * - Chunk assembly with atomic commit (all-or-nothing + timeout retry)
 * - Sync throttling (content immediate, cursor/scroll 150ms debounce)
 * - Remote parse throttle (300ms to prevent jank)
 *
 * Constants (from HarmonyOS distributedDataObject limits):
 * - CHUNK_SIZE_BYTES: 500 * 1024 (500KB max per object write)
 * - CLOCK_SKEW_MS: 30000 (treat as true conflict)
 * - CHUNK_TIMEOUT_MS: 30000 (retry missing chunks)
 * - CURSOR_DEBOUNCE_MS: 150
 * - REMOTE_PARSE_THROTTLE_MS: 300
 */
const CHUNK_SIZE_BYTES: number = 500 * 1024 // distributedDataObject 500KB limit
const CLOCK_SKEW_MS: number = 30000
const CHUNK_TIMEOUT_MS: number = 30000
const CURSOR_DEBOUNCE_MS: number = 150
const REMOTE_PARSE_THROTTLE_MS: number = 300

export class SyncManager {
  // Inbound chunk assembly state (one active assembly at a time)
  private inboundChunks: InboundChunkState | null = null

  // Throttle controllers
  private cursorDebouncer: Debouncer = new Debouncer(CURSOR_DEBOUNCE_MS)
  private scrollDebouncer: Debouncer = new Debouncer(CURSOR_DEBOUNCE_MS)
  private remoteParseThrottler: Throttler = new Throttler(REMOTE_PARSE_THROTTLE_MS)

  /**
   * Resolve conflict between local Session and incoming remote Session.
   *
   * Strategy: Last-Write-Wins by lastModified timestamp.
   * Clock-skew protection: if timestamps differ by < CLOCK_SKEW_MS,
   * treat as true concurrent conflict → preserve both versions.
   *
   * @param local  Current local Session
   * @param remote Incoming remote Session
   * @returns ConflictResult with resolution and winning session
   */
  resolveConflict(local: Session, remote: Session): ConflictResult {
    const timeDiff: number = Math.abs(local.lastModified - remote.lastModified)

    // Clock-skew window: both edits within 30s → true conflict
    if (timeDiff <= CLOCK_SKEW_MS) {
      // Keep the more recent as winner, preserve the other as conflict copy
      if (remote.lastModified >= local.lastModified) {
        return new ConflictResult(
          ConflictResolution.CONFLICT_BOTH,
          remote, // remote wins (more recent or equal)
          local, // local preserved as conflict copy
        )
      } else {
        return new ConflictResult(
          ConflictResolution.CONFLICT_BOTH,
          local, // local wins (more recent)
          remote, // remote preserved as conflict copy
        )
      }
    }

    // Clear winner (outside skew window)
    if (remote.lastModified > local.lastModified) {
      return new ConflictResult(
        ConflictResolution.ACCEPT_REMOTE,
        remote,
        null,
      )
    } else {
      return new ConflictResult(
        ConflictResolution.KEEP_LOCAL,
        local,
        null,
      )
    }
  }

  /**
   * Check whether content needs chunking for distributedDataObject transit.
   * Returns array of content chunks. Single-element array if <=500KB.
   */
  chunkContent(content: string, chunkId: string): string[] {
    // Estimate UTF-8 byte length: ASCII=1, CJK=3, safe upper bound = content.length * 3
    const estimatedByteLen: number = content.length * 3

    if (estimatedByteLen <= CHUNK_SIZE_BYTES) {
      // Conservative: under the limit even in worst case (all CJK)
      return [content]
    }

    // Split by character count: ~170K chars = 500KB worst-case (all CJK)
    const maxCharsPerChunk: number = Math.floor(CHUNK_SIZE_BYTES / 3)
    const chunks: string[] = []
    let remaining: string = content

    while (remaining.length > 0) {
      const chunkLen: number = Math.min(remaining.length, maxCharsPerChunk)
      chunks.push(remaining.slice(0, chunkLen))
      remaining = remaining.slice(chunkLen)
    }

    return chunks
  }

  /**
   * Handle inbound chunked content. Returns assembled content when complete,
   * or null if still waiting for more chunks.
   *
   * Caller should call this whenever a remote chunk arrives.
   * When all chunks are present, the assembled content is returned
   * and the chunk state is cleaned up.
   */
  handleInboundChunk(
    chunkedSession: Session,
  ): Result<string | null, AppError> {
    // Not chunked — return content directly
    if (chunkedSession.chunkIndex < 0 || chunkedSession.chunkCount <= 1) {
      return ok<string | null, AppError>(chunkedSession.content)
    }

    const chunkId: string = chunkedSession.chunkId
    const totalCount: number = chunkedSession.chunkCount

    // New chunk session or continuation
    if (this.inboundChunks === null || this.inboundChunks.chunkId !== chunkId) {
      // Clean up previous (stale) chunk session
      if (this.inboundChunks !== null) {
        clearTimeout(this.inboundChunks.timeoutHandle)
      }

      this.inboundChunks = new InboundChunkState(chunkId, totalCount)

      // Set timeout for missing chunks
      this.inboundChunks.timeoutHandle = setTimeout(() => {
        // Timeout: chunk assembly failed. Clean up.
        // The content will remain incomplete until a retransmit.
        this.inboundChunks = null
      }, CHUNK_TIMEOUT_MS)
    }

    // Store this chunk
    this.inboundChunks.chunks.set(chunkedSession.chunkIndex, chunkedSession.content)

    // Check completion
    if (this.inboundChunks.isComplete()) {
      clearTimeout(this.inboundChunks.timeoutHandle)
      const assembled: string = this.inboundChunks.assemble()
      this.inboundChunks = null
      return ok<string | null, AppError>(assembled)
    }

    // Still waiting for more chunks
    return ok<string | null, AppError>(null)
  }

  /**
   * Whether content should be synced immediately.
   * Content is always synced — no throttle. Data safety > performance.
   */
  shouldSyncContent(): boolean {
    return true // immediate, always
  }

  /**
   * Queue a cursor sync with debounce.
   * Caller provides the actual sync function.
   */
  debounceCursor(syncFn: () => void): void {
    this.cursorDebouncer.run(syncFn)
  }

  /**
   * Queue a scroll sync with debounce.
   */
  debounceScroll(syncFn: () => void): void {
    this.scrollDebouncer.run(syncFn)
  }

  /**
   * Throttle remote content parse to prevent jank.
   * Caller provides the parse function.
   */
  throttleRemoteParse(parseFn: () => void): void {
    this.remoteParseThrottler.run(parseFn)
  }

  /**
   * Clean up all pending timers.
   */
  destroy(): void {
    this.cursorDebouncer.cancel()
    this.scrollDebouncer.cancel()
    this.remoteParseThrottler.cancel()

    if (this.inboundChunks !== null) {
      clearTimeout(this.inboundChunks.timeoutHandle)
      this.inboundChunks = null
    }
  }
}
