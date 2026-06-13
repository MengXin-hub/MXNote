import { ok, err, Result, AppError, ErrorCode } from '../model/Result'

/**
 * Token types produced by the Markdown parser.
 * Each token maps 1:1 to an ArkUI rendering primitive.
 */
export enum TokenType {
  HEADING = 'HEADING',
  PARAGRAPH = 'PARAGRAPH',
  CODE_BLOCK = 'CODE_BLOCK',
  BLOCKQUOTE = 'BLOCKQUOTE',
  HORIZONTAL_RULE = 'HORIZONTAL_RULE',
  UNORDERED_LIST = 'UNORDERED_LIST',
  ORDERED_LIST = 'ORDERED_LIST',
  LIST_ITEM = 'LIST_ITEM',
}

/**
 * Inline formatting span within a block-level token.
 */
export interface InlineSpan {
  text: string
  bold: boolean
  italic: boolean
  code: boolean
}

/**
 * A parsed block-level token.
 *
 * For HEADING, level is 1-6.
 * For paragraphs and list items, children contains inline spans.
 * For CODE_BLOCK, language is the optional info string.
 */
export interface MarkdownToken {
  type: TokenType
  level: number // heading level (1-6), 0 for non-headings
  language: string // code block language, '' for none
  children: InlineSpan[] // inline content spans
  rawText: string // original source text
}

/**
 * Optimized Markdown parser for MXNote.
 *
 * V1 scope: headings (# ~ ######), bold (**text**), italic (*text*),
 * inline code (`code`), code blocks (```), blockquotes (>), lists (-, 1.),
 * horizontal rules (---), paragraphs.
 *
 * Architecture: single-pass scan. No AST tree. Direct token production.
 * Highlight tokens are embedded in InlineSpan (bold/italic/code flags).
 *
 * Performance: O(n) single pass. Handles V1 typical notes (<50KB) in <5ms.
 */
export class MarkdownParser {
  /**
   * Parse Markdown source into renderable tokens.
   * Returns Result with token array or parse error.
   */
  parse(source: string): Result<MarkdownToken[], AppError> {
    if (!source || source.trim().length === 0) {
      return ok<MarkdownToken[], AppError>([])
    }

    try {
      const lines: string[] = source.split('\n')
      const tokens: MarkdownToken[] = []
      let i: number = 0

      while (i < lines.length) {
        const line: string = lines[i]

        // Blank line
        if (line.trim().length === 0) {
          i++
          continue
        }

        // Code block: ```
        if (line.trimStart().startsWith('```')) {
          const result: ParseBlockResult = this.parseCodeBlock(lines, i)
          tokens.push(result.token)
          i = result.nextIndex
          continue
        }

        // Horizontal rule: ---, ***, ___
        if (/^(-{3,}|\*{3,}|_{3,})\s*$/.test(line.trim())) {
          tokens.push({
            type: TokenType.HORIZONTAL_RULE,
            level: 0,
            language: '',
            children: [],
            rawText: line,
          })
          i++
          continue
        }

        // Heading: # ~ ######
        const headingMatch: RegExpMatchArray | null = line.match(/^(#{1,6})\s+(.+)/)
        if (headingMatch) {
          const level: number = headingMatch[1].length
          const text: string = headingMatch[2]
          tokens.push({
            type: TokenType.HEADING,
            level: level,
            language: '',
            children: this.parseInlineSpans(text),
            rawText: line,
          })
          i++
          continue
        }

        // Blockquote: >
        if (line.trimStart().startsWith('>')) {
          const result: ParseBlockResult = this.parseBlockquote(lines, i)
          tokens.push(result.token)
          i = result.nextIndex
          continue
        }

        // Unordered list: -, *, +
        if (/^[\s]*[-*+]\s+/.test(line)) {
          const result: ParseBlockResult = this.parseList(lines, i, false)
          tokens.push(result.token)
          i = result.nextIndex
          continue
        }

        // Ordered list: 1.
        if (/^[\s]*\d+\.\s+/.test(line)) {
          const result: ParseBlockResult = this.parseList(lines, i, true)
          tokens.push(result.token)
          i = result.nextIndex
          continue
        }

        // Paragraph (default)
        const result: ParseBlockResult = this.parseParagraph(lines, i)
        tokens.push(result.token)
        i = result.nextIndex
      }

      return ok<MarkdownToken[], AppError>(tokens)
    } catch (e) {
      return err<MarkdownToken[], AppError>(
        new AppError(ErrorCode.PARSE_INVALID_MARKDOWN, 'Markdown parse failed')
      )
    }
  }

  /**
   * Parse inline formatting: bold (**), italic (*), inline code (`).
   * Extracts highlight token info (bold/italic/code flags) for the
   * syntax highlighter to consume without a separate lexer pass.
   */
  private parseInlineSpans(text: string): InlineSpan[] {
    const spans: InlineSpan[] = []
    let remaining: string = text

    while (remaining.length > 0) {
      // Bold: **text**
      const boldMatch: RegExpMatchArray | null = remaining.match(/^\*\*(.+?)\*\*/)
      if (boldMatch) {
        spans.push({ text: boldMatch[1], bold: true, italic: false, code: false })
        remaining = remaining.slice(boldMatch[0].length)
        continue
      }

      // Italic: *text* (but not **)
      const italicMatch: RegExpMatchArray | null = remaining.match(/^\*(.+?)\*(?!\*)/)
      if (italicMatch) {
        spans.push({ text: italicMatch[1], bold: false, italic: true, code: false })
        remaining = remaining.slice(italicMatch[0].length)
        continue
      }

      // Inline code: `code`
      const codeMatch: RegExpMatchArray | null = remaining.match(/^`(.+?)`/)
      if (codeMatch) {
        spans.push({ text: codeMatch[1], bold: false, italic: false, code: true })
        remaining = remaining.slice(codeMatch[0].length)
        continue
      }

      // Plain text: up to next formatting marker
      const nextMarker: number = Math.min(
        ...([remaining.indexOf('**'), remaining.indexOf('*'), remaining.indexOf('`')]
          .filter((n: number): boolean => n >= 0)),
      )

      if (nextMarker === Infinity || nextMarker < 0) {
        // No more markers — rest is plain text
        spans.push({ text: remaining, bold: false, italic: false, code: false })
        break
      }

      if (nextMarker > 0) {
        spans.push({
          text: remaining.slice(0, nextMarker),
          bold: false,
          italic: false,
          code: false,
        })
      }
      remaining = remaining.slice(nextMarker)
    }

    return spans.filter((s: InlineSpan): boolean => s.text.length > 0)
  }

  /**
   * Parse a fenced code block. Collects lines until closing ```.
   */
  private parseCodeBlock(lines: string[], startIndex: number): ParseBlockResult {
    const openLine: string = lines[startIndex]
    const language: string = openLine.trimStart().slice(3).trim()
    const codeLines: string[] = []

    let i: number = startIndex + 1
    while (i < lines.length) {
      if (lines[i].trimStart().startsWith('```')) {
        i++ // skip closing ```
        break
      }
      codeLines.push(lines[i])
      i++
    }

    return {
      token: {
        type: TokenType.CODE_BLOCK,
        level: 0,
        language: language,
        children: [{ text: codeLines.join('\n'), bold: false, italic: false, code: true }],
        rawText: codeLines.join('\n'),
      },
      nextIndex: i,
    }
  }

  /**
   * Parse a blockquote. Collects contiguous > lines.
   */
  private parseBlockquote(lines: string[], startIndex: number): ParseBlockResult {
    const quoteLines: string[] = []
    let i: number = startIndex

    while (i < lines.length) {
      const line: string = lines[i]
      if (line.trimStart().startsWith('>')) {
        // Strip the leading > and optional space
        const content: string = line.trimStart().slice(1).replace(/^\s?/, '')
        quoteLines.push(content)
        i++
      } else if (line.trim().length === 0 && i + 1 < lines.length && lines[i + 1].trimStart().startsWith('>')) {
        // Empty line inside blockquote
        quoteLines.push('')
        i++
      } else {
        break
      }
    }

    return {
      token: {
        type: TokenType.BLOCKQUOTE,
        level: 0,
        language: '',
        children: this.parseInlineSpans(quoteLines.join('\n')),
        rawText: quoteLines.join('\n'),
      },
      nextIndex: i,
    }
  }

  /**
   * Parse contiguous paragraph lines.
   */
  private parseParagraph(lines: string[], startIndex: number): ParseBlockResult {
    const paraLines: string[] = []
    let i: number = startIndex

    while (i < lines.length) {
      const line: string = lines[i]
      // Stop at blank lines, headings, code blocks, blockquotes, lists, HR
      if (
        line.trim().length === 0 ||
        /^(#{1,6})\s+/.test(line) ||
        line.trimStart().startsWith('```') ||
        line.trimStart().startsWith('>') ||
        /^[\s]*[-*+]\s+/.test(line) ||
        /^[\s]*\d+\.\s+/.test(line) ||
        /^(-{3,}|\*{3,}|_{3,})\s*$/.test(line.trim())
      ) {
        break
      }
      paraLines.push(line)
      i++
    }

    return {
      token: {
        type: TokenType.PARAGRAPH,
        level: 0,
        language: '',
        children: this.parseInlineSpans(paraLines.join('\n')),
        rawText: paraLines.join('\n'),
      },
      nextIndex: i,
    }
  }

  /**
   * Parse contiguous list items.
   */
  private parseList(lines: string[], startIndex: number, ordered: boolean): ParseBlockResult {
    const listType: TokenType = ordered ? TokenType.ORDERED_LIST : TokenType.UNORDERED_LIST
    const items: InlineSpan[] = []
    let i: number = startIndex

    while (i < lines.length) {
      const line: string = lines[i]
      const listMatch: RegExpMatchArray | null = ordered
        ? line.match(/^[\s]*\d+\.\s+(.+)/)
        : line.match(/^[\s]*[-*+]\s+(.+)/)

      if (listMatch) {
        items.push({ text: listMatch[1], bold: false, italic: false, code: false })
        i++
      } else if (line.trim().length === 0) {
        break
      } else {
        break
      }
    }

    if (items.length === 0) {
      // Degenerate case: treat as paragraph
      return this.parseParagraph(lines, startIndex)
    }

    return {
      token: {
        type: listType,
        level: 0,
        language: '',
        children: items,
        rawText: items.map((s: InlineSpan): string => s.text).join('\n'),
      },
      nextIndex: i,
    }
  }
}

/**
 * Internal helper: result of parsing a block-level element.
 */
interface ParseBlockResult {
  token: MarkdownToken
  nextIndex: number // index of the NEXT unprocessed line
}
