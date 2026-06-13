/**
 * Session — MXNote 的原子同步单元。
 *
 * ⚠️ ARCHITECTURE CONSTRAINT: All properties MUST be flat.
 * distributedDataObject does NOT sync nested property changes.
 * Never add objects/arrays as property values — no `metadata: {}`,
 * no `tags: []`. If you need nested data, use separate root properties
 * or JSON-serialized strings.
 *
 * Single Session = one opened note, from open to dismiss.
 * The session protects the THINKING FLOW, not the .md file.
 */
export interface Session {
  // === Core: synced across devices ===
  noteId: string // GUID
  content: string // Markdown source text
  cursorOffset: number // UTF-16 code unit offset
  scrollY: number // pixel scroll position
  lastModified: number // Unix ms timestamp, LWW arbiter
  deviceId: string // last writing device

  // === Chunk protocol (only used for >500KB notes) ===
  chunkIndex: number // -1 = not chunked; >=0 = chunk fragment index
  chunkCount: number // 0 = not chunked; >1 = total chunk count
  chunkId: string // shared chunk session ID for assembly

  // === Metadata (NOT synced — local only, stored in LocalStore) ===
  // title: derived from first heading or filename
  // createdAt: first creation timestamp
  // syncStatus: 'synced' | 'pending' | 'conflict' | 'offline'
}

/**
 * Create an empty new Session for noteId.
 * All flat properties — distributedDataObject compatible.
 */
export function createEmptySession(noteId: string, deviceId: string): Session {
  return {
    noteId: noteId,
    content: '',
    cursorOffset: 0,
    scrollY: 0,
    lastModified: Date.now(),
    deviceId: deviceId,
    chunkIndex: -1,
    chunkCount: 0,
    chunkId: '',
  }
}

/**
 * Session discovery message shown to user when a nearby device
 * has an active Session.
 */
export interface SessionDiscovery {
  noteId: string
  deviceName: string
  preview: string // first 80 chars of content
  lastModified: number
}
