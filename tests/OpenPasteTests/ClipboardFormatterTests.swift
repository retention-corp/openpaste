import Testing
@testable import OpenPaste

@Test func joinsWrappedParagraphLines() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    This paragraph was wrapped by a terminal at eighty columns so the text
    continues on the next line even though it should read as one sentence.
    """
  )

  #expect(
    result.cleanText
      == "This paragraph was wrapped by a terminal at eighty columns so the text continues on the next line even though it should read as one sentence."
  )
  #expect(result.meta.joinedLineBreaks == 1)
}

@Test func joinsWrappedKoreanParagraphLines() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    원래 40~45% 베이스라인은 2026년 1월에 Mailgun A/B
    시스템 + 약 300명 정제 리스트 기준이었습니다. content/Blog/archive/mailgun-ab-test-history-260128.md:14
    """
  )

  #expect(
    result.cleanText
      == "원래 40~45% 베이스라인은 2026년 1월에 Mailgun A/B 시스템 + 약 300명 정제 리스트 기준이었습니다. content/Blog/archive/mailgun-ab-test-history-260128.md:14"
  )
}

@Test func stripsPromptAndHeredocWrapperLines() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    Clipboard has 21 lines → cf (one-line) or cp (keep structure)
    upsim@Gyusupui-Macmini ~/P/t/coding_agent> cat <<'EOF'
    - 원래 40~45% 베이스라인은 2026년 1월에 Mailgun A/B
    시스템 + 약 300명 정제 리스트 기준이었습니다.
    EOF
    """
  )

  #expect(result.cleanText == "- 원래 40~45% 베이스라인은 2026년 1월에 Mailgun A/B 시스템 + 약 300명 정제 리스트 기준이었습니다.")
}

@Test func joinsWrappedPathWithoutInsertingSpaceAfterSlash() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    cd /Users/gyusupsim/Projects/products/
    coupang_partners && codex —resume 019d93da-5d5a-7973-b09a-379bda59eeb5
    """
  )

  #expect(
    result.cleanText
      == "cd /Users/gyusupsim/Projects/products/coupang_partners && codex —resume 019d93da-5d5a-7973-b09a-379bda59eeb5"
  )
}

@Test func joinsUUIDStyleDashWrapKeepingDash() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    Session 019d93da-5d5a-
    7973-b09a-379bda59eeb5 ended successfully and all pending jobs were drained to disk.
    """
  )

  #expect(
    result.cleanText
      == "Session 019d93da-5d5a-7973-b09a-379bda59eeb5 ended successfully and all pending jobs were drained to disk."
  )
}

@Test func joinsShellContinuationAndDropsBackslash() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    curl -X POST https://api.example.com/v1/ingest \\
      -H "Content-Type: application/json" \\
      -d '{"hello":"world"}'
    """
  )

  #expect(
    result.cleanText
      == #"curl -X POST https://api.example.com/v1/ingest -H "Content-Type: application/json" -d '{"hello":"world"}'"#
  )
}

@Test func joinsVersionNumberWrappedAtDot() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    Download openpaste-v1.
    0.3-macos-arm64.tar.gz from the release assets and verify the signature before install.
    """
  )

  #expect(
    result.cleanText
      == "Download openpaste-v1.0.3-macos-arm64.tar.gz from the release assets and verify the signature before install."
  )
}

@Test func joinsURLSchemeWrappedAtColon() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    Redirecting to https:
    //prettypaste.interappy.io/landing because the legacy host has been retired this quarter.
    """
  )

  #expect(
    result.cleanText
      == "Redirecting to https://prettypaste.interappy.io/landing because the legacy host has been retired this quarter."
  )
}

@Test func keepsSpaceAtSentenceBoundary() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    The migration finished successfully without rolling back the schema changes.
    Next steps are documented in the README file at the repository root.
    """
  )

  #expect(
    result.cleanText
      == "The migration finished successfully without rolling back the schema changes. Next steps are documented in the README file at the repository root."
  )
}

@Test func preservesDashInsideWrappedDashedIdentifier() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    Opening the error-
    handling module to add a missing retry path for transient network failures.
    """
  )

  #expect(
    result.cleanText
      == "Opening the error-handling module to add a missing retry path for transient network failures."
  )
}

@Test func preservesAndRepairsListItems() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    Key findings:
    - auth.ts has 3 potential security
    issues
    - utils/format.ts lacks error
    handling
    """
  )

  #expect(result.cleanText.contains("- auth.ts has 3 potential security issues"))
  #expect(result.cleanText.contains("- utils/format.ts lacks error handling"))
  #expect(result.meta.listItems == 2)
}

@Test func rendersPipeTablesAsHTMLTables() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    | Route | ETA |
    | --- | --- |
    | Seoul | 2 days |
    | Tokyo | 1 day |
    """
  )

  #expect(result.html?.contains("<table>") == true)
  #expect(result.html?.contains("<th>Route</th>") == true)
  #expect(result.html?.contains("<td>Tokyo</td>") == true)
  #expect(result.meta.tables == 1)
}

@Test func collapsesConsecutiveDuplicateParagraphsFromHTML() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanHTML(
    """
    <div>
      <p>같은 경고가 계속 뜨면 권한 캐시를 다시 확인하세요.</p>
      <p>같은 경고가 계속 뜨면 권한 캐시를 다시 확인하세요.</p>
    </div>
    """,
    fallbackPlainText: "같은 경고가 계속 뜨면 권한 캐시를 다시 확인하세요."
  )

  #expect(
    result.cleanText == "같은 경고가 계속 뜨면 권한 캐시를 다시 확인하세요."
  )
}

@Test func prefersPlainTextForNonStructuralChatHTML() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.clean(
    payload: ClipboardPayload(
      plainText: "메모장에서는 이 문장만 한 번 들어가야 합니다.",
      html: """
      <div class="chat-shell">
        <div>메모장에서는 이 문장만 한 번 들어가야 합니다.</div>
        <div>메모장에서는 이 문장만 한 번 들어가야 합니다.</div>
        <div>&lt;- ··</div>
      </div>
      """
    )
  )

  #expect(result?.path == .plainText)
  #expect(result?.cleanText == "메모장에서는 이 문장만 한 번 들어가야 합니다.")
  #expect(result?.html?.contains("<p>메모장에서는 이 문장만 한 번 들어가야 합니다.</p>") == true)
}

@Test func oneLineModeCollapsesWrappedParagraphIntoSingleLine() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.clean(
    payload: ClipboardPayload(
      plainText: """
      This paragraph was wrapped by a terminal at eighty columns so the text
      continues on the next line even though it should read as one sentence.
      """,
      html: nil
    ),
    mode: .oneLine
  )

  #expect(
    result?.cleanText
      == "This paragraph was wrapped by a terminal at eighty columns so the text continues on the next line even though it should read as one sentence."
  )
}

@Test func oneLineModeFlattensBulletListIntoSpaceJoinedSentence() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.clean(
    payload: ClipboardPayload(
      plainText: """
      Key findings:
      - auth.ts has 3 potential security issues
      - utils/format.ts lacks error handling
      - network.ts is missing timeouts
      """,
      html: nil
    ),
    mode: .oneLine
  )

  #expect(
    result?.cleanText
      == "Key findings: auth.ts has 3 potential security issues utils/format.ts lacks error handling network.ts is missing timeouts"
  )
}

@Test func oneLineModePreservesPathsAndCollapsesKoreanWrap() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.clean(
    payload: ClipboardPayload(
      plainText: """
      cd /Users/gyusupsim/Projects/products/
      coupang_partners && codex —resume 019d93da-5d5a-7973-b09a-379bda59eeb5

      원래 40~45% 베이스라인은 2026년 1월에 Mailgun A/B
      시스템 + 약 300명 정제 리스트 기준이었습니다.
      """,
      html: nil
    ),
    mode: .oneLine
  )

  #expect(
    result?.cleanText
      == "cd /Users/gyusupsim/Projects/products/coupang_partners && codex —resume 019d93da-5d5a-7973-b09a-379bda59eeb5 원래 40~45% 베이스라인은 2026년 1월에 Mailgun A/B 시스템 + 약 300명 정제 리스트 기준이었습니다."
  )
}

@Test func oneLineModeKeepsStructureModeUnchanged() async throws {
  let formatter = ClipboardFormatter()
  let plain = """
  First sentence in paragraph one.
  Second sentence in paragraph one.

  Paragraph two starts here and ends here.
  """
  let keep = formatter.clean(payload: ClipboardPayload(plainText: plain, html: nil))
  let oneLine = formatter.clean(
    payload: ClipboardPayload(plainText: plain, html: nil),
    mode: .oneLine
  )

  #expect(keep?.cleanText.contains("\n\n") == true)
  #expect(oneLine?.cleanText.contains("\n") == false)
  #expect(
    oneLine?.cleanText
      == "First sentence in paragraph one. Second sentence in paragraph one. Paragraph two starts here and ends here."
  )
}

@Test func preservesGrepOutputAsBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    src/app.js:10:function main() {
    src/app.js:24:function handler(req) {
    src/util.js:7:function parse(x) {
    """
  )

  #expect(result.cleanText.contains("\n"))
  #expect(result.cleanText.contains("src/app.js:10:function main() {"))
  #expect(result.cleanText.contains("src/util.js:7:function parse(x) {"))
}

@Test func preservesDiffOutputAsBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    diff --git a/foo.swift b/foo.swift
    --- a/foo.swift
    +++ b/foo.swift
    @@ -1,3 +1,3 @@
    -old line
    +new line
    """
  )

  #expect(result.cleanText.contains("diff --git a/foo.swift b/foo.swift"))
  #expect(result.cleanText.contains("--- a/foo.swift\n+++ b/foo.swift"))
  #expect(result.cleanText.contains("@@ -1,3 +1,3 @@"))
}

@Test func preservesLsStatOutputAsBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    -rw-r--r--   1 user  staff   1234 Jan  1 12:00 README.md
    drwxr-xr-x   5 user  staff    160 Jan  2 09:30 Sources
    -rwxr-xr-x   1 user  staff   8421 Jan  3 10:00 build.sh
    """
  )

  #expect(result.cleanText.contains("\n"))
  #expect(result.cleanText.contains("-rw-r--r--"))
  #expect(result.cleanText.contains("drwxr-xr-x"))
}

@Test func preservesBoxDrawingTreeAsBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    Sources
    ├── AppDelegate.swift
    ├── ClipboardFormatter.swift
    └── OpenPasteApp.swift
    """
  )

  #expect(result.cleanText.contains("├── AppDelegate.swift"))
  #expect(result.cleanText.contains("└── OpenPasteApp.swift"))
  #expect(result.cleanText.contains("\n"))
}

@Test func preservesQuoteBlockAsBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    > first quoted line
    > second quoted line
    > third quoted line
    """
  )

  #expect(result.cleanText.contains("> first quoted line"))
  #expect(result.cleanText.contains("> third quoted line"))
  #expect(result.cleanText.contains("\n"))
}

@Test func preservesShellPromptArrowBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    ~/Projects ❯ swift test
    Test Suite 'All tests' started
    Test Suite 'All tests' passed
    """
  )

  #expect(result.cleanText.contains("❯"))
  #expect(result.cleanText.contains("Test Suite 'All tests' started"))
  #expect(result.cleanText.contains("\n"))
}

@Test func singleGrepLineDoesNotForceBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    src/app.js:10:this is a long single grep-like line that should just be treated as
    a normal wrapped paragraph continuation here.
    """
  )

  #expect(result.cleanText.contains("\n") == false)
  #expect(
    result.cleanText
      == "src/app.js:10:this is a long single grep-like line that should just be treated as a normal wrapped paragraph continuation here."
  )
}

@Test func singleLsStatLineDoesNotForceBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    -rw-r--r--   1 user  staff   1234 Jan  1 12:00 README.md is the only entry
    and the description continues on the next wrapped line here.
    """
  )

  #expect(result.cleanText.contains("\n") == false)
}

@Test func mixedParagraphAndPreservedBlockSeparated() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    Here is a regular wrapped paragraph explaining the grep results
    that follow below in a preserved block.

    src/app.js:10:function main() {
    src/app.js:24:function handler(req) {
    """
  )

  #expect(
    result.cleanText.contains(
      "Here is a regular wrapped paragraph explaining the grep results that follow below in a preserved block."
    )
  )
  #expect(result.cleanText.contains("src/app.js:10:function main() {"))
  #expect(result.cleanText.contains("src/app.js:24:function handler(req) {"))
  #expect(result.cleanText.contains("\n\n"))
}

@Test func alwaysPrefersPlainTextWhenAvailable() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.clean(
    payload: ClipboardPayload(
      plainText: "이미 새 빌드로 /Applications/OpenPaste.app까지 교체했고 다시 열었습니다. 검증도 끝났습니다!",
      html: """
      <div style="background:#444;color:white;padding:12px;border-radius:8px">
        <p>이미 새 빌드로 /Applications/OpenPaste.app까지 교체했고 다시 열었습니다.</p>
        <p>검증도 끝났습니다!</p>
      </div>
      """
    )
  )

  #expect(result?.path == .plainText)
  #expect(result?.cleanText == "이미 새 빌드로 /Applications/OpenPaste.app까지 교체했고 다시 열었습니다. 검증도 끝났습니다!")
}
