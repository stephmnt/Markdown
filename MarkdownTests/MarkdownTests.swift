//
//  MarkdownTests.swift
//  MarkdownTests
//
//  Created by Stéphane on 22/04/2026.
//

import AppKit
import Foundation
import PDFKit
import Testing
@testable import Markdown

/// Unit tests for the document, formatting and live styling layers.
struct MarkdownTests {
    @Test func newDocumentStartsEmpty() {
        let document = MarkdownDocument()

        #expect(document.editor.text.isEmpty)
    }

    @Test func initFromDataReadsUTF8Text() {
        let source = "# Titre\n\nContenu en UTF-8."
        let document = MarkdownDocument(data: Data(source.utf8))

        #expect(document.editor.text == source)
    }

    @Test func serializedDataWritesUTF8Text() {
        let source = "- item 1\n- item 2\n"
        let document = MarkdownDocument(editor: EditorState(text: source))

        #expect(document.serializedData() == Data(source.utf8))
    }

    @Test func markdownRoundTripPreservesContent() {
        let source = """
        # Notes

        Bonjour **Markdown**

        - un
        - deux
        """

        let loaded = MarkdownDocument(data: Data(source.utf8))
        let reserialized = loaded.serializedData()
        let roundTripped = MarkdownDocument(data: reserialized)

        #expect(roundTripped.editor.text == source)
    }

    @Test func pdfRendererUsesBaskervilleAsBaseFont() throws {
        let attributedString = try MarkdownPDFRenderer.attributedString(for: "Bonjour PDF")
        let font = attributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let style = attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle

        #expect(font?.fontName.contains("Baskerville") == true)
        #expect(font?.pointSize == 12)
        #expect(style?.lineHeightMultiple == 1.5)
        #expect(style?.paragraphSpacingBefore == 0)
        #expect(style?.paragraphSpacing == 6)
    }

    @Test func pdfRendererPreservesParagraphBreaksAndHardLineBreaks() throws {
        let source = """
        Première ligne  
        Deuxième ligne

        Nouveau paragraphe
        """
        let attributedString = try MarkdownPDFRenderer.attributedString(for: source)

        #expect(attributedString.string.contains("Première ligne\nDeuxième ligne"))
        #expect(attributedString.string.contains("\nNouveau paragraphe"))
    }

    @Test func pdfRendererRemovesLatexFenceMarkers() throws {
        let source = """
        Avant

        $$
        x^2 + y^2 = z^2
        $$

        Après
        """
        let attributedString = try MarkdownPDFRenderer.attributedString(for: source)

        #expect(!attributedString.string.contains("$$"))
        #expect(attributedString.string.contains("x^2 + y^2 = z^2"))
    }

    @Test func pdfRendererAppliesSubscriptAndSuperscriptWithoutKeepingMarkers() throws {
        let attributedString = try MarkdownPDFRenderer.attributedString(for: "H~2~O et x^2^")

        #expect(attributedString.string == "H2O et x2")
        #expect(attributedBaselineOffset(in: attributedString, matching: "2", occurrence: 1) < 0)
        #expect(attributedBaselineOffset(in: attributedString, matching: "2", occurrence: 2) > 0)
    }

    @Test func pdfRendererRendersUnorderedListsWithBullets() throws {
        let attributedString = try MarkdownPDFRenderer.attributedString(for: "- premier\n- second")
        let firstItemRange = (attributedString.string as NSString).range(of: "premier")
        let style = attributedString.attribute(.paragraphStyle, at: firstItemRange.location, effectiveRange: nil) as? NSParagraphStyle

        #expect(attributedString.string.contains("•\tpremier"))
        #expect(attributedString.string.contains("•\tsecond"))
        #expect((style?.headIndent ?? 0) > 0)
    }

    @Test func pdfRendererRendersOrderedListsWithNumbers() throws {
        let attributedString = try MarkdownPDFRenderer.attributedString(for: "1. premier\n2. second")

        #expect(attributedString.string.contains("1.\tpremier"))
        #expect(attributedString.string.contains("2.\tsecond"))
    }

    @Test func pdfRendererUsesFullWidthAttachmentForHorizontalRule() throws {
        let attributedString = try MarkdownPDFRenderer.attributedString(for: "Avant\n\n---\n\nAprès")
        let markerRange = try #require(rangeOfAttribute(.markdownThematicBreak, in: attributedString))
        let attachment = try #require(attributedString.attribute(.attachment, at: markerRange.location, effectiveRange: nil) as? NSTextAttachment)
        let expectedWidth = MarkdownPDFRenderer.paperSize.width - (2 * (72 / 2.54 * 2.5))

        #expect(abs((attachment.attachmentCell?.cellSize().width ?? 0) - expectedWidth) < 1)
    }

    @Test func pdfRendererAppliesRequestedHeadingAndParagraphTypography() throws {
        let source = """
        # Titre article

        Paragraphe courant.

        # Titre niveau 1

        ## Titre niveau 2

        ### Titre niveau 3
        """
        let attributedString = try MarkdownPDFRenderer.attributedString(for: source)

        let articleFont = attributedFont(in: attributedString, matching: "Titre article")
        let articleStyle = attributedParagraphStyle(in: attributedString, matching: "Titre article")
        let bodyFont = attributedFont(in: attributedString, matching: "Paragraphe courant.")
        let bodyStyle = attributedParagraphStyle(in: attributedString, matching: "Paragraphe courant.")
        let h1Font = attributedFont(in: attributedString, matching: "Titre niveau 1")
        let h1Style = attributedParagraphStyle(in: attributedString, matching: "Titre niveau 1")
        let h2Font = attributedFont(in: attributedString, matching: "Titre niveau 2")
        let h2Style = attributedParagraphStyle(in: attributedString, matching: "Titre niveau 2")
        let h3Font = attributedFont(in: attributedString, matching: "Titre niveau 3")
        let h3Style = attributedParagraphStyle(in: attributedString, matching: "Titre niveau 3")

        #expect(articleFont.pointSize == 16)
        #expect(fontTraits(of: articleFont).contains(.boldFontMask))
        #expect(!fontTraits(of: articleFont).contains(.italicFontMask))
        #expect(articleStyle.paragraphSpacingBefore == 0)
        #expect(articleStyle.paragraphSpacing == 12)

        #expect(bodyFont.pointSize == 12)
        #expect(bodyStyle.lineHeightMultiple == 1.5)
        #expect(bodyStyle.paragraphSpacingBefore == 0)
        #expect(bodyStyle.paragraphSpacing == 6)

        #expect(h1Font.pointSize == 14)
        #expect(fontTraits(of: h1Font).contains(.boldFontMask))
        #expect(!fontTraits(of: h1Font).contains(.italicFontMask))
        #expect(h1Style.paragraphSpacingBefore == 12)
        #expect(h1Style.paragraphSpacing == 6)

        #expect(h2Font.pointSize == 12)
        #expect(fontTraits(of: h2Font).contains(.boldFontMask))
        #expect(!fontTraits(of: h2Font).contains(.italicFontMask))
        #expect(h2Style.paragraphSpacingBefore == 6)
        #expect(h2Style.paragraphSpacing == 6)

        #expect(h3Font.pointSize == 12)
        #expect(fontTraits(of: h3Font).contains(.boldFontMask))
        #expect(fontTraits(of: h3Font).contains(.italicFontMask))
        #expect(h3Style.paragraphSpacingBefore == 0)
        #expect(h3Style.paragraphSpacing == 3)
    }

    @Test func pdfRendererCentersStandaloneImages() throws {
        let imageURL = try makeTemporaryTestImage()
        let attributedString = try MarkdownPDFRenderer.attributedString(for: "Avant\n\n![Chat](\(imageURL.path))\n\nAprès")
        let imageRange = try #require(rangeOfAttribute(.markdownCenteredImage, in: attributedString))
        let attachment = try #require(attributedString.attribute(.attachment, at: imageRange.location, effectiveRange: nil) as? NSTextAttachment)
        let style = try #require(attributedString.attribute(.paragraphStyle, at: imageRange.location, effectiveRange: nil) as? NSParagraphStyle)

        #expect(attributedString.string.contains("Avant"))
        #expect(attributedString.string.contains("Après"))
        #expect(style.alignment == .center)
        #expect((attachment.attachmentCell?.cellSize().width ?? 0) > 0)
    }

    @Test func pdfRendererLimitsStandaloneImageHeightForPageFlow() throws {
        let imageURL = try makeTemporaryTestImage(fileName: "large-square.png", size: NSSize(width: 1024, height: 1024))
        let attributedString = try MarkdownPDFRenderer.attributedString(for: "Avant\n\n![Chat](\(imageURL.path))\n\nAprès")
        let imageRange = try #require(rangeOfAttribute(.markdownCenteredImage, in: attributedString))
        let attachment = try #require(
            attributedString.attribute(.attachment, at: imageRange.location, effectiveRange: nil) as? NSTextAttachment
        )

        let printableHeight = MarkdownPDFRenderer.paperSize.height - (2 * (72 / 2.54 * 2.5))
        let expectedMaxHeight = printableHeight * 0.45

        #expect((attachment.attachmentCell?.cellSize().height ?? 0) <= expectedMaxHeight + 1)
    }

    @Test func pdfRendererSeparatesAdjacentDifferentBlockTypes() throws {
        let source = """
        # **texte**
        * ***je teste***
        __texte__
        $$
        x^2 + y^2 = z^2
        $$
        """

        let attributedString = try MarkdownPDFRenderer.attributedString(for: source)

        #expect(attributedString.string.contains("texte\n•\tje teste"))
        #expect(attributedString.string.contains("je teste\ntexte"))
        #expect(attributedString.string.contains("texte\nx^2 + y^2 = z^2"))
    }

    @Test func pdfRendererSeparatesParagraphHeadingAndFollowingParagraphWithoutBlankLines() throws {
        let source = """
        ***texte***
        ### Titre niveau 3
        Code ici
        """

        let attributedString = try MarkdownPDFRenderer.attributedString(for: source)

        #expect(attributedString.string.contains("texte\nTitre niveau 3\nCode ici"))
    }

    @MainActor
    @Test func pdfRendererProducesPDFData() throws {
        let data = try MarkdownPDFRenderer.pdfData(for: "# Titre\n\nBonjour **PDF**")
        let signature = String(decoding: data.prefix(4), as: UTF8.self)

        #expect(signature == "%PDF")
    }

    @MainActor
    @Test func pdfRendererIncludesImagesInRenderedPDF() throws {
        let imageURL = try makeTemporaryTestImage()
        let data = try MarkdownPDFRenderer.pdfData(for: "![Chat](\(imageURL.path))")
        let pdfDocument = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdfDocument.page(at: 0))
        let thumbnail = firstPage.thumbnail(of: NSSize(width: 595, height: 842), for: .mediaBox)
        let bitmap = try #require(bitmapImageRep(for: thumbnail))

        #expect(bitmapContainsBluePixels(bitmap))
    }

    @MainActor
    @Test func pdfRendererIncludesImagesWithParenthesesInPath() throws {
        let imageURL = try makeTemporaryTestImage(fileName: "chat (1).png")
        let data = try MarkdownPDFRenderer.pdfData(for: "![Chat](\(imageURL.path))")
        let pdfDocument = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdfDocument.page(at: 0))
        let thumbnail = firstPage.thumbnail(of: NSSize(width: 595, height: 842), for: .mediaBox)
        let bitmap = try #require(bitmapImageRep(for: thumbnail))

        #expect(bitmapContainsBluePixels(bitmap))
    }

    @MainActor
    @Test func pdfRendererIncludesImagesWithRelativePathAndBaseURL() throws {
        let imageURL = try makeTemporaryTestImage(fileName: "chat.png")
        let baseURL = imageURL.deletingLastPathComponent()
        let data = try MarkdownPDFRenderer.pdfData(for: "![Chat](chat.png)", baseURL: baseURL)
        let pdfDocument = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdfDocument.page(at: 0))
        let thumbnail = firstPage.thumbnail(of: NSSize(width: 595, height: 842), for: .mediaBox)
        let bitmap = try #require(bitmapImageRep(for: thumbnail))

        #expect(bitmapContainsBluePixels(bitmap))
    }

    @MainActor
    @Test func pdfRendererIncludesImagesWithRelativePathAndOptionalTitle() throws {
        let imageURL = try makeTemporaryTestImage(fileName: "chat.png")
        let baseURL = imageURL.deletingLastPathComponent()
        let data = try MarkdownPDFRenderer.pdfData(
            for: "![Chat](chat.png \"Titre optionnel\")",
            baseURL: baseURL
        )
        let pdfDocument = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdfDocument.page(at: 0))
        let thumbnail = firstPage.thumbnail(of: NSSize(width: 595, height: 842), for: .mediaBox)
        let bitmap = try #require(bitmapImageRep(for: thumbnail))

        #expect(bitmapContainsBluePixels(bitmap))
    }

    @MainActor
    @Test func pdfRendererExportsFunctionalRecipeDocument() throws {
        let directoryURL = temporaryDirectoryURL()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let imageFileName = "ChatGPT Image 1 mai 2026, 21_38_12.png"
        let imageURL = try makeTemporaryTestImage(in: directoryURL, fileName: imageFileName)
        let source = functionalRecipeMarkdown(absoluteImagePath: imageURL.path)
        let data = try MarkdownPDFRenderer.pdfData(for: source, baseURL: directoryURL)
        let pdfDocument = try #require(PDFDocument(data: data))

        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "%PDF")
        #expect(pdfDocument.pageCount >= 2)
        #expect(pdfDocumentContainsBluePixels(pdfDocument))
    }

    @Test func pdfRendererFindsLocalImageURLWithSpaces() {
        let url = URL(fileURLWithPath: "/Users/steph/Downloads/ChatGPT Image 1 mai 2026, 21_38_12.png")
        let urls = MarkdownPDFRenderer.localImageURLs(in: "![Texte alternatif](\(url.path))")

        #expect(urls == [url.standardizedFileURL])
    }

    @Test func pdfRendererFindsLocalImageURLWithOptionalTitle() {
        let baseURL = URL(fileURLWithPath: "/Users/steph/Documents")
        let urls = MarkdownPDFRenderer.localImageURLs(
            in: "![Texte alternatif](images/chat.png \"Titre optionnel\")",
            baseURL: baseURL
        )

        #expect(urls == [baseURL.appendingPathComponent("images/chat.png").standardizedFileURL])
    }

    @Test func fileAccessTreatsEquivalentFileLocationsAsSame() {
        let canonicalURL = URL(fileURLWithPath: "/Users/steph/Downloads/ChatGPT Image 1 mai 2026, 21_38_12.png")
        let equivalentURL = URL(fileURLWithPath: "/Users/steph/Downloads/../Downloads/ChatGPT Image 1 mai 2026, 21_38_12.png")

        #expect(MarkdownFileAccess.sameFileLocation(canonicalURL, equivalentURL))
    }

    @Test func fileAccessKeepsOriginalSessionURL() throws {
        let fileURL = try makeTemporaryTestImage(fileName: "session-image.png")
        let originalURL = fileURL.deletingLastPathComponent().appendingPathComponent(".").appendingPathComponent(fileURL.lastPathComponent)

        MarkdownFileAccess.debugRemoveAccess(for: fileURL)
        MarkdownFileAccess.registerAccess(to: originalURL)

        #expect(MarkdownFileAccess.debugSessionURL(for: fileURL) == originalURL)
        MarkdownFileAccess.debugRemoveAccess(for: fileURL)
    }

    @Test func fileAccessResolvesAncestorFolderScopeForImageFile() throws {
        let fileURL = try makeTemporaryTestImage(fileName: "ancestor-scope-image.png")
        let folderURL = fileURL.deletingLastPathComponent()

        MarkdownFileAccess.debugRemoveAccess(for: folderURL)
        MarkdownFileAccess.registerAccess(to: folderURL)

        #expect(MarkdownFileAccess.debugAccessScopeURL(for: fileURL) == folderURL)
        MarkdownFileAccess.debugRemoveAccess(for: folderURL)
    }

    @Test func fileAccessMaterializesImageDataBeforeReturning() throws {
        let fileURL = try makeTemporaryTestImage(fileName: "materialized-image.png")
        let image = try #require(MarkdownFileAccess.loadImage(at: fileURL))

        try FileManager.default.removeItem(at: fileURL)

        let bitmap = try #require(bitmapImageRep(for: image))
        #expect(bitmapContainsBluePixels(bitmap))
    }

    @Test func fileAccessDownsamplesLargeImagesForPDFRendering() throws {
        let fileURL = try makeTemporaryTestImage(
            fileName: "downsampled-image.png",
            size: NSSize(width: 1600, height: 1600)
        )
        let image = try #require(MarkdownFileAccess.loadImage(at: fileURL, maximumPixelSize: 256))
        let bitmap = try #require(bitmapImageRep(for: image))

        #expect(max(image.size.width, image.size.height) <= 256)
        #expect(max(bitmap.pixelsWide, bitmap.pixelsHigh) <= 256)
        #expect(bitmapContainsBluePixels(bitmap))
    }

    @Test func fileAccessAllowsChoosingAncestorDirectoryForImageAccess() throws {
        let rootDirectoryURL = temporaryDirectoryURL()
        let nestedDirectoryURL = rootDirectoryURL.appendingPathComponent("assets/images", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectoryURL, withIntermediateDirectories: true)
        let fileURL = try makeTemporaryTestImage(in: nestedDirectoryURL, fileName: "ancestor-access-image.png")

        #expect(MarkdownFileAccess.directory(rootDirectoryURL, contains: fileURL))
    }

    @Test func fileAccessSuggestsPreferredDirectoryWhenItCoversAllImages() throws {
        let rootDirectoryURL = temporaryDirectoryURL()
        let nestedDirectoryURL = rootDirectoryURL.appendingPathComponent("assets/images", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectoryURL, withIntermediateDirectories: true)
        let fileURL = try makeTemporaryTestImage(in: nestedDirectoryURL, fileName: "preferred-directory-image.png")

        let suggestedDirectoryURL = MarkdownFileAccess.debugSuggestedAccessDirectory(
            for: [fileURL],
            preferredDirectoryURL: rootDirectoryURL
        )

        #expect(suggestedDirectoryURL == rootDirectoryURL.standardizedFileURL)
    }

    @Test func fileAccessFindsCommonAncestorDirectoryForMultipleImages() throws {
        let rootDirectoryURL = temporaryDirectoryURL()
        let firstDirectoryURL = rootDirectoryURL.appendingPathComponent("assets/figures", isDirectory: true)
        let secondDirectoryURL = rootDirectoryURL.appendingPathComponent("assets/photos", isDirectory: true)
        try FileManager.default.createDirectory(at: firstDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDirectoryURL, withIntermediateDirectories: true)
        let firstImageURL = try makeTemporaryTestImage(in: firstDirectoryURL, fileName: "first-image.png")
        let secondImageURL = try makeTemporaryTestImage(in: secondDirectoryURL, fileName: "second-image.png")

        let ancestorDirectoryURL = MarkdownFileAccess.commonAncestorDirectory(for: [firstImageURL, secondImageURL])

        #expect(ancestorDirectoryURL == rootDirectoryURL.appendingPathComponent("assets", isDirectory: true).standardizedFileURL)
    }

    @MainActor
    @Test func pdfRendererPaginatesLongDocumentsIntoA4Pages() throws {
        let source = Array(repeating: "Paragraphe de test pour le PDF avec assez de texte pour remplir plusieurs pages.\n\n", count: 220).joined()
        let data = try MarkdownPDFRenderer.pdfData(for: source)
        let pdfDocument = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdfDocument.page(at: 0))
        let bounds = firstPage.bounds(for: .mediaBox)

        #expect(pdfDocument.pageCount > 1)
        #expect(abs(bounds.width - MarkdownPDFRenderer.paperSize.width) < 1)
        #expect(abs(bounds.height - MarkdownPDFRenderer.paperSize.height) < 1)
    }

    @MainActor
    @Test func pdfRendererCanWritePDFDirectlyToDisk() throws {
        let directoryURL = temporaryDirectoryURL()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let outputURL = directoryURL.appendingPathComponent("direct-write.pdf")

        try MarkdownPDFRenderer.writePDF(for: "# Titre\n\nBonjour **PDF**", to: outputURL)

        let data = try Data(contentsOf: outputURL)
        let pdfDocument = try #require(PDFDocument(url: outputURL))

        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "%PDF")
        #expect(pdfDocument.pageCount >= 1)
    }

    @Test func formattingWrapsSelectedText() {
        let result = MarkdownFormatting.wrap(
            text: "Bonjour monde",
            selectedRange: NSRange(location: 8, length: 5),
            prefix: "**",
            suffix: "**"
        )

        #expect(result.text == "Bonjour **monde**")
        #expect(result.selectedRange == NSRange(location: 10, length: 5))
    }

    @Test func formattingInsertsSuperscriptPlaceholderWhenSelectionIsEmpty() {
        let result = MarkdownFormatting.wrap(
            text: "Bonjour",
            selectedRange: NSRange(location: 7, length: 0),
            prefix: "^",
            suffix: "^",
            placeholder: "2"
        )

        #expect(result.text == "Bonjour^2^")
        #expect(result.selectedRange == NSRange(location: 8, length: 1))
    }

    @Test func formattingWrapsSelectionAsSubscript() {
        let result = MarkdownFormatting.wrap(
            text: "H2O",
            selectedRange: NSRange(location: 1, length: 1),
            prefix: "~",
            suffix: "~",
            placeholder: "2"
        )

        #expect(result.text == "H~2~O")
        #expect(result.selectedRange == NSRange(location: 2, length: 1))
    }

    @Test func formattingCreatesInlineLinkAndSelectsURL() {
        let result = MarkdownFormatting.inlineLink(
            text: "OpenAI",
            selectedRange: NSRange(location: 0, length: 6)
        )

        #expect(result.text == "[OpenAI](https://example.com/)")
        #expect(result.selectedRange == NSRange(location: 9, length: 20))
    }

    @Test func formattingInsertsHardLineBreakAtCaret() {
        let result = MarkdownFormatting.hardLineBreak(
            text: "Bonjourmonde",
            selectedRange: NSRange(location: 7, length: 0)
        )

        #expect(result.text == "Bonjour  \nmonde")
        #expect(result.selectedRange == NSRange(location: 10, length: 0))
    }

    @Test func formattingReplacesInlineImagePath() {
        let result = MarkdownFormatting.replaceImagePath(
            text: "![Texte alternatif](/chemin/image.jpg)",
            pathRange: NSRange(location: 20, length: 17),
            with: "/Users/steph/Pictures/chat.png"
        )

        #expect(result.text == "![Texte alternatif](/Users/steph/Pictures/chat.png)")
        #expect(result.selectedRange == NSRange(location: 20, length: 30))
    }

    @Test func formattingPrefixesSelectedLinesAsBlockquote() {
        let result = MarkdownFormatting.prefixLines(
            text: "Ligne 1\nLigne 2",
            selectedRange: NSRange(location: 0, length: 14),
            prefix: "> ",
            placeholder: "Citation"
        )

        #expect(result.text == "> Ligne 1\n> Ligne 2")
        #expect(result.selectedRange == NSRange(location: 0, length: 19))
    }

    @Test func formattingNumbersSelectedLines() {
        let result = MarkdownFormatting.numberLines(
            text: "Alpha\nBeta",
            selectedRange: NSRange(location: 0, length: 10)
        )

        #expect(result.text == "1. Alpha\n2. Beta")
        #expect(result.selectedRange == NSRange(location: 0, length: 16))
    }

    @Test func formattingCreatesFencedCodeBlock() {
        let result = MarkdownFormatting.fencedCodeBlock(
            text: "print(\"Hi\")",
            selectedRange: NSRange(location: 0, length: 11)
        )

        #expect(result.text == "```\nprint(\"Hi\")\n```")
        #expect(result.selectedRange == NSRange(location: 4, length: 11))
    }

    @Test func horizontalRuleSkipsTwoLinesWhenCurrentLineHasText() {
        let result = MarkdownFormatting.horizontalRule(
            text: "Bonjour",
            selectedRange: NSRange(location: 3, length: 0)
        )

        #expect(result.text == "Bonjour\n\n---")
    }

    @Test func horizontalRuleSkipsOneLineWhenOnlyPreviousLineHasText() {
        let result = MarkdownFormatting.horizontalRule(
            text: "Bonjour\n",
            selectedRange: NSRange(location: 8, length: 0)
        )

        #expect(result.text == "Bonjour\n\n---")
    }

    @Test func horizontalRuleSkipsNoLineWhenCurrentAndPreviousLinesAreEmpty() {
        let result = MarkdownFormatting.horizontalRule(
            text: "Bonjour\n\n",
            selectedRange: NSRange(location: 9, length: 0)
        )

        #expect(result.text == "Bonjour\n\n---")
    }

    @Test func formattingEscapesMarkdownCharacters() {
        let result = MarkdownFormatting.escapeSelection(
            text: "*gras*",
            selectedRange: NSRange(location: 0, length: 6)
        )

        #expect(result.text == "\\*gras\\*")
        #expect(result.selectedRange == NSRange(location: 0, length: 8))
    }

    @Test func paragraphFormattingReplacesBlockquoteWithHeading() {
        let result = MarkdownFormatting.paragraphPrefix(
            text: "> Citation",
            selectedRange: NSRange(location: 0, length: 0),
            prefix: "# ",
            placeholder: "Titre"
        )

        #expect(result.text == "# Citation")
    }

    @Test func paragraphFormattingReplacesHeadingLevelInsteadOfStackingIt() {
        let result = MarkdownFormatting.paragraphPrefix(
            text: "# Ancien titre",
            selectedRange: NSRange(location: 0, length: 0),
            prefix: "## ",
            placeholder: "Titre"
        )

        #expect(result.text == "## Ancien titre")
    }

    @Test func paragraphFormattingReplacesSetextHeadingWithATXHeading() {
        let result = MarkdownFormatting.paragraphPrefix(
            text: "Titre\n=====",
            selectedRange: NSRange(location: 0, length: 0),
            prefix: "## ",
            placeholder: "Titre"
        )

        #expect(result.text == "## Titre")
    }

    @Test func paragraphFormattingWrapsLatexBlockAfterRemovingPreviousParagraphStyle() {
        let result = MarkdownFormatting.paragraphFencedBlock(
            text: "> a^2 + b^2 = c^2",
            selectedRange: NSRange(location: 0, length: 0),
            fence: "$$",
            placeholder: "x^2 + y^2 = z^2"
        )

        #expect(result.text == "$$\na^2 + b^2 = c^2\n$$")
    }

    @Test func listContinuationAddsAnotherUnorderedItemAtLineEnd() {
        let result = MarkdownListContinuation.action(
            text: "- premier",
            selectedRange: NSRange(location: 9, length: 0)
        )

        #expect(result?.text == "- premier\n- ")
        #expect(result?.selectedRange == NSRange(location: 12, length: 0))
    }

    @Test func listContinuationRemovesEmptyBulletAndReturnsToPlainParagraph() {
        let result = MarkdownListContinuation.action(
            text: "- ",
            selectedRange: NSRange(location: 2, length: 0)
        )

        #expect(result?.text == "")
        #expect(result?.selectedRange == NSRange(location: 0, length: 0))
    }

    @Test func listContinuationIncrementsOrderedLists() {
        let result = MarkdownListContinuation.action(
            text: "3. suite",
            selectedRange: NSRange(location: 8, length: 0)
        )

        #expect(result?.text == "3. suite\n4. ")
        #expect(result?.selectedRange == NSRange(location: 12, length: 0))
    }

    @Test @MainActor func stylerSupportsUnderscoreEmphasisVariants() {
        let textView = NSTextView()
        textView.string = "_italique_ __gras__"

        MarkdownTextStyler.apply(to: textView)

        let italicFont = font(in: textView, matching: "italique")
        let boldFont = font(in: textView, matching: "gras")

        #expect(NSFontManager.shared.traits(of: italicFont).contains(.italicFontMask))
        #expect(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))
    }

    @Test @MainActor func stylerDistinguishesSingleDoubleAndTripleAsterisks() {
        let textView = NSTextView()
        textView.string = "*italique* **gras** ***mixte***"

        MarkdownTextStyler.apply(to: textView)

        let italicTraits = NSFontManager.shared.traits(of: font(in: textView, matching: "italique"))
        let boldTraits = NSFontManager.shared.traits(of: font(in: textView, matching: "gras"))
        let mixedTraits = NSFontManager.shared.traits(of: font(in: textView, matching: "mixte"))

        #expect(italicTraits.contains(.italicFontMask))
        #expect(!italicTraits.contains(.boldFontMask))
        #expect(boldTraits.contains(.boldFontMask))
        #expect(!boldTraits.contains(.italicFontMask))
        #expect(mixedTraits.contains(.boldFontMask))
        #expect(mixedTraits.contains(.italicFontMask))
    }

    @Test @MainActor func stylerSupportsAsteriskListsContainingBoldAndItalicText() {
        let textView = NSTextView()
        textView.string = """
        * **gras**
        * *italique*
        """

        MarkdownTextStyler.apply(to: textView)

        let boldTraits = NSFontManager.shared.traits(of: font(in: textView, matching: "gras"))
        let italicTraits = NSFontManager.shared.traits(of: font(in: textView, matching: "italique"))

        #expect(boldTraits.contains(.boldFontMask))
        #expect(!boldTraits.contains(.italicFontMask))
        #expect(italicTraits.contains(.italicFontMask))
        #expect(!italicTraits.contains(.boldFontMask))
    }

    @Test @MainActor func stylerHighlightsHardLineBreakOnlyAtLineEnd() throws {
        let textView = makeMarkdownTextView()
        textView.string = "ligne  \nligne  suivante"

        MarkdownTextStyler.apply(to: textView)

        let highlightedSpacesRange = NSRange(location: 5, length: 2)
        let regularSpacesRange = NSRange(location: 13, length: 2)
        let textStorage = try #require(textView.textStorage)

        let highlightedBackground = textStorage.attribute(.backgroundColor, at: highlightedSpacesRange.location, effectiveRange: nil)
        let regularBackground = textStorage.attribute(.backgroundColor, at: regularSpacesRange.location, effectiveRange: nil)
        let layoutManager = try #require(textView.layoutManager as? MarkdownLayoutManager)

        #expect(highlightedBackground as? NSColor != nil)
        #expect(regularBackground == nil)
        #expect(layoutManager.hardLineBreakMarkers == [MarkdownHardLineBreakMarker(spacesRange: highlightedSpacesRange)])
    }

    @Test @MainActor func stylerMarksInlineImagePathAsClickable() throws {
        let textView = makeMarkdownTextView()
        textView.string = "![Texte alternatif](/chemin/image.jpg)"

        MarkdownTextStyler.apply(to: textView)

        let textStorage = try #require(textView.textStorage)
        let pathRange = NSRange(location: 20, length: 17)
        let altRange = NSRange(location: 2, length: 17)

        let imagePath = textStorage.attribute(.markdownInlineImagePath, at: pathRange.location, effectiveRange: nil) as? String
        let altTextMarker = textStorage.attribute(.markdownInlineImagePath, at: altRange.location, effectiveRange: nil)
        let underline = textStorage.attribute(.underlineStyle, at: pathRange.location, effectiveRange: nil) as? Int

        #expect(imagePath == "/chemin/image.jpg")
        #expect(altTextMarker == nil)
        #expect(underline == NSUnderlineStyle.single.rawValue)
    }

    @Test @MainActor func stylerMarksInlineImagePathAsClickableWithParenthesesInPath() throws {
        let path = "/Users/steph/Pictures/chat (1).png"
        let markdown = "![Texte alternatif](\(path))"
        let textView = makeMarkdownTextView()
        textView.string = markdown

        MarkdownTextStyler.apply(to: textView)

        let textStorage = try #require(textView.textStorage)
        let pathLocation = (markdown as NSString).range(of: path).location
        let imagePath = textStorage.attribute(.markdownInlineImagePath, at: pathLocation, effectiveRange: nil) as? String
        let underline = textStorage.attribute(.underlineStyle, at: pathLocation, effectiveRange: nil) as? Int

        #expect(imagePath == path)
        #expect(underline == NSUnderlineStyle.single.rawValue)
    }

    @Test @MainActor func stylerMarksInlineImagePathAsClickableWithOptionalTitle() throws {
        let path = "/Users/steph/Pictures/chat.png"
        let markdown = "![Texte alternatif](\(path) \"Titre optionnel\")"
        let textView = makeMarkdownTextView()
        textView.string = markdown

        MarkdownTextStyler.apply(to: textView)

        let textStorage = try #require(textView.textStorage)
        let pathLocation = (markdown as NSString).range(of: path).location
        let imagePath = textStorage.attribute(.markdownInlineImagePath, at: pathLocation, effectiveRange: nil) as? String
        let underline = textStorage.attribute(.underlineStyle, at: pathLocation, effectiveRange: nil) as? Int

        #expect(imagePath == path)
        #expect(underline == NSUnderlineStyle.single.rawValue)
    }

    @Test @MainActor func stylerIncrementalRestyleKeepsReferenceLinksResolvable() throws {
        let textView = makeMarkdownTextView()
        textView.string = """
        Premier paragraphe.

        Deuxieme paragraphe avec [OpenAI][openai].

        [openai]: https://openai.com/
        """
        MarkdownTextStyler.apply(to: textView)

        let original = textView.string as NSString
        let replacedRange = original.range(of: "Deuxieme")
        let replacement = "Troisieme"
        textView.textStorage?.replaceCharacters(in: replacedRange, with: replacement)
        MarkdownTextStyler.apply(
            to: textView,
            editedRange: NSRange(location: replacedRange.location, length: (replacement as NSString).length)
        )

        let url = link(in: textView, matching: "OpenAI")
        #expect(url?.absoluteString == "https://openai.com/")
    }

    @Test @MainActor func stylerSupportsSetextHeadings() {
        let textView = NSTextView()
        textView.string = "Titre Setext\n============"

        MarkdownTextStyler.apply(to: textView)

        let headingFont = font(in: textView, matching: "Titre Setext")
        #expect(headingFont.pointSize > 16)
    }

    @Test @MainActor func stylerCompactsSetextUnderlineSpacing() {
        let textView = NSTextView()
        textView.string = "Titre Setext\n============"

        MarkdownTextStyler.apply(to: textView)

        let titleStyle = paragraphStyle(in: textView, matching: "Titre Setext")
        let underlineStyle = paragraphStyle(in: textView, matching: "============")

        #expect(titleStyle.lineSpacing == 0)
        #expect(underlineStyle.lineSpacing == 0)
        #expect(underlineStyle.paragraphSpacing == 8)
    }

    @Test @MainActor func stylerProtectsInlineCodeFromMarkdownEmphasis() {
        let textView = NSTextView()
        textView.string = "`**code**`"

        MarkdownTextStyler.apply(to: textView)

        let codeFont = font(in: textView, matching: "code")
        let traits = NSFontManager.shared.traits(of: codeFont)

        #expect(codeFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #expect(!traits.contains(.boldFontMask))
    }

    @Test @MainActor func stylerSupportsSubscriptAndSuperscript() {
        let textView = NSTextView()
        textView.string = "H~2~O X^2^"

        MarkdownTextStyler.apply(to: textView)

        let subscriptOffset = baselineOffset(in: textView, matching: "2", occurrence: 1)
        let superscriptOffset = baselineOffset(in: textView, matching: "2", occurrence: 2)

        #expect(subscriptOffset < 0)
        #expect(superscriptOffset > 0)
    }

    @Test @MainActor func stylerTreatsLatexBlocksAsLiteralContent() {
        let textView = NSTextView()
        textView.string = """
        $$
        *alpha* x^2^ H~2~O
        $$
        """

        MarkdownTextStyler.apply(to: textView)

        let alphaTraits = NSFontManager.shared.traits(of: font(in: textView, matching: "alpha"))
        let superscriptOffset = baselineOffset(in: textView, matching: "2", occurrence: 1)
        let subscriptOffset = baselineOffset(in: textView, matching: "2", occurrence: 2)

        #expect(!alphaTraits.contains(.italicFontMask))
        #expect(!alphaTraits.contains(.boldFontMask))
        #expect(superscriptOffset == 0)
        #expect(subscriptOffset == 0)
    }

    @Test @MainActor func stylerSupportsMultilineFencedCodeBlocks() {
        let textView = NSTextView()
        textView.string = "```\nlet a = 1\nlet b = 2\n```"

        MarkdownTextStyler.apply(to: textView)

        let firstCodeFont = font(in: textView, matching: "let a = 1")
        let secondCodeFont = font(in: textView, matching: "let b = 2")

        #expect(firstCodeFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #expect(secondCodeFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }

    @Test @MainActor func stylerDoesNotIndentBlockquotesOrCodeBlocks() {
        let textView = NSTextView()
        textView.string = "> Citation\n\n```\nlet valeur = 1\n```"

        MarkdownTextStyler.apply(to: textView)

        let quoteStyle = paragraphStyle(in: textView, matching: "Citation")
        let codeStyle = paragraphStyle(in: textView, matching: "let valeur = 1")

        #expect(quoteStyle.headIndent == 0)
        #expect(quoteStyle.firstLineHeadIndent == 0)
        #expect(codeStyle.headIndent == 0)
        #expect(codeStyle.firstLineHeadIndent == 0)
    }

    @Test @MainActor func stylerMakesInlineLinksClickable() {
        let textView = NSTextView()
        textView.string = "[OpenAI](https://openai.com/)"

        MarkdownTextStyler.apply(to: textView)

        let url = link(in: textView, matching: "OpenAI")
        #expect(url?.absoluteString == "https://openai.com/")
    }
}

@MainActor
private func font(in textView: NSTextView, matching substring: String) -> NSFont {
    let nsString = textView.string as NSString
    let range = nsString.range(of: substring)
    return textView.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? .systemFont(ofSize: 16)
}

private func attributedFont(in attributedString: NSAttributedString, matching substring: String) -> NSFont {
    let nsString = attributedString.string as NSString
    let range = nsString.range(of: substring)
    return attributedString.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? .systemFont(ofSize: 16)
}

@MainActor
private func baselineOffset(in textView: NSTextView, matching substring: String, occurrence: Int) -> CGFloat {
    let nsString = textView.string as NSString
    var searchRange = NSRange(location: 0, length: nsString.length)
    var currentOccurrence = 0

    while searchRange.location < nsString.length {
        let range = nsString.range(of: substring, options: [], range: searchRange)
        if range.location == NSNotFound {
            break
        }

        currentOccurrence += 1
        if currentOccurrence == occurrence {
            return baselineOffsetValue(textView.textStorage?.attribute(.baselineOffset, at: range.location, effectiveRange: nil))
        }

        let nextLocation = NSMaxRange(range)
        searchRange = NSRange(location: nextLocation, length: nsString.length - nextLocation)
    }

    return 0
}

private func attributedBaselineOffset(in attributedString: NSAttributedString, matching substring: String, occurrence: Int) -> CGFloat {
    let nsString = attributedString.string as NSString
    var searchRange = NSRange(location: 0, length: nsString.length)
    var currentOccurrence = 0

    while searchRange.location < nsString.length {
        let range = nsString.range(of: substring, options: [], range: searchRange)
        if range.location == NSNotFound {
            break
        }

        currentOccurrence += 1
        if currentOccurrence == occurrence {
            return baselineOffsetValue(attributedString.attribute(.baselineOffset, at: range.location, effectiveRange: nil))
        }

        let nextLocation = NSMaxRange(range)
        searchRange = NSRange(location: nextLocation, length: nsString.length - nextLocation)
    }

    return 0
}

private func baselineOffsetValue(_ value: Any?) -> CGFloat {
    if let value = value as? CGFloat {
        return value
    }

    if let value = value as? Double {
        return value
    }

    if let value = value as? NSNumber {
        return CGFloat(truncating: value)
    }

    return 0
}

private func rangeOfAttribute(_ key: NSAttributedString.Key, in attributedString: NSAttributedString) -> NSRange? {
    let fullRange = NSRange(location: 0, length: attributedString.length)
    var matchedRange: NSRange?

    attributedString.enumerateAttribute(key, in: fullRange, options: []) { value, range, stop in
        guard value != nil else { return }
        matchedRange = range
        stop.pointee = true
    }

    return matchedRange
}

private func makeTemporaryTestImage() throws -> URL {
    try makeTemporaryTestImage(fileName: "\(UUID().uuidString).png")
}

private func makeTemporaryTestImage(fileName: String) throws -> URL {
    try makeTemporaryTestImage(
        in: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        fileName: fileName
    )
}

private func makeTemporaryTestImage(fileName: String, size: NSSize) throws -> URL {
    try makeTemporaryTestImage(
        in: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        fileName: fileName,
        size: size
    )
}

private func makeTemporaryTestImage(in directoryURL: URL, fileName: String) throws -> URL {
    try makeTemporaryTestImage(in: directoryURL, fileName: fileName, size: NSSize(width: 120, height: 60))
}

private func makeTemporaryTestImage(in directoryURL: URL, fileName: String, size: NSSize) throws -> URL {
    let url = directoryURL.appendingPathComponent(fileName)
    let image = NSImage(size: size)

    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw CocoaError(.fileWriteUnknown)
    }

    try pngData.write(to: url, options: .atomic)
    return url
}

private func temporaryDirectoryURL() -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

private func bitmapImageRep(for image: NSImage) -> NSBitmapImageRep? {
    if let existing = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
        return existing
    }

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff)
    else {
        return nil
    }

    return bitmap
}

private func bitmapContainsBluePixels(_ bitmap: NSBitmapImageRep) -> Bool {
    for x in 0..<bitmap.pixelsWide {
        for y in 0..<bitmap.pixelsHigh {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }

            if color.blueComponent > 0.5 && color.blueComponent > color.redComponent + 0.1 {
                return true
            }
        }
    }

    return false
}

private func pdfDocumentContainsBluePixels(_ pdfDocument: PDFDocument) -> Bool {
    for pageIndex in 0..<pdfDocument.pageCount {
        guard let page = pdfDocument.page(at: pageIndex) else {
            continue
        }

        let thumbnail = page.thumbnail(of: NSSize(width: 595, height: 842), for: .mediaBox)
        guard let bitmap = bitmapImageRep(for: thumbnail) else {
            continue
        }

        if bitmapContainsBluePixels(bitmap) {
            return true
        }
    }

    return false
}

@MainActor
private func paragraphStyle(in textView: NSTextView, matching substring: String) -> NSParagraphStyle {
    let nsString = textView.string as NSString
    let range = nsString.range(of: substring)
    return textView.textStorage?.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle ?? NSParagraphStyle.default
}

private func attributedParagraphStyle(in attributedString: NSAttributedString, matching substring: String) -> NSParagraphStyle {
    let nsString = attributedString.string as NSString
    let range = nsString.range(of: substring)
    return attributedString.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle ?? NSParagraphStyle.default
}

private func fontTraits(of font: NSFont) -> NSFontTraitMask {
    NSFontManager.shared.traits(of: font)
}

@MainActor
private func link(in textView: NSTextView, matching substring: String) -> URL? {
    let nsString = textView.string as NSString
    let range = nsString.range(of: substring)
    let value = textView.textStorage?.attribute(.link, at: range.location, effectiveRange: nil)
    return MarkdownTextStyler.url(from: value)
}

@MainActor
private func makeMarkdownTextView() -> MarkdownTextView {
    let textStorage = NSTextStorage()
    let layoutManager = MarkdownLayoutManager()
    let textContainer = NSTextContainer(size: NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude))

    textStorage.addLayoutManager(layoutManager)
    layoutManager.addTextContainer(textContainer)

    let textView = MarkdownTextView(
        frame: NSRect(x: 0, y: 0, width: 600, height: 400),
        textContainer: textContainer
    )
    textView.textContainerInset = NSSize(width: 18, height: 16)
    textView.textContainer?.widthTracksTextView = true
    return textView
}

private func functionalRecipeMarkdown(absoluteImagePath: String) -> String {
    """
    # Recette fonctionnelle complete

    Ce document sert de recette manuelle pour tester l'editeur, le rendu live et l'export PDF.  
    La ligne ci-dessus doit produire un saut de ligne Markdown visible dans l'editeur et dans le PDF.

    ## Checklist rapide

    - Ouvrir ce fichier dans l'application.
    - Verifier le rendu live des titres, emphases, indices, exposants, listes, citations et blocs de code.
    - Exporter en PDF avec `Option + Commande + P`.
    - Verifier que la premiere ligne `#` est rendue comme titre d'article dans le PDF.
    - Verifier que les images s'affichent dans le PDF au lieu du texte alternatif.
    - Tester `Commande + clic` sur un lien.
    - Tester le clic sur le chemin d'une image pour la remplacer.
    - Tester `Shift + Entree` sur une ligne de paragraphe.
    - Tester la continuation automatique des listes avec `Entree`.

    # Titre de l'article

    Paragraphe d'introduction en texte courant, taille 12, Baskerville, interligne 1,5 au rendu PDF.

    # Titre niveau 1

    Texte sous un titre H1.

    ## Titre niveau 2

    Texte sous un titre H2.

    ### Titre niveau 3

    Texte sous un titre H3.

    #### Titre niveau 4

    Texte sous un titre H4.

    ##### Titre niveau 5

    Texte sous un titre H5.

    ###### Titre niveau 6

    Texte sous un titre H6.

    Titre Setext niveau 1
    =====================

    Texte sous un titre Setext niveau 1.

    Titre Setext niveau 2
    ---------------------

    Texte sous un titre Setext niveau 2.

    ## Emphases et caracteres

    Texte en *italique* avec asterisques.

    Texte en _italique_ avec underscores.

    Texte en **gras** avec doubles asterisques.

    Texte en __gras__ avec doubles underscores.

    Texte en ***gras italique*** avec triples asterisques.

    Texte avec `code inline`, formule H~2~O et puissance x^2^.

    Texte avec caracteres echappes : \\*ceci ne doit pas etre en italique\\*.

    ## Liens

    Lien inline : [OpenAI](https://openai.com/)

    Lien de reference : [OpenAI reference][openai]

    Autolien : <https://openai.com/>

    ## Citation

    > Ceci est une citation.
    > Elle tient sur plusieurs lignes.
    >
    > Deuxieme paragraphe de citation.

    ## Liste non ordonnee

    - Premier element
    - Deuxieme element avec **gras**
    - Troisieme element avec *italique*

    ## Liste ordonnee

    1. Premier element
    2. Deuxieme element
    3. Troisieme element

    ## Bloc de code fence

    ```swift
    struct Exemple {
        let message = "Bonjour"
    }
    ```

    ## Bloc de code indente

        let valeur = 42
        print(valeur)

    ## Bloc LaTeX

    $$
    x^2 + y^2 = z^2
    $$

    ## Ligne horizontale

    Le separateur ci-dessous doit devenir une vraie barre pleine largeur dans le PDF.

    ---

    ## Images

    Image absolue de test :

    ![Texte alternatif](\(absoluteImagePath))

    Image absolue avec titre optionnel :

    ![Texte alternatif](\(absoluteImagePath) "Titre optionnel")

    Image relative de test :

    Cette ligne ne fonctionnera que si `ChatGPT Image 1 mai 2026, 21_38_12.png` est copie a cote de ce fichier.

    ![Texte alternatif](ChatGPT Image 1 mai 2026, 21_38_12.png)

    ## Tests manuels de toolbar

    Selectionner la phrase suivante et tester les boutons `Gras`, `Italique`, `Code inline`, `Indice`, `Exposant` :

    Phrase de test a formatter.

    Selectionner la ligne suivante et tester le menu `Titre` :

    Ligne de test de titre

    Selectionner le paragraphe suivant et tester `Citation`, `Liste non ordonnee`, `Liste ordonnee`, `Bloc LaTeX`, `Bloc de code` :

    Paragraphe de test de transformation de bloc.

    ## Tests manuels d'insertion

    Placer le curseur dans la ligne suivante et tester `Lien`, `Image`, `Saut de ligne` et `HR` :

    Zone de test d'insertion

    ## Tests manuels de continuation de liste

    - Placer le curseur a la fin de cette ligne puis appuyer sur Entree
    -

    1. Placer le curseur a la fin de cette ligne puis appuyer sur Entree
    2.

    ## Tests manuels de liens et images cliquables

    Faire `Commande + clic` sur ce lien : [Documentation OpenAI](https://openai.com/)

    Cliquer sur le chemin de cette image pour ouvrir le selecteur natif :

    ![Image a remplacer](\(absoluteImagePath))

    [openai]: https://openai.com/ "OpenAI"
    """
}
