//
//  MarkdownApp.swift
//  Markdown
//
//  Created by Stéphane on 22/04/2026.
//

import SwiftUI

/// App entry point: wires the document system, the editor view and custom commands.
@main
struct MarkdownApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(
                editor: file.$document.editor,
                documentURL: file.fileURL
            )
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            DocumentCommands()
            FormattingCommands()
        }
    }
}
