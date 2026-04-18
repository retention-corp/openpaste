import AppKit
import Foundation

struct ClipboardPayload {
  var plainText: String?
  var html: String?
}

enum CleaningPath: String {
  case plainText = "text"
  case richHTML = "html"
}

enum CleaningMode {
  case keepStructure
  case oneLine
}

struct CleaningMeta {
  var zeroWidthRemoved = 0
  var joinedLineBreaks = 0
  var listItems = 0
  var tables = 0
  var strippedStyles = 0
  var removedNodes = 0
  var wrapWidth = 96
  var wrapConfidence = 0
}

struct CleanResult {
  var path: CleaningPath
  var cleanText: String
  var html: String?
  var meta: CleaningMeta

  var previewSummary: String {
    var lines = [
      "path: \(path.rawValue)",
      "wrap width: \(meta.wrapWidth)",
      "joined line breaks: \(meta.joinedLineBreaks)",
      "list items: \(meta.listItems)",
      "tables: \(meta.tables)",
      "zero-width removed: \(meta.zeroWidthRemoved)",
    ]

    if meta.strippedStyles > 0 || meta.removedNodes > 0 {
      lines.append("styles stripped: \(meta.strippedStyles)")
      lines.append("nodes removed: \(meta.removedNodes)")
    }

    lines.append("")
    lines.append(cleanText)
    return lines.joined(separator: "\n")
  }
}

enum Block {
  case paragraph(String)
  case unorderedList([String])
  case orderedList([String])
  case table([String])
  case code(String)
}

struct ClipboardFormatter {
  func clean(payload: ClipboardPayload) -> CleanResult? {
    clean(payload: payload, mode: .keepStructure)
  }

  func clean(payload: ClipboardPayload, mode: CleaningMode) -> CleanResult? {
    let plainText = payload.plainText?.trimmingCharacters(in: .whitespacesAndNewlines)
    let html = payload.html?.trimmingCharacters(in: .whitespacesAndNewlines)

    var base: CleanResult?
    if let plainText, !plainText.isEmpty {
      base = cleanPlainText(plainText)
    } else if let html, html.contains("<") {
      base = cleanHTML(html, fallbackPlainText: nil)
    }

    guard var result = base else {
      return nil
    }

    if mode == .oneLine {
      result.cleanText = flattenToOneLine(result.cleanText)
      result.html = "<p>\(escapeHTML(result.cleanText))</p>"
    }

    return result
  }

  private func flattenToOneLine(_ text: String) -> String {
    let pattern = #"^(?:[-*•●]|\d+[.)])\s+(.*)$"#
    let stripped = text
      .components(separatedBy: "\n")
      .map { line -> String in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let match = regexMatch(pattern, in: trimmed),
           let rest = capturedGroup(1, from: match, in: trimmed)
        {
          return rest
        }
        return trimmed
      }
      .filter { !$0.isEmpty }

    let joined = stripped.joined(separator: " ")
    let collapsed = joined.replacingOccurrences(
      of: #"[ \t]+"#,
      with: " ",
      options: .regularExpression
    )
    return collapsed.trimmingCharacters(in: .whitespaces)
  }

  func cleanPlainText(_ input: String) -> CleanResult {
    var meta = CleaningMeta()
    let normalized = normalizeInput(input, meta: &meta)
    let lines = sanitizeTerminalSelectionLines(
      trimTrailingWhitespace(normalized.components(separatedBy: "\n"))
    )
    let wrapDetection = detectWrapWidth(lines)
    meta.wrapWidth = wrapDetection.width
    meta.wrapConfidence = wrapDetection.confidence
    let blocks = parseBlocks(lines, meta: &meta, wrapWidth: wrapDetection.width)

    return CleanResult(
      path: .plainText,
      cleanText: blocksToText(blocks),
      html: blocksToHTML(blocks),
      meta: meta
    )
  }

  func cleanHTML(_ input: String, fallbackPlainText: String?) -> CleanResult {
    var meta = CleaningMeta()
    meta.strippedStyles = countMatches("style\\s*=", in: input)
    meta.removedNodes = countMatches("<\\s*(script|style|meta|link|noscript)\\b", in: input)
    let sanitizedHTML = sanitizeHTML(input)
    let extractedText = chooseBestHTMLText(
      htmlText: htmlToPlainText(sanitizedHTML),
      fallbackPlainText: fallbackPlainText,
      meta: &meta
    ) ?? input
    let plainResult = cleanPlainText(extractedText)

    meta.zeroWidthRemoved = plainResult.meta.zeroWidthRemoved
    meta.joinedLineBreaks = plainResult.meta.joinedLineBreaks
    meta.listItems = plainResult.meta.listItems
    meta.tables = plainResult.meta.tables
    meta.wrapWidth = plainResult.meta.wrapWidth
    meta.wrapConfidence = plainResult.meta.wrapConfidence

    return CleanResult(
      path: .richHTML,
      cleanText: plainResult.cleanText,
      html: sanitizedHTML.isEmpty ? plainResult.html : sanitizedHTML,
      meta: meta
    )
  }

  private func countMatches(_ pattern: String, in value: String) -> Int {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return 0
    }

    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return regex.numberOfMatches(in: value, options: [], range: range)
  }

  private func sanitizeHTML(_ input: String) -> String {
    guard let attributed = attributedString(fromHTML: input) else {
      return ""
    }

    guard
      let data = try? attributed.data(
        from: NSRange(location: 0, length: attributed.length),
        documentAttributes: [
          .documentType: NSAttributedString.DocumentType.html,
          .characterEncoding: String.Encoding.utf8.rawValue,
        ]
      ),
      let html = String(data: data, encoding: .utf8)
    else {
      return ""
    }

    return html
  }

  private func attributedString(fromHTML html: String) -> NSAttributedString? {
    guard let data = html.data(using: .utf8) else {
      return nil
    }

    return try? NSAttributedString(
      data: data,
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue,
      ],
      documentAttributes: nil
    )
  }

  private func htmlToPlainText(_ html: String) -> String? {
    attributedString(fromHTML: html)?.string
  }

  private func chooseBestHTMLText(
    htmlText: String?,
    fallbackPlainText: String?,
    meta: inout CleaningMeta
  ) -> String? {
    let cleanedHTMLText = htmlText.map(cleanDuplicatedParagraphs)
    let cleanedFallbackText = fallbackPlainText.map(cleanDuplicatedParagraphs)

    if let cleanedHTMLText, let cleanedFallbackText {
      let htmlParagraphCount = paragraphCount(in: cleanedHTMLText)
      let fallbackParagraphCount = paragraphCount(in: cleanedFallbackText)
      let normalizedHTMLText = normalizeForComparison(cleanedHTMLText)
      let normalizedFallbackText = normalizeForComparison(cleanedFallbackText)

      if htmlParagraphCount >= fallbackParagraphCount * 2,
         cleanedHTMLText.contains(cleanedFallbackText)
      {
        meta.removedNodes += htmlParagraphCount - fallbackParagraphCount
        return cleanedFallbackText
      }

      if countOccurrences(of: normalizedFallbackText, in: normalizedHTMLText) >= 2 {
        return cleanedFallbackText
      }
    }

    if let cleanedHTMLText, !cleanedHTMLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return cleanedHTMLText
    }

    return cleanedFallbackText
  }

  private func cleanDuplicatedParagraphs(_ input: String) -> String {
    let normalized = input
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let paragraphs = splitIntoParagraphs(normalized)

    guard !paragraphs.isEmpty else {
      return normalized
    }

    var deduped: [String] = []
    for paragraph in paragraphs {
      if deduped.last == paragraph {
        continue
      }
      deduped.append(paragraph)
    }

    return deduped.joined(separator: "\n\n")
  }

  private func paragraphCount(in input: String) -> Int {
    splitIntoParagraphs(input).count
  }

  private func splitIntoParagraphs(_ input: String) -> [String] {
    let normalized = input
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    var paragraphs: [String] = []
    var current: [String] = []

    for line in normalized.components(separatedBy: "\n") {
      if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        if !current.isEmpty {
          paragraphs.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
          current.removeAll(keepingCapacity: true)
        }
        continue
      }

      current.append(line)
    }

    if !current.isEmpty {
      paragraphs.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return paragraphs.filter { !$0.isEmpty }
  }

  private func normalizeForComparison(_ input: String) -> String {
    input
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func countOccurrences(of needle: String, in haystack: String) -> Int {
    guard !needle.isEmpty, !haystack.isEmpty else {
      return 0
    }

    var count = 0
    var searchStart = haystack.startIndex

    while searchStart < haystack.endIndex,
          let range = haystack.range(of: needle, range: searchStart..<haystack.endIndex)
    {
      count += 1
      searchStart = range.upperBound
    }

    return count
  }

  private func normalizeInput(_ input: String, meta: inout CleaningMeta) -> String {
    let unixLines = input
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "\u{00A0}", with: " ")
    let ansiStripped = stripAnsiEscapes(unixLines)
    return stripInvisibleCharacters(ansiStripped, meta: &meta)
  }

  private func stripAnsiEscapes(_ input: String) -> String {
    guard input.contains("\u{001B}") else { return input }
    return input.replacingOccurrences(
      of: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]",
      with: "",
      options: .regularExpression
    )
  }

  private func stripInvisibleCharacters(_ input: String, meta: inout CleaningMeta) -> String {
    let scalars = input.unicodeScalars.filter { scalar in
      switch scalar.value {
      case 0x200B ... 0x200F, 0x2060, 0xFEFF:
        meta.zeroWidthRemoved += 1
        return false
      default:
        return true
      }
    }
    return String(String.UnicodeScalarView(scalars))
  }

  private func trimTrailingWhitespace(_ lines: [String]) -> [String] {
    lines.map { line in
      var trimmed = line
      while let last = trimmed.last, last == " " || last == "\t" {
        trimmed.removeLast()
      }
      return trimmed
    }
  }

  private func sanitizeTerminalSelectionLines(_ lines: [String]) -> [String] {
    var result = lines
    var heredocTerminator: String?

    while let first = result.first, first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      result.removeFirst()
    }
    while let last = result.last, last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      result.removeLast()
    }

    if let first = result.first, isClipboardHelperStatusLine(first) {
      result.removeFirst()
    }

    if let first = result.first, isShellPromptLine(first) {
      result.removeFirst()
    }

    if let first = result.first, let terminator = heredocTerminatorToken(in: first) {
      heredocTerminator = terminator
      result.removeFirst()
    }

    if let heredocTerminator {
      while let last = result.last,
            last.trimmingCharacters(in: .whitespacesAndNewlines) == heredocTerminator
      {
        result.removeLast()
      }
    }

    if let last = result.last, isShellPromptLine(last) {
      result.removeLast()
    }

    return result
  }

  private func isClipboardHelperStatusLine(_ line: String) -> Bool {
    regexMatch(#"^\s*Clipboard has \d+ lines\b"#, in: line, options: [.caseInsensitive]) != nil
  }

  private func isShellPromptLine(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return false
    }

    if regexMatch(#"^[^ \t\n]+@[^ \t\n]+ .*[%#$>]$"#, in: trimmed) != nil {
      return true
    }

    if regexMatch(#"^[~/][^ \t\n]*[%#$>]$"#, in: trimmed) != nil {
      return true
    }

    return false
  }

  private func heredocTerminatorToken(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let match = regexMatch(#"<<[-~]?\s*['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?$"#, in: trimmed) else {
      return nil
    }

    return capturedGroup(1, from: match, in: trimmed)
  }

  private func detectWrapWidth(_ lines: [String]) -> (width: Int, confidence: Int) {
    var histogram: [Int: Int] = [:]

    for line in lines {
      guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
        continue
      }
      if isListItem(line) || isTableLine(line) || isFenceLine(line) {
        continue
      }

      let width = line.trimmingCharacters(in: .whitespaces).count
      guard (72 ... 140).contains(width) else {
        continue
      }
      histogram[width, default: 0] += 1
    }

    let best = histogram.max { lhs, rhs in
      lhs.value < rhs.value
    }

    return (best?.key ?? 96, best?.value ?? 0)
  }

  private func parseBlocks(_ lines: [String], meta: inout CleaningMeta, wrapWidth: Int) -> [Block] {
    var blocks: [Block] = []
    var index = 0

    while index < lines.count {
      let line = lines[index]

      if line.trimmingCharacters(in: .whitespaces).isEmpty {
        index += 1
        continue
      }

      if isFenceLine(line) {
        var chunk = [line]
        index += 1
        while index < lines.count {
          chunk.append(lines[index])
          if isFenceLine(lines[index]) {
            index += 1
            break
          }
          index += 1
        }
        blocks.append(.code(chunk.joined(separator: "\n")))
        continue
      }

      if index + 1 < lines.count, isTableLine(line), isTableSeparator(lines[index + 1]) {
        var tableLines: [String] = []
        while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
          tableLines.append(lines[index])
          index += 1
        }
        meta.tables += 1
        blocks.append(.table(normalizeTableLines(tableLines)))
        continue
      }

      if isListItem(line) {
        let ordered = isOrderedListItem(line)
        var listLines: [String] = []
        while index < lines.count {
          let current = lines[index]
          if current.trimmingCharacters(in: .whitespaces).isEmpty {
            var peek = index + 1
            while peek < lines.count,
                  lines[peek].trimmingCharacters(in: .whitespaces).isEmpty
            {
              peek += 1
            }
            if peek < lines.count {
              let nextLine = lines[peek]
              if isListItem(nextLine), isOrderedListItem(nextLine) == ordered {
                index = peek
                continue
              }
              if let lastListLine = listLines.last,
                 listContinuesAcrossBlank(prev: lastListLine, next: nextLine),
                 !isListItem(nextLine),
                 !isFenceLine(nextLine),
                 !looksLikeSectionLabel(nextLine),
                 !(isTableLine(nextLine)
                   && peek + 1 < lines.count
                   && isTableSeparator(lines[peek + 1]))
              {
                index = peek
                continue
              }
            }
            break
          }
          if isListItem(current)
            || beginsIndentedContinuation(current)
            || (!isFenceLine(current)
              && !looksLikeSectionLabel(current)
              && !(isTableLine(current)
                && index + 1 < lines.count
                && isTableSeparator(lines[index + 1])))
          {
            listLines.append(current)
            index += 1
            continue
          }
          break
        }

        let items = normalizeListItems(listLines, meta: &meta, ordered: ordered)
        blocks.append(ordered ? .orderedList(items) : .unorderedList(items))
        continue
      }

      var paragraphLines: [String] = []
      while index < lines.count {
        let current = lines[index]
        if current.trimmingCharacters(in: .whitespaces).isEmpty {
          break
        }
        if !paragraphLines.isEmpty
          && (isFenceLine(current)
            || isListItem(current)
            || (isTableLine(current)
              && index + 1 < lines.count
              && isTableSeparator(lines[index + 1])))
        {
          break
        }
        paragraphLines.append(current)
        index += 1
      }

      if shouldPreserveAsBlock(paragraphLines) {
        blocks.append(.code(paragraphLines.joined(separator: "\n")))
      } else {
        blocks.append(.paragraph(joinParagraphLines(paragraphLines, meta: &meta, wrapWidth: wrapWidth)))
      }
    }

    return blocks
  }

  private func normalizeTableLines(_ lines: [String]) -> [String] {
    lines
      .map { line in
        line
          .trimmingCharacters(in: .whitespaces)
          .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
          .split(separator: "|", omittingEmptySubsequences: false)
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .joined(separator: " | ")
      }
  }

  private func normalizeListItems(_ lines: [String], meta: inout CleaningMeta, ordered: Bool) -> [String] {
    var items: [String] = []
    var current: String?

    for line in lines {
      let raw = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !raw.isEmpty else { continue }

      if let match = regexMatch(#"^((?:[-*•●])|(?:\d+[.)]))\s+(.*)$"#, in: raw) {
        if let current {
          items.append(current)
        }
        current = capturedGroup(2, from: match, in: raw)
        meta.listItems += 1
        continue
      }

      guard let existing = current else {
        current = raw
        meta.listItems += 1
        continue
      }

      current = existing + " " + raw.trimmingCharacters(in: .whitespaces)
      meta.joinedLineBreaks += 1
    }

    if let current {
      items.append(current)
    }

    if ordered {
      return items.enumerated().map { offset, item in
        "\(offset + 1). \(item)"
      }
    }

    return items.map { "- \($0)" }
  }

  private func joinParagraphLines(_ lines: [String], meta: inout CleaningMeta, wrapWidth: Int) -> String {
    guard !lines.isEmpty else {
      return ""
    }

    var current = lines[0].trimmingCharacters(in: .whitespaces)

    for line in lines.dropFirst() {
      let next = line.trimmingCharacters(in: .whitespaces)
      guard !next.isEmpty else { continue }

      if shouldJoinParagraphLine(current: current, next: next, wrapWidth: wrapWidth) {
        if current.hasSuffix("\\") {
          current.removeLast()
          while let last = current.last, last == " " || last == "\t" {
            current.removeLast()
          }
          current += " " + next
        } else if shouldJoinWithoutSpace(current: current, next: next) {
          current += next
        } else {
          current += " " + next
        }
        meta.joinedLineBreaks += 1
      } else {
        current += "\n\n" + next
      }
    }

    return current
  }

  private func shouldJoinWithoutSpace(current: String, next: String) -> Bool {
    guard let last = current.last, let first = next.first else {
      return false
    }

    if first == " " || first == "\t" {
      return false
    }

    if lastTokenLooksLikeURL(current), !first.isWhitespace {
      return true
    }

    switch last {
    case "/", "_", "-":
      return true
    case ".":
      return first.isNumber
    case ":":
      return first == "/"
    default:
      return false
    }
  }

  private func shouldJoinParagraphLine(current: String, next: String, wrapWidth: Int) -> Bool {
    guard !current.isEmpty, !next.isEmpty else {
      return false
    }

    if let first = next.first, ",.;:)]".contains(first) {
      return true
    }

    if let last = current.last, "/_-\\".contains(last) {
      return true
    }

    if endsWithKoreanConnective(current) {
      return true
    }

    // Terminal selections usually turn soft wraps into hard newlines.
    // Bias strongly toward rejoining contiguous paragraph lines, including CJK text.
    if displayWidth(current) < max(24, wrapWidth / 3),
       displayWidth(next) < max(24, wrapWidth / 3)
    {
      return false
    }

    return true
  }

  private func endsWithKoreanConnective(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard let last = trimmed.last else { return false }
    let particles: Set<Character> = [
      "을", "를", "이", "가", "은", "는", "의", "에", "도", "만",
      "로", "과", "와", "나", "고", "며", "서", "면", "지", "야",
      "된", "한", "할", "던", "들", "중", "때"
    ]
    return particles.contains(last)
  }

  private func lastTokenLooksLikeURL(_ s: String) -> Bool {
    let tokens = s.split(whereSeparator: { $0 == " " || $0 == "\t" })
    guard let last = tokens.last else { return false }
    return last.contains("://")
  }

  private func isDollarPromptLine(_ line: String) -> Bool {
    regexMatch(#"^\s*\$\s+\S"#, in: line) != nil
  }

  private func displayWidth(_ s: String) -> Int {
    var width = 0
    for scalar in s.unicodeScalars {
      let v = scalar.value
      if (0x1100 ... 0x115F).contains(v)
        || (0x2E80 ... 0x9FFF).contains(v)
        || (0xA000 ... 0xA4CF).contains(v)
        || (0xAC00 ... 0xD7A3).contains(v)
        || (0xF900 ... 0xFAFF).contains(v)
        || (0xFE30 ... 0xFE4F).contains(v)
        || (0xFF00 ... 0xFF60).contains(v)
        || (0xFFE0 ... 0xFFE6).contains(v)
      {
        width += 2
      } else {
        width += 1
      }
    }
    return width
  }

  private func blocksToText(_ blocks: [Block]) -> String {
    blocks.compactMap { block in
      switch block {
      case let .paragraph(text), let .code(text):
        return text
      case let .table(lines):
        return lines.joined(separator: "\n")
      case let .unorderedList(items), let .orderedList(items):
        return items.joined(separator: "\n")
      }
    }
    .joined(separator: "\n\n")
  }

  private func blocksToHTML(_ blocks: [Block]) -> String {
    blocks.map { block in
      switch block {
      case let .paragraph(text):
        return text
          .components(separatedBy: "\n\n")
          .map { "<p>\(escapeHTML($0))</p>" }
          .joined()
      case let .code(text):
        return "<pre><code>\(escapeHTML(text))</code></pre>"
      case let .table(lines):
        return tableHTML(from: lines)
      case let .unorderedList(items):
        let body = items.map { item in
          "<li>\(escapeHTML(item.replacingOccurrences(of: "- ", with: "")))</li>"
        }
        .joined()
        return "<ul>\(body)</ul>"
      case let .orderedList(items):
        let body = items.map { item in
          let text = item.replacingOccurrences(of: #"^\d+\.\s+"#, with: "", options: .regularExpression)
          return "<li>\(escapeHTML(text))</li>"
        }
        .joined()
        return "<ol>\(body)</ol>"
      }
    }
    .joined()
  }

  private func tableHTML(from lines: [String]) -> String {
    let rows = lines.map { line in
      line.split(separator: "|", omittingEmptySubsequences: false)
        .map { escapeHTML($0.trimmingCharacters(in: .whitespaces)) }
    }

    guard rows.count >= 2 else {
      return "<pre><code>\(escapeHTML(lines.joined(separator: "\n")))</code></pre>"
    }

    let header = rows[0]
    let potentialSeparator = rows[1].joined(separator: " | ")
    let bodyRows = isTableSeparator(potentialSeparator) ? Array(rows.dropFirst(2)) : Array(rows.dropFirst())

    let headerHTML = header.map { "<th>\($0)</th>" }.joined()
    let bodyHTML = bodyRows
      .map { row in
        "<tr>\(row.map { "<td>\($0)</td>" }.joined())</tr>"
      }
      .joined()

    return "<table><thead><tr>\(headerHTML)</tr></thead><tbody>\(bodyHTML)</tbody></table>"
  }

  private func escapeHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

  private func beginsIndentedContinuation(_ line: String) -> Bool {
    let leadingSpaces = line.prefix { $0 == " " || $0 == "\t" }.count
    return leadingSpaces >= 2
  }

  private func isFenceLine(_ line: String) -> Bool {
    line.trimmingCharacters(in: .whitespaces).hasPrefix("```")
      || line.trimmingCharacters(in: .whitespaces).hasPrefix("~~~")
  }

  private func isListItem(_ line: String) -> Bool {
    regexMatch(#"^\s*(?:[-*•●]|\d+[.)])\s+"#, in: line) != nil
  }

  private func isOrderedListItem(_ line: String) -> Bool {
    regexMatch(#"^\s*\d+[.)]\s+"#, in: line) != nil
  }

  private func isTableLine(_ line: String) -> Bool {
    line.contains("|")
  }

  private func isTableSeparator(_ line: String) -> Bool {
    regexMatch(#"^\s*\|?(?:\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$"#, in: line) != nil
  }

  private func looksLikeSectionLabel(_ line: String) -> Bool {
    regexMatch(#"^[A-Z][\w /()\-\+]+:$"#, in: line) != nil
  }

  private func shouldPreserveAsBlock(_ lines: [String]) -> Bool {
    let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    guard nonEmpty.count >= 2 else { return false }

    if nonEmpty.contains(where: containsBoxDrawing) {
      return true
    }

    if nonEmpty.contains(where: looksLikeDiffHeader) {
      return true
    }

    let quoteCount = nonEmpty.filter {
      $0.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }.count
    if quoteCount >= 2, quoteCount * 2 >= nonEmpty.count {
      return true
    }

    let grepCount = nonEmpty.filter(looksLikeGrepLine).count
    if grepCount >= 2 {
      return true
    }

    let lsCount = nonEmpty.filter(looksLikeLsStatLine).count
    if lsCount >= 2 {
      return true
    }

    let promptArrowCount = nonEmpty.filter(containsShellPromptArrow).count
    if promptArrowCount >= 1, nonEmpty.count >= 3 {
      return true
    }

    if nonEmpty.contains(where: containsClaudeCodeToolMarker) {
      return true
    }

    let dollarCount = nonEmpty.filter(isDollarPromptLine).count
    if dollarCount >= 1, nonEmpty.count >= 2 {
      return true
    }

    return false
  }

  private func containsClaudeCodeToolMarker(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed.hasPrefix("⏺") || trimmed.hasPrefix("⎿")
  }

  private func containsBoxDrawing(_ line: String) -> Bool {
    for scalar in line.unicodeScalars {
      if (0x2500 ... 0x257F).contains(scalar.value) {
        return true
      }
    }
    return false
  }

  private func looksLikeDiffHeader(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("diff --git ") { return true }
    if trimmed.hasPrefix("@@ ") || trimmed.hasPrefix("@@@ ") { return true }
    if trimmed.hasPrefix("--- ") || trimmed.hasPrefix("+++ ") { return true }
    if trimmed.hasPrefix("index "), trimmed.contains("..") { return true }
    return false
  }

  private func looksLikeGrepLine(_ line: String) -> Bool {
    regexMatch(#"^[^:\s]+:\d+:"#, in: line) != nil
  }

  private func looksLikeLsStatLine(_ line: String) -> Bool {
    regexMatch(#"^[d-][rwxsSt-]{9}[@+.]?\s+\d+"#, in: line) != nil
  }

  private func containsShellPromptArrow(_ line: String) -> Bool {
    line.contains("❯") || line.contains("➜")
  }

  private func listContinuesAcrossBlank(prev: String, next: String) -> Bool {
    let prevTrim = prev.trimmingCharacters(in: .whitespaces)
    let nextTrim = next.trimmingCharacters(in: .whitespaces)
    guard !prevTrim.isEmpty, !nextTrim.isEmpty else { return false }

    let terminals: Set<Character> = [".", "!", "?", "。", "！", "？", "…"]
    if let last = prevTrim.last, terminals.contains(last) {
      return false
    }

    if endsWithKoreanConnective(prevTrim) {
      return true
    }

    if let first = nextTrim.first,
       first.isLetter, first.isLowercase,
       first.isASCII
    {
      return true
    }

    return false
  }

  private func regexMatch(
    _ pattern: String,
    in value: String,
    options: NSRegularExpression.Options = []
  ) -> NSTextCheckingResult? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
      return nil
    }
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return regex.firstMatch(in: value, options: [], range: range)
  }

  private func capturedGroup(_ index: Int, from match: NSTextCheckingResult, in value: String) -> String? {
    guard
      index < match.numberOfRanges,
      let range = Range(match.range(at: index), in: value)
    else {
      return nil
    }
    return String(value[range])
  }
}
