//
//  MarkdownTests.swift
//  MarkdownTests
//
//  Created by Stéphane on 22/04/2026.
//

import Foundation
import Testing
@testable import Markdown

/// Unit tests for the document read/write layer.
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
}
