import { ok, err, Result, AppError, ErrorCode } from '../model/Result'

export enum TokenType {
  HEADING = 'HEADING',
  PARAGRAPH = 'PARAGRAPH',
  CODE_BLOCK = 'CODE_BLOCK',
  BLOCKQUOTE = 'BLOCKQUOTE',
  HORIZONTAL_RULE = 'HORIZONTAL_RULE',
  UNORDERED_LIST = 'UL',
  ORDERED_LIST = 'OL',
}

export class InlineSpan {
  text: string = ''
  bold: boolean = false
  italic: boolean = false
  code: boolean = false

  constructor(text: string, bold: boolean, italic: boolean, code: boolean) {
    this.text = text
    this.bold = bold
    this.italic = italic
    this.code = code
  }
}

export class MarkdownToken {
  type: TokenType = TokenType.PARAGRAPH
  level: number = 0
  language: string = ''
  children: InlineSpan[] = []
  rawText: string = ''

  constructor(type: TokenType, level: number, language: string, children: InlineSpan[], rawText: string) {
    this.type = type
    this.level = level
    this.language = language
    this.children = children
    this.rawText = rawText
  }
}

function ix(s: string, ch: string, from: number): number {
  const v: number = s.indexOf(ch, from)
  return v < 0 ? s.length : v
}

function rtrim(s: string): string {
  let i: number = s.length - 1
  while (i >= 0 && (s.charAt(i) === ' ' || s.charAt(i) === '\t')) { i-- }
  return s.slice(0, i + 1)
}

function isHr(s: string, start: number): boolean {
  let c: string = ''
  for (let i: number = start; i < s.length; i++) {
    const ch: string = s.charAt(i)
    if (ch === '\n') { break }
    if (c === '') { c = ch; continue }
    if (ch !== c) { return false }
  }
  return c === '-' || c === '*' || c === '_'
}

function collectInline(text: string): InlineSpan[] {
  if (text.length === 0) { return [] }
  const out: InlineSpan[] = []
  let pos: number = 0
  while (pos < text.length) {
    const ch: string = text.charAt(pos)
    // **bold**
    if (ch === '*' && pos + 1 < text.length && text.charAt(pos + 1) === '*') {
      const end: number = ix(text, '**', pos + 2)
      if (end > pos + 2) {
        out.push(new InlineSpan(text.slice(pos + 2, end), true, false, false))
        pos = end + 2
        continue
      }
    }
    // *italic*
    if (ch === '*' && pos + 1 < text.length && text.charAt(pos + 1) !== '*') {
      const end: number = ix(text, '*', pos + 1)
      if (end > pos + 1) {
        const prevCh: string = pos > 0 ? text.charAt(pos - 1) : ''
        if (prevCh !== '*') {
          out.push(new InlineSpan(text.slice(pos + 1, end), false, true, false))
          pos = end + 1
          continue
        }
      }
    }
    // `code`
    if (ch === '`') {
      const end: number = ix(text, '`', pos + 1)
      if (end > pos + 1) {
        out.push(new InlineSpan(text.slice(pos + 1, end), false, false, true))
        pos = end + 1
        continue
      }
    }
    // plain text segment
    const ii: number = ix(text, '*', pos)
    const ci: number = ix(text, '`', pos)
    let nxt: number = ii
    if (ci < nxt) { nxt = ci }
    if (nxt > pos) {
      out.push(new InlineSpan(text.slice(pos, nxt), false, false, false))
    }
    pos = nxt
  }
  return out
}

export class MarkdownParser {
  parse(source: string): Result<MarkdownToken[], AppError> {
    if (!source || source.trim().length === 0) {
      return ok<MarkdownToken[], AppError>([])
    }
    try {
      const tokens: MarkdownToken[] = []
      let i: number = 0
      const n: number = source.length

      while (i < n) {
        const ch: string = source.charAt(i)

        // heading # ~ ######
        let hh: number = 0
        let hi: number = i
        while (hi < n && source.charAt(hi) === '#' && hh < 6) { hh++; hi++ }
        if (hh > 0 && hi < n && source.charAt(hi) === ' ') {
          const e: number = ix(source, '\n', hi)
          const htxt: string = source.slice(hi + 1, e).trim()
          tokens.push(new MarkdownToken(TokenType.HEADING, hh, '', collectInline(htxt), htxt))
          i = e + 1
          continue
        }

        // code block ```
        if (ch === '`' && i + 2 < n && source.charAt(i + 1) === '`' && source.charAt(i + 2) === '`') {
          const langEnd: number = ix(source, '\n', i + 3)
          const lang: string = rtrim(source.slice(i + 3, langEnd))
          const close: number = source.indexOf('```', langEnd + 1)
          const body: string = close >= 0 ? source.slice(langEnd + 1, close) : source.slice(langEnd + 1)
          tokens.push(new MarkdownToken(TokenType.CODE_BLOCK, 0, lang, [], body))
          i = close >= 0 ? close + 3 : n
          continue
        }

        // HR --- or *** or ___
        if (isHr(source, i)) {
          tokens.push(new MarkdownToken(TokenType.HORIZONTAL_RULE, 0, '', [], ''))
          i = ix(source, '\n', i) + 1
          continue
        }

        // blockquote >
        if (ch === '>') {
          const e: number = ix(source, '\n', i)
          const qs: string = source.slice(i + 1, e).replace(/^\s+/, '')
          tokens.push(new MarkdownToken(TokenType.BLOCKQUOTE, 0, '', collectInline(qs), qs))
          i = e + 1
          continue
        }

        // unordered list
        if ((ch === '-' || ch === '*') && i + 1 < n && source.charAt(i + 1) === ' ') {
          const e: number = ix(source, '\n', i)
          const txt: string = source.slice(i + 2, e).trim()
          const spans: InlineSpan[] = collectInline(txt)
          if (spans.length === 0) { spans.push(new InlineSpan(txt, false, false, false)) }
          tokens.push(new MarkdownToken(TokenType.UNORDERED_LIST, 0, '', spans, txt))
          i = e + 1
          continue
        }

        // ordered list 1.
        if (ch >= '0' && ch <= '9') {
          let di: number = i
          while (di < n && source.charAt(di) >= '0' && source.charAt(di) <= '9') { di++ }
          if (di < n && source.charAt(di) === '.' && di + 1 < n && source.charAt(di + 1) === ' ') {
            const e: number = ix(source, '\n', di)
            const txt: string = source.slice(di + 2, e).trim()
            const spans: InlineSpan[] = collectInline(txt)
            if (spans.length === 0) { spans.push(new InlineSpan(txt, false, false, false)) }
            tokens.push(new MarkdownToken(TokenType.ORDERED_LIST, 0, '', spans, txt))
            i = e + 1
            continue
          }
        }

        // paragraph
        const pe: number = ix(source, '\n', i)
        const pt: string = source.slice(i, pe).trim()
        if (pt.length > 0) {
          tokens.push(new MarkdownToken(TokenType.PARAGRAPH, 0, '', collectInline(pt), pt))
        }
        i = pe + 1
      }
      return ok<MarkdownToken[], AppError>(tokens)
    } catch (e) {
      return ok<MarkdownToken[], AppError>([])
    }
  }
}
