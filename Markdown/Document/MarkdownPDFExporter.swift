//
//  MarkdownPDFExporter.swift
//  Markdown
//
//  Created by Stéphane on 02/05/2026.
//

import AppKit
import UniformTypeIdentifiers

/// Presents a save panel and writes a rendered PDF for the current editor contents.
@MainActor
enum MarkdownPDFExporter {
    static func export(markdown: String, from textView: NSView) {
        let documentURL = currentDocumentURL(for: textView)
        let window = textView.window
        MarkdownPDFDiagnostics.record(
            "export requested documentURL=\(documentURL?.path ?? "nil") markdownLength=\(markdown.utf16.count)"
        )

        DispatchQueue.main.async {
            Task { @MainActor in
                await performExport(markdown: markdown, documentURL: documentURL, window: window)
            }
        }
    }

    private static func performExport(markdown: String, documentURL: URL?, window: NSWindow?) async {
        let savePanel = configuredSavePanel(for: documentURL)

        do {
            MarkdownPDFDiagnostics.record("presenting save panel")
            guard let outputURL = await MarkdownPanelPresenter.present(savePanel, for: window) else {
                MarkdownPDFDiagnostics.record("save panel cancelled")
                return
            }

            MarkdownPDFDiagnostics.record("save panel accepted outputURL=\(outputURL.path)")
            let baseURL = documentURL?.standardizedFileURL.deletingLastPathComponent() ??
                outputURL.standardizedFileURL.deletingLastPathComponent()
            MarkdownPDFDiagnostics.record("authorizing image access baseURL=\(baseURL.path)")
            guard let accessSession = await prepareImageAccessSession(for: markdown, baseURL: baseURL, window: window) else {
                MarkdownPDFDiagnostics.record("image access denied or cancelled")
                return
            }
            defer {
                accessSession.invalidate()
            }

            MarkdownPDFDiagnostics.record("rendering pdf started")
            try MarkdownPDFRenderer.writePDF(for: markdown, to: outputURL, baseURL: baseURL)
            let fileSize = ((try? FileManager.default.attributesOfItem(atPath: outputURL.path))?[.size] as? NSNumber)?.intValue
            MarkdownPDFDiagnostics.record("rendering pdf completed bytes=\(fileSize ?? 0)")
        } catch {
            MarkdownPDFDiagnostics.record("rendering pdf failed error=\(error.localizedDescription)")
            NSApp.presentError(error)
        }
    }

    private static func configuredSavePanel(for documentURL: URL?) -> NSSavePanel {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.prompt = "Exporter"
        savePanel.nameFieldStringValue = suggestedFileName(for: documentURL)

        if let fileURL = documentURL {
            savePanel.directoryURL = fileURL.deletingLastPathComponent()
        }

        return savePanel
    }

    private static func suggestedFileName(for documentURL: URL?) -> String {
        if let fileURL = documentURL {
            return fileURL.standardizedFileURL.deletingPathExtension().lastPathComponent + ".pdf"
        }

        return "Document.pdf"
    }

    private static func currentDocumentURL(for textView: NSView) -> URL? {
        if let markdownTextView = textView as? MarkdownTextView, let fileURL = markdownTextView.documentURL {
            return fileURL.standardizedFileURL
        }

        if let fileURL = textView.window?.windowController?.document?.fileURL?.standardizedFileURL {
            return fileURL
        }

        if let fileURL = textView.window?.representedURL {
            return fileURL.standardizedFileURL
        }

        return NSDocumentController.shared.currentDocument?.fileURL?.standardizedFileURL
    }

    private static func prepareImageAccessSession(
        for markdown: String,
        baseURL: URL,
        window: NSWindow?
    ) async -> MarkdownSecurityScopedAccessSession? {
        await MarkdownFileAccess.prepareAccessSession(
            for: MarkdownPDFRenderer.localImageURLs(in: markdown, baseURL: baseURL),
            suggestedDirectoryURL: baseURL,
            presentingWindow: window
        )
    }
}

@MainActor
enum MarkdownPanelPresenter {
    static func present(_ panel: NSSavePanel, for window: NSWindow?) async -> URL? {
        if let window {
            let response = await withCheckedContinuation { continuation in
                panel.beginSheetModal(for: window) { response in
                    continuation.resume(returning: response)
                }
            }

            guard response == .OK else { return nil }
            return panel.url
        }

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}
