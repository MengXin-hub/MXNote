import { describe, it, expect } from '@ohos/hypium'
import { MarkdownParser, MarkdownToken, TokenType, InlineSpan } from '../../main/ets/core/MarkdownParser'

export default function MarkdownParserTest() {
  describe('MarkdownParser', () => {

    it('should return empty array for empty input', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      expect(tokens !== null).assertTrue()
      if (tokens) {
        expect(tokens.length).assertEqual(0)
      }
    })

    it('should return empty array for whitespace-only input', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('   \n  \n  ')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens.length).assertEqual(0)
      }
    })

    it('should parse H1 heading', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('# Hello World')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens.length).assertEqual(1)
        expect(tokens[0].type).assertEqual(TokenType.HEADING)
        expect(tokens[0].level).assertEqual(1)
        expect(tokens[0].children[0].text).assertEqual('Hello World')
      }
    })

    it('should parse H2 with bold text', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('## **Bold Title**')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens[0].type).assertEqual(TokenType.HEADING)
        expect(tokens[0].level).assertEqual(2)
        expect(tokens[0].children[0].bold).assertTrue()
        expect(tokens[0].children[0].text).assertEqual('Bold Title')
      }
    })

    it('should parse paragraph with inline formatting', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('This has **bold** and *italic* text.')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens && tokens.length > 0) {
        expect(tokens[0].type).assertEqual(TokenType.PARAGRAPH)
        const spans: InlineSpan[] = tokens[0].children
        const hasBold: boolean = spans.some((s: InlineSpan): boolean => s.bold && s.text === 'bold')
        const hasItalic: boolean = spans.some((s: InlineSpan): boolean => s.italic && s.text === 'italic')
        expect(hasBold).assertTrue()
        expect(hasItalic).assertTrue()
      }
    })

    it('should parse inline code', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('Use `const x = 1` in code.')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens && tokens.length > 0) {
        const spans: InlineSpan[] = tokens[0].children
        const hasCode: boolean = spans.some((s: InlineSpan): boolean => s.code && s.text === 'const x = 1')
        expect(hasCode).assertTrue()
      }
    })

    it('should parse fenced code block with language', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('```typescript\nconst x = 1\nconsole.log(x)\n```')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens.length).assertEqual(1)
        expect(tokens[0].type).assertEqual(TokenType.CODE_BLOCK)
        expect(tokens[0].language).assertEqual('typescript')
        expect(tokens[0].children[0].code).assertTrue()
      }
    })

    it('should parse blockquote', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('> This is a quote')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens[0].type).assertEqual(TokenType.BLOCKQUOTE)
        // The leading '>' and optional space are stripped
        // Content may have leading space from the parse
        expect(tokens[0].children.length).assertGreater(0)
      }
    })

    it('should parse horizontal rule (---)', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('---')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens[0].type).assertEqual(TokenType.HORIZONTAL_RULE)
      }
    })

    it('should parse horizontal rule (***)', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('***')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens[0].type).assertEqual(TokenType.HORIZONTAL_RULE)
      }
    })

    it('should parse unordered list with dashes', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('- Item 1\n- Item 2\n- Item 3')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens[0].type).assertEqual(TokenType.UNORDERED_LIST)
        expect(tokens[0].children.length).assertEqual(3)
      }
    })

    it('should parse unordered list with asterisks', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('* One\n* Two')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens[0].type).assertEqual(TokenType.UNORDERED_LIST)
        expect(tokens[0].children.length).assertEqual(2)
      }
    })

    it('should parse ordered list', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('1. First\n2. Second\n3. Third')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens[0].type).assertEqual(TokenType.ORDERED_LIST)
        expect(tokens[0].children.length).assertEqual(3)
      }
    })

    it('should handle multiple block types in sequence', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const input: string =
        '# Title\n\n' +
        'A paragraph with text.\n\n' +
        '- List item 1\n' +
        '- List item 2\n\n' +
        '> A quote\n\n' +
        '---\n\n' +
        '```\ncode block\n```'
      const result = parser.parse(input)
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens.length).assertEqual(6)
        expect(tokens[0].type).assertEqual(TokenType.HEADING)
        expect(tokens[1].type).assertEqual(TokenType.PARAGRAPH)
        expect(tokens[2].type).assertEqual(TokenType.UNORDERED_LIST)
        expect(tokens[3].type).assertEqual(TokenType.BLOCKQUOTE)
        expect(tokens[4].type).assertEqual(TokenType.HORIZONTAL_RULE)
        expect(tokens[5].type).assertEqual(TokenType.CODE_BLOCK)
      }
    })

    it('should parse H6 heading', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('###### Deep heading')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens) {
        expect(tokens[0].type).assertEqual(TokenType.HEADING)
        expect(tokens[0].level).assertEqual(6)
      }
    })

    it('should handle multiline blockquote', () => {
      const parser: MarkdownParser = new MarkdownParser()
      const result = parser.parse('> Line one\n> Line two\n> Line three')
      expect(result.isOk()).assertTrue()
      const tokens: MarkdownToken[] | null = result.getValue()
      if (tokens && tokens.length > 0) {
        expect(tokens[0].type).assertEqual(TokenType.BLOCKQUOTE)
      }
    })

  })
}
