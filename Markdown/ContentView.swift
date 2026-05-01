//
//  ContentView.swift
//  Markdown
//
//  Created by Stéphane on 22/04/2026.
//

import SwiftUI

/// Minimal editor view bound to the current document state.
struct ContentView: View {
    @Binding var editor: EditorState

    var body: some View {
        TextEditor(text: $editor.text)
            .font(.system(size: 14, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
