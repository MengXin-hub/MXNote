/**
 * MarkdownParser — 单遍扫描, 零分配解析器。
 * 全部用 class 构造 (ArkTS strict mode), 不抛异常, 超大文档截断。
 */
import { ok, Result } from '../model/Result'

export enum TokenType {
  H = 'H',        // heading
  P = 'P',        // paragraph
  C = 'C',        // code block
  Q = 'Q',        // blockquote
  HR = 'HR',      // horizontal rule
  UL = 'UL',      // unordered list
  OL = 'OL',      // ordered list
}

export class InlineSpan {
  t: string = ''
  b: boolean = false  // bold
  i: boolean = false  // italic
  c: boolean = false  // code
  constructor(t: string, b: boolean, i: boolean, c: boolean) {
    this.t = t; this.b = b; this.i = i; this.c = c
  }
}

export class MarkdownToken {
  type: TokenType = TokenType.P
  lv: number = 0
  lang: string = ''
  kids: InlineSpan[] = []
  raw: string = ''
  constructor(type: TokenType, lv: number, lang: string, kids: InlineSpan[], raw: string) {
    this.type = type; this.lv = lv; this.lang = lang; this.kids = kids; this.raw = raw
  }
}

const MAX = 60000

function idx(s: string, ch: string, from: number): number {
  const v: number = s.indexOf(ch, from); return v < 0 ? s.length : v
}

function rtrim(s: string): string {
  let i: number = s.length - 1
  while (i >= 0 && (s.charAt(i) === ' ' || s.charAt(i) === '\t')) i--
  return s.slice(0, i + 1)
}

function isHr(s: string, start: number): boolean {
  let c: string = ''
  for (let i: number = start; i < s.length; i++) {
    const ch: string = s.charAt(i)
    if (ch === '\n') break
    if (c === '') { c = ch; continue }
    if (ch !== c) return false
  }
  return c === '-' || c === '*' || c === '_'
}

function spans(text: string): InlineSpan[] {
  if (text.length === 0) return []
  const out: InlineSpan[] = []
  let pos: number = 0
  const L: number = text.length
  while (pos < L) {
    const ch: string = text.charAt(pos)
    // **bold**
    if (ch === '*' && pos + 1 < L && text.charAt(pos + 1) === '*') {
      const e: number = idx(text, '**', pos + 2)
      if (e > pos + 2) { out.push(new InlineSpan(text.slice(pos + 2, e), true, false, false)); pos = e + 2; continue }
    }
    // *italic*
    if (ch === '*' && pos + 1 < L && text.charAt(pos + 1) !== '*') {
      const prev: string = pos > 0 ? text.charAt(pos - 1) : ''
      if (prev !== '*') {
        const e: number = idx(text, '*', pos + 1)
        if (e > pos + 1) { out.push(new InlineSpan(text.slice(pos + 1, e), false, true, false)); pos = e + 1; continue }
      }
    }
    // `code`
    if (ch === '`') {
      const e: number = idx(text, '`', pos + 1)
      if (e > pos + 1) { out.push(new InlineSpan(text.slice(pos + 1, e), false, false, true)); pos = e + 1; continue }
    }
    // plain
    const si: number = idx(text, '*', pos)
    const ci: number = idx(text, '`', pos)
    let nxt: number = si < ci ? si : ci
    if (nxt > pos) out.push(new InlineSpan(text.slice(pos, nxt), false, false, false))
    pos = nxt
  }
  return out
}

function oneSpan(text: string): InlineSpan {
  const s: InlineSpan[] = spans(text); return s.length > 0 ? s[0] : new InlineSpan(text, false, false, false)
}

export class MarkdownParser {
  parse(source: string): Result<MarkdownToken[], Object> {
    if (!source || source.trim().length === 0) return ok([])
    try {
      const tokens: MarkdownToken[] = []
      let i: number = 0
      const n: number = Math.min(source.length, MAX)
      while (i < n) {
        const ch: string = source.charAt(i)
        // heading
        let hh: number = 0; let hi: number = i
        while (hi < n && source.charAt(hi) === '#' && hh < 6) { hh++; hi++ }
        if (hh > 0 && hi < n && source.charAt(hi) === ' ') {
          const e: number = idx(source, '\n', hi)
          const ht: string = source.slice(hi + 1, e).trim()
          tokens.push(new MarkdownToken(TokenType.H, hh, '', spans(ht), ht)); i = e + 1; continue
        }
        // code block
        if (ch === '`' && i + 2 < n && source.charAt(i + 1) === '`' && source.charAt(i + 2) === '`') {
          const le: number = idx(source, '\n', i + 3)
          const lang: string = rtrim(source.slice(i + 3, le))
          const cl: number = source.indexOf('```', le + 1)
          const body: string = cl >= 0 ? source.slice(le + 1, cl) : source.slice(le + 1)
          tokens.push(new MarkdownToken(TokenType.C, 0, lang, [], body)); i = cl >= 0 ? cl + 3 : n; continue
        }
        // HR
        if (isHr(source, i)) {
          tokens.push(new MarkdownToken(TokenType.HR, 0, '', [], '')); i = idx(source, '\n', i) + 1; continue
        }
        // blockquote
        if (ch === '>') {
          const e: number = idx(source, '\n', i)
          const qs: string = source.slice(i + 1, e).replace(/^\s+/, '')
          tokens.push(new MarkdownToken(TokenType.Q, 0, '', spans(qs), qs)); i = e + 1; continue
        }
        // UL
        if ((ch === '-' || ch === '*') && i + 1 < n && source.charAt(i + 1) === ' ') {
          const e: number = idx(source, '\n', i)
          const txt: string = source.slice(i + 2, e).trim()
          tokens.push(new MarkdownToken(TokenType.UL, 0, '', [oneSpan(txt)], txt)); i = e + 1; continue
        }
        // OL
        if (ch >= '0' && ch <= '9') {
          let di: number = i
          while (di < n && source.charAt(di) >= '0' && source.charAt(di) <= '9') di++
          if (di < n && source.charAt(di) === '.' && di + 1 < n && source.charAt(di + 1) === ' ') {
            const e: number = idx(source, '\n', di)
            const txt: string = source.slice(di + 2, e).trim()
            tokens.push(new MarkdownToken(TokenType.OL, 0, '', [oneSpan(txt)], txt)); i = e + 1; continue
          }
        }
        // paragraph
        const pe: number = idx(source, '\n', i)
        const pt: string = source.slice(i, pe).trim()
        if (pt.length > 0) tokens.push(new MarkdownToken(TokenType.P, 0, '', spans(pt), pt))
        i = pe + 1
      }
      return ok(tokens)
    } catch (e) { return ok([]) }
  }
}
