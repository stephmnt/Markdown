//
//  MarkdownTextStyler.swift
//  Markdown
//
//  Created by Stéphane on 01/05/2026.
//

import AppKit

extension NSAttributedString.Key {
    static let markdownInlineImagePath = NSAttributedString.Key("MarkdownInlineImagePath")
}

enum MarkdownTextStyler {
    private static let baseFontSize: CGFloat = 16
    private static let codeFontSize: CGFloat = 15
    private static let baseFont = NSFont.systemFont(ofSize: baseFontSize)
    private static let codeFont = NSFont.monospacedSystemFont(ofSize: codeFontSize, weight: .regular)
    private static let baseColor = NSColor.labelColor
    private static let markerColor = NSColor.secondaryLabelColor
    private static let linkColor = NSColor.linkColor
    private static let codeBackgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
    private static let hardLineBreakHighlightColor = NSColor.controlAccentColor.withAlphaComponent(0.16)
    private static let baseParagraphStyle = makeParagraphStyle { style in
        style.lineSpacing = 4
    }
    private static let headingParagraphStyle = makeParagraphStyle { style in
        style.lineSpacing = 4
        style.paragraphSpacing = 8
    }
    private static let setextHeadingContentParagraphStyle = makeParagraphStyle { style in
        style.lineSpacing = 0
        style.paragraphSpacing = 0
    }
    private static let setextHeadingUnderlineParagraphStyle = makeParagraphStyle { style in
        style.lineSpacing = 0
        style.paragraphSpacing = 8
    }
    private static let codeBlockParagraphStyle = makeParagraphStyle { style in
        style.lineSpacing = 4
    }
    private static let headingFonts: [NSFont] = [
        .systemFont(ofSize: 30, weight: .bold),
        .systemFont(ofSize: 26, weight: .bold),
        .systemFont(ofSize: 22, weight: .semibold),
        .systemFont(ofSize: 20, weight: .semibold),
        .systemFont(ofSize: 18, weight: .medium),
        .systemFont(ofSize: 16, weight: .medium)
    ]
    private static let atxHeadingRegex = try! NSRegularExpression(pattern: #"(?m)^(#{1,6})([ \t]+)(.+?)([ \t]+#+[ \t]*)?$"#)
    private static let setextHeadingRegex = try! NSRegularExpression(pattern: #"(?m)^(?![ \t]{4,}|[ \t]*$)(.+)\n([=-]{3,})[ \t]*$"#)
    private static let blockquoteRegex = try! NSRegularExpression(pattern: #"(?m)^([ \t]*(?:> ?)+)(.*)$"#)
    private static let unorderedListRegex = try! NSRegularExpression(pattern: #"(?m)^([ \t]*)([*+-])([ \t]+)(.+)$"#)
    private static let orderedListRegex = try! NSRegularExpression(pattern: #"(?m)^([ \t]*)(\d+\.)([ \t]+)(.+)$"#)
    private static let horizontalRuleRegex = try! NSRegularExpression(pattern: #"(?m)^[ \t]{0,3}((?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$"#)
    private static let fencedCodeRegex = try! NSRegularExpression(pattern: #"(?ms)^```[^\n]*\n.*?^```[ \t]*$"#)
    private static let indentedCodeRegex = try! NSRegularExpression(pattern: #"(?m)^(?: {4}|\t).+$"#)
    private static let inlineCodeRegex = try! NSRegularExpression(pattern: #"(?<!`)(`+)(.+?)\1(?!`)"#)
    private static let latexBlockRegex = try! NSRegularExpression(pattern: #"(?ms)^\$\$[ \t]*\n.*?^\$\$[ \t]*$"#)
    private static let hardLineBreakRegex = try! NSRegularExpression(pattern: #"(?m)( {2,})(?=\n)"#)
    private static let inlineLinkRegex = try! NSRegularExpression(pattern: #"(?<!\!)\[([^\]]+)\]\(([^)\s]+)(?:[ \t]+(?:"[^"]*"|'[^']*'|\([^)]*\)))?\)"#)
    private static let referenceLinkRegex = try! NSRegularExpression(pattern: #"(?<!\!)\[([^\]]+)\]\[([^\]]*)\]"#)
    private static let referenceDefinitionRegex = try! NSRegularExpression(pattern: #"(?m)^\[([^\]]+)\]:[ \t]*(\S+)(?:[ \t]+(?:"[^"]*"|'[^']*'|\([^)]*\)))?$"#)
    private static let autolinkRegex = try! NSRegularExpression(pattern: #"<((?:https?://[^<>\s]+)|(?:[^<>\s]+@[^<>\s]+))>"#)
    private static let subscriptShorthandRegex = try! NSRegularExpression(pattern: #"(?<!\\)~([^~]+)~"#)
    private static let subscriptHTMLRegex = try! NSRegularExpression(pattern: #"<sub>(.+?)</sub>"#)
    private static let superscriptShorthandRegex = try! NSRegularExpression(pattern: #"(?<!\\)\^([^^]+)\^"#)
    private static let superscriptHTMLRegex = try! NSRegularExpression(pattern: #"<sup>(.+?)</sup>"#)
    private static let boldItalicRegexes = [
        try! NSRegularExpression(pattern: #"(?<!\\)(?<!\*)(\*\*\*)(?=\S)(.+?)(?<=\S)\1(?!\*)"#),
        try! NSRegularExpression(pattern: #"(?<!\\)(?<!_)(___)(?=\S)(.+?)(?<=\S)\1(?!_)"#)
    ]
    private static let boldRegexes = [
        try! NSRegularExpression(pattern: #"(?<!\\)(?<!\*)(\*\*)(?!\*)(?=\S)(.+?)(?<=\S)(?<!\*)\1(?!\*)"#),
        try! NSRegularExpression(pattern: #"(?<!\\)(?<!_)(__)(?!_)(?=\S)(.+?)(?<=\S)(?<!_)\1(?!_)"#)
    ]
    private static let italicRegexes = [
        try! NSRegularExpression(pattern: #"(?<!\\)(?<!\*)(\*)(?!\*)(?=\S)(.+?)(?<=\S)(?<!\*)\1(?!\*)"#),
        try! NSRegularExpression(pattern: #"(?<!\\)(?<!_)(_)(?!_)(?=\S)(.+?)(?<=\S)(?<!_)\1(?!_)"#)
    ]

    static func url(from value: Any?) -> URL? {
        if let url = value as? URL {
            return url
        }

        guard let string = value as? String else {
            return nil
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("@"), !trimmed.contains("://"), !trimmed.hasPrefix("mailto:") {
            return URL(string: "mailto:\(trimmed)")
        }

        return URL(string: trimmed)
    }

    static func apply(to textView: NSTextView, editedRange: NSRange? = nil) {
        guard let textStorage = textView.textStorage else { return }

        let string = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: string.length)
        let searchRange = stylingRange(for: editedRange, in: string)
        let isFullRestyle = NSEqualRanges(searchRange, fullRange)

        textStorage.beginEditing()
        textStorage.setAttributes(baseAttributes(), range: searchRange)

        styleATXHeadings(in: textStorage, string: string, searchRange: searchRange)
        styleSetextHeadings(in: textStorage, string: string, searchRange: searchRange)
        styleBlockquotes(in: textStorage, string: string, searchRange: searchRange)
        styleLists(in: textStorage, string: string, searchRange: searchRange)
        styleHorizontalRules(in: textStorage, string: string, searchRange: searchRange)

        let codeProtectedRanges = styleCode(in: textStorage, string: string, searchRange: searchRange)
        let latexProtectedRanges = styleLatexBlocks(
            in: textStorage,
            string: string,
            protectedRanges: codeProtectedRanges,
            searchRange: searchRange
        )
        let protectedRanges = codeProtectedRanges + latexProtectedRanges
        let hardLineBreakMarkers = styleHardLineBreaks(
            in: textStorage,
            string: string,
            protectedRanges: protectedRanges,
            searchRange: searchRange
        )

        let referenceDefinitions = collectReferenceDefinitions(
            in: string,
            protectedRanges: protectedRanges,
            searchRange: fullRange
        )

        styleBoldItalicRanges(in: textStorage, string: string, protectedRanges: protectedRanges, searchRange: searchRange)
        styleBoldRanges(in: textStorage, string: string, protectedRanges: protectedRanges, searchRange: searchRange)
        styleItalicRanges(in: textStorage, string: string, protectedRanges: protectedRanges, searchRange: searchRange)
        styleInlineImages(in: textStorage, string: string, protectedRanges: protectedRanges, searchRange: searchRange)
        styleLinks(in: textStorage, string: string, protectedRanges: protectedRanges, searchRange: searchRange)
        styleReferenceLinks(
            in: textStorage,
            string: string,
            protectedRanges: protectedRanges,
            referenceDefinitions: referenceDefinitions,
            searchRange: searchRange
        )
        styleAutolinks(in: textStorage, string: string, protectedRanges: protectedRanges, searchRange: searchRange)
        styleSubscripts(in: textStorage, string: string, protectedRanges: protectedRanges, searchRange: searchRange)
        styleSuperscripts(in: textStorage, string: string, protectedRanges: protectedRanges, searchRange: searchRange)

        textStorage.endEditing()

        if let layoutManager = textView.layoutManager as? MarkdownLayoutManager {
            if isFullRestyle {
                layoutManager.hardLineBreakMarkers = hardLineBreakMarkers
            } else {
                layoutManager.hardLineBreakMarkers = mergedHardLineBreakMarkers(
                    existing: layoutManager.hardLineBreakMarkers,
                    replacingIn: searchRange,
                    with: hardLineBreakMarkers
                )
            }
        }

        textView.typingAttributes = attributes(at: textView.selectedRange().location, in: textStorage)
    }

    private static func baseAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: baseParagraphStyle
        ]
    }

    private static func listParagraphStyle(indent: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        style.headIndent = indent + 18
        style.firstLineHeadIndent = indent
        return style
    }

    private static func styleATXHeadings(in textStorage: NSTextStorage, string: NSString, searchRange: NSRange) {
        enumerateMatches(regex: atxHeadingRegex, in: string, searchRange: searchRange) { match in
            guard
                let markerRange = range(match, at: 1),
                let spacingRange = range(match, at: 2),
                let contentRange = range(match, at: 3)
            else { return }

            let level = markerRange.length
            let font = headingFont(for: level)

            textStorage.addAttribute(.paragraphStyle, value: headingParagraphStyle, range: match.range)
            textStorage.addAttributes(
                [
                    .font: font,
                    .foregroundColor: baseColor,
                    .paragraphStyle: headingParagraphStyle
                ],
                range: contentRange
            )

            var markerRanges = [markerRange, spacingRange]
            if let closingRange = range(match, at: 4), closingRange.length > 0 {
                markerRanges.append(closingRange)
            }
            setMarkerColor(in: textStorage, ranges: markerRanges)
        }
    }

    private static func styleSetextHeadings(in textStorage: NSTextStorage, string: NSString, searchRange: NSRange) {
        enumerateMatches(regex: setextHeadingRegex, in: string, searchRange: searchRange) { match in
            guard
                let contentRange = range(match, at: 1),
                let underlineRange = range(match, at: 2)
            else { return }

            let marker = string.substring(with: underlineRange)
            let level = marker.first == "=" ? 1 : 2
            let font = headingFont(for: level)

            textStorage.addAttributes(
                [
                    .font: font,
                    .foregroundColor: baseColor,
                    .paragraphStyle: setextHeadingContentParagraphStyle
                ],
                range: contentRange
            )
            textStorage.addAttribute(
                .paragraphStyle,
                value: setextHeadingContentParagraphStyle,
                range: contentRange
            )
            textStorage.addAttribute(
                .paragraphStyle,
                value: setextHeadingUnderlineParagraphStyle,
                range: underlineRange
            )
            setMarkerColor(in: textStorage, ranges: [underlineRange])
        }
    }

    private static func styleBlockquotes(in textStorage: NSTextStorage, string: NSString, searchRange: NSRange) {
        enumerateMatches(regex: blockquoteRegex, in: string, searchRange: searchRange) { match in
            guard
                let markerRange = range(match, at: 1),
                let contentRange = range(match, at: 2)
            else { return }

            textStorage.addAttribute(.paragraphStyle, value: baseParagraphStyle, range: match.range)
            textStorage.addAttribute(.foregroundColor, value: baseColor, range: contentRange)
            setMarkerColor(in: textStorage, ranges: [markerRange])
        }
    }

    private static func styleLists(in textStorage: NSTextStorage, string: NSString, searchRange: NSRange) {
        styleListMatches(regex: unorderedListRegex, in: textStorage, string: string, searchRange: searchRange)
        styleListMatches(regex: orderedListRegex, in: textStorage, string: string, searchRange: searchRange)
    }

    private static func styleHorizontalRules(in textStorage: NSTextStorage, string: NSString, searchRange: NSRange) {
        enumerateMatches(regex: horizontalRuleRegex, in: string, searchRange: searchRange) { match in
            textStorage.addAttribute(.foregroundColor, value: markerColor, range: match.range)
            textStorage.addAttribute(.paragraphStyle, value: headingParagraphStyle, range: match.range)
        }
    }

    private static func styleCode(in textStorage: NSTextStorage, string: NSString, searchRange: NSRange) -> [NSRange] {
        let blockRanges = styleCodeBlocks(in: textStorage, string: string, searchRange: searchRange)
        let inlineRanges = styleInlineCode(
            in: textStorage,
            string: string,
            protectedRanges: blockRanges,
            searchRange: searchRange
        )
        return blockRanges + inlineRanges
    }

    private static func styleCodeBlocks(in textStorage: NSTextStorage, string: NSString, searchRange: NSRange) -> [NSRange] {
        var protectedRanges: [NSRange] = []

        enumerateMatches(regex: fencedCodeRegex, in: string, searchRange: searchRange) { match in
            protectedRanges.append(match.range)
            applyCodeBlockAttributes(in: textStorage, range: match.range)
        }

        enumerateMatches(regex: indentedCodeRegex, in: string, searchRange: searchRange) { match in
            guard !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges) else { return }

            protectedRanges.append(match.range)
            applyCodeBlockAttributes(in: textStorage, range: match.range)
        }

        return protectedRanges
    }

    private static func styleInlineCode(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) -> [NSRange] {
        var codeRanges: [NSRange] = []

        enumerateMatches(regex: inlineCodeRegex, in: string, searchRange: searchRange) { match in
            guard
                let markerRange = range(match, at: 1),
                let contentRange = range(match, at: 2),
                !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges)
            else { return }

            let suffixRange = NSRange(location: NSMaxRange(contentRange), length: markerRange.length)
            codeRanges.append(match.range)

            setMarkerColor(in: textStorage, ranges: [markerRange, suffixRange])
            textStorage.addAttributes(
                [
                    .font: codeFont,
                    .backgroundColor: codeBackgroundColor
                ],
                range: contentRange
            )
        }

        return codeRanges
    }

    private static func styleLatexBlocks(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) -> [NSRange] {
        var literalRanges: [NSRange] = []

        enumerateMatches(regex: latexBlockRegex, in: string, searchRange: searchRange) { match in
            guard !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges) else { return }

            literalRanges.append(match.range)
            textStorage.addAttributes(
                [
                    .font: baseFont,
                    .foregroundColor: baseColor,
                    .paragraphStyle: baseParagraphStyle
                ],
                range: match.range
            )
            setMarkerColor(in: textStorage, ranges: latexDelimiterRanges(in: match.range, string: string))
        }

        return literalRanges
    }

    private static func styleHardLineBreaks(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) -> [MarkdownHardLineBreakMarker] {
        var markers: [MarkdownHardLineBreakMarker] = []

        enumerateMatches(regex: hardLineBreakRegex, in: string, searchRange: searchRange) { match in
            guard
                let spacesRange = range(match, at: 1),
                !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges)
            else { return }

            let visibleRange = NSRange(
                location: max(spacesRange.location, NSMaxRange(spacesRange) - 2),
                length: min(2, spacesRange.length)
            )

            textStorage.addAttributes(
                [
                    .foregroundColor: markerColor,
                    .backgroundColor: hardLineBreakHighlightColor
                ],
                range: visibleRange
            )
            markers.append(MarkdownHardLineBreakMarker(spacesRange: visibleRange))
        }

        return markers
    }

    private static func styleBoldItalicRanges(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) {
        styleDelimitedFontTraits(
            patterns: boldItalicRegexes,
            traits: [.boldFontMask, .italicFontMask],
            in: textStorage,
            string: string,
            protectedRanges: protectedRanges,
            searchRange: searchRange
        )
    }

    private static func styleBoldRanges(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) {
        styleDelimitedFontTraits(
            patterns: boldRegexes,
            traits: [.boldFontMask],
            in: textStorage,
            string: string,
            protectedRanges: protectedRanges,
            searchRange: searchRange
        )
    }

    private static func styleInlineImages(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) {
        for match in MarkdownInlineImageSyntax.matches(in: string as String, intersecting: searchRange) {
            guard !intersectsProtectedRanges(match.fullRange, protectedRanges: protectedRanges) else {
                continue
            }

            let openMarkerRange = NSRange(location: match.fullRange.location, length: 2)
            let middleMarkerRange = NSRange(location: NSMaxRange(match.altTextRange), length: 2)
            let closeMarkerRange = NSRange(location: NSMaxRange(match.fullRange) - 1, length: 1)

            setMarkerColor(in: textStorage, ranges: [openMarkerRange, middleMarkerRange, closeMarkerRange])
            textStorage.addAttributes(
                [
                    .foregroundColor: linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .markdownInlineImagePath: match.path
                ],
                range: match.pathRange
            )
        }
    }

    private static func styleItalicRanges(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) {
        styleDelimitedFontTraits(
            patterns: italicRegexes,
            traits: [.italicFontMask],
            in: textStorage,
            string: string,
            protectedRanges: protectedRanges,
            searchRange: searchRange
        )
    }

    private static func styleLinks(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) {
        enumerateMatches(regex: inlineLinkRegex, in: string, searchRange: searchRange) { match in
            guard
                let labelRange = range(match, at: 1),
                let urlRange = range(match, at: 2),
                !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges)
            else { return }

            let openBracketRange = NSRange(location: match.range.location, length: 1)
            let closeBracketRange = NSRange(location: labelRange.location + labelRange.length, length: 2)
            let closingParenRange = NSRange(location: NSMaxRange(match.range) - 1, length: 1)
            let url = url(from: string.substring(with: urlRange))

            setMarkerColor(in: textStorage, ranges: [openBracketRange, closeBracketRange, closingParenRange])
            applyLinkAttributes(to: labelRange, in: textStorage, url: url)
            textStorage.addAttribute(.foregroundColor, value: markerColor, range: urlRange)
        }
    }

    private static func styleReferenceLinks(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        referenceDefinitions: [String: URL],
        searchRange: NSRange
    ) {
        enumerateMatches(regex: referenceLinkRegex, in: string, searchRange: searchRange) { match in
            guard
                let labelRange = range(match, at: 1),
                let referenceRange = range(match, at: 2),
                !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges)
            else { return }

            let openBracketRange = NSRange(location: match.range.location, length: 1)
            let middleMarkerRange = NSRange(location: labelRange.location + labelRange.length, length: 2)
            let closingBracketRange = NSRange(location: NSMaxRange(match.range) - 1, length: 1)
            let explicitIdentifier = string.substring(with: referenceRange)
            let identifier = normalizedReferenceIdentifier(
                explicitIdentifier.isEmpty ? string.substring(with: labelRange) : explicitIdentifier
            )
            let url = referenceDefinitions[identifier]

            setMarkerColor(in: textStorage, ranges: [openBracketRange, middleMarkerRange, closingBracketRange])
            applyLinkAttributes(to: labelRange, in: textStorage, url: url)

            if referenceRange.length > 0 {
                textStorage.addAttribute(.foregroundColor, value: markerColor, range: referenceRange)
            }
        }

        enumerateMatches(regex: referenceDefinitionRegex, in: string, searchRange: searchRange) { match in
            guard
                let idRange = range(match, at: 1),
                let urlRange = range(match, at: 2),
                !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges)
            else { return }

            let openBracketRange = NSRange(location: match.range.location, length: 1)
            let closeBracketAndColonRange = NSRange(location: idRange.location + idRange.length, length: 2)
            let identifier = normalizedReferenceIdentifier(string.substring(with: idRange))
            let url = referenceDefinitions[identifier]

            setMarkerColor(in: textStorage, ranges: [openBracketRange, closeBracketAndColonRange])
            textStorage.addAttribute(.foregroundColor, value: markerColor, range: idRange)
            applyLinkAttributes(to: urlRange, in: textStorage, url: url)
        }
    }

    private static func styleAutolinks(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) {
        enumerateMatches(regex: autolinkRegex, in: string, searchRange: searchRange) { match in
            guard
                let contentRange = range(match, at: 1),
                !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges)
            else { return }

            let openMarkerRange = NSRange(location: match.range.location, length: 1)
            let closeMarkerRange = NSRange(location: NSMaxRange(match.range) - 1, length: 1)
            let url = url(from: string.substring(with: contentRange))

            setMarkerColor(in: textStorage, ranges: [openMarkerRange, closeMarkerRange])
            applyLinkAttributes(to: contentRange, in: textStorage, url: url)
        }
    }

    private static func styleSubscripts(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) {
        styleVerticalOffsetRanges(
            in: textStorage,
            string: string,
            protectedRanges: protectedRanges,
            patterns: [
                StyledMarkerPattern(regex: subscriptShorthandRegex, prefixLength: 1, suffixLength: 1),
                StyledMarkerPattern(regex: subscriptHTMLRegex, prefixLength: 5, suffixLength: 6)
            ],
            offset: -3,
            scale: 0.8,
            searchRange: searchRange
        )
    }

    private static func styleSuperscripts(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) {
        styleVerticalOffsetRanges(
            in: textStorage,
            string: string,
            protectedRanges: protectedRanges,
            patterns: [
                StyledMarkerPattern(regex: superscriptShorthandRegex, prefixLength: 1, suffixLength: 1),
                StyledMarkerPattern(regex: superscriptHTMLRegex, prefixLength: 5, suffixLength: 6)
            ],
            offset: 5,
            scale: 0.8,
            searchRange: searchRange
        )
    }

    private static func styleDelimitedFontTraits(
        patterns: [NSRegularExpression],
        traits: [NSFontTraitMask],
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) {
        for pattern in patterns {
            enumerateMatches(regex: pattern, in: string, searchRange: searchRange) { match in
                guard
                    let markerRange = range(match, at: 1),
                    let contentRange = range(match, at: 2),
                    !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges)
                else { return }

                let suffixRange = NSRange(location: NSMaxRange(contentRange), length: markerRange.length)
                setMarkerColor(in: textStorage, ranges: [markerRange, suffixRange])
                for trait in traits {
                    applyFontTrait(trait, to: contentRange, in: textStorage)
                }
            }
        }
    }

    private static func applyLinkAttributes(to range: NSRange, in textStorage: NSTextStorage, url: URL? = nil) {
        guard range.length > 0 else { return }

        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        if let url {
            attributes[.link] = url
        }

        textStorage.addAttributes(attributes, range: range)
    }

    private static func styleListMatches(
        regex: NSRegularExpression,
        in textStorage: NSTextStorage,
        string: NSString,
        searchRange: NSRange
    ) {
        enumerateMatches(regex: regex, in: string, searchRange: searchRange) { match in
            guard
                let indentRange = range(match, at: 1),
                let markerRange = range(match, at: 2),
                let spacingRange = range(match, at: 3)
            else { return }

            let indent = CGFloat(indentWidth(for: string.substring(with: indentRange)))
            textStorage.addAttribute(.paragraphStyle, value: listParagraphStyle(indent: indent), range: match.range)
            setMarkerColor(in: textStorage, ranges: [markerRange, spacingRange])
        }
    }

    private static func applyCodeBlockAttributes(in textStorage: NSTextStorage, range: NSRange) {
        textStorage.addAttributes(
            [
                .font: codeFont,
                .backgroundColor: codeBackgroundColor,
                .paragraphStyle: codeBlockParagraphStyle
            ],
            range: range
        )
    }

    private static func styleVerticalOffsetRanges(
        in textStorage: NSTextStorage,
        string: NSString,
        protectedRanges: [NSRange],
        patterns: [StyledMarkerPattern],
        offset: CGFloat,
        scale: CGFloat,
        searchRange: NSRange
    ) {
        for pattern in patterns {
            enumerateMatches(regex: pattern.regex, in: string, searchRange: searchRange) { match in
                guard
                    let contentRange = range(match, at: 1),
                    !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges)
                else { return }

                let prefixRange = NSRange(location: match.range.location, length: pattern.prefixLength)
                let suffixRange = NSRange(location: NSMaxRange(contentRange), length: pattern.suffixLength)

                setMarkerColor(in: textStorage, ranges: [prefixRange, suffixRange])
                applyVerticalOffset(to: contentRange, in: textStorage, offset: offset, scale: scale)
            }
        }
    }

    private static func applyVerticalOffset(
        to range: NSRange,
        in textStorage: NSTextStorage,
        offset: CGFloat,
        scale: CGFloat
    ) {
        guard range.length > 0 else { return }

        textStorage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let currentFont = (value as? NSFont) ?? baseFont
            let scaledFont = scaledFont(from: currentFont, scale: scale)

            textStorage.addAttributes(
                [
                    .font: scaledFont,
                    .baselineOffset: offset
                ],
                range: subrange
            )
        }
    }

    private static func scaledFont(from font: NSFont, scale: CGFloat) -> NSFont {
        let newSize = max(11, font.pointSize * scale)

        if font.fontDescriptor.symbolicTraits.contains(.monoSpace) {
            return .monospacedSystemFont(ofSize: newSize, weight: .regular)
        }

        return .systemFont(ofSize: newSize)
    }

    private static func setMarkerColor(in textStorage: NSTextStorage, ranges: [NSRange]) {
        for range in ranges where range.length > 0 {
            textStorage.addAttribute(.foregroundColor, value: markerColor, range: range)
        }
    }

    private static func applyFontTrait(_ trait: NSFontTraitMask, to range: NSRange, in textStorage: NSTextStorage) {
        guard range.length > 0 else { return }

        textStorage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let currentFont = (value as? NSFont) ?? baseFont
            let convertedFont = NSFontManager.shared.convert(currentFont, toHaveTrait: trait)
            let font = convertedFont == currentFont ? fallbackFont(from: currentFont, adding: trait) : convertedFont
            textStorage.addAttribute(.font, value: font, range: subrange)
        }
    }

    private static func fallbackFont(from font: NSFont, adding trait: NSFontTraitMask) -> NSFont {
        switch trait {
        case .boldFontMask:
            return .systemFont(ofSize: font.pointSize, weight: .bold)
        case .italicFontMask:
            return NSFontManager.shared.convert(.systemFont(ofSize: font.pointSize), toHaveTrait: .italicFontMask)
        default:
            return font
        }
    }

    private static func headingFont(for level: Int) -> NSFont {
        let index = min(max(level, 1), headingFonts.count) - 1
        return headingFonts[index]
    }

    private static func intersectsProtectedRanges(_ range: NSRange, protectedRanges: [NSRange]) -> Bool {
        protectedRanges.contains { NSIntersectionRange(range, $0).length > 0 }
    }

    private static func indentWidth(for value: String) -> Int {
        value.reduce(into: 0) { width, character in
            width += character == "\t" ? 4 : 1
        }
    }

    private static func attributes(at location: Int, in textStorage: NSTextStorage) -> [NSAttributedString.Key: Any] {
        guard textStorage.length > 0 else {
            return baseAttributes()
        }

        let safeLocation = min(location, textStorage.length - 1)
        return textStorage.attributes(at: safeLocation, effectiveRange: nil)
    }

    private static func enumerateMatches(
        regex: NSRegularExpression,
        in string: NSString,
        searchRange: NSRange,
        using block: (NSTextCheckingResult) -> Void
    ) {
        guard searchRange.length > 0 else { return }

        regex.enumerateMatches(in: string as String, range: searchRange) { match, _, _ in
            guard let match else { return }
            block(match)
        }
    }

    private static func range(_ match: NSTextCheckingResult, at index: Int) -> NSRange? {
        let range = match.range(at: index)
        return range.location == NSNotFound ? nil : range
    }

    private static func collectReferenceDefinitions(
        in string: NSString,
        protectedRanges: [NSRange],
        searchRange: NSRange
    ) -> [String: URL] {
        var definitions: [String: URL] = [:]

        enumerateMatches(regex: referenceDefinitionRegex, in: string, searchRange: searchRange) { match in
            guard
                let idRange = range(match, at: 1),
                let urlRange = range(match, at: 2),
                !intersectsProtectedRanges(match.range, protectedRanges: protectedRanges)
            else { return }

            let identifier = normalizedReferenceIdentifier(string.substring(with: idRange))
            guard let url = url(from: string.substring(with: urlRange)) else { return }

            definitions[identifier] = url
        }

        return definitions
    }

    private static func normalizedReferenceIdentifier(_ identifier: String) -> String {
        identifier
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    private static func latexDelimiterRanges(in blockRange: NSRange, string: NSString) -> [NSRange] {
        guard blockRange.length > 0 else { return [] }

        let firstLineRange = string.lineRange(for: NSRange(location: blockRange.location, length: 0))
        let lastCharacterLocation = max(blockRange.location, NSMaxRange(blockRange) - 1)
        let lastLineRange = string.lineRange(for: NSRange(location: lastCharacterLocation, length: 0))

        if NSEqualRanges(firstLineRange, lastLineRange) {
            return [firstLineRange]
        }

        return [firstLineRange, lastLineRange]
    }

    private static func makeParagraphStyle(_ configure: (NSMutableParagraphStyle) -> Void) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        configure(style)
        return style
    }

    private static func stylingRange(for editedRange: NSRange?, in string: NSString) -> NSRange {
        let fullRange = NSRange(location: 0, length: string.length)
        guard
            let editedRange,
            fullRange.length > 0
        else {
            return fullRange
        }

        return expandedBlockRange(around: clamp(editedRange, to: fullRange), in: string)
    }

    private static func expandedBlockRange(around editedRange: NSRange, in string: NSString) -> NSRange {
        guard string.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let maximumLocation = max(0, string.length - 1)
        let startLocation = min(editedRange.location, maximumLocation)
        let endLocation = min(max(startLocation, NSMaxRange(editedRange) - 1), maximumLocation)
        var expandedRange = NSUnionRange(
            string.lineRange(for: NSRange(location: startLocation, length: 0)),
            string.lineRange(for: NSRange(location: endLocation, length: 0))
        )

        while expandedRange.location > 0 {
            let previousLineRange = string.lineRange(for: NSRange(location: expandedRange.location - 1, length: 0))
            guard !isBlankLine(previousLineRange, in: string) else { break }
            expandedRange = NSUnionRange(expandedRange, previousLineRange)
        }

        while NSMaxRange(expandedRange) < string.length {
            let nextLineRange = string.lineRange(for: NSRange(location: NSMaxRange(expandedRange), length: 0))
            guard !isBlankLine(nextLineRange, in: string) else { break }
            expandedRange = NSUnionRange(expandedRange, nextLineRange)
        }

        return expandedRange
    }

    private static func clamp(_ range: NSRange, to bounds: NSRange) -> NSRange {
        let lowerBound = bounds.location
        let upperBound = NSMaxRange(bounds)
        let location = min(max(range.location, lowerBound), upperBound)
        let length = min(max(0, range.length), upperBound - location)
        return NSRange(location: location, length: length)
    }

    private static func isBlankLine(_ range: NSRange, in string: NSString) -> Bool {
        string.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func mergedHardLineBreakMarkers(
        existing: [MarkdownHardLineBreakMarker],
        replacingIn searchRange: NSRange,
        with replacements: [MarkdownHardLineBreakMarker]
    ) -> [MarkdownHardLineBreakMarker] {
        let preservedMarkers = existing.filter { NSIntersectionRange($0.spacesRange, searchRange).length == 0 }
        return preservedMarkers + replacements
    }
}

private struct StyledMarkerPattern {
    let regex: NSRegularExpression
    let prefixLength: Int
    let suffixLength: Int
}
