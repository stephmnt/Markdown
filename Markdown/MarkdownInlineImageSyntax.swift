//
//  MarkdownInlineImageSyntax.swift
//  Markdown
//
//  Created by Stéphane on 02/05/2026.
//

import Foundation

struct MarkdownInlineImageMatch {
    let fullRange: NSRange
    let altTextRange: NSRange
    let pathRange: NSRange
    let altText: String
    let path: String
}

enum MarkdownInlineImageSyntax {
    private static let trailingQuotedTitlePattern = try! NSRegularExpression(
        pattern: #"\s+(?:"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')\s*$"#
    )

    static func matchWholeString(_ string: String) -> MarkdownInlineImageMatch? {
        guard let match = firstMatch(in: string) else {
            return nil
        }

        return match.fullRange.length == (string as NSString).length ? match : nil
    }

    static func matches(in string: String, intersecting searchRange: NSRange? = nil) -> [MarkdownInlineImageMatch] {
        var matches: [MarkdownInlineImageMatch] = []
        let nsString = string as NSString
        let lowerBound = max(0, min(searchRange?.location ?? 0, nsString.length))
        let upperBound = min(nsString.length, searchRange.map(NSMaxRange) ?? nsString.length)
        var cursor = String.Index(utf16Offset: lowerBound, in: string)

        while cursor < string.endIndex {
            guard let start = string[cursor...].range(of: "![")?.lowerBound else {
                break
            }

            if start.utf16Offset(in: string) > upperBound {
                break
            }

            if let match = parseMatch(in: string, startingAt: start) {
                if searchRange == nil || NSIntersectionRange(match.fullRange, searchRange!).length > 0 {
                    matches.append(match)
                }
                cursor = String.Index(utf16Offset: NSMaxRange(match.fullRange), in: string)
            } else {
                cursor = string.index(after: start)
            }
        }

        return matches
    }

    private static func firstMatch(in string: String) -> MarkdownInlineImageMatch? {
        matches(in: string).first
    }

    private static func parseMatch(in string: String, startingAt start: String.Index) -> MarkdownInlineImageMatch? {
        guard
            start < string.endIndex,
            string[start] == "!"
        else {
            return nil
        }

        let openBracket = string.index(after: start)
        guard openBracket < string.endIndex, string[openBracket] == "[" else {
            return nil
        }

        guard let closeBracket = string[openBracket...].firstIndex(of: "]") else {
            return nil
        }

        let altTextStart = string.index(after: openBracket)
        let altTextRange = altTextStart..<closeBracket

        let openParen = string.index(after: closeBracket)
        guard openParen < string.endIndex, string[openParen] == "(" else {
            return nil
        }

        guard let closeParen = matchingClosingParenthesis(in: string, from: openParen) else {
            return nil
        }

        let contentStart = string.index(after: openParen)
        let contentRange = contentStart..<closeParen
        guard let pathRange = destinationRange(in: string, contentRange: contentRange) else {
            return nil
        }

        let fullRange = start..<string.index(after: closeParen)

        return MarkdownInlineImageMatch(
            fullRange: nsRange(of: fullRange, in: string),
            altTextRange: nsRange(of: altTextRange, in: string),
            pathRange: nsRange(of: pathRange, in: string),
            altText: String(string[altTextRange]),
            path: String(string[pathRange])
        )
    }

    private static func matchingClosingParenthesis(in string: String, from openParen: String.Index) -> String.Index? {
        var depth = 0
        var isInsideAngleBrackets = false
        var index = openParen

        while index < string.endIndex {
            let character = string[index]

            if character == "<" {
                isInsideAngleBrackets = true
            } else if character == ">" {
                isInsideAngleBrackets = false
            } else if !isInsideAngleBrackets {
                if character == "(" {
                    depth += 1
                } else if character == ")" {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }

            index = string.index(after: index)
        }

        return nil
    }

    private static func destinationRange(in string: String, contentRange: Range<String.Index>) -> Range<String.Index>? {
        guard let trimmedRange = trimmingWhitespace(in: string, range: contentRange) else {
            return nil
        }

        if string[trimmedRange.lowerBound] == "<" {
            let pathStart = string.index(after: trimmedRange.lowerBound)
            guard let closeAngle = string[pathStart..<trimmedRange.upperBound].firstIndex(of: ">") else {
                return nil
            }
            return pathStart..<closeAngle
        }

        let trimmedContent = String(string[trimmedRange])
        let nsString = trimmedContent as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        if let titleMatch = trailingQuotedTitlePattern.firstMatch(in: trimmedContent, range: fullRange) {
            let pathEnd = String.Index(
                utf16Offset: trimmedRange.lowerBound.utf16Offset(in: string) + titleMatch.range.location,
                in: string
            )
            return trimmingWhitespace(in: string, range: trimmedRange.lowerBound..<pathEnd)
        }

        return trimmedRange
    }

    private static func trimmingWhitespace(in string: String, range: Range<String.Index>) -> Range<String.Index>? {
        var start = range.lowerBound
        var end = range.upperBound

        while start < end, string[start].isWhitespace {
            start = string.index(after: start)
        }

        while start < end {
            let beforeEnd = string.index(before: end)
            guard string[beforeEnd].isWhitespace else {
                break
            }
            end = beforeEnd
        }

        return start < end ? start..<end : nil
    }

    private static func nsRange(of range: Range<String.Index>, in string: String) -> NSRange {
        NSRange(
            location: range.lowerBound.utf16Offset(in: string),
            length: range.upperBound.utf16Offset(in: string) - range.lowerBound.utf16Offset(in: string)
        )
    }
}
