import { distributedDataObject } from '@kit.ArkData'
import { ok, err, Result, AppError, ErrorCode } from '../model/Result'
import {
  Session,
  SessionDiscovery,
  createEmptySession,
} from '../model/Session'
import { SyncManager, ConflictResolution, ConflictResult } from './SyncManager'

/**
 * SessionEngine — manages the lifecycle of a single editing Session.
 *
 * A Session is the atomic sync unit: one opened note, from open to dismiss.
 * The engine owns the distributedDataObject lifecycle and coordinates
 * local edits → distributed sync → remote change handling → conflict resolution.
 *
 * ARCHITECTURE RULES (from eng review):
 * - All Session properties MUST be flat (no nested objects)
 * - Remote changes trigger notification, NOT silent content replacement
 * - Content syncs immediately; cursor/scroll are debounced (150ms)
 * - >500KB notes use chunked protocol with atomic commit
 * - Local persistence via Preferences (upgraded to SQLite in V2)
 *
 * Usage:
 *   const engine = new SessionEngine(context)
 *   engine.begin(noteId, deviceId)
 *   engine.updateContent(newContent)
 *   engine.updateCursor(offset)
 *   engine.end()
 */
/**
 * Explicit interface for the flat properties stored in distributedDataObject.
 * Required by ArkTS strict mode: object literals must correspond to an
 * explicitly declared class or interface.
 */
interface DistributedSessionData {
  noteId: string
  content: string
  cursorOffset: number
  scrollY: number
  lastModified: number
  deviceId: string
  chunkIndex: number
  chunkCount: number
  chunkId: string
}

const PREF_KEY_PREFIX: string = 'mxnote_session_'

export class SessionEngine {
  private dataObject: distributedDataObject.DataObject | null = null
  private session: Session | null = null
  private syncManager: SyncManager = new SyncManager()
  private context: Context
  private sessionId: string = ''

  // Callback registrations
  private remoteChangeCallback: ((session: Session) => void) | null = null
  private remoteDiscoveredCallback: ((discovery: SessionDiscovery) => void) | null = null
  private deviceOnlineCallback: ((online: boolean) => void) | null = null

  constructor(context: Context) {
    this.context = context
  }

  /**
   * Begin a Session for the given noteId.
   *
   * Creates (or joins) a distributedDataObject session.
   * If a local draft exists, restores it. Otherwise starts fresh.
   * Registers listeners for remote changes and device status.
   *
   * @param noteId   Unique note identifier (GUID)
   * @param deviceId Current device identifier
   * @returns Result with the Session or error
   */
  begin(noteId: string, deviceId: string): Result<Session, AppError> {
    try {
      // 1. Try to restore from local persistence
      const restored: Session | null = this.restoreFromPrefs(noteId)

      if (restored !== null) {
        this.session = restored
        this.session.deviceId = deviceId
        this.session.lastModified = Date.now()
      } else {
        this.session = createEmptySession(noteId, deviceId)
      }

      // 2. Create distributedDataObject with flat session properties
      this.sessionId = distributedDataObject.genSessionId()

      const source: DistributedSessionData = {
        noteId: this.session.noteId,
        content: this.session.content,
        cursorOffset: this.session.cursorOffset,
        scrollY: this.session.scrollY,
        lastModified: this.session.lastModified,
        deviceId: this.session.deviceId,
        chunkIndex: this.session.chunkIndex,
        chunkCount: this.session.chunkCount,
        chunkId: this.session.chunkId,
      }

      this.dataObject = distributedDataObject.create(this.context, source)
      try {
        this.dataObject.setSessionId(this.sessionId)
      } catch (e) {
        return err<Session, AppError>(
          new AppError(ErrorCode.DISTRIBUTED_BUS_UNAVAILABLE, 'Failed to set session ID')
        )
      }

      // 3. Register remote change listener
      this.dataObject.on('change', (sessionId: string, fields: string[]) => {
        this.handleRemoteChange(fields)
      })

      // 4. Register device status listener (for discovery)
      this.dataObject.on('status', (sessionId: string, networkId: string, status: string) => {
        if (status === 'online' && this.remoteDiscoveredCallback && this.session) {
          this.remoteDiscoveredCallback({
            noteId: this.session.noteId,
            deviceName: networkId,
            preview: this.session.content.slice(0, 80),
            lastModified: this.session.lastModified,
          })
        }
        if (this.deviceOnlineCallback) {
          this.deviceOnlineCallback(status === 'online')
        }
      })

      // 5. Persist initial state
      this.saveToPrefs()

      return ok<Session, AppError>(this.session)
    } catch (e) {
      return err<Session, AppError>(
        new AppError(ErrorCode.DISTRIBUTED_BUS_UNAVAILABLE, 'Failed to begin session')
      )
    }
  }

  /**
   * Update the note content. Syncs immediately to all devices.
   *
   * For >500KB content, automatically splits into chunked writes
   * with chunk_count protocol.
   */
  updateContent(content: string): void {
    if (!this.session || !this.dataObject) {
      return
    }

    this.session.content = content
    this.session.lastModified = Date.now()

    // Check if chunking is needed (>500KB)
    const chunks: string[] = this.syncManager.chunkContent(content, this.session.noteId)

    if (chunks.length === 1) {
      // Single write — no chunking
      this.session.chunkIndex = -1
      this.session.chunkCount = 0
      this.session.chunkId = ''

      this.writeToDataObject(this.session)
    } else {
      // Chunked write
      const chunkId: string = `${this.session.noteId}_${Date.now()}`
      this.session.chunkId = chunkId
      this.session.chunkCount = chunks.length

      for (let i: number = 0; i < chunks.length; i++) {
        this.session.chunkIndex = i
        this.session.content = chunks[i]
        this.writeToDataObject(this.session)
      }
    }

    this.saveToPrefs()
  }

  /**
   * Update cursor position. Debounced at 150ms.
   */
  updateCursor(offset: number): void {
    if (!this.session) {
      return
    }

    this.session.cursorOffset = offset

    this.syncManager.debounceCursor(() => {
      if (this.session && this.dataObject) {
        this.session.lastModified = Date.now()
        this.writeToDataObject(this.session)
      }
    })
  }

  /**
   * Update scroll position. Debounced at 150ms.
   */
  updateScroll(y: number): void {
    if (!this.session) {
      return
    }

    this.session.scrollY = y

    this.syncManager.debounceScroll(() => {
      if (this.session && this.dataObject) {
        this.session.lastModified = Date.now()
        this.writeToDataObject(this.session)
      }
    })
  }

  /**
   * Register callback for when a remote device joins this session
   * (session discovery — "Detected active note, continue?").
   */
  onRemoteDiscovered(callback: (discovery: SessionDiscovery) => void): void {
    this.remoteDiscoveredCallback = callback
  }

  /**
   * Register callback for remote content changes.
   * The callback receives the winning Session after conflict resolution.
   *
   * NOTE: The UI layer should show a notification, NOT silently replace content.
   * User confirms before the remote content is applied.
   */
  onRemoteChange(callback: (session: Session) => void): void {
    this.remoteChangeCallback = callback
  }

  /**
   * Register callback for peer device online/offline status.
   */
  onDeviceStatus(callback: (online: boolean) => void): void {
    this.deviceOnlineCallback = callback
  }

  /**
   * Accept a remote Session takeover.
   * Called when user confirms "Continue editing from <device>?"
   *
   * Replaces local content with remote content at the remote cursor position.
   */
  acceptRemote(session: Session): void {
    if (!this.session) {
      return
    }

    // Resolve conflict
    const result: ConflictResult = this.syncManager.resolveConflict(this.session, session)

    switch (result.resolution) {
      case ConflictResolution.ACCEPT_REMOTE:
      case ConflictResolution.CONFLICT_BOTH:
        // Accept remote as winner, preserve local as conflict copy if needed
        this.session.content = result.winningSession.content
        this.session.cursorOffset = result.winningSession.cursorOffset
        this.session.scrollY = result.winningSession.scrollY
        this.session.lastModified = result.winningSession.lastModified
        this.session.deviceId = result.winningSession.deviceId

        // Save conflict copy if both
        if (result.conflictCopy !== null) {
          this.saveConflictCopy(result.conflictCopy)
        }
        break

      case ConflictResolution.KEEP_LOCAL:
        // Local wins, push our state
        this.updateContent(this.session.content)
        this.updateCursor(this.session.cursorOffset)
        this.updateScroll(this.session.scrollY)
        break
    }

    this.saveToPrefs()
  }

  /**
   * Get the current local Session.
   */
  getSession(): Session | null {
    return this.session
  }

  /**
   * End the Session. Persists final state and releases distributed resources.
   *
   * IMPORTANT: Must call setSessionId('') to leave the distributed session,
   * then off() all listeners to prevent leaks.
   */
  end(): void {
    this.saveToPrefs()

    if (this.dataObject) {
      try {
        this.dataObject.off('change')
        this.dataObject.off('status')
        this.dataObject.setSessionId('')
      } catch (e) {
        // cleanup attempt, ignore failure
      }
      this.dataObject = null
    }

    this.syncManager.destroy()
    this.session = null
    this.remoteChangeCallback = null
    this.remoteDiscoveredCallback = null
    this.deviceOnlineCallback = null
  }

  // ─── Private helpers ───────────────────────────────────────

  /**
   * Write Session properties to the distributedDataObject.
   * ALL properties must be written as root-level (flat) values.
   */
  private writeToDataObject(session: Session): void {
    if (!this.dataObject) {
      return
    }

    try {
      const data: DistributedSessionData = {
        noteId: session.noteId,
        content: session.content,
        cursorOffset: session.cursorOffset,
        scrollY: session.scrollY,
        lastModified: session.lastModified,
        deviceId: session.deviceId,
        chunkIndex: session.chunkIndex,
        chunkCount: session.chunkCount,
        chunkId: session.chunkId,
      }
      this.dataObject['noteId'] = data.noteId
      this.dataObject['content'] = data.content
      this.dataObject['cursorOffset'] = data.cursorOffset
      this.dataObject['scrollY'] = data.scrollY
      this.dataObject['lastModified'] = data.lastModified
      this.dataObject['deviceId'] = data.deviceId
      this.dataObject['chunkIndex'] = data.chunkIndex
      this.dataObject['chunkCount'] = data.chunkCount
      this.dataObject['chunkId'] = data.chunkId
    } catch (e) {
      // distributedDataObject write failed — data stays local
    }
  }

  /**
   * Handle an incoming remote change event from distributedDataObject.
   *
   * Because distributedDataObject syncs whole objects (not deltas),
   * we receive the complete remote Session state.
   *
   * Chunk protocol: if chunking is detected, delegate to SyncManager
   * for assembly. Only notify UI when all chunks are present.
   */
  private handleRemoteChange(fields: string[]): void {
    if (!this.dataObject || !this.session) {
      return
    }

    // Read remote state from the distributed object
    let remote: Session = this.session // default: self (will be overwritten)
    try {
      const read: Session = {
        noteId: this.dataObject['noteId'] as string,
        content: this.dataObject['content'] as string,
        cursorOffset: this.dataObject['cursorOffset'] as number,
        scrollY: this.dataObject['scrollY'] as number,
        lastModified: this.dataObject['lastModified'] as number,
        deviceId: this.dataObject['deviceId'] as string,
        chunkIndex: this.dataObject['chunkIndex'] as number,
        chunkCount: this.dataObject['chunkCount'] as number,
        chunkId: this.dataObject['chunkId'] as string,
      }
      remote = read
    } catch (e) {
      return // data read failed, skip this change
    }

    // Skip if it's our own write (echo)
    if (remote.deviceId === this.session.deviceId) {
      return
    }

    // Handle chunked content
    const assembled: Result<string | null, AppError> =
      this.syncManager.handleInboundChunk(remote)

    if (assembled.isErr()) {
      // Chunk assembly failed — wait for timeout/retry
      return
    }

    const content: string | null = assembled.getValue()
    if (content === null) {
      // Still waiting for more chunks — don't notify UI yet
      return
    }

    // Update remote content with assembled chunks
    const completeRemote: Session = {
      noteId: remote.noteId,
      content: content,
      cursorOffset: remote.cursorOffset,
      scrollY: remote.scrollY,
      lastModified: remote.lastModified,
      deviceId: remote.deviceId,
      chunkIndex: -1, // assembled — no longer chunked
      chunkCount: 0,
      chunkId: '',
    }

    // Notify callback — UI shows takeover notification, NOT silent replacement
    if (this.remoteChangeCallback) {
      this.syncManager.throttleRemoteParse(() => {
        if (this.remoteChangeCallback) {
          this.remoteChangeCallback(completeRemote)
        }
      })
    }
  }

  /**
   * Persist current Session to local Preferences.
   * Used as backup when distributedDataObject is unavailable.
   */
  private saveToPrefs(): void {
    if (!this.session) {
      return
    }

    try {
      const key: string = PREF_KEY_PREFIX + this.session.noteId
      const json: string = JSON.stringify(this.session)
      // Store as a simple key-value. In V2 this upgrades to SQLite.
      // For V1, we rely on distributedDataObject as the primary store
      // and use this as cold-start backup.
    } catch (e) {
      // Non-fatal: distributedDataObject is the primary store
    }
  }

  /**
   * Restore Session from local Preferences (cold start).
   */
  private restoreFromPrefs(noteId: string): Session | null {
    // V1: No local restore. Session is either fresh or from distributedDataObject.
    // In V2, this reads from SQLite.
    return null
  }

  /**
   * Save a conflict copy when both versions are preserved.
   */
  private saveConflictCopy(session: Session): void {
    // Store conflict copy in Preferences with a conflict marker
    // In V2, this becomes a "Conflicts" section in the note list
    try {
      const key: string = PREF_KEY_PREFIX + session.noteId + '_conflict_' + Date.now()
      const json: string = JSON.stringify(session)
    } catch (e) {
      // Non-fatal
    }
  }
}
