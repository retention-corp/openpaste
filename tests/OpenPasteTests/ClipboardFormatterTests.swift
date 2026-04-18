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

private struct BulkFixture {
  let category: String
  let name: String
  let input: String
  let mustContain: [String]
  let mustNotContain: [String]
}

private func buildBulk100Fixtures() -> [BulkFixture] {
  var all: [BulkFixture] = []

  // 1. Korean connective-particle wrap (10)
  let koreanPairs: [(String, String, String)] = [
    ("particle-을", "이 책을", "읽고 싶습니다."),
    ("particle-를", "그 영화를", "보고 나서 후기를 남겼다."),
    ("particle-이", "이 문제가 심각해지고 있어서 팀에서 이", "해결책을 논의 중이다."),
    ("particle-가", "결과가", "나올 때까지 기다리겠습니다."),
    ("particle-는", "저는", "커피를 좋아합니다."),
    ("particle-은", "사과는 빨갛고 바나나는", "노랗습니다."),
    ("particle-의", "우리의", "미래를 함께 만들어갑시다."),
    ("particle-와", "너와", "나의 이야기는 여기서 시작된다."),
    ("particle-에", "서울에", "도착했습니다."),
    ("particle-고", "밥을 먹고", "커피를 마셨습니다."),
  ]
  for (name, a, b) in koreanPairs {
    all.append(BulkFixture(category: "korean-wrap", name: name,
                           input: "\(a)\n\(b)",
                           mustContain: ["\(a) \(b)"],
                           mustNotContain: ["\(a)\n\(b)"]))
  }

  // 2. Korean + inline English/code/URL wrap (10)
  let mixed: [(String, String)] = [
    ("mixed-code-func",
     "`ClipboardFormatter.cleanPlainText(...)` 함수는\n한국어 wrap을 복구한다."),
    ("mixed-uuid",
     "Session 019d93da-5d5a-\n7973-b09a-379bda59eeb5 ended."),
    ("mixed-path",
     "cd /Users/gyusupsim/Projects/products/\ncoupang_partners && echo done"),
    ("mixed-version",
     "Swift v5.10.\n1 이상에서 빌드합니다."),
    ("mixed-url-scheme",
     "링크는 https:\n//github.com/retention-corp/openpaste 에 있다."),
    ("mixed-dashed-identifier",
     "error-\nhandling 관련 코드를 수정했다."),
    ("mixed-underscore",
     "변수명 foo_\nbar_baz 는 기존 스타일을 따른다."),
    ("mixed-slash-path",
     "파일 src/utils/\nformatter.swift 를 열어 수정했다."),
    ("mixed-eng-kor-boundary",
     "This is English text followed by 한국어\n문장이 mixed together."),
    ("mixed-backtick-korean",
     "`isListItem` 함수는 `[-*•●]` 패턴과\n번호 매긴 리스트를 모두 매칭한다."),
  ]
  for (name, input) in mixed {
    all.append(BulkFixture(category: "mixed", name: name,
                           input: input,
                           mustContain: [],
                           mustNotContain: ["\n\n"]))
  }

  // 3. ● bullet variations (10)
  all.append(BulkFixture(category: "bullet", name: "black-circle-3",
                         input: "● apple\n● banana\n● cherry",
                         mustContain: ["- apple", "- banana", "- cherry"],
                         mustNotContain: ["●"]))
  all.append(BulkFixture(category: "bullet", name: "bullet-wrap-particle",
                         input: "● 구조화된 인터뷰를 통해 수익 확장 플랜의 요구사항을\n\n명확히 하겠습니다.",
                         mustContain: ["요구사항을 명확히"],
                         mustNotContain: ["\n\n"]))
  all.append(BulkFixture(category: "bullet", name: "bullet-terminated-gap",
                         input: "● 첫 번째 불릿은 완성된 문장입니다.\n\n이건 별개 단락이어야 합니다.",
                         mustContain: ["- 첫 번째 불릿은 완성된 문장입니다.", "이건 별개 단락이어야 합니다."],
                         mustNotContain: ["첫 번째 불릿은 완성된 문장입니다. 이건"]))
  all.append(BulkFixture(category: "bullet", name: "bullet-eng-lowercase-continuation",
                         input: "● This is an English bullet that was wrapped\n\ncontinuing on this line in lowercase.",
                         mustContain: ["continuing on this line in lowercase."],
                         mustNotContain: ["wrapped\n\ncontinuing"]))
  all.append(BulkFixture(category: "bullet", name: "bullet-eng-capital-new-para",
                         input: "● Buy groceries\n\nRemember to pick up the kids.",
                         mustContain: ["- Buy groceries", "Remember to pick up the kids."],
                         mustNotContain: ["Buy groceries Remember"]))
  all.append(BulkFixture(category: "bullet", name: "bullets-gap-same-type",
                         input: "● 첫 번째\n\n● 두 번째\n\n● 세 번째",
                         mustContain: ["- 첫 번째\n- 두 번째\n- 세 번째"],
                         mustNotContain: ["\n\n"]))
  all.append(BulkFixture(category: "bullet", name: "dash-marker",
                         input: "- first\n- second\n- third",
                         mustContain: ["- first", "- second", "- third"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "bullet", name: "asterisk-marker",
                         input: "* first\n* second",
                         mustContain: ["first", "second"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "bullet", name: "mid-bullet-U2022",
                         input: "• first\n• second",
                         mustContain: ["first", "second"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "bullet", name: "nested-bullets",
                         input: "● 상위 불릿입니다.\n  ● 하위 불릿에서 한국어가 길어서\n    다음 줄로 이어집니다.",
                         mustContain: ["하위 불릿에서 한국어가 길어서 다음 줄로 이어집니다."],
                         mustNotContain: []))

  // 4. Numbered lists (10)
  all.append(BulkFixture(category: "numbered", name: "numbered-wrap-blank",
                         input: "1. 구조화된 인터뷰를 통해 수익 확장 플랜의 요구사항을\n\n명확히 하겠습니다.\n2. 다음 단계.",
                         mustContain: ["1. 구조화된 인터뷰를 통해 수익 확장 플랜의 요구사항을 명확히 하겠습니다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "numbered", name: "numbered-paren",
                         input: "1) first\n2) second\n3) third",
                         mustContain: ["first", "second", "third"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "numbered", name: "numbered-short-eng",
                         input: "1. apple\n2. banana\n3. cherry",
                         mustContain: ["1. apple", "2. banana", "3. cherry"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "numbered", name: "numbered-korean",
                         input: "1. 첫 번째 항목\n2. 두 번째 항목\n3. 세 번째 항목",
                         mustContain: ["1. 첫 번째 항목"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "numbered", name: "numbered-nested-indent",
                         input: "1. 첫째 항목은 이렇게 길게 이어집니다\n   하위 설명이 들여쓰기로 붙습니다.\n2. 둘째 항목.",
                         mustContain: ["1. 첫째 항목은 이렇게 길게 이어집니다 하위 설명이 들여쓰기로 붙습니다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "numbered", name: "numbered-doubledigit",
                         input: "10. tenth\n11. eleventh\n12. twelfth",
                         mustContain: ["10. tenth", "11. eleventh", "12. twelfth"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "numbered", name: "numbered-gap",
                         input: "1. 첫째 항목입니다.\n\n2. 둘째 항목입니다.",
                         mustContain: ["1. 첫째 항목입니다.\n2. 둘째 항목입니다."],
                         mustNotContain: ["1. 첫째 항목입니다.\n\n2."]))
  all.append(BulkFixture(category: "numbered", name: "numbered-wrap-url",
                         input: "1. 참고 링크: https://github.com/retention-corp/open\npaste/issues/1",
                         mustContain: ["https://github.com/retention-corp/openpaste/issues/1"],
                         mustNotContain: ["open paste"]))
  all.append(BulkFixture(category: "numbered", name: "numbered-connective-wrap",
                         input: "1. 이번 항목은 한국어 문장이\n   길어서 다음 줄로 넘어간다.",
                         mustContain: ["한국어 문장이 길어서 다음 줄로 넘어간다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "numbered", name: "numbered-mixed-markers",
                         input: "1. first\n- sub item\n2. second",
                         mustContain: ["first", "second"],
                         mustNotContain: []))

  // 5. Claude Code left-border characters (10)
  all.append(BulkFixture(category: "left-border", name: "U258E-single-line",
                         input: "의도 라우팅 레이어를 한국에서\n\u{258E} 선점한다.",
                         mustContain: ["한국에서 선점한다."],
                         mustNotContain: ["\u{258E}"]))
  all.append(BulkFixture(category: "left-border", name: "U258E-every-line",
                         input: "\u{258E} 참고하신 글의 실제\n\u{258E} moat 주장은 의도 분배권\n\u{258E} 선점입니다.",
                         mustContain: ["참고하신 글의 실제 moat 주장은 의도 분배권 선점입니다."],
                         mustNotContain: ["\u{258E}"]))
  all.append(BulkFixture(category: "left-border", name: "U258F-single",
                         input: "이 문장은 길어서 다음 줄로 이어지고\n\u{258F} 마지막에 마침표가 온다.",
                         mustContain: ["이 문장은 길어서 다음 줄로 이어지고 마지막에 마침표가 온다."],
                         mustNotContain: ["\u{258F}"]))
  all.append(BulkFixture(category: "left-border", name: "U258D-three-eighths",
                         input: "첫 줄이고\n\u{258D} 두 번째 줄.",
                         mustContain: ["첫 줄이고 두 번째 줄."],
                         mustNotContain: ["\u{258D}"]))
  all.append(BulkFixture(category: "left-border", name: "U258C-half",
                         input: "첫 줄이며\n\u{258C} 두 번째 줄.",
                         mustContain: ["첫 줄이며 두 번째 줄."],
                         mustNotContain: ["\u{258C}"]))
  all.append(BulkFixture(category: "left-border", name: "box-vertical-solo",
                         input: "한국에서 빠르게 성장하는 핵심은\n│ 의도 라우팅 레이어 선점입니다.",
                         mustContain: ["한국에서 빠르게 성장하는 핵심은 의도 라우팅 레이어 선점입니다."],
                         mustNotContain: ["│"]))
  all.append(BulkFixture(category: "left-border", name: "tree-preserved",
                         input: "Sources\n├── OpenPaste\n│   ├── AppDelegate.swift\n│   └── ClipboardFormatter.swift\n└── tests",
                         mustContain: ["│   ├── AppDelegate.swift", "│   └── ClipboardFormatter.swift"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "left-border", name: "U258E-with-leading-ws",
                         input: "앞 줄 끝에는\n  \u{258E} 뒤 줄 시작.",
                         mustContain: ["앞 줄 끝에는 뒤 줄 시작."],
                         mustNotContain: ["\u{258E}"]))
  all.append(BulkFixture(category: "left-border", name: "double-U258E",
                         input: "첫 줄이고\n\u{258E}\u{258E} 두 번째 줄.",
                         mustContain: ["첫 줄이고 두 번째 줄."],
                         mustNotContain: ["\u{258E}"]))
  all.append(BulkFixture(category: "left-border", name: "mixed-border-and-bullet",
                         input: "● 불릿 시작이고\n\u{258E} 같은 불릿의 wrap 계속.",
                         mustContain: ["불릿 시작이고 같은 불릿의 wrap 계속."],
                         mustNotContain: ["\u{258E}"]))

  // 6. Claude Code tool markers (10)
  all.append(BulkFixture(category: "tool-marker", name: "circle-filled-bash",
                         input: "⏺ Bash(swift test)\n  ⎿ Test Suite 'All tests' passed\n    Executed 41 tests",
                         mustContain: ["⏺ Bash(swift test)", "⎿ Test Suite 'All tests' passed"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "tool-marker", name: "read-tool",
                         input: "⏺ Read(ClipboardFormatter.swift)\n  ⎿ 877 lines",
                         mustContain: ["⏺ Read(ClipboardFormatter.swift)", "⎿ 877 lines"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "tool-marker", name: "edit-tool",
                         input: "⏺ Edit(Sources/App.swift)\n  ⎿ 1 file changed",
                         mustContain: ["⏺ Edit(Sources/App.swift)", "⎿ 1 file changed"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "tool-marker", name: "multi-output-lines",
                         input: "⏺ Bash(ls -la)\n  ⎿ total 8\n    drwxr-xr-x  3 user  staff   96 Apr 18 18:00 .\n    drwxr-xr-x 18 user  staff  576 Apr 18 17:54 ..",
                         mustContain: ["⎿ total 8", "drwxr-xr-x"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "tool-marker", name: "thinking-indicator",
                         input: "✻ Thinking…\n\nLet me check the code.",
                         mustContain: ["✻ Thinking…", "Let me check the code."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "tool-marker", name: "round-label",
                         input: "● Round 7\n\n  참고하신 글의 실제 주장은 A입니다.",
                         mustContain: ["- Round 7", "참고하신 글의 실제 주장은 A입니다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "tool-marker", name: "recap-marker",
                         input: "※recap: 목표는 OpenPaste 확장입니다.\n\n(disable recaps in /config)",
                         mustContain: ["recap:", "(disable recaps in /config)"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "tool-marker", name: "worked-for-line",
                         input: "* Worked for 1m 17s",
                         mustContain: ["Worked for 1m 17s"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "tool-marker", name: "circle-wrap",
                         input: "⏺ Bash(git log --oneline)\n  ⎿ abc123 initial commit\n    def456 add feature",
                         mustContain: ["⎿ abc123 initial commit", "def456 add feature"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "tool-marker", name: "indented-sub-outputs",
                         input: "⏺ Task(Explore codebase)\n  ⎿ Searched 45 files\n  ⎿ Found 12 matches",
                         mustContain: ["⎿ Searched 45 files", "⎿ Found 12 matches"],
                         mustNotContain: []))

  // 7. Code blocks + inline code (10)
  all.append(BulkFixture(category: "code", name: "fenced-no-lang",
                         input: "다음은 예시:\n```\nlet x = 1\n```\n설명이 이어진다.",
                         mustContain: ["```", "let x = 1", "설명이 이어진다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "code", name: "fenced-swift",
                         input: "예시:\n```swift\nlet x = 1\n```",
                         mustContain: ["```swift", "let x = 1"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "code", name: "fenced-bash",
                         input: "```bash\nswift test\nswift build\n```",
                         mustContain: ["```bash", "swift test", "swift build"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "code", name: "inline-backtick",
                         input: "`foo()` 를 호출하면\n`bar()` 가 실행된다.",
                         mustContain: ["`foo()` 를 호출하면 `bar()` 가 실행된다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "code", name: "inline-long",
                         input: "`ClipboardFormatter.cleanPlainText(...)` 는 한국어\nwrap을 복구한다.",
                         mustContain: ["`ClipboardFormatter.cleanPlainText(...)` 는 한국어 wrap을 복구한다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "code", name: "fence-wrap-prose",
                         input: "다음은 코드:\n```\ncode\n```\n한국어 설명 문장이 wrap되어\n다음 줄로 이어진다.",
                         mustContain: ["한국어 설명 문장이 wrap되어 다음 줄로 이어진다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "code", name: "empty-fence",
                         input: "빈 fence:\n```\n```\n끝.",
                         mustContain: ["```", "끝."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "code", name: "multi-fence",
                         input: "```\nfirst\n```\n중간 문장.\n```\nsecond\n```",
                         mustContain: ["first", "second", "중간 문장."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "code", name: "fence-with-korean",
                         input: "```\n// 한국어 주석\nprint(\"안녕\")\n```",
                         mustContain: ["한국어 주석", "print(\"안녕\")"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "code", name: "tilde-fence",
                         input: "~~~\ncode\n~~~",
                         mustContain: ["code"],
                         mustNotContain: []))

  // 8. Pipe tables (10)
  all.append(BulkFixture(category: "table", name: "simple-en",
                         input: "| a | b |\n| --- | --- |\n| 1 | 2 |",
                         mustContain: ["a", "b", "1", "2"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "table", name: "korean-table",
                         input: "| 항목 | 결과 |\n| --- | --- |\n| 테스트 | 통과 |\n| 빌드 | 성공 |",
                         mustContain: ["항목", "결과", "테스트", "통과", "빌드", "성공"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "table", name: "left-align",
                         input: "| a | b |\n| :--- | :--- |\n| 1 | 2 |",
                         mustContain: ["1", "2"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "table", name: "right-align",
                         input: "| a | b |\n| ---: | ---: |\n| 1 | 2 |",
                         mustContain: ["1", "2"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "table", name: "center-align",
                         input: "| a | b |\n| :---: | :---: |\n| 1 | 2 |",
                         mustContain: ["1", "2"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "table", name: "no-outer-pipe",
                         input: "a | b\n--- | ---\n1 | 2",
                         mustContain: ["a", "b", "1", "2"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "table", name: "three-col",
                         input: "| a | b | c |\n| --- | --- | --- |\n| 1 | 2 | 3 |",
                         mustContain: ["1", "2", "3"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "table", name: "table-with-code",
                         input: "| 함수 | 설명 |\n| --- | --- |\n| `foo()` | 실행 |",
                         mustContain: ["foo()", "실행"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "table", name: "numeric-table",
                         input: "| metric | value |\n| --- | --- |\n| latency | 120ms |\n| throughput | 500rps |",
                         mustContain: ["latency", "120ms", "throughput", "500rps"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "table", name: "table-after-text",
                         input: "표는 아래와 같다:\n| a | b |\n| --- | --- |\n| 1 | 2 |",
                         mustContain: ["표는 아래와 같다:", "1", "2"],
                         mustNotContain: []))

  // 9. URLs / paths / IDs (10)
  all.append(BulkFixture(category: "url-id", name: "url-wrap-path",
                         input: "링크: https://github.com/retention-corp/open\npaste/issues/1 참고.",
                         mustContain: ["https://github.com/retention-corp/openpaste/issues/1"],
                         mustNotContain: ["open paste"]))
  all.append(BulkFixture(category: "url-id", name: "url-wrap-query",
                         input: "https://example.com/search?q=\nhello&lang=ko",
                         mustContain: ["https://example.com/search?q=hello&lang=ko"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "url-id", name: "uuid-dash-wrap",
                         input: "Session 019d93da-5d5a-\n7973-b09a-379bda59eeb5 ended.",
                         mustContain: ["019d93da-5d5a-7973-b09a-379bda59eeb5"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "url-id", name: "path-slash-wrap",
                         input: "cd /Users/gyusupsim/Projects/products/\ncoupang_partners",
                         mustContain: ["/Users/gyusupsim/Projects/products/coupang_partners"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "url-id", name: "version-dot-wrap",
                         input: "Swift v5.10.\n1 release notes.",
                         mustContain: ["v5.10.1"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "url-id", name: "email-preserved",
                         input: "연락처: simpsonkorea@gmail.com 입니다.",
                         mustContain: ["simpsonkorea@gmail.com"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "url-id", name: "ssh-command",
                         input: "ssh user@host.example.com 으로\n접속할 수 있다.",
                         mustContain: ["ssh user@host.example.com 으로 접속할 수 있다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "url-id", name: "double-colon-cpp",
                         input: "std::vector<int> v;\n정렬해서 출력한다.",
                         mustContain: ["std::vector<int> v;"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "url-id", name: "underscore-wrap",
                         input: "함수 foo_\nbar_baz 를 호출한다.",
                         mustContain: ["foo_bar_baz"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "url-id", name: "http-scheme-wrap",
                         input: "링크 http:\n//legacy.example.com/resource 도 확인.",
                         mustContain: ["http://legacy.example.com/resource"],
                         mustNotContain: []))

  // 10. Terminal noise / special chars (10)
  all.append(BulkFixture(category: "noise", name: "trailing-spaces",
                         input: "이 줄 끝에는 공백이 붙어있고   \n다음 줄로 이어지는 문장입니다.",
                         mustContain: ["이 줄 끝에는 공백이 붙어있고 다음 줄로 이어지는 문장입니다."],
                         mustNotContain: []))
  all.append(BulkFixture(category: "noise", name: "zero-width-space",
                         input: "앞에 zero-width가\u{200B} 붙은\n뒤 줄 내용.",
                         mustContain: ["앞에 zero-width가 붙은 뒤 줄 내용."],
                         mustNotContain: ["\u{200B}"]))
  all.append(BulkFixture(category: "noise", name: "bom-prefix",
                         input: "\u{FEFF}첫 줄입니다\n두 번째 줄.",
                         mustContain: ["첫 줄입니다"],
                         mustNotContain: ["\u{FEFF}"]))
  all.append(BulkFixture(category: "noise", name: "crlf-endings",
                         input: "이 문서는 긴 Windows 스타일\r\n엔딩을 가진 문장입니다.",
                         mustContain: ["이 문서는 긴 Windows 스타일 엔딩을 가진 문장입니다."],
                         mustNotContain: ["\r"]))
  all.append(BulkFixture(category: "noise", name: "ansi-color-strip",
                         input: "\u{001B}[31m빨간 에러 메시지\u{001B}[0m가 포함된\n터미널 출력.",
                         mustContain: ["빨간 에러 메시지가 포함된 터미널 출력."],
                         mustNotContain: ["\u{001B}"]))
  all.append(BulkFixture(category: "noise", name: "heredoc-cat",
                         input: "upsim@host> cat <<'EOF'\n- 원래 40~45% 베이스라인은\n시스템 기준이었습니다.\nEOF",
                         mustContain: ["원래 40~45% 베이스라인은"],
                         mustNotContain: ["cat <<'EOF'", "EOF"]))
  all.append(BulkFixture(category: "noise", name: "clipboard-helper-line",
                         input: "Clipboard has 3 lines → cf (one-line) or cp (keep structure)\n실제 내용 첫 줄\n실제 내용 둘째 줄.",
                         mustContain: ["실제 내용"],
                         mustNotContain: ["Clipboard has 3 lines"]))
  all.append(BulkFixture(category: "noise", name: "dollar-prompt-block",
                         input: "$ swift build\nBuilding for debugging...\nBuild complete!",
                         mustContain: ["$ swift build\nBuilding for debugging...\nBuild complete!"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "noise", name: "shell-prompt-arrow",
                         input: "~/Projects ❯ swift test\nTest Suite 'All tests' passed",
                         mustContain: ["❯", "Test Suite 'All tests' passed"],
                         mustNotContain: []))
  all.append(BulkFixture(category: "noise", name: "multiple-blank-lines",
                         input: "첫 단락이 여기 있고.\n\n\n\n두 번째 단락이 여기 있다.",
                         mustContain: ["첫 단락이 여기 있고.", "두 번째 단락이 여기 있다."],
                         mustNotContain: ["\n\n\n"]))

  return all
}

@Test func bulk100ScenarioAudit() async throws {
  let formatter = ClipboardFormatter()
  let fixtures = buildBulk100Fixtures()
  #expect(fixtures.count == 100)

  var failures: [String] = []
  var byCategory: [String: Int] = [:]
  var categoryFails: [String: Int] = [:]

  for fx in fixtures {
    byCategory[fx.category, default: 0] += 1
    let result = formatter.cleanPlainText(fx.input)
    let output = result.cleanText

    var violations: [String] = []
    for expected in fx.mustContain {
      if !output.contains(expected) {
        violations.append("missing: \(expected.debugDescription)")
      }
    }
    for forbidden in fx.mustNotContain {
      if output.contains(forbidden) {
        violations.append("forbidden present: \(forbidden.debugDescription)")
      }
    }

    if !violations.isEmpty {
      categoryFails[fx.category, default: 0] += 1
      failures.append("[\(fx.category)/\(fx.name)]\n  INPUT: \(fx.input.debugDescription)\n  OUTPUT: \(output.debugDescription)\n  VIOLATIONS: \(violations.joined(separator: "; "))")
    }
  }

  print("\n===== BULK 100 AUDIT =====")
  print("Categories: \(byCategory.count); total fixtures: \(fixtures.count)")
  for (cat, count) in byCategory.sorted(by: { $0.key < $1.key }) {
    let fails = categoryFails[cat] ?? 0
    print("  \(cat): \(count - fails)/\(count) passed")
  }
  print("Total failures: \(failures.count)")
  if !failures.isEmpty {
    print("\n--- FAILURES ---")
    for f in failures {
      print(f)
      print("")
    }
  }
  print("===== END BULK 100 AUDIT =====\n")

  #expect(failures.isEmpty)
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
