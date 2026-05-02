//
//  MarkdownTextView.swift
//  Markdown
//
//  Created by Stéphane on 01/05/2026.
//

import AppKit
import UniformTypeIdentifiers

private final class WeakMarkdownTextViewReference {
    weak var value: MarkdownTextView?
}

enum MarkdownEditorActionDispatcher {
    private static let currentTextViewReference = WeakMarkdownTextViewReference()

    static var currentTextView: MarkdownTextView? {
        get { currentTextViewReference.value }
        set { currentTextViewReference.value = newValue }
    }

    static func send(_ action: Selector) {
        if let textView = currentTextView {
            _ = textView.window?.makeFirstResponder(textView)

            if NSApp.sendAction(action, to: textView, from: textView) {
                return
            }
        }

        NSApp.sendAction(action, to: nil, from: nil)
    }
}

final class MarkdownTextView: NSTextView {
    private static let baseLiveRestyleDelay: TimeInterval = 0.03
    private static let markdownStructuralCharacters = CharacterSet(charactersIn: "\n\r`*_[]()!~^#-+><")
    var documentURL: URL?
    private var pendingRestyleWorkItem: DispatchWorkItem?
    private var pendingEditedRange: NSRange?
    private var pendingRequiresFullRestyle = false

    deinit {
        pendingRestyleWorkItem?.cancel()
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            MarkdownEditorActionDispatcher.currentTextView = self
        }
        return didBecomeFirstResponder
    }

    func setMarkdownText(_ text: String) {
        guard string != text else { return }

        string = text
        pendingEditedRange = nil
        pendingRequiresFullRestyle = true
        restyleImmediately()
    }

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        let shouldChange = super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        guard shouldChange else { return false }

        recordPendingRestyle(for: affectedCharRange, replacementString: replacementString)
        return true
    }

    override func didChangeText() {
        super.didChangeText()
        scheduleRestyle()
    }

    override func insertNewline(_ sender: Any?) {
        if let result = MarkdownListContinuation.action(text: string, selectedRange: selectedRange()) {
            apply(result)
            return
        }

        super.insertNewline(sender)
    }

    override func insertLineBreak(_ sender: Any?) {
        applyHardLineBreakMarkup(sender)
    }

    override func mouseDown(with event: NSEvent) {
        flushPendingRestyleIfNeeded()

        if event.modifierFlags.contains(.command) {
            if let imagePathClick = inlineImagePath(at: event) {
                chooseImagePath(replacing: imagePathClick.range, currentPath: imagePathClick.path)
                return
            }

            if let url = linkURL(at: event) {
                NSWorkspace.shared.open(url)
                return
            }
        }

        super.mouseDown(with: event)
    }

    @objc func applyBoldMarkup(_ sender: Any?) {
        applyMarkup(prefix: "**", suffix: "**")
    }

    @objc func applyItalicMarkup(_ sender: Any?) {
        applyMarkup(prefix: "*", suffix: "*")
    }

    @objc func applyInlineCodeMarkup(_ sender: Any?) {
        applyMarkup(prefix: "`", suffix: "`", placeholder: "code")
    }

    @objc func applyInlineLinkMarkup(_ sender: Any?) {
        applyFormatting { text, selectedRange in
            MarkdownFormatting.inlineLink(text: text, selectedRange: selectedRange)
        }
    }

    @objc func applyInlineImageMarkup(_ sender: Any?) {
        applyFormatting { text, selectedRange in
            MarkdownFormatting.inlineImage(text: text, selectedRange: selectedRange)
        }
    }

    @objc func applyHardLineBreakMarkup(_ sender: Any?) {
        applyFormatting { text, selectedRange in
            MarkdownFormatting.hardLineBreak(text: text, selectedRange: selectedRange)
        }
    }

    @objc func applySubscriptMarkup(_ sender: Any?) {
        applyMarkup(prefix: "~", suffix: "~", placeholder: "2")
    }

    @objc func applySuperscriptMarkup(_ sender: Any?) {
        applyMarkup(prefix: "^", suffix: "^", placeholder: "2")
    }

    @objc func applyHeading1Markup(_ sender: Any?) {
        applyParagraphPrefix("# ", placeholder: "Titre niveau 1")
    }

    @objc func applyHeading2Markup(_ sender: Any?) {
        applyParagraphPrefix("## ", placeholder: "Titre niveau 2")
    }

    @objc func applyHeading3Markup(_ sender: Any?) {
        applyParagraphPrefix("### ", placeholder: "Titre niveau 3")
    }

    @objc func applyHeading4Markup(_ sender: Any?) {
        applyParagraphPrefix("#### ", placeholder: "Titre niveau 4")
    }

    @objc func applyHeading5Markup(_ sender: Any?) {
        applyParagraphPrefix("##### ", placeholder: "Titre niveau 5")
    }

    @objc func applyHeading6Markup(_ sender: Any?) {
        applyParagraphPrefix("###### ", placeholder: "Titre niveau 6")
    }

    @objc func applyBlockquoteMarkup(_ sender: Any?) {
        applyParagraphPrefix("> ", placeholder: "Citation")
    }

    @objc func applyDashListMarkup(_ sender: Any?) {
        applyParagraphPrefix("- ", placeholder: "Élément")
    }

    @objc func applyOrderedListMarkup(_ sender: Any?) {
        applyFormatting { text, selectedRange in
            MarkdownFormatting.paragraphOrderedList(text: text, selectedRange: selectedRange)
        }
    }

    @objc func applyFencedCodeBlockMarkup(_ sender: Any?) {
        applyFormatting { text, selectedRange in
            MarkdownFormatting.paragraphFencedBlock(
                text: text,
                selectedRange: selectedRange,
                fence: "```",
                placeholder: "code ici"
            )
        }
    }

    @objc func applyLatexBlockMarkup(_ sender: Any?) {
        applyFormatting { text, selectedRange in
            MarkdownFormatting.paragraphFencedBlock(
                text: text,
                selectedRange: selectedRange,
                fence: "$$",
                placeholder: "x^2 + y^2 = z^2"
            )
        }
    }

    @objc func applyHorizontalRuleMarkup(_ sender: Any?) {
        applyFormatting { text, selectedRange in
            MarkdownFormatting.horizontalRule(text: text, selectedRange: selectedRange)
        }
    }

    @objc func exportPDF(_ sender: Any?) {
        MarkdownPDFExporter.export(markdown: string, from: self)
    }

    private func scheduleRestyle() {
        pendingRestyleWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.restyleImmediately()
        }
        pendingRestyleWorkItem = workItem

        // Coalesce rapid edits so live styling does not monopolize the main thread.
        DispatchQueue.main.asyncAfter(deadline: .now() + liveRestyleDelay(), execute: workItem)
    }

    private func flushPendingRestyleIfNeeded() {
        guard pendingRestyleWorkItem != nil else { return }
        restyleImmediately()
    }

    private func restyleImmediately() {
        let editedRange = pendingRequiresFullRestyle ? nil : pendingEditedRange
        pendingRestyleWorkItem?.cancel()
        pendingRestyleWorkItem = nil
        pendingEditedRange = nil
        pendingRequiresFullRestyle = false
        MarkdownTextStyler.apply(to: self, editedRange: editedRange)
    }

    private func liveRestyleDelay() -> TimeInterval {
        switch string.utf16.count {
        case 0..<4_000:
            return Self.baseLiveRestyleDelay
        case 4_000..<20_000:
            return 0.05
        default:
            return 0.08
        }
    }

    private func recordPendingRestyle(for affectedCharRange: NSRange, replacementString: String?) {
        let source = string as NSString
        let clampedRange = NSRange(
            location: min(max(0, affectedCharRange.location), source.length),
            length: min(max(0, affectedCharRange.length), max(0, source.length - affectedCharRange.location))
        )
        let removedText = source.substring(with: clampedRange)
        let insertedText = replacementString ?? ""
        let likelyStructuralEdit =
            requiresFullRestyle(for: removedText) ||
            requiresFullRestyle(for: insertedText) ||
            clampedRange.length > 64 ||
            (insertedText as NSString).length > 64

        if likelyStructuralEdit {
            pendingRequiresFullRestyle = true
            pendingEditedRange = nil
            return
        }

        let affectedLength = max(clampedRange.length, (insertedText as NSString).length)
        let candidateRange = NSRange(location: clampedRange.location, length: affectedLength)
        pendingEditedRange = mergeRanges(pendingEditedRange, candidateRange)
    }

    private func requiresFullRestyle(for text: String) -> Bool {
        text.rangeOfCharacter(from: Self.markdownStructuralCharacters) != nil
    }

    private func mergeRanges(_ lhs: NSRange?, _ rhs: NSRange) -> NSRange {
        guard let lhs else { return rhs }

        let start = min(lhs.location, rhs.location)
        let end = max(NSMaxRange(lhs), NSMaxRange(rhs))
        return NSRange(location: start, length: end - start)
    }

    private func applyMarkup(prefix: String, suffix: String, placeholder: String = "texte") {
        applyFormatting { text, selectedRange in
            MarkdownFormatting.wrap(
                text: text,
                selectedRange: selectedRange,
                prefix: prefix,
                suffix: suffix,
                placeholder: placeholder
            )
        }
    }

    private func applyParagraphPrefix(_ prefix: String, placeholder: String) {
        applyFormatting { text, selectedRange in
            MarkdownFormatting.paragraphPrefix(
                text: text,
                selectedRange: selectedRange,
                prefix: prefix,
                placeholder: placeholder
            )
        }
    }

    private func applyFormatting(_ transform: (String, NSRange) -> MarkdownFormattingResult) {
        let currentSelection = selectedRange()
        let result = transform(string, currentSelection)
        apply(result)
    }

    private func apply(_ result: MarkdownFormattingResult) {
        guard shouldChangeText(in: result.replacedRange, replacementString: result.replacement) else {
            return
        }

        textStorage?.replaceCharacters(in: result.replacedRange, with: result.replacement)
        didChangeText()
        setSelectedRange(result.selectedRange)
    }

    private func chooseImagePath(replacing range: NSRange, currentPath: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Choisir"

        configureImagePanel(panel, currentPath: currentPath)

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        let replacementPath = selectedURL.standardizedFileURL.path
        MarkdownFileAccess.registerAccess(to: selectedURL.deletingLastPathComponent())
        let result = MarkdownFormatting.replaceImagePath(
            text: string,
            pathRange: range,
            with: replacementPath
        )
        apply(result)
    }

    private func configureImagePanel(_ panel: NSOpenPanel, currentPath: String) {
        let normalizedPath = (currentPath as NSString).expandingTildeInPath
        guard !normalizedPath.isEmpty else { return }

        let currentURL = URL(fileURLWithPath: normalizedPath)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: currentURL.path) {
            panel.directoryURL = currentURL.deletingLastPathComponent()
            panel.nameFieldStringValue = currentURL.lastPathComponent
            return
        }

        let directoryURL = currentURL.deletingLastPathComponent()
        if fileManager.fileExists(atPath: directoryURL.path) {
            panel.directoryURL = directoryURL
            panel.nameFieldStringValue = currentURL.lastPathComponent
        }
    }

    private func inlineImagePath(at event: NSEvent) -> (range: NSRange, path: String)? {
        guard
            let textStorage,
            let characterIndex = characterIndex(at: event)
        else {
            return nil
        }

        var effectiveRange = NSRange(location: 0, length: 0)
        let value = textStorage.attribute(.markdownInlineImagePath, at: characterIndex, effectiveRange: &effectiveRange)

        guard
            effectiveRange.length > 0,
            let path = value as? String
        else {
            return nil
        }

        return (effectiveRange, path)
    }

    private func linkURL(at event: NSEvent) -> URL? {
        guard
            let textStorage,
            let characterIndex = characterIndex(at: event)
        else {
            return nil
        }

        let linkValue = textStorage.attribute(.link, at: characterIndex, effectiveRange: nil)
        return MarkdownTextStyler.url(from: linkValue)
    }

    private func characterIndex(at event: NSEvent) -> Int? {
        guard
            let layoutManager,
            let textContainer
        else {
            return nil
        }

        let pointInView = convert(event.locationInWindow, from: nil)
        let containerOrigin = textContainerOrigin
        let pointInTextContainer = NSPoint(
            x: pointInView.x - containerOrigin.x,
            y: pointInView.y - containerOrigin.y
        )

        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(
            for: pointInTextContainer,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )

        guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }

        let glyphRange = NSRange(location: glyphIndex, length: 1)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        guard glyphRect.contains(pointInTextContainer) else { return nil }

        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        return characterIndex < string.utf16.count ? characterIndex : nil
    }
}
