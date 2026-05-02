//
//  MarkdownFormattingActions.swift
//  Markdown
//
//  Created by Stéphane on 01/05/2026.
//

import AppKit
import SwiftUI

enum MarkdownFormattingToolbarLabel {
    case text(String)
    case symbol(String)
    case boldText(String)
    case italicText(String)
    case monospaced(String)
}

struct MarkdownFormattingAction: Identifiable {
    let id: String
    let toolbarLabel: MarkdownFormattingToolbarLabel
    let menuTitle: String
    let selector: Selector
    let help: String
    let keyboardShortcut: KeyEquivalent?
    let keyboardModifiers: EventModifiers

    init(
        id: String,
        toolbarLabel: MarkdownFormattingToolbarLabel,
        menuTitle: String,
        selector: Selector,
        help: String,
        keyboardShortcut: KeyEquivalent? = nil,
        keyboardModifiers: EventModifiers = .command
    ) {
        self.id = id
        self.toolbarLabel = toolbarLabel
        self.menuTitle = menuTitle
        self.selector = selector
        self.help = help
        self.keyboardShortcut = keyboardShortcut
        self.keyboardModifiers = keyboardModifiers
    }
}

enum MarkdownFormattingCatalog {
    static let writingToolsAction = MarkdownFormattingAction(
        id: "writing-tools",
        toolbarLabel: .symbol("apple.intelligence"),
        menuTitle: "Writing Tools",
        selector: #selector(NSResponder.showWritingTools(_:)),
        help: "Ouvre les Writing Tools d'Apple Intelligence sur la sélection courante."
    )

    static let exportPDFAction = MarkdownFormattingAction(
        id: "export-pdf",
        toolbarLabel: .text("PDF"),
        menuTitle: "Exporter en PDF…",
        selector: #selector(MarkdownTextView.exportPDF(_:)),
        help: "Exporte le document courant en PDF. Raccourci : ⌘⇧E.",
        keyboardShortcut: "E",
        keyboardModifiers: [.command, .shift]
    )

    static let characterActions: [MarkdownFormattingAction] = [
        MarkdownFormattingAction(
            id: "bold",
            toolbarLabel: .boldText("G"),
            menuTitle: "Gras",
            selector: #selector(MarkdownTextView.applyBoldMarkup(_:)),
            help: "Entoure la sélection avec **gras**.",
            keyboardShortcut: "b"
        ),
        MarkdownFormattingAction(
            id: "italic",
            toolbarLabel: .italicText("I"),
            menuTitle: "Italique",
            selector: #selector(MarkdownTextView.applyItalicMarkup(_:)),
            help: "Entoure la sélection avec *italique*.",
            keyboardShortcut: "i"
        ),
        MarkdownFormattingAction(
            id: "inline-code",
            toolbarLabel: .symbol("chevron.left.forwardslash.chevron.right"),
            menuTitle: "Code inline",
            selector: #selector(MarkdownTextView.applyInlineCodeMarkup(_:)),
            help: "Entoure la sélection avec des backticks.",
            keyboardShortcut: "c",
            keyboardModifiers: [.command, .control]
        ),
        MarkdownFormattingAction(
            id: "subscript",
            toolbarLabel: .symbol("textformat.subscript"),
            menuTitle: "Indice",
            selector: #selector(MarkdownTextView.applySubscriptMarkup(_:)),
            help: "Entoure la sélection avec ~indice~.",
            keyboardShortcut: "-",
            keyboardModifiers: [.command, .control]
        ),
        MarkdownFormattingAction(
            id: "superscript",
            toolbarLabel: .symbol("textformat.superscript"),
            menuTitle: "Exposant",
            selector: #selector(MarkdownTextView.applySuperscriptMarkup(_:)),
            help: "Entoure la sélection avec ^exposant^.",
            keyboardShortcut: "+",
            keyboardModifiers: [.command, .control]
        )
    ]

    static let headingActions: [MarkdownFormattingAction] = [
        MarkdownFormattingAction(
            id: "heading-1",
            toolbarLabel: .text("H1"),
            menuTitle: "Titre H1",
            selector: #selector(MarkdownTextView.applyHeading1Markup(_:)),
            help: "Préfixe la ligne avec #.",
            keyboardShortcut: "1",
            keyboardModifiers: [.command, .option]
        ),
        MarkdownFormattingAction(
            id: "heading-2",
            toolbarLabel: .text("H2"),
            menuTitle: "Titre H2",
            selector: #selector(MarkdownTextView.applyHeading2Markup(_:)),
            help: "Préfixe la ligne avec ##.",
            keyboardShortcut: "2",
            keyboardModifiers: [.command, .option]
        ),
        MarkdownFormattingAction(
            id: "heading-3",
            toolbarLabel: .text("H3"),
            menuTitle: "Titre H3",
            selector: #selector(MarkdownTextView.applyHeading3Markup(_:)),
            help: "Préfixe la ligne avec ###.",
            keyboardShortcut: "3",
            keyboardModifiers: [.command, .option]
        ),
        MarkdownFormattingAction(
            id: "heading-4",
            toolbarLabel: .text("H4"),
            menuTitle: "Titre H4",
            selector: #selector(MarkdownTextView.applyHeading4Markup(_:)),
            help: "Préfixe la ligne avec ####.",
            keyboardShortcut: "4",
            keyboardModifiers: [.command, .option]
        ),
        MarkdownFormattingAction(
            id: "heading-5",
            toolbarLabel: .text("H5"),
            menuTitle: "Titre H5",
            selector: #selector(MarkdownTextView.applyHeading5Markup(_:)),
            help: "Préfixe la ligne avec #####.",
            keyboardShortcut: "5",
            keyboardModifiers: [.command, .option]
        ),
        MarkdownFormattingAction(
            id: "heading-6",
            toolbarLabel: .text("H6"),
            menuTitle: "Titre H6",
            selector: #selector(MarkdownTextView.applyHeading6Markup(_:)),
            help: "Préfixe la ligne avec ######.",
            keyboardShortcut: "6",
            keyboardModifiers: [.command, .option]
        )
    ]

    static let paragraphActions: [MarkdownFormattingAction] = [
        MarkdownFormattingAction(
            id: "blockquote",
            toolbarLabel: .symbol("text.quote"),
            menuTitle: "Citation",
            selector: #selector(MarkdownTextView.applyBlockquoteMarkup(_:)),
            help: "Préfixe les lignes avec >.",
            keyboardShortcut: "q",
            keyboardModifiers: [.command, .option]
        ),
        MarkdownFormattingAction(
            id: "unordered-list",
            toolbarLabel: .symbol("list.bullet"),
            menuTitle: "Liste non ordonnée",
            selector: #selector(MarkdownTextView.applyDashListMarkup(_:)),
            help: "Préfixe les lignes avec -.",
            keyboardShortcut: "8",
            keyboardModifiers: [.command, .shift]
        ),
        MarkdownFormattingAction(
            id: "ordered-list",
            toolbarLabel: .symbol("list.number"),
            menuTitle: "Liste ordonnée",
            selector: #selector(MarkdownTextView.applyOrderedListMarkup(_:)),
            help: "Numérote les lignes.",
            keyboardShortcut: "7",
            keyboardModifiers: [.command, .shift]
        ),
        MarkdownFormattingAction(
            id: "latex-block",
            toolbarLabel: .monospaced("f(x)"),
            menuTitle: "Bloc LaTeX",
            selector: #selector(MarkdownTextView.applyLatexBlockMarkup(_:)),
            help: "Entoure la sélection avec un bloc $$.",
            keyboardShortcut: "l",
            keyboardModifiers: [.command, .option]
        ),
        MarkdownFormattingAction(
            id: "code-block",
            toolbarLabel: .monospaced(">_"),
            menuTitle: "Bloc de code",
            selector: #selector(MarkdownTextView.applyFencedCodeBlockMarkup(_:)),
            help: "Entoure la sélection avec un bloc ```.",
            keyboardShortcut: "c",
            keyboardModifiers: [.command, .option]
        )
    ]

    static let insertionActions: [MarkdownFormattingAction] = [
        MarkdownFormattingAction(
            id: "link",
            toolbarLabel: .symbol("link"),
            menuTitle: "Lien simple",
            selector: #selector(MarkdownTextView.applyInlineLinkMarkup(_:)),
            help: "Insère un lien Markdown [texte](url).",
            keyboardShortcut: "k"
        ),
        MarkdownFormattingAction(
            id: "image",
            toolbarLabel: .symbol("photo"),
            menuTitle: "Image",
            selector: #selector(MarkdownTextView.applyInlineImageMarkup(_:)),
            help: "Insère une image Markdown ![alt](chemin).",
            keyboardShortcut: "i",
            keyboardModifiers: [.command, .option]
        ),
        MarkdownFormattingAction(
            id: "line-break",
            toolbarLabel: .symbol("arrow.turn.down.left"),
            menuTitle: "Saut de ligne",
            selector: #selector(MarkdownTextView.applyHardLineBreakMarkup(_:)),
            help: "Insère un saut de ligne Markdown avec deux espaces en fin de ligne.",
            keyboardShortcut: .return,
            keyboardModifiers: [.shift]
        ),
        MarkdownFormattingAction(
            id: "horizontal-rule",
            toolbarLabel: .text("HR"),
            menuTitle: "Ligne horizontale",
            selector: #selector(MarkdownTextView.applyHorizontalRuleMarkup(_:)),
            help: "Insère une ligne horizontale ---.",
            keyboardShortcut: "r",
            keyboardModifiers: [.command, .option]
        )
    ]
}
