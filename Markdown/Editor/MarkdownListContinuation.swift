//
//  MarkdownListContinuation.swift
//  Markdown
//
//  Created by Stéphane on 02/05/2026.
//

import Foundation

enum MarkdownListContinuation {
    private static let unorderedPattern = try! NSRegularExpression(pattern: #"^([ \t]*)([-+*])([ \t]+)(.*)$"#)
    private static let orderedPattern = try! NSRegularExpression(pattern: #"^([ \t]*)(\d+)\.([ \t]+)(.*)$"#)

    static func action(text: String, selectedRange: NSRange) -> MarkdownFormattingResult? {
        guard selectedRange.length == 0 else { return nil }

        let source = text as NSString
        let location = min(max(0, selectedRange.location), source.length)
        let lineRange = currentLineRange(in: source, around: location)
        let lineContentRange = lineRangeWithoutTrailingNewline(lineRange, in: source)

        guard location == NSMaxRange(lineContentRange) else { return nil }

        let line = source.substring(with: lineContentRange)

        if let match = unorderedMatch(in: line) {
            return continuationResult(
                in: source,
                lineContentRange: lineContentRange,
                indentation: match.indentation,
                marker: match.marker,
                spacing: match.spacing,
                content: match.content
            )
        }

        if let match = orderedMatch(in: line) {
            let nextMarker = "\(match.number + 1)."
            return continuationResult(
                in: source,
                lineContentRange: lineContentRange,
                indentation: match.indentation,
                marker: nextMarker,
                spacing: match.spacing,
                content: match.content
            )
        }

        return nil
    }

    private static func continuationResult(
        in source: NSString,
        lineContentRange: NSRange,
        indentation: String,
        marker: String,
        spacing: String,
        content: String
    ) -> MarkdownFormattingResult {
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return MarkdownFormattingResult(
                replacement: "",
                replacedRange: lineContentRange,
                text: source.replacingCharacters(in: lineContentRange, with: ""),
                selectedRange: NSRange(location: lineContentRange.location, length: 0)
            )
        }

        let insertion = "\n\(indentation)\(marker)\(spacing)"
        let insertionRange = NSRange(location: NSMaxRange(lineContentRange), length: 0)

        return MarkdownFormattingResult(
            replacement: insertion,
            replacedRange: insertionRange,
            text: source.replacingCharacters(in: insertionRange, with: insertion),
            selectedRange: NSRange(
                location: insertionRange.location + (insertion as NSString).length,
                length: 0
            )
        )
    }

    private static func unorderedMatch(in line: String) -> (indentation: String, marker: String, spacing: String, content: String)? {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        guard
            let match = unorderedPattern.firstMatch(in: line, range: fullRange),
            let indentation = substring(match, at: 1, in: nsLine),
            let marker = substring(match, at: 2, in: nsLine),
            let spacing = substring(match, at: 3, in: nsLine),
            let content = substring(match, at: 4, in: nsLine)
        else {
            return nil
        }

        return (indentation, marker, spacing, content)
    }

    private static func orderedMatch(in line: String) -> (indentation: String, number: Int, spacing: String, content: String)? {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        guard
            let match = orderedPattern.firstMatch(in: line, range: fullRange),
            let indentation = substring(match, at: 1, in: nsLine),
            let numberString = substring(match, at: 2, in: nsLine),
            let spacing = substring(match, at: 3, in: nsLine),
            let content = substring(match, at: 4, in: nsLine),
            let number = Int(numberString)
        else {
            return nil
        }

        return (indentation, number, spacing, content)
    }

    private static func currentLineRange(in source: NSString, around location: Int) -> NSRange {
        var start = min(location, source.length)
        var end = min(location, source.length)

        while start > 0, character(in: source, at: start - 1) != "\n" {
            start -= 1
        }

        while end < source.length, character(in: source, at: end) != "\n" {
            end += 1
        }

        if end < source.length, character(in: source, at: end) == "\n" {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    private static func lineRangeWithoutTrailingNewline(_ lineRange: NSRange, in source: NSString) -> NSRange {
        guard lineRange.length > 0 else { return lineRange }

        let lastCharacterIndex = NSMaxRange(lineRange) - 1
        guard character(in: source, at: lastCharacterIndex) == "\n" else { return lineRange }

        return NSRange(location: lineRange.location, length: lineRange.length - 1)
    }

    private static func character(in source: NSString, at index: Int) -> String {
        source.substring(with: NSRange(location: index, length: 1))
    }

    private static func substring(_ match: NSTextCheckingResult, at index: Int, in source: NSString) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return nil }
        return source.substring(with: range)
    }
}
