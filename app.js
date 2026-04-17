import { formatPlainText, sanitizeRichHtml, summarizeMeta } from "./formatter.js";

const terminalSample = `➜ claude analyze --output report.md
Analyzing codebase structure...

Found 47 files across 8 modules

Key findings:
  - auth.ts has 3 potential security
issues
  - utils/format.ts lacks error
handling
  - 12 components missing
accessibility attributes

Recommendations:
  1. Add input validation to
login()
  2. Wrap format calls in
try/catch
  3. Add aria-labels to
interactive elements
`;

const htmlSample = `
  <div style="font-family: Inter; color: #1f2937; line-height: 1.8;">
    <h2 style="font-size: 20px;">Shipping summary</h2>
    <p>This came from a rich clipboard payload with <strong>inline styles</strong> and hidden characters\u200b.</p>
    <ul style="padding-left: 30px;">
      <li><span style="color: #0f766e;">Priority</span> items preserved</li>
      <li>Links stay linked: <a href="https://example.com" style="color: hotpink;">example.com</a></li>
    </ul>
    <table style="width: 100%; border-collapse: collapse;">
      <tr>
        <th style="background: #f3f4f6; border: 1px solid #ddd;">Route</th>
        <th style="background: #f3f4f6; border: 1px solid #ddd;">ETA</th>
      </tr>
      <tr>
        <td style="border: 1px solid #ddd;">Seoul</td>
        <td style="border: 1px solid #ddd;">2 days</td>
      </tr>
    </table>
  </div>
`;

const rawInput = document.querySelector("#raw-input");
const cleanOutput = document.querySelector("#clean-output");
const renderedPreview = document.querySelector("#rendered-preview");
const stats = document.querySelector("#stats");
const statusLine = document.querySelector("#status-line");
const pathBadge = document.querySelector("#path-badge");

const loadTerminalSampleButton = document.querySelector("#load-terminal-sample");
const loadHtmlSampleButton = document.querySelector("#load-html-sample");
const clearInputButton = document.querySelector("#clear-input");
const pasteFromClipboardButton = document.querySelector("#paste-from-clipboard");
const copyCleanTextButton = document.querySelector("#copy-clean-text");
const copyCleanHtmlButton = document.querySelector("#copy-clean-html");

let state = {
  path: "empty",
  cleanText: "",
  cleanHtml: "",
};

function setStatus(message) {
  statusLine.textContent = message;
}

function setStats(path, meta) {
  const chips = summarizeMeta(path, meta);
  stats.innerHTML = chips.map((chip) => `<span class="stat-chip">${chip}</span>`).join("");
}

function updatePreview(path, html) {
  pathBadge.textContent = path;
  if (!html) {
    renderedPreview.innerHTML = `
      <p class="preview-placeholder">
        Paste something messy and the cleaned rich preview will show up here.
      </p>
    `;
    return;
  }
  renderedPreview.innerHTML = html;
}

function cleanTextPayload(text) {
  const result = formatPlainText(text);
  return {
    path: "text",
    cleanText: result.cleanText,
    cleanHtml: result.html,
    meta: result.meta,
  };
}

function cleanHtmlPayload(html, fallbackText) {
  const sanitized = sanitizeRichHtml(html);
  const textResult = formatPlainText(fallbackText || sanitized.text);
  return {
    path: "html",
    cleanText: textResult.cleanText,
    cleanHtml: sanitized.html || textResult.html,
    meta: {
      ...textResult.meta,
      ...sanitized.meta,
    },
  };
}

function applyResult(result, message) {
  state = result;
  cleanOutput.value = result.cleanText;
  updatePreview(result.path, result.cleanHtml);
  setStats(result.path, result.meta);
  setStatus(message);
}

function processPayload({ text = "", html = "" }) {
  const hasHtml = html && /<[a-z][\s\S]*>/i.test(html);
  const hasText = text.trim().length > 0;

  if (!hasHtml && !hasText) {
    state = { path: "empty", cleanText: "", cleanHtml: "" };
    cleanOutput.value = "";
    updatePreview("waiting for input", "");
    stats.innerHTML = "";
    setStatus("Nothing to clean yet.");
    return;
  }

  if (hasHtml) {
    applyResult(
      cleanHtmlPayload(html, text),
      "Captured rich clipboard content and stripped noisy formatting.",
    );
    return;
  }

  applyResult(
    cleanTextPayload(text),
    "Cleaned plain text clipboard content and repaired wrapped lines where possible.",
  );
}

rawInput.addEventListener("input", () => {
  processPayload({ text: rawInput.value });
});

rawInput.addEventListener("paste", (event) => {
  const text = event.clipboardData?.getData("text/plain") || "";
  const html = event.clipboardData?.getData("text/html") || "";
  event.preventDefault();
  rawInput.value = text;
  processPayload({ text, html });
});

loadTerminalSampleButton.addEventListener("click", () => {
  rawInput.value = terminalSample;
  processPayload({ text: terminalSample });
});

loadHtmlSampleButton.addEventListener("click", () => {
  rawInput.value = "Loaded a rich HTML sample payload. Check the cleaned output and rendered preview.";
  processPayload({
    text:
      "Shipping summary\n\nThis came from a rich clipboard payload with inline styles and hidden characters.",
    html: htmlSample,
  });
});

clearInputButton.addEventListener("click", () => {
  rawInput.value = "";
  processPayload({ text: "" });
});

pasteFromClipboardButton.addEventListener("click", async () => {
  if (!navigator.clipboard) {
    setStatus("Clipboard API is not available in this browser. Use normal paste into the input box.");
    return;
  }

  try {
    if (typeof navigator.clipboard.read === "function") {
      const items = await navigator.clipboard.read();
      let text = "";
      let html = "";

      for (const item of items) {
        if (item.types.includes("text/html")) {
          const blob = await item.getType("text/html");
          html = await blob.text();
        }
        if (item.types.includes("text/plain")) {
          const blob = await item.getType("text/plain");
          text = await blob.text();
        }
      }

      rawInput.value = text;
      processPayload({ text, html });
      return;
    }

    const text = await navigator.clipboard.readText();
    rawInput.value = text;
    processPayload({ text });
  } catch (error) {
    setStatus(`Clipboard read failed: ${error.message}. Try manual paste instead.`);
  }
});

copyCleanTextButton.addEventListener("click", async () => {
  if (!state.cleanText) {
    setStatus("There is no cleaned text to copy yet.");
    return;
  }

  try {
    await navigator.clipboard.writeText(state.cleanText);
    setStatus("Copied cleaned plain text to the clipboard.");
  } catch (error) {
    setStatus(`Plain-text copy failed: ${error.message}`);
  }
});

copyCleanHtmlButton.addEventListener("click", async () => {
  if (!state.cleanHtml) {
    setStatus("There is no rich output to copy yet.");
    return;
  }

  try {
    if (typeof ClipboardItem === "function" && navigator.clipboard?.write) {
      await navigator.clipboard.write([
        new ClipboardItem({
          "text/plain": new Blob([state.cleanText], { type: "text/plain" }),
          "text/html": new Blob([state.cleanHtml], { type: "text/html" }),
        }),
      ]);
      setStatus("Copied cleaned rich HTML and plain text to the clipboard.");
      return;
    }

    await navigator.clipboard.writeText(state.cleanText);
    setStatus("Rich clipboard write is not supported here. Copied plain text instead.");
  } catch (error) {
    setStatus(`Rich copy failed: ${error.message}`);
  }
});

processPayload({ text: "" });
