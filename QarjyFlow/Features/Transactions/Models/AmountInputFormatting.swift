import Foundation

/// Presentation-only formatting. The draft keeps ungrouped text for exact tiyn parsing.
enum AmountInputFormatting {
    struct Edit {
        let rawText: String
        let displayText: String
        let caretOffset: Int
    }

    private static let groupingSpaces: Set<Character> = [" ", "\u{00A0}", "\u{202F}"]

    static func rawText(from input: String) -> String? {
        var raw = String(input.filter { !groupingSpaces.contains($0) })
        if raw.first == "." || raw.first == "," { raw = "0" + raw }
        let parts = raw.split(whereSeparator: { $0 == "." || $0 == "," })
        guard raw.allSatisfy({ ($0 >= "0" && $0 <= "9") || $0 == "." || $0 == "," }),
              raw.filter({ $0 == "." || $0 == "," }).count <= 1 else { return nil }
        let integer = raw.prefix { $0 != "." && $0 != "," }
        guard integer.count <= 12 else { return nil }
        if parts.count == 2, parts[1].count > 2 { return nil }
        return raw
    }

    static func display(_ raw: String) -> String {
        let integer = raw.prefix { $0 != "." && $0 != "," }
        var formatted = ""
        for (index, digit) in integer.enumerated() {
            if index > 0 && (integer.count - index).isMultiple(of: 3) { formatted.append(" ") }
            formatted.append(digit)
        }
        return formatted + raw.dropFirst(integer.count)
    }

    /// Applies a UIKit UTF-16 edit and maps the caret by meaningful characters,
    /// so regrouping doesn't force the cursor to the end during middle edits.
    static func edit(display current: String, range: NSRange, replacement: String) -> Edit? {
        let source = current as NSString
        guard range.location >= 0, range.length >= 0,
              range.location <= source.length, range.length <= source.length - range.location else { return nil }
        var effectiveRange = range
        if replacement.isEmpty, range.length == 1, range.location > 0,
           groupingSpaces.contains(Character(source.substring(with: range))) {
            // Backspacing a generated space should delete the digit before it,
            // rather than regenerating the space and appearing to do nothing.
            effectiveRange = NSRange(location: range.location - 1, length: 2)
        }
        let candidate = source.replacingCharacters(in: effectiveRange, with: replacement)
        guard let raw = rawText(from: candidate) else { return nil }
        let prefix = source.substring(to: effectiveRange.location) + replacement
        var meaningfulCount = prefix.filter { !groupingSpaces.contains($0) }.count
        let ungroupedCandidate = candidate.filter { !groupingSpaces.contains($0) }
        if ungroupedCandidate.first == "." || ungroupedCandidate.first == "," { meaningfulCount += 1 }
        let formatted = display(raw)
        var caret = 0
        var seen = 0
        for character in formatted {
            if seen >= meaningfulCount { break }
            caret += String(character).utf16.count
            if !groupingSpaces.contains(character) { seen += 1 }
        }
        return Edit(rawText: raw, displayText: formatted, caretOffset: caret)
    }
}
