//
//  MarkdownDocument.swift
//  Markdown
//
//  Created by Stéphane on 01/05/2026.
//

import SwiftUI
import UniformTypeIdentifiers

// The app reads and writes plain text and Markdown files.
private let markdownContentType = UTType(filenameExtension: "md") ?? .plainText

/// Bridges the editor state to the macOS document system.
struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [markdownContentType, .plainText]
    }

    // `EditorState` stays focused on UI editing state.
    var editor: EditorState

    init(editor: EditorState = EditorState()) {
        self.editor = editor
    }

    init(data: Data) {
        editor = EditorState(text: String(decoding: data, as: UTF8.self))
    }

    init(configuration: ReadConfiguration) throws {
        self.init(data: configuration.file.regularFileContents ?? Data())
    }

    func serializedData() -> Data {
        Data(editor.text.utf8)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: serializedData())
    }
}
