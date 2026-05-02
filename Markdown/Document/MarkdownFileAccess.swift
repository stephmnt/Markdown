//
//  MarkdownFileAccess.swift
//  Markdown
//
//  Created by Stéphane on 02/05/2026.
//

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

final class MarkdownSecurityScopedAccessSession {
    private let stateLock = NSLock()
    private var startedScopeURLs: [URL] = []

    init(scopeURLs: [URL]) {
        let uniqueScopeURLs = Array(
            Dictionary(
                uniqueKeysWithValues: scopeURLs.map { ($0.standardizedFileURL.path, $0.standardizedFileURL) }
            ).values
        )

        for scopeURL in uniqueScopeURLs where scopeURL.isFileURL {
            guard scopeURL.startAccessingSecurityScopedResource() else {
                MarkdownPDFDiagnostics.record("security scope start failed url=\(scopeURL.path)")
                continue
            }

            startedScopeURLs.append(scopeURL)
        }
    }

    func invalidate() {
        let scopeURLsToStop = withStateLock { () -> [URL] in
            let scopeURLs = startedScopeURLs
            startedScopeURLs.removeAll()
            return scopeURLs
        }

        for scopeURL in scopeURLsToStop.reversed() {
            scopeURL.stopAccessingSecurityScopedResource()
        }
    }

    deinit {
        invalidate()
    }

    private func withStateLock<T>(_ work: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return work()
    }
}

/// Persists security-scoped access to user-selected image folders so PDF export can reopen nested images later.
enum MarkdownFileAccess {
    private static let bookmarksDefaultsKey = "MarkdownSecurityScopedImageBookmarks"
    private static let stateLock = NSLock()
    private static var sessionScopedURLs: [String: URL] = [:]

    static func registerAccess(to url: URL) {
        let securityScopedURL = url
        let standardizedURL = securityScopedURL.standardizedFileURL
        guard standardizedURL.isFileURL else { return }

        do {
            let bookmark = try securityScopedURL.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            withStateLock {
                sessionScopedURLs[standardizedURL.path] = securityScopedURL
                var bookmarks = storedBookmarksUnlocked()
                bookmarks[standardizedURL.path] = bookmark
                UserDefaults.standard.set(bookmarks, forKey: bookmarksDefaultsKey)
            }
        } catch {}
    }

    static func canLoadImage(at url: URL) -> Bool {
        withTemporaryAccess(to: url) { accessibleURL in
            canReadFile(at: accessibleURL)
        }
    }

    static func loadImage(at url: URL, maximumPixelSize: Int? = nil) -> NSImage? {
        withTemporaryAccess(to: url) { accessibleURL in
            guard canReadFile(at: accessibleURL) else {
                MarkdownPDFDiagnostics.record("image read check failed url=\(accessibleURL.path)")
                return nil
            }

            return decodedImage(at: accessibleURL, maximumPixelSize: maximumPixelSize)
        }
    }

    @MainActor
    static func prepareAccessSession(
        for urls: [URL],
        suggestedDirectoryURL: URL? = nil,
        presentingWindow: NSWindow? = nil
    ) async -> MarkdownSecurityScopedAccessSession? {
        purgeInvalidStoredBookmarks()

        let normalizedURLs = normalizedFileURLs(from: urls)
        var plan = accessPlan(for: normalizedURLs)
        MarkdownPDFDiagnostics.record(
            "image access check totalURLs=\(normalizedURLs.count) unresolvedURLs=\(plan.unresolvedURLs.count)"
        )

        for url in plan.unresolvedURLs {
            MarkdownPDFDiagnostics.record("unresolved image url=\(url.path)")
        }

        if !plan.unresolvedURLs.isEmpty {
            let suggestedDirectory = suggestedAccessDirectory(
                for: plan.unresolvedURLs,
                preferredDirectoryURL: suggestedDirectoryURL
            )
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Autoriser"
            panel.message = accessRequestMessage(for: plan.unresolvedURLs.count)

            if let suggestedDirectory {
                panel.directoryURL = suggestedDirectory.deletingLastPathComponent()
                panel.nameFieldStringValue = suggestedDirectory.lastPathComponent
                MarkdownPDFDiagnostics.record("suggested access directory=\(suggestedDirectory.path)")
            }

            guard let selectedURL = await MarkdownPanelPresenter.present(panel, for: presentingWindow)?.standardizedFileURL else {
                MarkdownPDFDiagnostics.record("image access panel cancelled")
                return nil
            }

            MarkdownPDFDiagnostics.record("image access selected directory=\(selectedURL.path)")
            guard plan.unresolvedURLs.allSatisfy({ directory(selectedURL, contains: $0) }) else {
                MarkdownPDFDiagnostics.record("selected directory does not cover every unresolved image")
                return nil
            }

            registerAccess(to: selectedURL)
            plan = accessPlan(for: normalizedURLs)
        }

        guard plan.unresolvedURLs.isEmpty else {
            MarkdownPDFDiagnostics.record("image access resolution result=false")
            return nil
        }

        let accessSession = MarkdownSecurityScopedAccessSession(scopeURLs: plan.scopeURLs)
        MarkdownPDFDiagnostics.record(
            "image access resolution result=true scopeCount=\(plan.scopeURLs.count)"
        )
        return accessSession
    }

    private static func withTemporaryAccess<T>(to url: URL, _ work: (URL) -> T) -> T {
        let standardizedURL = url.standardizedFileURL

        if canReadFile(at: standardizedURL, logFailures: false) {
            return work(standardizedURL)
        }

        if let scopeURL = resolvedAccessScopeURL(for: standardizedURL) {
            let didStartAccessing = scopeURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    scopeURL.stopAccessingSecurityScopedResource()
                }
            }
            return work(standardizedURL)
        }

        return work(standardizedURL)
    }

    private static func resolvedAccessScopeURL(for url: URL) -> URL? {
        for path in candidateScopePaths(for: url.standardizedFileURL) {
            if let scopeURL = resolvedStoredURL(forPath: path) {
                return scopeURL
            }
        }

        return nil
    }

    private static func resolvedStoredURL(forPath path: String) -> URL? {
        if let sessionURL = withStateLock({ sessionScopedURLs[path] }) {
            return sessionURL
        }

        guard let bookmarkData = withStateLock({ storedBookmarksUnlocked()[path] }) else {
            return nil
        }

        do {
            var isStale = false
            let bookmarkedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ).standardizedFileURL

            if isStale {
                registerAccess(to: bookmarkedURL)
            }

            return bookmarkedURL
        } catch {
            removeStoredAccess(forPath: path)
            return nil
        }
    }

    private static func candidateScopePaths(for url: URL) -> [String] {
        var paths: [String] = []
        var currentURL = url.standardizedFileURL
        var seenPaths: Set<String> = []

        while true {
            let currentPath = currentURL.path
            guard !currentPath.isEmpty else {
                MarkdownPDFDiagnostics.record("candidate scope traversal stopped for empty path url=\(currentURL.absoluteString)")
                break
            }

            guard seenPaths.insert(currentPath).inserted else {
                MarkdownPDFDiagnostics.record(
                    "candidate scope traversal loop detected url=\(currentURL.absoluteString)"
                )
                break
            }

            paths.append(currentPath)

            let parentURL = currentURL.deletingLastPathComponent().standardizedFileURL
            if parentURL.path == currentPath {
                break
            }

            currentURL = parentURL
        }

        return paths
    }

    private static func storedBookmarksUnlocked() -> [String: Data] {
        guard let rawBookmarks = UserDefaults.standard.dictionary(forKey: bookmarksDefaultsKey) else {
            return [:]
        }

        var bookmarks: [String: Data] = [:]
        for (path, value) in rawBookmarks {
            if let data = value as? Data {
                bookmarks[path] = data
            }
        }
        return bookmarks
    }

    private static func withStateLock<T>(_ work: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return work()
    }

    private static func normalizedFileURLs(from urls: [URL]) -> [URL] {
        var normalizedURLs: [URL] = []
        var seenPaths: Set<String> = []

        for url in urls.map(\.standardizedFileURL) where url.isFileURL {
            guard seenPaths.insert(url.path).inserted else { continue }
            normalizedURLs.append(url)
        }

        return normalizedURLs
    }

    private static func accessPlan(for urls: [URL]) -> MarkdownFileAccessPlan {
        var unresolvedURLs: [URL] = []
        var scopeURLsByPath: [String: URL] = [:]

        for url in urls {
            switch accessResolution(for: url) {
            case .direct, .missing:
                continue

            case let .scoped(scopeURL):
                scopeURLsByPath[scopeURL.standardizedFileURL.path] = scopeURL.standardizedFileURL

            case .unresolved:
                unresolvedURLs.append(url)
            }
        }

        return MarkdownFileAccessPlan(
            unresolvedURLs: unresolvedURLs,
            scopeURLs: Array(scopeURLsByPath.values)
        )
    }

    private static func accessResolution(for url: URL) -> MarkdownFileAccessResolution {
        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.isFileURL else { return .direct }

        switch fileReadabilityStatus(at: standardizedURL, logFailures: false) {
        case .readable:
            return .direct

        case .missing:
            MarkdownPDFDiagnostics.record("image file missing url=\(standardizedURL.path)")
            return .missing

        case .noPermission, .unavailable:
            for path in candidateScopePaths(for: standardizedURL) {
                guard let scopeURL = resolvedStoredURL(forPath: path) else {
                    continue
                }

                let accessSession = MarkdownSecurityScopedAccessSession(scopeURLs: [scopeURL])
                defer {
                    accessSession.invalidate()
                }

                switch fileReadabilityStatus(at: standardizedURL, logFailures: false) {
                case .readable:
                    return .scoped(scopeURL)

                case .missing:
                    MarkdownPDFDiagnostics.record("image file missing url=\(standardizedURL.path)")
                    return .missing

                case .noPermission, .unavailable:
                    MarkdownPDFDiagnostics.record(
                        "stored security scope unusable scopeURL=\(scopeURL.path) targetURL=\(standardizedURL.path)"
                    )
                    removeStoredAccess(forPath: path)
                }
            }

            MarkdownPDFDiagnostics.record("missing security scope for image url=\(standardizedURL.path)")
            return .unresolved
        }
    }

    private static func suggestedAccessDirectory(
        for urls: [URL],
        preferredDirectoryURL: URL?
    ) -> URL? {
        if
            let preferredDirectoryURL,
            urls.allSatisfy({ directory(preferredDirectoryURL, contains: $0) })
        {
            return preferredDirectoryURL.standardizedFileURL
        }

        if let commonAncestorDirectory = commonAncestorDirectory(for: urls) {
            return commonAncestorDirectory
        }

        return urls.first?.deletingLastPathComponent()
    }

    private static func accessRequestMessage(for imageCount: Int) -> String {
        if imageCount == 1 {
            return "Autorisez l’accès à un dossier contenant cette image pour l’export PDF. Vous pouvez choisir son dossier ou un dossier parent plus général."
        }

        return "Autorisez l’accès à un dossier contenant ces images pour l’export PDF. Vous pouvez choisir un dossier parent plus général qui couvre toute votre bibliothèque."
    }

    private static func canReadFile(at url: URL, logFailures: Bool = true) -> Bool {
        switch fileReadabilityStatus(at: url, logFailures: logFailures) {
        case .readable, .missing:
            return true

        case .noPermission, .unavailable:
            return false
        }
    }

    private static func fileReadabilityStatus(
        at url: URL,
        logFailures: Bool
    ) -> MarkdownFileReadabilityStatus {
        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.isFileURL else { return .readable }

        do {
            _ = try coordinatedReadData(at: standardizedURL, maximumByteCount: 1)
            return .readable
        } catch {
            if isMissingFileError(error) {
                return .missing
            }

            if isNoPermissionError(error) {
                if logFailures {
                    MarkdownPDFDiagnostics.record(
                        "file open failed url=\(standardizedURL.path) error=\(error.localizedDescription)"
                    )
                }
                return .noPermission
            }

            if logFailures {
                MarkdownPDFDiagnostics.record(
                    "file open failed url=\(standardizedURL.path) error=\(error.localizedDescription)"
                )
            }
            return .unavailable(error.localizedDescription)
        }
    }

    private static func decodedImage(at url: URL, maximumPixelSize: Int? = nil) -> NSImage? {
        do {
            let data = try coordinatedReadData(at: url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                MarkdownPDFDiagnostics.record("image decode failed url=\(url.path)")
                return nil
            }

            let cgImage = decodeImage(
                from: source,
                maximumPixelSize: maximumPixelSize
            )
            guard let cgImage else {
                MarkdownPDFDiagnostics.record("image decode failed url=\(url.path)")
                return nil
            }

            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        } catch {
            MarkdownPDFDiagnostics.record(
                "image data load failed url=\(url.path) error=\(error.localizedDescription)"
            )
            return nil
        }
    }

    private static func decodeImage(
        from source: CGImageSource,
        maximumPixelSize: Int?
    ) -> CGImage? {
        if let maximumPixelSize {
            let downsampleOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
            ]

            if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) {
                return thumbnail
            }
        }

        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func coordinatedReadData(
        at url: URL,
        maximumByteCount: Int? = nil
    ) throws -> Data {
        var coordinatedData = Data()
        var coordinationError: NSError?
        var readError: Error?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                let handle = try FileHandle(forReadingFrom: coordinatedURL)
                defer {
                    try? handle.close()
                }

                if let maximumByteCount {
                    coordinatedData = try handle.read(upToCount: maximumByteCount) ?? Data()
                } else {
                    coordinatedData = try handle.readToEnd() ?? Data()
                }
            } catch {
                readError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        if let readError {
            throw readError
        }

        return coordinatedData
    }

    private static func isMissingFileError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return
            nsError.code == CocoaError.fileReadNoSuchFile.rawValue ||
            (nsError.domain == NSPOSIXErrorDomain && nsError.code == ENOENT)
    }

    private static func isNoPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return
            nsError.code == CocoaError.fileReadNoPermission.rawValue ||
            (nsError.domain == NSPOSIXErrorDomain && (nsError.code == EACCES || nsError.code == EPERM))
    }

    private static func removeStoredAccess(forPath path: String) {
        withStateLock {
            sessionScopedURLs.removeValue(forKey: path)
            var bookmarks = storedBookmarksUnlocked()
            bookmarks.removeValue(forKey: path)
            UserDefaults.standard.set(bookmarks, forKey: bookmarksDefaultsKey)
        }
    }

    private static func purgeInvalidStoredBookmarks() {
        let storedBookmarks = withStateLock {
            storedBookmarksUnlocked()
        }

        var pathsToRemove: [String] = []
        for (path, bookmarkData) in storedBookmarks {
            do {
                var isStale = false
                let bookmarkedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ).standardizedFileURL

                if isStale {
                    registerAccess(to: bookmarkedURL)
                }
            } catch {
                pathsToRemove.append(path)
            }
        }

        for path in pathsToRemove {
            removeStoredAccess(forPath: path)
        }
    }

    static func sameFileLocation(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.resolvingSymlinksInPath().path == rhs.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func directory(_ directoryURL: URL, contains fileURL: URL) -> Bool {
        let normalizedDirectory = directoryURL.standardizedFileURL.resolvingSymlinksInPath()
        let normalizedFile = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        let directoryComponents = normalizedDirectory.pathComponents
        let fileComponents = normalizedFile.pathComponents

        guard directoryComponents.count <= fileComponents.count else {
            return false
        }

        return zip(directoryComponents, fileComponents).allSatisfy(==)
    }

    static func commonAncestorDirectory(for urls: [URL]) -> URL? {
        let normalizedDirectories = urls
            .map { $0.standardizedFileURL.resolvingSymlinksInPath().deletingLastPathComponent() }

        guard var sharedComponents = normalizedDirectories.first?.pathComponents else {
            return nil
        }

        for directoryURL in normalizedDirectories.dropFirst() {
            let components = directoryURL.pathComponents
            let sharedCount = zip(sharedComponents, components).prefix { $0 == $1 }.count
            sharedComponents = Array(sharedComponents.prefix(sharedCount))

            if sharedComponents.isEmpty {
                return nil
            }
        }

        return url(fromPathComponents: sharedComponents)
    }

    private static func url(fromPathComponents components: [String]) -> URL? {
        guard !components.isEmpty else {
            return nil
        }

        let path = NSString.path(withComponents: components)
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

#if DEBUG
    static func debugSessionURL(for url: URL) -> URL? {
        withStateLock {
            sessionScopedURLs[url.standardizedFileURL.path]
        }
    }

    static func debugAccessScopeURL(for url: URL) -> URL? {
        resolvedAccessScopeURL(for: url.standardizedFileURL)
    }

    static func debugSuggestedAccessDirectory(
        for urls: [URL],
        preferredDirectoryURL: URL? = nil
    ) -> URL? {
        suggestedAccessDirectory(for: urls, preferredDirectoryURL: preferredDirectoryURL)
    }

    static func debugClearSessionURLs() {
        withStateLock {
            sessionScopedURLs.removeAll()
        }
    }

    static func debugRemoveAccess(for url: URL) {
        removeStoredAccess(forPath: url.standardizedFileURL.path)
    }
#endif
}

private struct MarkdownFileAccessPlan {
    var unresolvedURLs: [URL]
    var scopeURLs: [URL]
}

private enum MarkdownFileAccessResolution {
    case direct
    case scoped(URL)
    case missing
    case unresolved
}

private enum MarkdownFileReadabilityStatus {
    case readable
    case missing
    case noPermission
    case unavailable(String)
}
