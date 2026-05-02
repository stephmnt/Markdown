//
//  EditorFormattingBar.swift
//  Markdown
//
//  Created by Stéphane on 01/05/2026.
//

import SwiftUI

struct EditorFormattingBar: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 18) {
                ParagraphFormattingSection()

                Divider()
                    .frame(height: 56)

                FormattingActionSection(
                    title: "Caractères",
                    actions: MarkdownFormattingCatalog.characterActions
                )

                Divider()
                    .frame(height: 56)

                FormattingActionSection(
                    title: "Insertion",
                    actions: MarkdownFormattingCatalog.insertionActions
                )

                Divider()
                    .frame(height: 56)

                DocumentActionSection()

                Divider()
                    .frame(height: 56)

                VStack(alignment: .leading, spacing: 8) {
                    Text("IA")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    FormattingActionButton(action: MarkdownFormattingCatalog.writingToolsAction)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.thinMaterial)
    }
}

private struct DocumentActionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            FormattingActionButton(action: MarkdownFormattingCatalog.exportPDFAction)
        }
    }
}

private struct ParagraphFormattingSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paragraphes")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 6) {
                HeadingLevelMenu()

                ForEach(MarkdownFormattingCatalog.paragraphActions) { action in
                    FormattingActionButton(action: action)
                }
            }
        }
    }
}

private struct FormattingActionSection: View {
    let title: String
    let actions: [MarkdownFormattingAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 6) {
                ForEach(actions) { action in
                    FormattingActionButton(action: action)
                }
            }
        }
    }
}

private struct HeadingLevelMenu: View {
    var body: some View {
        Menu {
            ForEach(MarkdownFormattingCatalog.headingActions) { action in
                Button(action.menuTitle) {
                    MarkdownEditorActionDispatcher.send(action.selector)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Titre")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(minWidth: 64)
            .fixedSize(horizontal: true, vertical: false)
            .lineLimit(1)
        }
        .buttonStyle(FormattingChipButtonStyle())
        .help("Choisit le niveau de titre en utilisant la syntaxe #.")
    }
}

private struct FormattingActionButton: View {
    let action: MarkdownFormattingAction

    var body: some View {
        Button {
            MarkdownEditorActionDispatcher.send(action.selector)
        } label: {
            toolbarLabel(for: action.toolbarLabel)
                .lineLimit(1)
        }
        .buttonStyle(FormattingChipButtonStyle())
        .help(action.help)
    }

    @ViewBuilder
    private func toolbarLabel(for label: MarkdownFormattingToolbarLabel) -> some View {
        switch label {
        case .text(let value):
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        case .symbol(let systemName):
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
        case .boldText(let value):
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .default))
        case .italicText(let value):
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .default))
                .italic()
        case .monospaced(let value):
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }
}

private struct FormattingChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
    }
}
