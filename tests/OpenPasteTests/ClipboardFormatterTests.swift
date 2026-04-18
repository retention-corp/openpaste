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

@Test func absorbsBlankLineInsideWrappedKoreanBullet() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    ● 구조화된 인터뷰를 통해 수익 확장 플랜의 요구사항을

    명확히 하겠습니다. 전담 인터뷰어가 타겟 질문을 던지고, 저는 Ambiguity Score로 명확도를 추적합니다. 점수가 0.2 이하로 떨어지면 마무리합니다.
    """
  )

  #expect(
    result.cleanText.contains(
      "구조화된 인터뷰를 통해 수익 확장 플랜의 요구사항을 명확히 하겠습니다."
    )
  )
  #expect(result.cleanText.contains("\n\n") == false)
}

@Test func joinsWrappedKoreanHeadingAcrossDisplayWidth() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    ## 매우 긴 한국어 제목이 터미널 너비를
    넘어서 다음 줄로 이어지는 경우
    """
  )
  #expect(
    result.cleanText == "## 매우 긴 한국어 제목이 터미널 너비를 넘어서 다음 줄로 이어지는 경우"
  )
}

@Test func joinsWrappedKoreanConnectiveEnding() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    "이 줄 끝에는 공백이 붙어있고   \n다음 줄로 이어지는 문장입니다."
  )
  #expect(result.cleanText == "이 줄 끝에는 공백이 붙어있고 다음 줄로 이어지는 문장입니다.")
}

@Test func joinsWrappedURLWithoutSpace() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    참고 링크: https://github.com/retention-corp/open
    paste/issues/1 에 자세한 내용이 있습니다.
    """
  )
  #expect(result.cleanText.contains("https://github.com/retention-corp/openpaste/issues/1"))
  #expect(result.cleanText.contains("open paste") == false)
}

@Test func preservesClaudeCodeToolMarkerBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    ⏺ Bash(swift test)
      ⎿ Test Suite 'All tests' passed
        Executed 28 tests
    """
  )
  #expect(result.cleanText.contains("⏺ Bash(swift test)"))
  #expect(result.cleanText.contains("⎿ Test Suite 'All tests' passed"))
  #expect(result.cleanText.contains("\n  ⎿"))
}

@Test func preservesShellDollarPromptBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    $ swift build
    Building for debugging...
    Build complete!
    """
  )
  #expect(result.cleanText.contains("$ swift build\nBuilding"))
  #expect(result.cleanText.contains("\nBuild complete!"))
}

@Test func mergesConsecutiveBulletsAcrossBlankLine() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    ● 첫 번째 불릿입니다.

    ● 두 번째 불릿입니다.
    """
  )
  #expect(result.cleanText == "- 첫 번째 불릿입니다.\n- 두 번째 불릿입니다.")
}

@Test func stripsClaudeCodeLeftBorderQuarterBlock() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    의도 라우팅 레이어'를 한국에서
    \u{258E} 선점한다는 뜻인가요, 아니면 단순히 유저
    """
  )
  #expect(result.cleanText.contains("\u{258E}") == false)
  #expect(
    result.cleanText == "의도 라우팅 레이어'를 한국에서 선점한다는 뜻인가요, 아니면 단순히 유저"
  )
}

@Test func stripsPerLineLeftBorderAcrossParagraph() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    \u{258E} 참고하신 twocents.xyz 글의 실제 moat 주장은
    \u{258E} 빠른 스케일업이 아니라 의도 분배권(intent
    \u{258E} distribution rights) 선점입니다.
    """
  )
  #expect(result.cleanText.contains("\u{258E}") == false)
  #expect(result.cleanText.contains("intent distribution rights"))
  #expect(result.cleanText.contains("\n") == false)
}

@Test func stripsBoxVerticalBorderOutsideTreeContext() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    한국에서 빠르게 성장하는 핵심은
    │ 의도 라우팅 레이어 선점입니다.
    """
  )
  #expect(result.cleanText.contains("│") == false)
  #expect(
    result.cleanText == "한국에서 빠르게 성장하는 핵심은 의도 라우팅 레이어 선점입니다."
  )
}

@Test func preservesBoxVerticalInsideTreeStructure() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    Sources
    ├── OpenPaste
    │   ├── AppDelegate.swift
    │   └── ClipboardFormatter.swift
    └── tests
    """
  )
  #expect(result.cleanText.contains("│   ├── AppDelegate.swift"))
  #expect(result.cleanText.contains("│   └── ClipboardFormatter.swift"))
}

@Test func recognizesBlackCircleBulletAsListMarker() async throws {
  let formatter = ClipboardFormatter()
  let result = formatter.cleanPlainText(
    """
    ● apple
    ● banana
    ● cherry
    """
  )
  #expect(result.cleanText == "- apple\n- banana\n- cherry")
}

@Test func probeRealisticClaudeCodePatterns() async throws {
  let formatter = ClipboardFormatter()
  let fixtures: [(String, String)] = [
    ("numbered-list-blank-wrap",
     """
     1. 구조화된 인터뷰를 통해 수익 확장 플랜의 요구사항을

     명확히 하겠습니다.
     2. 다음 단계는 질문을 정제하는 것입니다.
     """),
    ("bullet-terminated-then-paragraph",
     """
     ● 첫 번째 불릿은 완성된 문장입니다.

     이건 별개 단락이어야 합니다.
     """),
    ("short-bullet-list-preserved",
     """
     ● apple
     ● banana
     ● cherry
     """),
    ("tool-markers",
     """
     ⏺ Bash(swift test)
       ⎿ Test Suite 'All tests' passed
         Executed 28 tests
     """),
    ("heading-wrapped-korean",
     """
     ## 매우 긴 한국어 제목이 터미널 너비를
     넘어서 다음 줄로 이어지는 경우
     """),
    ("nested-bullets-wrapped",
     """
     ● 상위 불릿입니다. 이 줄은 짧습니다.
       ● 하위 불릿에서 한국어가 길어서
         다음 줄로 이어집니다.
     """),
    ("code-fence-then-text",
     """
     다음은 코드입니다:
     ```swift
     let x = "hello"
     ```
     코드 뒤에 오는 한국어 문장이 길어서
     다음 줄로 넘어갑니다.
     """),
    ("indented-prompt-padding",
     """
       이 텍스트는 프롬프트 정렬 때문에 앞에 공백이 붙어서
       복사되었습니다. 원래는 단락 하나입니다.
     """),
    ("bullet-english-lowercase-continuation",
     """
     ● This is an English bullet that was wrapped

     continuing on this line in lowercase.
     """),
    ("bullet-english-capital-new-paragraph",
     """
     ● Buy groceries

     Remember to pick up the kids.
     """),
    ("bold-inline-wrapped",
     """
     이 문장은 **볼드 텍스트**를 포함하고 있으며 터미널에서
     길어서 다음 줄로 넘어갑니다.
     """),
    ("backtick-code-korean-wrap",
     """
     `ClipboardFormatter.cleanPlainText(...)` 함수는 한국어
     문장이 잘려서 복사되면 복구합니다.
     """),
    ("trailing-spaces-wrapped",
     "이 줄 끝에는 공백이 붙어있고   \n다음 줄로 이어지는 문장입니다."),
    ("numbered-nested-sub",
     """
     1. 첫째 항목은 이렇게 길게 이어집니다
        하위 설명이 들여쓰기로 붙습니다.
     2. 둘째 항목입니다.
     """),
    ("ansi-escape-stripped",
     "\u{001B}[31m빨간 에러 메시지\u{001B}[0m가 포함된\n터미널 출력의 줄바꿈 처리"),
    ("crlf-line-endings",
     "첫 번째 줄입니다\r\n두 번째 줄이 이어집니다"),
    ("bracket-numbered-markers",
     """
     [1] 첫 번째 로그 엔트리는 꽤 길어서
     다음 줄로 넘어갑니다.
     [2] 두 번째 엔트리.
     """),
    ("mixed-eng-kor-wrap",
     """
     This is English text followed by 한국어 문장이
     mixed together across the wrap boundary.
     """),
    ("long-url-wrapped",
     """
     참고 링크: https://github.com/retention-corp/open
     paste/issues/1 에 자세한 내용이 있습니다.
     """),
    ("claude-code-thinking-indicator",
     """
     ✻ Thinking…

     Let me check the code structure.
     """),
    ("consecutive-bullets-with-gap",
     """
     ● 첫 번째 불릿입니다.

     ● 두 번째 불릿입니다.
     """),
    ("dollar-prompt-lines",
     """
     $ swift build
     Building for debugging...
     Build complete!
     """),
    ("claude-code-left-border-U258E",
     """
     의도 라우팅 레이어'를 한국에서
     \u{258E} 선점한다는 뜻인가요, 아니면 단순히 유저
     """),
    ("claude-code-left-border-every-line",
     """
     \u{258E} 참고하신 twocents.xyz 글의 실제 moat 주장은
     \u{258E} 빠른 스케일업이 아니라 의도 분배권(intent
     \u{258E} distribution rights) 선점입니다.
     """),
    ("claude-code-left-border-box-vertical",
     """
     한국에서 빠르게 성장하는 핵심은
     │ 의도 라우팅 레이어 선점입니다.
     """),
  ]

  print("\n\n===== PROBE RESULTS =====")
  for (name, input) in fixtures {
    let result = formatter.cleanPlainText(input)
    print("\n--- [\(name)] ---")
    print("INPUT:")
    print(input)
    print("OUTPUT:")
    print(result.cleanText)
  }
  print("===== END PROBE =====\n")
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
