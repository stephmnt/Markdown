//
//  ContentView.swift
//  Markdown
//
//  Created by Stéphane on 22/04/2026.
//

import SwiftUI

/// Main editor view with a split formatting bar for paragraph, character and insertion actions.
struct ContentView: View {
    @Binding var editor: EditorState
    let documentURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            EditorFormattingBar()
            Divider()

            MarkdownEditor(text: $editor.text, documentURL: documentURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
