//
//  MarkdownLayoutManager.swift
//  Markdown
//
//  Created by Stéphane on 02/05/2026.
//

import AppKit

struct MarkdownHardLineBreakMarker: Equatable {
    let spacesRange: NSRange
}

final class MarkdownLayoutManager: NSLayoutManager {
    var hardLineBreakMarkers: [MarkdownHardLineBreakMarker] = [] {
        didSet {
            invalidateMarkers(oldValue + hardLineBreakMarkers)
        }
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        drawHardLineBreakSymbols(forGlyphRange: glyphsToShow, at: origin)
    }

    private func invalidateMarkers(_ markers: [MarkdownHardLineBreakMarker]) {
        for marker in markers {
            invalidateDisplay(forCharacterRange: marker.spacesRange)
        }
    }

    private func drawHardLineBreakSymbols(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let symbol = "↩" as NSString

        for marker in hardLineBreakMarkers {
            let glyphRange = glyphRange(forCharacterRange: marker.spacesRange, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { continue }

            let lastGlyphIndex = NSMaxRange(glyphRange) - 1
            guard NSLocationInRange(lastGlyphIndex, glyphsToShow) else { continue }
            guard let textContainer = textContainer(forGlyphAt: lastGlyphIndex, effectiveRange: nil) else { continue }

            let glyphRect = boundingRect(
                forGlyphRange: NSRange(location: lastGlyphIndex, length: 1),
                in: textContainer
            )
            let symbolSize = symbol.size(withAttributes: attributes)
            let symbolPoint = NSPoint(
                x: origin.x + glyphRect.maxX + 2,
                y: origin.y + glyphRect.minY + max(0, (glyphRect.height - symbolSize.height) / 2 - 1)
            )

            symbol.draw(at: symbolPoint, withAttributes: attributes)
        }
    }
}
