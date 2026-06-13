/**
 * Result<T, E> — Rust-style error handling pattern for MXNote.
 *
 * Every operation that can fail returns Result instead of throwing.
 * Callers MUST handle both Ok and Err branches (no silent failures).
 *
 * Usage:
 *   const r = someOperation()
 *   if (r.isOk()) {
 *     const value: string = r.value
 *   } else {
 *     const err: AppError = r.error
 *   }
 */
export class AppError {
  readonly code: ErrorCode
  readonly message: string

  constructor(code: ErrorCode, message: string) {
    this.code = code
    this.message = message
  }
}

export enum ErrorCode {
  // Network (retryable)
  NETWORK_DISCONNECTED = 'NETWORK_DISCONNECTED',
  NETWORK_TIMEOUT = 'NETWORK_TIMEOUT',
  DISTRIBUTED_BUS_UNAVAILABLE = 'DISTRIBUTED_BUS_UNAVAILABLE',

  // Storage (local fallback)
  STORAGE_DISK_FULL = 'STORAGE_DISK_FULL',
  STORAGE_READ_FAILED = 'STORAGE_READ_FAILED',
  STORAGE_WRITE_FAILED = 'STORAGE_WRITE_FAILED',

  // Parse (user-visible, mark location)
  PARSE_INVALID_MARKDOWN = 'PARSE_INVALID_MARKDOWN',
  PARSE_CHUNK_INCOMPLETE = 'PARSE_CHUNK_INCOMPLETE',

  // Sync
  SYNC_CONFLICT = 'SYNC_CONFLICT',
  SYNC_CHUNK_MISSING = 'SYNC_CHUNK_MISSING',
  SYNC_SESSION_EXPIRED = 'SYNC_SESSION_EXPIRED',

  // General
  UNKNOWN = 'UNKNOWN',
}

export function ok<T, E>(value: T): Result<T, E> {
  return new OkImpl(value)
}

export function err<T, E>(error: E): Result<T, E> {
  return new ErrImpl(error)
}

export interface Result<T, E> {
  isOk(): boolean
  isErr(): boolean
  getValue(): T | null
  getError(): E | null
}

class OkImpl<T, E> implements Result<T, E> {
  readonly value: T

  constructor(value: T) {
    this.value = value
  }

  isOk(): boolean {
    return true
  }

  isErr(): boolean {
    return false
  }

  getValue(): T | null {
    return this.value
  }

  getError(): E | null {
    return null
  }
}

class ErrImpl<T, E> implements Result<T, E> {
  readonly error: E

  constructor(error: E) {
    this.error = error
  }

  isOk(): boolean {
    return false
  }

  isErr(): boolean {
    return true
  }

  getValue(): T | null {
    return null
  }

  getError(): E | null {
    return this.error
  }
}
