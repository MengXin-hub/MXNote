/**
 * Simple throttle/debounce utilities for MXNote sync layer.
 *
 * - content changes: sync immediately (no throttle, data safety > perf)
 * - cursorOffset: 150ms debounce (visual polish, acceptable lag)
 * - scrollY: 150ms debounce
 * - remote parse: 300ms throttle (prevent jank from rapid remote pushes)
 */

/**
 * Debounce: call after `delayMs` of silence.
 * Each call resets the timer. Fires only once after activity stops.
 */
export class Debouncer {
  private timer: number = -1
  private readonly delayMs: number

  constructor(delayMs: number) {
    this.delayMs = delayMs
  }

  run(fn: () => void): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer)
    }
    this.timer = setTimeout(() => {
      this.timer = -1
      fn()
    }, this.delayMs)
  }

  cancel(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer)
      this.timer = -1
    }
  }
}

/**
 * Throttle: fire at most once per `intervalMs`.
 * First call fires immediately. Subsequent calls within window are queued.
 */
export class Throttler {
  private lastRun: number = 0
  private pending: boolean = false
  private pendingFn: (() => void) | null = null
  private readonly intervalMs: number

  constructor(intervalMs: number) {
    this.intervalMs = intervalMs
  }

  run(fn: () => void): void {
    const now: number = Date.now()

    if (now - this.lastRun >= this.intervalMs) {
      this.lastRun = now
      fn()
    } else {
      // Queue for later execution
      this.pendingFn = fn
      if (!this.pending) {
        this.pending = true
        const delay: number = this.intervalMs - (now - this.lastRun)
        setTimeout(() => {
          this.pending = false
          this.lastRun = Date.now()
          if (this.pendingFn) {
            this.pendingFn()
            this.pendingFn = null
          }
        }, delay)
      }
    }
  }

  cancel(): void {
    this.pending = false
    this.pendingFn = null
  }
}
