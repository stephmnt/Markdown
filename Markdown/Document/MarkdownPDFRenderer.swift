//
//  MarkdownPDFRenderer.swift
//  Markdown
//
//  Created by Stéphane on 02/05/2026.
//

import AppKit
import Foundation

extension NSAttributedString.Key {
    static let markdownLiteralBlock = NSAttributedString.Key("MarkdownLiteralBlock")
    static let markdownCustomListItem = NSAttributedString.Key("MarkdownCustomListItem")
    static let markdownThematicBreak = NSAttributedString.Key("MarkdownThematicBreak")
    static let markdownCenteredImage = NSAttributedString.Key("MarkdownCenteredImage")
}

/// Renders the current Markdown document as a paginated A4 PDF.
enum MarkdownPDFRenderer {
    static let paperSize = NSSize(width: 595.2, height: 841.8)

    private static let pointsPerCentimeter: CGFloat = 72 / 2.54
    private static let maxImageHeightRatio: CGFloat = 0.45
    private static let pageMargins = NSEdgeInsets(
        top: 2.5 * pointsPerCentimeter,
        left: 2.5 * pointsPerCentimeter,
        bottom: 2.5 * pointsPerCentimeter,
        right: 2.5 * pointsPerCentimeter
    )
    private static let baseFontSize: CGFloat = 12
    private static let codeBackgroundColor = NSColor(calibratedWhite: 0.94, alpha: 1)
    private static let quoteColor = NSColor(calibratedWhite: 0.28, alpha: 1)
    private static let markerColor = NSColor(calibratedWhite: 0.55, alpha: 1)
    private static let linkColor = NSColor(calibratedRed: 0.07, green: 0.28, blue: 0.63, alpha: 1)
    private static let subscriptPattern = try! NSRegularExpression(pattern: #"(?<!~)~([^~\n]+)~(?!~)"#)
    private static let superscriptPattern = try! NSRegularExpression(pattern: #"(?<!\^)\^([^^\n]+)\^(?!\^)"#)
    private static let protectedSubscriptPattern = try! NSRegularExpression(
        pattern: #"SUBSCRIPTOPENMARKER(.+?)SUBSCRIPTCLOSEMARKER"#
    )
    private static let unorderedListPattern = try! NSRegularExpression(pattern: #"^(\s*)([-+*])\s+(.+)$"#)
    private static let orderedListPattern = try! NSRegularExpression(pattern: #"^(\s*)(\d+)\.\s+(.+)$"#)
    private static let thematicBreakPattern = try! NSRegularExpression(pattern: #"^\s{0,3}(?:(?:-\s*){3,}|(?:_\s*){3,}|(?:\*\s*){3,})$"#)
    private static let atxHeadingPattern = try! NSRegularExpression(pattern: #"^\s{0,3}#{1,6}\s+.*$"#)
    private static let blockquotePattern = try! NSRegularExpression(pattern: #"^\s{0,3}>\s?.*$"#)
    private static let referenceDefinitionPattern = try! NSRegularExpression(pattern: #"^\s{0,3}\[[^\]]+\]:\s+\S.*$"#)
    private static let setextUnderlinePattern = try! NSRegularExpression(pattern: #"^\s{0,3}(?:=+|-+)\s*$"#)

    private static var printableWidth: CGFloat {
        paperSize.width - pageMargins.left - pageMargins.right
    }

    @MainActor
    static func pdfData(for markdown: String, baseURL: URL? = nil) throws -> Data {
        MarkdownPDFDiagnostics.record("pdfData start markdownLength=\(markdown.utf16.count)")
        let attributedString = try attributedString(for: markdown, baseURL: baseURL)
        let printableView = makePrintableView(for: attributedString)
        let data = try printableView.pdfData()
        MarkdownPDFDiagnostics.record("pdfData end bytes=\(data.count)")
        return data
    }

    @MainActor
    static func writePDF(for markdown: String, to outputURL: URL, baseURL: URL? = nil) throws {
        MarkdownPDFDiagnostics.record("writePDF start markdownLength=\(markdown.utf16.count) outputURL=\(outputURL.path)")
        let attributedString = try attributedString(for: markdown, baseURL: baseURL)
        let printableView = makePrintableView(for: attributedString)
        try printableView.writePDF(to: outputURL)
        MarkdownPDFDiagnostics.record("writePDF end outputURL=\(outputURL.path)")
    }

    static func localImageURLs(in markdown: String, baseURL: URL? = nil) -> [URL] {
        let blocks = markdownBlocks(in: markdown)
        var urls: [URL] = []
        var seenPaths: Set<String> = []

        for block in blocks {
            guard let imageMatch = inlineImageMatch(in: block) else {
                continue
            }

            guard let url = resolvedImageURL(for: imageMatch.path, baseURL: baseURL) else {
                continue
            }

            let standardizedURL = url.standardizedFileURL
            guard seenPaths.insert(standardizedURL.path).inserted else {
                continue
            }

            urls.append(standardizedURL)
        }

        return urls
    }

    static func attributedString(for markdown: String, baseURL: URL? = nil) throws -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        let blocks = markdownBlocks(in: markdown)
        let mutable = NSMutableAttributedString()
        MarkdownPDFDiagnostics.record("attributedString blocks=\(blocks.count)")

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                mutable.append(NSAttributedString(string: "\n"))
            }

            let blockKind = diagnosticBlockKind(for: block)
            let start = CFAbsoluteTimeGetCurrent()
            MarkdownPDFDiagnostics.record(
                "render block index=\(index) kind=\(blockKind.rawValue) length=\(block.utf16.count) preview=\(MarkdownPDFDiagnostics.preview(block))"
            )
            let renderedBlock = try renderBlock(block, options: options, baseURL: baseURL)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            MarkdownPDFDiagnostics.record(
                "render block done index=\(index) kind=\(blockKind.rawValue) outputLength=\(renderedBlock.length) elapsed=\(String(format: "%.3f", elapsed))s"
            )
            mutable.append(renderedBlock)
        }

        MarkdownPDFDiagnostics.record("apply thematic break replacements")
        replaceEmptyThematicBreakParagraphs(in: mutable)
        MarkdownPDFDiagnostics.record("apply paragraph styles")
        applyParagraphStyles(to: mutable)
        MarkdownPDFDiagnostics.record("apply inline styles")
        applyInlineStyles(to: mutable)
        MarkdownPDFDiagnostics.record("apply subscript and superscript styles")
        applyCustomSubscriptsAndSuperscripts(to: mutable)
        MarkdownPDFDiagnostics.record("attributedString complete length=\(mutable.length)")

        return mutable
    }

    private static func markdownBlocks(in markdown: String) -> [String] {
        let normalizedMarkdown = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalizedMarkdown.split(separator: "\n", omittingEmptySubsequences: false)

        var blocks: [String] = []
        var currentBlock: [String] = []
        var currentBlockKind: MarkdownPDFBlockKind?
        var activeFence: String?

        func flushCurrentBlock() {
            let block = currentBlock.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !block.isEmpty {
                blocks.append(block)
            }
            currentBlock.removeAll(keepingCapacity: true)
            currentBlockKind = nil
        }

        func startNewBlock(with line: String, kind: MarkdownPDFBlockKind) {
            currentBlock = [line]
            currentBlockKind = kind
        }

        for lineSlice in lines {
            let line = String(lineSlice)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine == "```" || trimmedLine.hasPrefix("```") {
                if activeFence == "```" {
                    currentBlock.append(line)
                    activeFence = nil
                    flushCurrentBlock()
                    continue
                }

                flushCurrentBlock()
                if activeFence == nil {
                    activeFence = "```"
                }
                startNewBlock(with: line, kind: .fencedCode)
                continue
            }

            if trimmedLine == "$$" {
                if activeFence == "$$" {
                    currentBlock.append(line)
                    activeFence = nil
                    flushCurrentBlock()
                    continue
                }

                flushCurrentBlock()
                if activeFence == nil {
                    activeFence = "$$"
                }
                startNewBlock(with: line, kind: .latexBlock)
                continue
            }

            if activeFence != nil {
                currentBlock.append(line)
                continue
            }

            if trimmedLine.isEmpty {
                flushCurrentBlock()
                continue
            }

            let lineKind = blockKind(for: line)

            if lineKind == .inlineImage {
                flushCurrentBlock()
                blocks.append(trimmedLine)
                continue
            }

            switch lineKind {
            case .heading, .thematicBreak, .referenceDefinition:
                flushCurrentBlock()
                blocks.append(line)

            case .unorderedList:
                if currentBlockKind == .unorderedList || canContinueListBlock(currentBlockKind, with: line) {
                    currentBlock.append(line)
                    currentBlockKind = .unorderedList
                } else {
                    flushCurrentBlock()
                    startNewBlock(with: line, kind: .unorderedList)
                }

            case .orderedList:
                if currentBlockKind == .orderedList || canContinueListBlock(currentBlockKind, with: line) {
                    currentBlock.append(line)
                    currentBlockKind = .orderedList
                } else {
                    flushCurrentBlock()
                    startNewBlock(with: line, kind: .orderedList)
                }

            case .blockquote:
                if currentBlockKind == .blockquote {
                    currentBlock.append(line)
                } else {
                    flushCurrentBlock()
                    startNewBlock(with: line, kind: .blockquote)
                }

            case .setextUnderline:
                if currentBlockKind == .paragraph, !currentBlock.isEmpty {
                    currentBlock.append(line)
                    flushCurrentBlock()
                } else {
                    flushCurrentBlock()
                    blocks.append(line)
                }

            case .paragraph:
                if currentBlockKind == .paragraph {
                    currentBlock.append(line)
                } else {
                    flushCurrentBlock()
                    startNewBlock(with: line, kind: .paragraph)
                }

            case .indentedCode:
                if currentBlockKind == .indentedCode {
                    currentBlock.append(line)
                } else {
                    flushCurrentBlock()
                    startNewBlock(with: line, kind: .indentedCode)
                }

            case .inlineImage, .fencedCode, .latexBlock:
                break
            }
        }

        flushCurrentBlock()
        return blocks
    }

    private static func blockKind(for line: String) -> MarkdownPDFBlockKind {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        if trimmedLine == "```" || trimmedLine.hasPrefix("```") {
            return .fencedCode
        }

        if trimmedLine == "$$" {
            return .latexBlock
        }

        if inlineImageMatch(in: trimmedLine) != nil {
            return .inlineImage
        }

        if matches(atxHeadingPattern, in: line) {
            return .heading
        }

        if matches(thematicBreakPattern, in: line) {
            return .thematicBreak
        }

        if matches(referenceDefinitionPattern, in: line) {
            return .referenceDefinition
        }

        if matches(blockquotePattern, in: line) {
            return .blockquote
        }

        if listMatch(for: unorderedListPattern, in: line) != nil {
            return .unorderedList
        }

        if listMatch(for: orderedListPattern, in: line) != nil {
            return .orderedList
        }

        if matches(setextUnderlinePattern, in: line) {
            return .setextUnderline
        }

        if line.hasPrefix("    ") || line.hasPrefix("\t") {
            return .indentedCode
        }

        return .paragraph
    }

    private static func matches(_ pattern: NSRegularExpression, in line: String) -> Bool {
        let nsString = line as NSString
        let range = NSRange(location: 0, length: nsString.length)
        return pattern.firstMatch(in: line, range: range) != nil
    }

    private static func canContinueListBlock(_ currentKind: MarkdownPDFBlockKind?, with line: String) -> Bool {
        guard currentKind == .unorderedList || currentKind == .orderedList else {
            return false
        }

        return line.hasPrefix("  ") || line.hasPrefix("\t")
    }

    private static func renderBlock(
        _ block: String,
        options: AttributedString.MarkdownParsingOptions,
        baseURL: URL?
    ) throws -> NSAttributedString {
        if isThematicBreakBlock(block) {
            return thematicBreakAttributedString()
        }

        if let listItems = listItems(in: block) {
            return try renderListBlock(listItems, options: options, baseURL: baseURL)
        }

        if let imageMatch = inlineImageMatch(in: block) {
            return renderImageBlock(altText: imageMatch.altText, path: imageMatch.path, baseURL: baseURL)
        }

        if isLatexBlock(block) {
            let literalBlock = latexBlockContents(from: block)
            let attributedString = NSMutableAttributedString(string: literalBlock)
            attributedString.addAttribute(.markdownLiteralBlock, value: true, range: NSRange(location: 0, length: attributedString.length))
            return attributedString
        }

        let preprocessedBlock = preprocessBlockForCustomSpans(block)
        return try NSAttributedString(markdown: preprocessedBlock, options: options, baseURL: baseURL)
    }

    private static func isLatexBlock(_ block: String) -> Bool {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false)
        guard
            let firstLine = lines.first?.trimmingCharacters(in: .whitespaces),
            let lastLine = lines.last?.trimmingCharacters(in: .whitespaces)
        else {
            return false
        }

        return firstLine == "$$" && lastLine == "$$" && lines.count >= 2
    }

    private static func latexBlockContents(from block: String) -> String {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2 else { return block }
        return lines.dropFirst().dropLast().joined(separator: "\n")
    }

    private static func replaceEmptyThematicBreakParagraphs(in attributedString: NSMutableAttributedString) {
        let string = attributedString.string as NSString
        var paragraphRanges: [NSRange] = []
        var location = 0

        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            paragraphRanges.append(paragraphRange)
            location = NSMaxRange(paragraphRange)
        }

        for paragraphRange in paragraphRanges.reversed() {
            let context = blockContext(at: paragraphRange.location, in: attributedString)
            guard context.isThematicBreak else { continue }

            let paragraph = (attributedString.string as NSString).substring(with: paragraphRange)
            let trailingNewline = paragraph.hasSuffix("\n") ? "\n" : ""
            let visibleText = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard visibleText.isEmpty else { continue }

            let replacement = NSMutableAttributedString(attributedString: thematicBreakAttributedString())
            if !trailingNewline.isEmpty {
                replacement.append(NSAttributedString(string: trailingNewline))
            }
            attributedString.replaceCharacters(in: paragraphRange, with: replacement)
        }
    }

    private static func applyParagraphStyles(to attributedString: NSMutableAttributedString) {
        let string = attributedString.string as NSString
        let articleTitleRange = articleTitleParagraphRange(in: attributedString)
        var previousParagraphSpacing: CGFloat = 0
        var location = 0

        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let context = blockContext(at: paragraphRange.location, in: attributedString)
            let style = mutableParagraphStyle(at: paragraphRange.location, in: attributedString)
            let isCustomListItem = isCustomListItemParagraph(paragraphRange, in: attributedString)
            let isArticleTitle = articleTitleRange.map { NSEqualRanges($0, paragraphRange) } ?? false
            let typography = typography(for: context, isArticleTitle: isArticleTitle)

            style.lineSpacing = 0
            style.lineHeightMultiple = 1.5
            style.paragraphSpacingBefore = max(0, typography.paragraphSpacingBefore - previousParagraphSpacing)
            style.paragraphSpacing = typography.paragraphSpacingAfter

            if context.isListItem || isCustomListItem || context.isCodeBlock || context.isBlockQuote {
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 6
            }

            attributedString.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
            previousParagraphSpacing = style.paragraphSpacing
            location = NSMaxRange(paragraphRange)
        }
    }

    private static func applyInlineStyles(to attributedString: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributedString.length)
        let articleTitleRange = articleTitleParagraphRange(in: attributedString)
        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            if attributes[.attachment] != nil {
                return
            }

            let context = blockContext(at: range.location, in: attributedString)
            let inlineIntent = inlinePresentationIntent(from: attributes[.inlinePresentationIntent])
            let isArticleTitle = articleTitleRange.map { NSLocationInRange(range.location, $0) } ?? false
            let font = font(for: context, inlineIntent: inlineIntent, isArticleTitle: isArticleTitle)
            var foregroundColor = context.isBlockQuote ? quoteColor : NSColor.black

            if attributes[.link] != nil {
                foregroundColor = linkColor
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }

            if context.isCodeBlock || inlineIntent.contains(.code) {
                attributedString.addAttribute(.backgroundColor, value: codeBackgroundColor, range: range)
            }

            attributedString.addAttributes(
                [
                    .font: font,
                    .foregroundColor: foregroundColor
                ],
                range: range
            )
        }
    }

    private static func applyCustomSubscriptsAndSuperscripts(to attributedString: NSMutableAttributedString) {
        applyCustomMarker(
            pattern: protectedSubscriptPattern,
            baselineOffset: -4,
            scale: 0.78,
            to: attributedString
        )
        applyCustomMarker(
            pattern: superscriptPattern,
            baselineOffset: 4,
            scale: 0.78,
            to: attributedString
        )
        applyCustomMarker(
            pattern: subscriptPattern,
            baselineOffset: -4,
            scale: 0.78,
            to: attributedString
        )
    }

    private static func preprocessBlockForCustomSpans(_ block: String) -> String {
        guard !block.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") else {
            return block
        }

        var result = ""
        var index = block.startIndex
        var isInsideInlineCode = false

        while index < block.endIndex {
            let character = block[index]

            if character == "`" {
                isInsideInlineCode.toggle()
                result.append(character)
                index = block.index(after: index)
                continue
            }

            if !isInsideInlineCode, character == "~", let closingIndex = matchingSubscriptDelimiter(in: block, from: index) {
                let contentStart = block.index(after: index)
                let content = block[contentStart..<closingIndex]
                result += "SUBSCRIPTOPENMARKER"
                result += content
                result += "SUBSCRIPTCLOSEMARKER"
                index = block.index(after: closingIndex)
                continue
            }

            result.append(character)
            index = block.index(after: index)
        }

        return result
    }

    private static func matchingSubscriptDelimiter(
        in block: String,
        from openingIndex: String.Index
    ) -> String.Index? {
        var currentIndex = block.index(after: openingIndex)

        while currentIndex < block.endIndex {
            let currentCharacter = block[currentIndex]
            if currentCharacter == "\n" {
                return nil
            }

            if currentCharacter == "~", currentIndex > block.index(after: openingIndex) {
                return currentIndex
            }

            currentIndex = block.index(after: currentIndex)
        }

        return nil
    }

    private static func applyCustomMarker(
        pattern: NSRegularExpression,
        baselineOffset: CGFloat,
        scale: CGFloat,
        to attributedString: NSMutableAttributedString
    ) {
        let string = attributedString.string as NSString
        let matches = pattern.matches(
            in: attributedString.string,
            range: NSRange(location: 0, length: string.length)
        )

        for match in matches.reversed() {
            if isLiteralBlock(match.range, in: attributedString) {
                continue
            }

            guard
                match.numberOfRanges > 1,
                let codeIntent = attributedString.attribute(.inlinePresentationIntent, at: match.range.location, effectiveRange: nil)
            else {
                replaceMarkerMatch(match, baselineOffset: baselineOffset, scale: scale, in: attributedString)
                continue
            }

            if inlinePresentationIntent(from: codeIntent).contains(.code) || blockContext(at: match.range.location, in: attributedString).isCodeBlock {
                continue
            }

            replaceMarkerMatch(match, baselineOffset: baselineOffset, scale: scale, in: attributedString)
        }
    }

    private static func replaceMarkerMatch(
        _ match: NSTextCheckingResult,
        baselineOffset: CGFloat,
        scale: CGFloat,
        in attributedString: NSMutableAttributedString
    ) {
        let contentRange = match.range(at: 1)
        guard contentRange.location != NSNotFound else { return }

        let replacement = NSMutableAttributedString(attributedString: attributedString.attributedSubstring(from: contentRange))
        let fullRange = NSRange(location: 0, length: replacement.length)
        var updatedFont = false

        replacement.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }

            let scaledFont = fontForCustomSpan(from: font, scale: scale)
            replacement.addAttributes(
                [
                    .font: scaledFont
                ],
                range: range
            )
            updatedFont = true
        }

        if !updatedFont {
            replacement.addAttribute(
                .font,
                value: baskervilleFont(size: max(9, round(baseFontSize * scale))),
                range: fullRange
            )
        }
        replacement.addAttribute(.baselineOffset, value: baselineOffset, range: fullRange)
        if baselineOffset > 0 {
            replacement.addAttribute(.superscript, value: 1, range: fullRange)
        }

        attributedString.replaceCharacters(in: match.range, with: replacement)
    }

    private static func isThematicBreakBlock(_ block: String) -> Bool {
        let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(location: 0, length: (trimmedBlock as NSString).length)
        return thematicBreakPattern.firstMatch(in: trimmedBlock, range: range) != nil
    }

    private static func inlineImageMatch(in block: String) -> (altText: String, path: String)? {
        let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = MarkdownInlineImageSyntax.matchWholeString(trimmedBlock) else {
            return nil
        }

        return (match.altText, match.path)
    }

    private static func listItems(in block: String) -> [RenderedListItem]? {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var items: [RenderedListItem] = []
        var currentItem: RenderedListItem?

        for line in lines {
            if let unorderedMatch = listMatch(for: unorderedListPattern, in: line), unorderedMatch.count == 3 {
                if let currentItem {
                    items.append(currentItem)
                }

                currentItem = RenderedListItem(
                    level: indentationLevel(from: unorderedMatch[0]),
                    marker: .unordered,
                    body: unorderedMatch[2]
                )
                continue
            }

            if let orderedMatch = listMatch(for: orderedListPattern, in: line), orderedMatch.count == 3 {
                if let currentItem {
                    items.append(currentItem)
                }

                currentItem = RenderedListItem(
                    level: indentationLevel(from: orderedMatch[0]),
                    marker: .ordered(number: Int(orderedMatch[1]) ?? (items.count + 1)),
                    body: orderedMatch[2]
                )
                continue
            }

            guard var pendingItem = currentItem else {
                return nil
            }

            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else {
                return nil
            }

            pendingItem.body += "\n" + trimmedLine
            currentItem = pendingItem
        }

        if let currentItem {
            items.append(currentItem)
        }

        return items.isEmpty ? nil : items
    }

    private static func listMatch(for pattern: NSRegularExpression, in line: String) -> [String]? {
        let nsString = line as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = pattern.firstMatch(in: line, range: range) else {
            return nil
        }

        return (1..<match.numberOfRanges).map { nsString.substring(with: match.range(at: $0)) }
    }

    private static func indentationLevel(from leadingWhitespace: String) -> Int {
        let expanded = leadingWhitespace.replacingOccurrences(of: "\t", with: "    ")
        return expanded.count / 2
    }

    private static func renderListBlock(
        _ items: [RenderedListItem],
        options: AttributedString.MarkdownParsingOptions,
        baseURL: URL?
    ) throws -> NSAttributedString {
        let mutable = NSMutableAttributedString()

        for (index, item) in items.enumerated() {
            if index > 0 {
                mutable.append(NSAttributedString(string: "\n"))
            }

            let markerText = item.marker.displayText
            let marker = NSMutableAttributedString(string: markerText + "\t")
            marker.addAttribute(.font, value: baskervilleFont(size: baseFontSize), range: NSRange(location: 0, length: marker.length))

            let body = NSMutableAttributedString(
                attributedString: try NSAttributedString(markdown: item.body, options: options, baseURL: baseURL)
            )
            let itemString = NSMutableAttributedString()
            itemString.append(marker)
            itemString.append(body)

            let fullRange = NSRange(location: 0, length: itemString.length)
            let paragraphStyle = NSMutableParagraphStyle()
            let indent = CGFloat(item.level) * 18
            let contentIndent = indent + 22
            paragraphStyle.firstLineHeadIndent = indent
            paragraphStyle.headIndent = contentIndent
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: contentIndent)]
            paragraphStyle.defaultTabInterval = contentIndent
            paragraphStyle.lineSpacing = 0
            paragraphStyle.lineHeightMultiple = 1.5
            paragraphStyle.paragraphSpacingBefore = 0
            paragraphStyle.paragraphSpacing = 6

            itemString.addAttributes(
                [
                    .paragraphStyle: paragraphStyle,
                    .markdownCustomListItem: true
                ],
                range: fullRange
            )
            mutable.append(itemString)
        }

        return mutable
    }

    private static func thematicBreakAttributedString() -> NSAttributedString {
        centeredAttachmentAttributedString(
            image: horizontalRuleImage(),
            markerAttribute: .markdownThematicBreak
        )
    }

    private static func horizontalRuleImage() -> NSImage {
        let size = NSSize(width: printableWidth, height: 2)
        let image = NSImage(size: size)
        image.lockFocus()
        markerColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = size.height
        path.move(to: NSPoint(x: 0, y: size.height / 2))
        path.line(to: NSPoint(x: size.width, y: size.height / 2))
        path.stroke()
        image.unlockFocus()
        return image
    }

    private static func renderImageBlock(altText: String, path: String, baseURL: URL?) -> NSAttributedString {
        MarkdownPDFDiagnostics.record("render image path=\(path)")
        guard
            let fileURL = resolvedImageURL(for: path, baseURL: baseURL),
            let image = MarkdownFileAccess.loadImage(
                at: fileURL,
                maximumPixelSize: imageLoadMaximumPixelSize()
            ),
            image.size.width > 0,
            image.size.height > 0
        else {
            MarkdownPDFDiagnostics.record("render image fallback altText=\(altText)")
            return NSAttributedString(string: altText.isEmpty ? path : altText)
        }

        MarkdownPDFDiagnostics.record(
            "render image resolvedURL=\(fileURL.path) size=\(Int(image.size.width))x\(Int(image.size.height))"
        )
        return centeredAttachmentAttributedString(
            image: scaledImageForPDF(from: image),
            markerAttribute: .markdownCenteredImage
        )
    }

    private static func imageLoadMaximumPixelSize() -> Int {
        let printableHeight = paperSize.height - pageMargins.top - pageMargins.bottom
        let maxHeight = printableHeight * maxImageHeightRatio
        let targetDimension = max(printableWidth, maxHeight)
        return max(1, Int(ceil(targetDimension * 2)))
    }

    private static func resolvedImageURL(for path: String, baseURL: URL?) -> URL? {
        let cleanedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let decodedPath = cleanedPath.removingPercentEncoding ?? cleanedPath

        if let url = URL(string: decodedPath), url.scheme == "file" {
            return url.standardizedFileURL
        }

        if decodedPath.hasPrefix("/") {
            return URL(fileURLWithPath: decodedPath).standardizedFileURL
        }

        if let baseURL {
            return baseURL.appendingPathComponent(decodedPath).standardizedFileURL
        }

        return URL(fileURLWithPath: decodedPath).standardizedFileURL
    }

    private static func scaledImageForPDF(from image: NSImage) -> NSImage {
        let maxWidth = printableWidth
        let printableHeight = paperSize.height - pageMargins.top - pageMargins.bottom
        let maxHeight = printableHeight * maxImageHeightRatio
        let widthScale = maxWidth / image.size.width
        let heightScale = maxHeight / image.size.height
        let scale = min(1, widthScale, heightScale)
        let targetSize = NSSize(
            width: floor(image.size.width * scale),
            height: floor(image.size.height * scale)
        )

        let scaledImage = NSImage(size: targetSize)
        scaledImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        scaledImage.unlockFocus()
        return scaledImage
    }

    private static func centeredAttachmentAttributedString(
        image: NSImage,
        markerAttribute: NSAttributedString.Key
    ) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.attachmentCell = NSTextAttachmentCell(imageCell: image)

        let attributedString = NSMutableAttributedString(attachment: attachment)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineHeightMultiple = 1.5
        paragraphStyle.paragraphSpacing = 6
        attributedString.addAttributes(
            [
                .paragraphStyle: paragraphStyle,
                markerAttribute: true
            ],
            range: NSRange(location: 0, length: attributedString.length)
        )
        return attributedString
    }

    private static func isLiteralBlock(_ range: NSRange, in attributedString: NSAttributedString) -> Bool {
        guard
            attributedString.length > 0,
            range.location < attributedString.length
        else {
            return false
        }

        return (attributedString.attribute(.markdownLiteralBlock, at: range.location, effectiveRange: nil) as? Bool) == true
    }

    private static func fontForCustomSpan(from font: NSFont, scale: CGFloat) -> NSFont {
        let targetSize = max(9, round(font.pointSize * scale))
        let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
        let isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
        return baskervilleFont(size: targetSize, bold: isBold, italic: isItalic)
    }

    @MainActor
    private static func makePrintableView(for attributedString: NSAttributedString) -> MarkdownPDFPrintableView {
        MarkdownPDFPrintableView(
            attributedString: attributedString,
            paperSize: paperSize,
            pageMargins: pageMargins
        )
    }

    private static func mutableParagraphStyle(at location: Int, in attributedString: NSAttributedString) -> NSMutableParagraphStyle {
        if
            attributedString.length > 0,
            location < attributedString.length,
            let style = attributedString.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle,
            let mutableStyle = style.mutableCopy() as? NSMutableParagraphStyle
        {
            return mutableStyle
        }

        return NSMutableParagraphStyle()
    }

    private static func isCustomListItemParagraph(_ range: NSRange, in attributedString: NSAttributedString) -> Bool {
        guard attributedString.length > 0, range.location < attributedString.length else {
            return false
        }

        return (attributedString.attribute(.markdownCustomListItem, at: range.location, effectiveRange: nil) as? Bool) == true
    }

    private static func inlinePresentationIntent(from value: Any?) -> InlinePresentationIntent {
        if let value = value as? InlinePresentationIntent {
            return value
        }

        if let number = value as? NSNumber {
            return InlinePresentationIntent(rawValue: number.uintValue)
        }

        return []
    }

    private static func font(
        for context: BlockContext,
        inlineIntent: InlinePresentationIntent,
        isArticleTitle: Bool
    ) -> NSFont {
        if context.isCodeBlock {
            return baskervilleFont(size: baseFontSize)
        }

        let typography = typography(for: context, isArticleTitle: isArticleTitle)
        let isBold = inlineIntent.contains(.stronglyEmphasized) || typography.isBold
        let isItalic = inlineIntent.contains(.emphasized) || context.isBlockQuote || typography.isItalic

        return baskervilleFont(size: typography.fontSize, bold: isBold, italic: isItalic)
    }

    private static func typography(for context: BlockContext, isArticleTitle: Bool) -> PDFTypography {
        if isArticleTitle {
            return PDFTypography(
                fontSize: 16,
                isBold: true,
                isItalic: false,
                paragraphSpacingBefore: 0,
                paragraphSpacingAfter: 12
            )
        }

        switch context.headingLevel {
        case 1:
            return PDFTypography(
                fontSize: 14,
                isBold: true,
                isItalic: false,
                paragraphSpacingBefore: 18,
                paragraphSpacingAfter: 6
            )
        case 2:
            return PDFTypography(
                fontSize: 12,
                isBold: true,
                isItalic: false,
                paragraphSpacingBefore: 12,
                paragraphSpacingAfter: 6
            )
        case .some:
            return PDFTypography(
                fontSize: 12,
                isBold: true,
                isItalic: true,
                paragraphSpacingBefore: 6,
                paragraphSpacingAfter: 3
            )
        default:
            return PDFTypography(
                fontSize: baseFontSize,
                isBold: false,
                isItalic: false,
                paragraphSpacingBefore: 0,
                paragraphSpacingAfter: 6
            )
        }
    }

    private static func baskervilleFont(size: CGFloat, bold: Bool = false, italic: Bool = false) -> NSFont {
        let baseFont = NSFont(name: "Baskerville", size: size) ?? NSFont.systemFont(ofSize: size)
        var traitMask: NSFontTraitMask = []
        if bold {
            traitMask.insert(.boldFontMask)
        }
        if italic {
            traitMask.insert(.italicFontMask)
        }

        if traitMask.isEmpty {
            return baseFont
        }

        let convertedFont = NSFontManager.shared.convert(baseFont, toHaveTrait: traitMask)
        return convertedFont.pointSize > 0 ? convertedFont : baseFont
    }

    private static func blockContext(at location: Int, in attributedString: NSAttributedString) -> BlockContext {
        guard attributedString.length > 0 else { return BlockContext() }

        let safeLocation = min(max(location, 0), attributedString.length - 1)
        let intent = attributedString.attribute(.presentationIntentAttributeName, at: safeLocation, effectiveRange: nil) as? PresentationIntent
        return BlockContext(intent: intent)
    }

    private static func articleTitleParagraphRange(in attributedString: NSAttributedString) -> NSRange? {
        let string = attributedString.string as NSString
        var location = 0

        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let visibleText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !visibleText.isEmpty {
                let context = blockContext(at: paragraphRange.location, in: attributedString)
                return context.headingLevel == 1 ? paragraphRange : nil
            }
            location = NSMaxRange(paragraphRange)
        }

        return nil
    }

    private static func diagnosticBlockKind(for block: String) -> MarkdownPDFBlockKind {
        if isThematicBreakBlock(block) {
            return .thematicBreak
        }

        if let imageMatch = inlineImageMatch(in: block) {
            MarkdownPDFDiagnostics.record("inline image match altText=\(imageMatch.altText) path=\(imageMatch.path)")
            return .inlineImage
        }

        if isLatexBlock(block) {
            return .latexBlock
        }

        if let firstLine = block.split(separator: "\n", omittingEmptySubsequences: false).first {
            return blockKind(for: String(firstLine))
        }

        return .paragraph
    }
}

private struct BlockContext {
    let headingLevel: Int?
    let isCodeBlock: Bool
    let isBlockQuote: Bool
    let isThematicBreak: Bool
    let isListItem: Bool

    init(intent: PresentationIntent? = nil) {
        var headingLevel: Int?
        var isCodeBlock = false
        var isBlockQuote = false
        var isThematicBreak = false
        var isListItem = false

        for component in intent?.components ?? [] {
            switch component.kind {
            case .header(let level):
                headingLevel = max(headingLevel ?? 0, level)
            case .codeBlock:
                isCodeBlock = true
            case .blockQuote:
                isBlockQuote = true
            case .thematicBreak:
                isThematicBreak = true
            case .listItem:
                isListItem = true
            default:
                break
            }
        }

        self.headingLevel = headingLevel
        self.isCodeBlock = isCodeBlock
        self.isBlockQuote = isBlockQuote
        self.isThematicBreak = isThematicBreak
        self.isListItem = isListItem
    }
}

private struct RenderedListItem: Equatable {
    let level: Int
    let marker: RenderedListMarker
    var body: String
}

private enum RenderedListMarker: Equatable {
    case unordered
    case ordered(number: Int)

    var displayText: String {
        switch self {
        case .unordered:
            return "•"
        case .ordered(let number):
            return "\(number)."
        }
    }
}

private enum MarkdownPDFBlockKind: String, Equatable {
    case paragraph
    case heading
    case unorderedList
    case orderedList
    case blockquote
    case thematicBreak
    case referenceDefinition
    case inlineImage
    case setextUnderline
    case indentedCode
    case fencedCode
    case latexBlock
}

private struct PDFTypography {
    let fontSize: CGFloat
    let isBold: Bool
    let isItalic: Bool
    let paragraphSpacingBefore: CGFloat
    let paragraphSpacingAfter: CGFloat
}

@MainActor
private final class MarkdownPDFPrintableView: NSView {
    private let pageMargins: NSEdgeInsets
    private let printableSize: NSSize
    private let textStorage: NSTextStorage
    private let layoutManager: NSLayoutManager

    override var isFlipped: Bool { true }

    init(attributedString: NSAttributedString, paperSize: NSSize, pageMargins: NSEdgeInsets) {
        self.pageMargins = pageMargins
        self.printableSize = NSSize(
            width: paperSize.width - pageMargins.left - pageMargins.right,
            height: paperSize.height - pageMargins.top - pageMargins.bottom
        )
        self.textStorage = NSTextStorage(attributedString: attributedString)
        self.layoutManager = NSLayoutManager()
        super.init(frame: NSRect(origin: .zero, size: paperSize))

        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        layoutManager.allowsNonContiguousLayout = false
        textStorage.addLayoutManager(layoutManager)
        paginateTextIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func pdfData() throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try writePDF(using: consumer)
        return data as Data
    }

    func writePDF(to url: URL) throws {
        guard let consumer = CGDataConsumer(url: url as CFURL) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try writePDF(using: consumer)
    }

    private func writePDF(using consumer: CGDataConsumer) throws {
        var mediaBox = CGRect(origin: .zero, size: bounds.size)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let pageCount = max(1, layoutManager.textContainers.count)
        MarkdownPDFDiagnostics.record("pdf page count=\(pageCount)")
        for pageIndex in 0..<pageCount {
            MarkdownPDFDiagnostics.record("draw pdf page index=\(pageIndex)")
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext
            drawPage(at: pageIndex)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            context.endPDFPage()
        }

        context.closePDF()
    }

    private func paginateTextIfNeeded() {
        if layoutManager.textContainers.isEmpty {
            addPageTextContainer()
        }

        while true {
            guard let lastContainer = layoutManager.textContainers.last else {
                break
            }

            layoutManager.ensureLayout(for: lastContainer)
            let glyphRange = layoutManager.glyphRange(for: lastContainer)
            let laidOutGlyphs = NSMaxRange(glyphRange)
            let totalGlyphs = layoutManager.numberOfGlyphs
            MarkdownPDFDiagnostics.record(
                "paginate containers=\(layoutManager.textContainers.count) laidOutGlyphs=\(laidOutGlyphs) totalGlyphs=\(totalGlyphs)"
            )

            if totalGlyphs == 0 || laidOutGlyphs >= totalGlyphs {
                break
            }

            guard glyphRange.length > 0 else {
                MarkdownPDFDiagnostics.record("paginate stopped because last glyph range is empty")
                break
            }

            addPageTextContainer()
        }
    }

    private func addPageTextContainer() {
        let textContainer = NSTextContainer(containerSize: printableSize)
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
    }

    private func drawPage(at pageIndex: Int) {
        NSColor.white.setFill()
        bounds.fill()

        guard pageIndex < layoutManager.textContainers.count else {
            return
        }

        let textContainer = layoutManager.textContainers[pageIndex]
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let drawingOrigin = NSPoint(x: pageMargins.left, y: pageMargins.top)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: drawingOrigin)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: drawingOrigin)
    }
}
