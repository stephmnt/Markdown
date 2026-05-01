//
//  DocumentCommands.swift
//  Markdown
//
//  Created by Codex on 01/05/2026.
//

import AppKit
import SwiftUI

/// Replaces the default save menu so shortcuts map to the expected document actions.
struct DocumentCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Enregistrer") {
                perform(#selector(NSDocument.save(_:)))
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Enregistrer sous…") {
                perform(#selector(NSDocument.saveAs(_:)))
            }
            .keyboardShortcut("S", modifiers: [.command, .shift])

            Divider()

            Button("Dupliquer") {
                perform(#selector(NSDocument.duplicate(_:)))
            }
        }
    }

    private func perform(_ action: Selector) {
        // Forward the action to the currently focused document window.
        NSApp.sendAction(action, to: nil, from: nil)
    }
}
