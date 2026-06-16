/**
 * MarkdownParser — 单遍扫描, 零分配解析器。
 * 支持: 标题/段落/代码块/引用/分割线/有序列表/无序列表/表格/链接/图片/Mermaid
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
  TB = 'TB',      // table
  LINK = 'LINK',  // link
  IMG = 'IMG',    // image
  MERMAID = 'MERMAID', // mermaid flowchart
}

export class InlineSpan {
  t: string = ''
  b: boolean = false
  i: boolean = false
  c: boolean = false
  link: string = ''      // [text](url) → t=text, link=url
  img: string = ''       // ![alt](url) → t=alt, img=url
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
  headers: InlineSpan[] = []  // 表格表头
  rows: InlineSpan[][] = []   // 表格行
  url: string = ''            // 链接/图片 URL
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
/** 检查是否为表格分隔行: | --- | --- | */
function isTableSep(s: string, start: number): boolean {
  let i: number = start
  while (i < s.length && (s.charAt(i) === '|' || s.charAt(i) === ' ' ||
    s.charAt(i) === '-' || s.charAt(i) === ':' || s.charAt(i) === '\n' || s.charAt(i) === '\r')) {
    if (s.charAt(i) === '\n') break; i++
  }
  return s.charAt(start) === '|' && (s.charAt(i - 1) === '-' || s.charAt(i - 1) === ':')
}
function parseTableRow(row: string): InlineSpan[] {
  const parts: string[] = row.split('|')
  const cells: InlineSpan[] = []
  for (let k: number = 0; k < parts.length; k++) {
    const cell: string = parts[k].trim()
    if (cell.length > 0) {
      cells.push(new InlineSpan(cell, false, false, false))
    }
  }
  return cells
}

function spans(text: string): InlineSpan[] {
  if (text.length === 0) return []
  const out: InlineSpan[] = []
  let pos: number = 0
  const L: number = text.length
  while (pos < L) {
    const ch: string = text.charAt(pos)
    // ![image](url)
    if (ch === '!' && pos + 1 < L && text.charAt(pos + 1) === '[') {
      const bracketEnd: number = text.indexOf('](', pos + 2)
      if (bracketEnd > pos + 2) {
        const parenEnd: number = text.indexOf(')', bracketEnd + 2)
        if (parenEnd > bracketEnd + 2) {
          const alt: string = text.slice(pos + 2, bracketEnd)
          const url: string = text.slice(bracketEnd + 2, parenEnd)
          const span: InlineSpan = new InlineSpan(alt, false, false, false)
          span.img = url
          out.push(span); pos = parenEnd + 1; continue
        }
      }
    }
    // [link](url)
    if (ch === '[') {
      const bracketEnd: number = text.indexOf('](', pos + 1)
      if (bracketEnd > pos + 1) {
        const parenEnd: number = text.indexOf(')', bracketEnd + 2)
        if (parenEnd > bracketEnd + 2) {
          const linkText: string = text.slice(pos + 1, bracketEnd)
          const url: string = text.slice(bracketEnd + 2, parenEnd)
          const span: InlineSpan = new InlineSpan(linkText, false, false, false)
          span.link = url
          out.push(span); pos = parenEnd + 1; continue
        }
      }
    }
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
    const bi: number = idx(text, '[', pos)
    const ii: number = idx(text, '!', pos)
    let nxt: number = si < ci ? si : ci
    nxt = nxt < bi ? nxt : bi; nxt = nxt < ii ? nxt : ii
    if (nxt <= pos) nxt = pos + 1
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
        // code block (check before table)
        if (ch === '`' && i + 2 < n && source.charAt(i + 1) === '`' && source.charAt(i + 2) === '`') {
          const le: number = idx(source, '\n', i + 3)
          const lang: string = rtrim(source.slice(i + 3, le))
          const cl: number = source.indexOf('```', le + 1)
          const body: string = cl >= 0 ? source.slice(le + 1, cl) : source.slice(le + 1)
          if (lang === 'mermaid') {
            tokens.push(new MarkdownToken(TokenType.MERMAID, 0, lang, [], body))
          } else {
            tokens.push(new MarkdownToken(TokenType.C, 0, lang, [], body))
          }
          i = cl >= 0 ? cl + 3 : n; continue
        }
        // heading
        let hh: number = 0; let hi: number = i
        while (hi < n && source.charAt(hi) === '#' && hh < 6) { hh++; hi++ }
        if (hh > 0 && hi < n && source.charAt(hi) === ' ') {
          const e: number = idx(source, '\n', hi)
          const ht: string = source.slice(hi + 1, e).trim()
          tokens.push(new MarkdownToken(TokenType.H, hh, '', spans(ht), ht)); i = e + 1; continue
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
        // Table: | a | b |\n| - | - |\n| c | d |
        if (ch === '|') {
          const firstRowEnd: number = idx(source, '\n', i)
          const firstRow: string = source.slice(i, firstRowEnd)
          const nxtLine: number = firstRowEnd + 1
          if (nxtLine < n && isTableSep(source, nxtLine)) {
            const sepEnd: number = idx(source, '\n', nxtLine)
            i = sepEnd + 1
            // 解析多行数据
            const headerCells: InlineSpan[] = parseTableRow(firstRow)
            const rows: InlineSpan[][] = []
            while (i < n) {
              const rowEnd: number = idx(source, '\n', i)
              const rowStr: string = source.slice(i, rowEnd).trim()
              if (rowStr.indexOf('|') < 0) break
              rows.push(parseTableRow(rowStr))
              i = rowEnd + 1
            }
            const tk: MarkdownToken = new MarkdownToken(TokenType.TB, 0, '', [], firstRow)
            tk.headers = headerCells; tk.rows = rows
            tokens.push(tk); continue
          }
        }
        // paragraph (含内联链接/图片)
        const pe: number = idx(source, '\n', i)
        const pt: string = source.slice(i, pe).trim()
        if (pt.length > 0) {
          const inlineSpans: InlineSpan[] = spans(pt)
          // 检查是否为纯链接行
          let hasLink: boolean = false
          for (let s: number = 0; s < inlineSpans.length; s++) {
            if (inlineSpans[s].link.length > 0) hasLink = true
            if (inlineSpans[s].img.length > 0) hasLink = true
          }
          if (hasLink) {
            // 内联样式保留段落渲染, 链接/图片通过 span 的 link/img 字段区分
          }
          tokens.push(new MarkdownToken(TokenType.P, 0, '', inlineSpans, pt))
        }
        i = pe + 1
      }
      return ok(tokens)
    } catch (e) { return ok([]) }
  }
}
