//
//  MarkdownPDFDiagnostics.swift
//  Markdown
//
//  Created by Stéphane on 02/05/2026.
//

import Foundation
import os

enum MarkdownPDFDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Markdown",
        category: "PDFExport"
    )

    static var isEnabled: Bool {
#if DEBUG
        true
#else
        ProcessInfo.processInfo.environment["MARKDOWN_PDF_DIAGNOSTICS"] == "1"
            || UserDefaults.standard.bool(forKey: "MarkdownPDFDiagnostics")
#endif
    }

    static func record(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }

        let line = "[MarkdownPDF] \(message())"
        logger.notice("\(line, privacy: .public)")
    }

    static func preview(_ text: String, limit: Int = 96) -> String {
        let flattened = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " | ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard flattened.count > limit else {
            return flattened
        }

        return String(flattened.prefix(limit)) + "..."
    }
}
