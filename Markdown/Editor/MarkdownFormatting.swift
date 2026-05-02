//
//  MarkdownFormatting.swift
//  Markdown
//
//  Created by Stéphane on 01/05/2026.
//

import Foundation

struct MarkdownFormattingResult {
    let replacement: String
    let replacedRange: NSRange
    let text: String
    let selectedRange: NSRange
}

enum MarkdownFormatting {
    private static let markdownEscapableCharacters = CharacterSet(charactersIn: #"\\`*_{}[]()#+-.!"#)
    private static let blockquotePrefixPattern = try! NSRegularExpression(pattern: #"^[ \t]*(?:> ?)+(.*)$"#)
    private static let atxHeadingPrefixPattern = try! NSRegularExpression(pattern: #"^[ \t]{0,3}#{1,6}[ \t]+(.*?)(?:[ \t]+#+[ \t]*)?$"#)
    private static let unorderedListPrefixPattern = try! NSRegularExpression(pattern: #"^[ \t]*[-+*][ \t]+(.*)$"#)
    private static let orderedListPrefixPattern = try! NSRegularExpression(pattern: #"^[ \t]*\d+\.[ \t]+(.*)$"#)
    private static let indentedCodePrefixPattern = try! NSRegularExpression(pattern: #"^(?: {4}|\t)(.*)$"#)

    static func wrap(
        text: String,
        selectedRange: NSRange,
        prefix: String,
        suffix: String,
        placeholder: String = "texte"
    ) -> MarkdownFormattingResult {
        let source = text as NSString
        let clampedRange = clamp(selectedRange, maxLength: source.length)

        let selectedText = source.substring(with: clampedRange)
        let body = selectedText.isEmpty ? placeholder : selectedText
        let replacement = prefix + body + suffix

        return replace(
            text: text,
            range: clampedRange,
            with: replacement,
            selectedRangeInReplacement: NSRange(
                location: (prefix as NSString).length,
                length: (body as NSString).length
            )
        )
    }

    static func inlineLink(
        text: String,
        selectedRange: NSRange,
        url: String = "https://example.com/"
    ) -> MarkdownFormattingResult {
        let selection = selectionContext(in: text, selectedRange: selectedRange)
        let label = selection.selectedText.isEmpty ? "texte" : selection.selectedText
        let replacement = "[\(label)](\(url))"

        let labelRange = NSRange(location: 1, length: (label as NSString).length)
        let urlRange = NSRange(
            location: labelRange.location + labelRange.length + 2,
            length: (url as NSString).length
        )

        return replace(
            text: text,
            range: selection.range,
            with: replacement,
            selectedRangeInReplacement: selection.selectedText.isEmpty ? labelRange : urlRange
        )
    }

    static func inlineImage(
        text: String,
        selectedRange: NSRange,
        path: String = "/chemin/image.jpg"
    ) -> MarkdownFormattingResult {
        let selection = selectionContext(in: text, selectedRange: selectedRange)
        let altText = selection.selectedText.isEmpty ? "Texte alternatif" : selection.selectedText
        let replacement = "![\(altText)](\(path))"
        let pathRange = NSRange(
            location: (altText as NSString).length + 5,
            length: (path as NSString).length
        )

        return replace(
            text: text,
            range: selection.range,
            with: replacement,
            selectedRangeInReplacement: selection.selectedText.isEmpty
                ? NSRange(location: 2, length: (altText as NSString).length)
                : pathRange
        )
    }

    static func escapeSelection(text: String, selectedRange: NSRange) -> MarkdownFormattingResult {
        let source = text as NSString
        let clampedRange = clamp(selectedRange, maxLength: source.length)

        if clampedRange.length == 0 {
            return replace(
                text: text,
                range: clampedRange,
                with: "\\",
                selectedRangeInReplacement: NSRange(location: 1, length: 0)
            )
        }

        let selectedText = source.substring(with: clampedRange)
        let escaped = selectedText.unicodeScalars.reduce(into: "") { partialResult, scalar in
            if markdownEscapableCharacters.contains(scalar) {
                partialResult.append("\\")
            }
            partialResult.append(String(scalar))
        }

        return replace(
            text: text,
            range: clampedRange,
            with: escaped,
            selectedRangeInReplacement: NSRange(location: 0, length: (escaped as NSString).length)
        )
    }

    static func prefixLines(
        text: String,
        selectedRange: NSRange,
        prefix: String,
        placeholder: String
    ) -> MarkdownFormattingResult {
        transformLines(
            text: text,
            selectedRange: selectedRange,
            emptyPlaceholder: placeholder
        ) { lines in
            lines.map { prefix + $0 }
        } selectionForEmptyLine: { _ in
            NSRange(location: (prefix as NSString).length, length: (placeholder as NSString).length)
        } caretAdjustment: { _ in
            (prefix as NSString).length
        }
    }

    static func numberLines(
        text: String,
        selectedRange: NSRange,
        placeholder: String = "Élément"
    ) -> MarkdownFormattingResult {
        transformLines(
            text: text,
            selectedRange: selectedRange,
            emptyPlaceholder: placeholder
        ) { lines in
            lines.enumerated().map { index, line in
                "\(index + 1). \(line)"
            }
        } selectionForEmptyLine: { _ in
            NSRange(location: 3, length: (placeholder as NSString).length)
        } caretAdjustment: { _ in
            3
        }
    }

    static func paragraphPrefix(
        text: String,
        selectedRange: NSRange,
        prefix: String,
        placeholder: String
    ) -> MarkdownFormattingResult {
        transformParagraphBlock(
            text: text,
            selectedRange: selectedRange,
            placeholder: placeholder
        ) { lines in
            lines.map { prefix + $0 }
        } collapsedSelection: { block, _, usedPlaceholder in
            usedPlaceholder
                ? NSRange(location: (prefix as NSString).length, length: (placeholder as NSString).length)
                : NSRange(location: block.visibleLength, length: 0)
        }
    }

    static func paragraphOrderedList(
        text: String,
        selectedRange: NSRange,
        placeholder: String = "Élément"
    ) -> MarkdownFormattingResult {
        transformParagraphBlock(
            text: text,
            selectedRange: selectedRange,
            placeholder: placeholder
        ) { lines in
            lines.enumerated().map { index, line in
                "\(index + 1). \(line)"
            }
        } collapsedSelection: { block, _, usedPlaceholder in
            usedPlaceholder
                ? NSRange(location: 3, length: (placeholder as NSString).length)
                : NSRange(location: block.visibleLength, length: 0)
        }
    }

    static func fencedCodeBlock(
        text: String,
        selectedRange: NSRange,
        placeholder: String = "code ici"
    ) -> MarkdownFormattingResult {
        let source = text as NSString
        let clampedRange = clamp(selectedRange, maxLength: source.length)
        let selectedText = source.substring(with: clampedRange)
        let body = selectedText.isEmpty ? placeholder : selectedText
        let replacement = "```\n\(body)\n```"

        return replace(
            text: text,
            range: clampedRange,
            with: replacement,
            selectedRangeInReplacement: NSRange(location: 4, length: (body as NSString).length)
        )
    }

    static func paragraphFencedBlock(
        text: String,
        selectedRange: NSRange,
        fence: String,
        placeholder: String
    ) -> MarkdownFormattingResult {
        let block = normalizedParagraphBlock(text: text, selectedRange: selectedRange)
        let shouldUsePlaceholder = block.lines.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let sourceLines = shouldUsePlaceholder ? [placeholder] : block.lines
        let body = sourceLines.joined(separator: "\n")
        let replacement = "\(fence)\n\(body)\n\(fence)" + (block.hasTrailingNewline ? "\n" : "")
        let bodyLocation = (fence as NSString).length + 1
        let bodySelection = shouldUsePlaceholder
            ? NSRange(location: bodyLocation, length: (placeholder as NSString).length)
            : NSRange(location: bodyLocation, length: (body as NSString).length)

        return replace(
            text: text,
            range: block.range,
            with: replacement,
            selectedRangeInReplacement: bodySelection
        )
    }

    static func horizontalRule(text: String, selectedRange: NSRange) -> MarkdownFormattingResult {
        let source = text as NSString
        let clampedRange = clamp(selectedRange, maxLength: source.length)
        let anchorLocation = clampedRange.location + clampedRange.length
        let currentLineRange = lineContentRange(in: source, around: anchorLocation)
        let currentHasText = lineHasText(in: source, range: currentLineRange)
        let previousLineHasText = previousLineContentRange(in: source, before: currentLineRange)
            .map { lineHasText(in: source, range: $0) } ?? false

        let replacementRange: NSRange
        let snippet: String

        if currentHasText {
            replacementRange = NSRange(location: NSMaxRange(currentLineRange), length: 0)
            snippet = "\n\n---"
        } else {
            replacementRange = currentLineRange
            snippet = previousLineHasText ? "\n---" : "---"
        }

        return replace(
            text: text,
            range: replacementRange,
            with: snippet,
            selectedRangeInReplacement: NSRange(location: (snippet as NSString).length, length: 0)
        )
    }

    static func hardLineBreak(text: String, selectedRange: NSRange) -> MarkdownFormattingResult {
        let source = text as NSString
        let clampedRange = clamp(selectedRange, maxLength: source.length)
        let selectedText = source.substring(with: clampedRange)
        let replacement = selectedText + "  \n"

        return replace(
            text: text,
            range: clampedRange,
            with: replacement,
            selectedRangeInReplacement: NSRange(
                location: (selectedText as NSString).length + 3,
                length: 0
            )
        )
    }

    static func replaceImagePath(
        text: String,
        pathRange: NSRange,
        with newPath: String
    ) -> MarkdownFormattingResult {
        let source = text as NSString
        let clampedRange = clamp(pathRange, maxLength: source.length)

        return replace(
            text: text,
            range: clampedRange,
            with: newPath,
            selectedRangeInReplacement: NSRange(location: 0, length: (newPath as NSString).length)
        )
    }

    private static func transformLines(
        text: String,
        selectedRange: NSRange,
        emptyPlaceholder: String,
        transform: ([String]) -> [String],
        selectionForEmptyLine: ([String]) -> NSRange,
        caretAdjustment: ([String]) -> Int
    ) -> MarkdownFormattingResult {
        let source = text as NSString
        let clampedRange = clamp(selectedRange, maxLength: source.length)

        if source.length == 0 {
            let replacement = transform([emptyPlaceholder]).joined(separator: "\n")
            return replace(
                text: text,
                range: clampedRange,
                with: replacement,
                selectedRangeInReplacement: selectionForEmptyLine([emptyPlaceholder])
            )
        }

        let lineRange = expandedLineRange(in: source, around: clampedRange)
        let blockText = source.substring(with: lineRange)
        let hasTrailingNewline = blockText.hasSuffix("\n")
        let blockWithoutTrailingNewline = hasTrailingNewline ? String(blockText.dropLast()) : blockText
        let rawLines = blockWithoutTrailingNewline.isEmpty ? [""] : blockWithoutTrailingNewline.components(separatedBy: "\n")
        let lines = rawLines.map { $0.isEmpty ? emptyPlaceholder : $0 }
        let replacementLines = transform(lines)
        let replacement = replacementLines.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")

        if clampedRange.length == 0 && rawLines.count == 1 {
            let originalLine = rawLines[0]
            if originalLine.isEmpty {
                return replace(
                    text: text,
                    range: lineRange,
                    with: replacement,
                    selectedRangeInReplacement: selectionForEmptyLine(lines)
                )
            }

            let caretOffset = min(
                clampedRange.location - lineRange.location,
                (originalLine as NSString).length
            ) + caretAdjustment(lines)

            return replace(
                text: text,
                range: lineRange,
                with: replacement,
                selectedRangeInReplacement: NSRange(location: caretOffset, length: 0)
            )
        }

        let selectableLength = max(0, (replacement as NSString).length - (hasTrailingNewline ? 1 : 0))
        return replace(
            text: text,
            range: lineRange,
            with: replacement,
            selectedRangeInReplacement: NSRange(location: 0, length: selectableLength)
        )
    }

    private static func transformParagraphBlock(
        text: String,
        selectedRange: NSRange,
        placeholder: String,
        transform: ([String]) -> [String],
        collapsedSelection: (ReplacementParagraphBlock, [String], Bool) -> NSRange
    ) -> MarkdownFormattingResult {
        let block = normalizedParagraphBlock(text: text, selectedRange: selectedRange)
        let usesPlaceholder = block.lines.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let sourceLines = usesPlaceholder ? [placeholder] : block.lines
        let replacementLines = transform(sourceLines)
        let replacement = replacementLines.joined(separator: "\n") + (block.hasTrailingNewline ? "\n" : "")
        let replacementBlock = ReplacementParagraphBlock(
            replacement: replacement,
            hasTrailingNewline: block.hasTrailingNewline
        )

        if selectedRange.length == 0, sourceLines.count == 1 {
            return replace(
                text: text,
                range: block.range,
                with: replacement,
                selectedRangeInReplacement: collapsedSelection(replacementBlock, sourceLines, usesPlaceholder)
            )
        }

        return replace(
            text: text,
            range: block.range,
            with: replacement,
            selectedRangeInReplacement: NSRange(location: 0, length: replacementBlock.visibleLength)
        )
    }

    private static func replace(
        text: String,
        range: NSRange,
        with replacement: String,
        selectedRangeInReplacement: NSRange
    ) -> MarkdownFormattingResult {
        let source = text as NSString
        let updatedText = source.replacingCharacters(in: range, with: replacement)
        let mappedSelection = NSRange(
            location: range.location + selectedRangeInReplacement.location,
            length: selectedRangeInReplacement.length
        )

        return MarkdownFormattingResult(
            replacement: replacement,
            replacedRange: range,
            text: updatedText,
            selectedRange: mappedSelection
        )
    }

    private static func expandedLineRange(in source: NSString, around selectedRange: NSRange) -> NSRange {
        if source.length == 0 {
            return NSRange(location: 0, length: 0)
        }

        let safeStart = min(selectedRange.location, max(0, source.length - 1))
        let startRange = source.lineRange(for: NSRange(location: safeStart, length: 0))

        guard selectedRange.length > 0 else {
            return startRange
        }

        let safeEnd = min(max(selectedRange.location, NSMaxRange(selectedRange) - 1), source.length - 1)
        let endRange = source.lineRange(for: NSRange(location: safeEnd, length: 0))

        return NSRange(
            location: startRange.location,
            length: NSMaxRange(endRange) - startRange.location
        )
    }

    private static func clamp(_ range: NSRange, maxLength: Int) -> NSRange {
        let location = min(max(0, range.location), maxLength)
        let length = min(max(0, range.length), max(0, maxLength - location))
        return NSRange(location: location, length: length)
    }

    private static func selectionContext(in text: String, selectedRange: NSRange) -> SelectionContext {
        let source = text as NSString
        let clampedRange = clamp(selectedRange, maxLength: source.length)
        return SelectionContext(
            range: clampedRange,
            selectedText: source.substring(with: clampedRange)
        )
    }

    private static func isNewlineCharacter(in source: NSString, at index: Int) -> Bool {
        guard index >= 0, index < source.length else { return false }
        let character = source.substring(with: NSRange(location: index, length: 1))
        return character == "\n"
    }

    private static func lineContentRange(in source: NSString, around location: Int) -> NSRange {
        let clampedLocation = min(max(0, location), source.length)
        var start = clampedLocation
        var end = clampedLocation

        while start > 0, !isNewlineCharacter(in: source, at: start - 1) {
            start -= 1
        }

        while end < source.length, !isNewlineCharacter(in: source, at: end) {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    private static func previousLineContentRange(in source: NSString, before currentRange: NSRange) -> NSRange? {
        guard currentRange.location > 0 else { return nil }
        return lineContentRange(in: source, around: currentRange.location - 1)
    }

    private static func lineHasText(in source: NSString, range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        let text = source.substring(with: range)
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func normalizedParagraphBlock(text: String, selectedRange: NSRange) -> NormalizedParagraphBlock {
        let source = text as NSString
        let clampedRange = clamp(selectedRange, maxLength: source.length)

        if source.length == 0 {
            return NormalizedParagraphBlock(range: clampedRange, lines: [""], hasTrailingNewline: false)
        }

        let paragraphRange = expandedParagraphRange(in: source, around: clampedRange)
        let blockText = source.substring(with: paragraphRange)
        let hasTrailingNewline = blockText.hasSuffix("\n")
        let bodyText = hasTrailingNewline ? String(blockText.dropLast()) : blockText
        let rawLines = bodyText.isEmpty ? [""] : bodyText.components(separatedBy: "\n")
        let unwrappedLines = unwrapParagraphLines(rawLines)
        let normalizedLines = unwrappedLines.map { line in
            stripExistingParagraphStyle(line)
        }

        return NormalizedParagraphBlock(
            range: paragraphRange,
            lines: normalizedLines,
            hasTrailingNewline: hasTrailingNewline
        )
    }

    private static func expandedParagraphRange(in source: NSString, around selectedRange: NSRange) -> NSRange {
        var range = expandedLineRange(in: source, around: selectedRange)

        if let setextRange = expandedSetextHeadingRange(in: source, currentRange: range) {
            range = setextRange
        }

        return range
    }

    private static func expandedSetextHeadingRange(in source: NSString, currentRange: NSRange) -> NSRange? {
        let currentLine = lineText(in: source, range: currentRange)

        if isSetextUnderlineLine(currentLine), let previousLineRange = previousLineRange(in: source, before: currentRange) {
            return NSRange(
                location: previousLineRange.location,
                length: NSMaxRange(currentRange) - previousLineRange.location
            )
        }

        guard let nextLineRange = nextLineRange(in: source, after: currentRange) else {
            return nil
        }

        let nextLine = lineText(in: source, range: nextLineRange)
        guard isSetextUnderlineLine(nextLine) else {
            return nil
        }

        return NSRange(
            location: currentRange.location,
            length: NSMaxRange(nextLineRange) - currentRange.location
        )
    }

    private static func unwrapParagraphLines(_ lines: [String]) -> [String] {
        if isWrappedByCodeFence(lines) || isWrappedByLatexFence(lines) {
            let innerLines = Array(lines.dropFirst().dropLast())
            return innerLines.isEmpty ? [""] : innerLines
        }

        if lines.count == 2, isSetextUnderlineLine(lines[1]) {
            return [lines[0]]
        }

        return lines
    }

    private static func stripExistingParagraphStyle(_ line: String) -> String {
        var current = line

        while true {
            let updated = stripSingleParagraphMarker(from: current)
            if updated == current {
                return current
            }
            current = updated
        }
    }

    private static func stripSingleParagraphMarker(from line: String) -> String {
        let patterns = [
            blockquotePrefixPattern,
            atxHeadingPrefixPattern,
            unorderedListPrefixPattern,
            orderedListPrefixPattern,
            indentedCodePrefixPattern
        ]

        for pattern in patterns {
            if let stripped = capturedBody(from: line, using: pattern) {
                return stripped
            }
        }

        return line
    }

    private static func capturedBody(from line: String, using regex: NSRegularExpression) -> String? {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        guard let match = regex.firstMatch(in: line, range: fullRange) else {
            return nil
        }

        let bodyRange = match.range(at: 1)
        guard bodyRange.location != NSNotFound else {
            return nil
        }

        return nsLine.substring(with: bodyRange)
    }

    private static func isSetextUnderlineLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return false }
        return Set(trimmed).count == 1 && (trimmed.first == "=" || trimmed.first == "-")
    }

    private static func isWrappedByCodeFence(_ lines: [String]) -> Bool {
        guard let first = lines.first, let last = lines.last, lines.count >= 2 else { return false }
        return first.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
            && last.trimmingCharacters(in: .whitespacesAndNewlines) == "```"
    }

    private static func isWrappedByLatexFence(_ lines: [String]) -> Bool {
        guard let first = lines.first, let last = lines.last, lines.count >= 2 else { return false }
        return first.trimmingCharacters(in: .whitespacesAndNewlines) == "$$"
            && last.trimmingCharacters(in: .whitespacesAndNewlines) == "$$"
    }

    private static func previousLineRange(in source: NSString, before range: NSRange) -> NSRange? {
        guard range.location > 0 else { return nil }

        let previousLocation = max(0, range.location - 1)
        let previousLine = source.lineRange(for: NSRange(location: previousLocation, length: 0))
        return previousLine.location == range.location ? nil : previousLine
    }

    private static func nextLineRange(in source: NSString, after range: NSRange) -> NSRange? {
        let nextLocation = NSMaxRange(range)
        guard nextLocation < source.length else { return nil }
        return source.lineRange(for: NSRange(location: nextLocation, length: 0))
    }

    private static func lineText(in source: NSString, range: NSRange) -> String {
        let fullLine = source.substring(with: range)
        return fullLine.hasSuffix("\n") ? String(fullLine.dropLast()) : fullLine
    }
}

private struct NormalizedParagraphBlock {
    let range: NSRange
    let lines: [String]
    let hasTrailingNewline: Bool
}

private struct SelectionContext {
    let range: NSRange
    let selectedText: String
}

private struct ReplacementParagraphBlock {
    let replacement: String
    let hasTrailingNewline: Bool

    var visibleLength: Int {
        max(0, (replacement as NSString).length - (hasTrailingNewline ? 1 : 0))
    }
}
