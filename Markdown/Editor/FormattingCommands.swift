//
//  FormattingCommands.swift
//  Markdown
//
//  Created by Stéphane on 01/05/2026.
//

import SwiftUI

struct FormattingCommands: Commands {
    var body: some Commands {
        CommandMenu("Format") {
            Section("Paragraphes") {
                FormattingCommandButtons(
                    actions: MarkdownFormattingCatalog.headingActions + MarkdownFormattingCatalog.paragraphActions
                )
            }

            Section("Caractères") {
                FormattingCommandButtons(actions: MarkdownFormattingCatalog.characterActions)
            }

            Section("Insertion") {
                FormattingCommandButtons(actions: MarkdownFormattingCatalog.insertionActions)
            }
        }
    }
}

private struct FormattingCommandButtons: View {
    let actions: [MarkdownFormattingAction]

    var body: some View {
        ForEach(actions) { action in
            if let keyboardShortcut = action.keyboardShortcut {
                Button(action.menuTitle) {
                    MarkdownEditorActionDispatcher.send(action.selector)
                }
                .keyboardShortcut(keyboardShortcut, modifiers: action.keyboardModifiers)
            } else {
                Button(action.menuTitle) {
                    MarkdownEditorActionDispatcher.send(action.selector)
                }
            }
        }
    }
}
