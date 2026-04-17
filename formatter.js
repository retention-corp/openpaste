function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function stripInvisibleCharacters(input) {
  let zeroWidthRemoved = 0;
  const normalized = input.replace(/[\u200b-\u200f\u2060\ufeff]/g, () => {
    zeroWidthRemoved += 1;
    return "";
  });
  return { normalized, zeroWidthRemoved };
}

function normalizeInput(input) {
  const withUnixLines = input.replace(/\r\n?/g, "\n").replace(/\u00a0/g, " ");
  const { normalized, zeroWidthRemoved } = stripInvisibleCharacters(withUnixLines);
  return { text: normalized, zeroWidthRemoved };
}

function trimTrailingWhitespace(lines) {
  return lines.map((line) => line.replace(/[ \t]+$/g, ""));
}

function lineLengthWithoutIndent(line) {
  return line.trimEnd().length;
}

function detectWrapWidth(lines) {
  const histogram = new Map();

  for (const line of lines) {
    if (!line.trim()) {
      continue;
    }
    if (isListItem(line) || isTableLine(line) || isFenceLine(line)) {
      continue;
    }
    const width = lineLengthWithoutIndent(line);
    if (width < 72 || width > 140) {
      continue;
    }
    histogram.set(width, (histogram.get(width) || 0) + 1);
  }

  let bestWidth = 96;
  let bestCount = 0;

  for (const [width, count] of histogram.entries()) {
    if (count > bestCount) {
      bestWidth = width;
      bestCount = count;
    }
  }

  return { width: bestWidth, confidence: bestCount };
}

function isFenceLine(line) {
  return /^\s*(```|~~~)/.test(line);
}

function isListItem(line) {
  return /^\s*(?:[-*•]|\d+[.)])\s+/.test(line);
}

function isOrderedListItem(line) {
  return /^\s*\d+[.)]\s+/.test(line);
}

function isTableLine(line) {
  return /\|/.test(line);
}

function isTableSeparator(line) {
  return /^\s*\|?(?:\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$/.test(line);
}

function looksLikeSectionLabel(line) {
  return /^[A-Z][\w /()-]+:$/.test(line.trim());
}

function paragraphJoiner(previous, next, wrapWidth) {
  if (!previous) {
    return false;
  }

  if (!next) {
    return false;
  }

  if (/[.!?]$/.test(previous) && /^[A-Z]/.test(next)) {
    return false;
  }

  if (previous.endsWith(":")) {
    return true;
  }

  if (previous.endsWith("-") && /^[A-Za-z]/.test(next)) {
    return true;
  }

  if (/^[,.;:)\]]/.test(next)) {
    return true;
  }

  if (/^[a-z0-9(]/.test(next)) {
    return true;
  }

  return previous.length >= wrapWidth - 8;
}

function joinParagraphLines(lines, meta, wrapWidth) {
  if (!lines.length) {
    return "";
  }

  let current = lines[0].trim();

  for (let index = 1; index < lines.length; index += 1) {
    const next = lines[index].trim();
    if (!next) {
      continue;
    }

    if (paragraphJoiner(current, next, wrapWidth)) {
      if (current.endsWith("-") && /^[A-Za-z]/.test(next)) {
        current = `${current.slice(0, -1)}${next}`;
      } else {
        current = `${current} ${next}`;
      }
      meta.joinedLineBreaks += 1;
      continue;
    }

    current = `${current}\n\n${next}`;
  }

  return current;
}

function normalizeListBlock(lines, meta, ordered) {
  const items = [];
  let current = null;

  for (const line of lines) {
    const raw = line.trimEnd();
    if (!raw.trim()) {
      continue;
    }

    const listMatch = raw.match(/^\s*((?:[-*•])|(?:\d+[.)]))\s+(.*)$/);
    if (listMatch) {
      if (current) {
        items.push(current);
      }
      current = {
        marker: listMatch[1],
        text: listMatch[2].trim(),
      };
      meta.listItems += 1;
      continue;
    }

    if (!current) {
      current = { marker: ordered ? "1." : "-", text: raw.trim() };
      meta.listItems += 1;
      continue;
    }

    const continuation = raw.trim();
    if (continuation) {
      current.text = `${current.text} ${continuation}`;
      meta.joinedLineBreaks += 1;
    }
  }

  if (current) {
    items.push(current);
  }

  return {
    type: ordered ? "ol" : "ul",
    items: items.map((item, index) => ({
      marker: ordered ? `${index + 1}.` : "-",
      text: item.text,
    })),
  };
}

function normalizeTableBlock(lines, meta) {
  const cleaned = lines
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const withoutEdges = line.replace(/^\|/, "").replace(/\|$/, "");
      return withoutEdges
        .split("|")
        .map((cell) => cell.trim())
        .join(" | ");
    });

  meta.tables += 1;
  return {
    type: "table",
    lines: cleaned,
  };
}

function normalizeFenceBlock(lines) {
  return {
    type: "code",
    text: lines.join("\n"),
  };
}

function normalizeParagraphBlock(lines, meta, wrapWidth) {
  return {
    type: "paragraph",
    text: joinParagraphLines(lines, meta, wrapWidth),
  };
}

function parseBlocks(lines, meta, wrapWidth) {
  const blocks = [];

  for (let index = 0; index < lines.length; ) {
    const line = lines[index];

    if (!line.trim()) {
      index += 1;
      continue;
    }

    if (isFenceLine(line)) {
      const chunk = [line];
      index += 1;
      while (index < lines.length) {
        chunk.push(lines[index]);
        if (isFenceLine(lines[index])) {
          index += 1;
          break;
        }
        index += 1;
      }
      blocks.push(normalizeFenceBlock(chunk));
      continue;
    }

    if (
      index + 1 < lines.length &&
      isTableLine(line) &&
      isTableSeparator(lines[index + 1])
    ) {
      const tableLines = [];
      while (index < lines.length && lines[index].trim()) {
        tableLines.push(lines[index]);
        index += 1;
      }
      blocks.push(normalizeTableBlock(tableLines, meta));
      continue;
    }

    if (isListItem(line)) {
      const ordered = isOrderedListItem(line);
      const listLines = [];
      while (index < lines.length) {
        const current = lines[index];
        if (!current.trim()) {
          break;
        }
        if (
          isListItem(current) ||
          /^\s{2,}\S/.test(current.trimEnd()) ||
          (!isFenceLine(current) &&
            !looksLikeSectionLabel(current) &&
            !(isTableLine(current) &&
              index + 1 < lines.length &&
              isTableSeparator(lines[index + 1])))
        ) {
          listLines.push(current);
          index += 1;
          continue;
        }
        break;
      }
      blocks.push(normalizeListBlock(listLines, meta, ordered));
      continue;
    }

    const paragraphLines = [];
    while (index < lines.length) {
      const current = lines[index];
      if (!current.trim()) {
        break;
      }
      if (
        paragraphLines.length &&
        (isFenceLine(current) ||
          isListItem(current) ||
          (isTableLine(current) &&
            index + 1 < lines.length &&
            isTableSeparator(lines[index + 1])))
      ) {
        break;
      }
      paragraphLines.push(current);
      index += 1;
    }
    blocks.push(normalizeParagraphBlock(paragraphLines, meta, wrapWidth));
  }

  return blocks;
}

function blocksToText(blocks) {
  return blocks
    .map((block) => {
      if (block.type === "paragraph" || block.type === "code") {
        return block.text;
      }
      if (block.type === "table") {
        return block.lines.join("\n");
      }
      if (block.type === "ul" || block.type === "ol") {
        return block.items
          .map((item, index) => {
            if (block.type === "ol") {
              return `${index + 1}. ${item.text}`;
            }
            return `- ${item.text}`;
          })
          .join("\n");
      }
      return "";
    })
    .filter(Boolean)
    .join("\n\n");
}

function tableLinesToHtml(lines) {
  const rows = lines.map((line) =>
    line.split("|").map((cell) => escapeHtml(cell.trim())),
  );

  if (rows.length < 2) {
    return `<pre>${escapeHtml(lines.join("\n"))}</pre>`;
  }

  const [headerRow, ...rest] = rows;
  const bodyRows = isTableSeparator(rest[0].join(" | ")) ? rest.slice(1) : rest;

  const headHtml = headerRow.map((cell) => `<th>${cell}</th>`).join("");
  const bodyHtml = bodyRows
    .map((row) => `<tr>${row.map((cell) => `<td>${cell}</td>`).join("")}</tr>`)
    .join("");

  return `
    <table>
      <thead><tr>${headHtml}</tr></thead>
      <tbody>${bodyHtml}</tbody>
    </table>
  `.trim();
}

function blocksToHtml(blocks) {
  return blocks
    .map((block) => {
      if (block.type === "paragraph") {
        const paragraphs = block.text
          .split(/\n{2,}/)
          .map((paragraph) => paragraph.trim())
          .filter(Boolean)
          .map((paragraph) => `<p>${escapeHtml(paragraph)}</p>`);
        return paragraphs.join("");
      }

      if (block.type === "code") {
        return `<pre><code>${escapeHtml(block.text)}</code></pre>`;
      }

      if (block.type === "table") {
        return tableLinesToHtml(block.lines);
      }

      if (block.type === "ul" || block.type === "ol") {
        const tag = block.type;
        const items = block.items.map((item) => `<li>${escapeHtml(item.text)}</li>`).join("");
        return `<${tag}>${items}</${tag}>`;
      }

      return "";
    })
    .join("");
}

export function formatPlainText(input) {
  const baseMeta = {
    zeroWidthRemoved: 0,
    joinedLineBreaks: 0,
    listItems: 0,
    tables: 0,
    wrapWidth: 96,
    wrapConfidence: 0,
  };

  if (!input.trim()) {
    return {
      cleanText: "",
      html: "",
      meta: baseMeta,
    };
  }

  const { text, zeroWidthRemoved } = normalizeInput(input);
  const lines = trimTrailingWhitespace(text.split("\n"));
  const wrap = detectWrapWidth(lines);
  const meta = {
    ...baseMeta,
    zeroWidthRemoved,
    wrapWidth: wrap.width,
    wrapConfidence: wrap.confidence,
  };
  const blocks = parseBlocks(lines, meta, wrap.width);

  return {
    cleanText: blocksToText(blocks),
    html: blocksToHtml(blocks),
    meta,
  };
}

export function sanitizeRichHtml(html) {
  if (typeof DOMParser === "undefined" || typeof document === "undefined") {
    throw new Error("sanitizeRichHtml requires a browser-like DOM environment");
  }

  const parser = new DOMParser();
  const documentFragment = parser.parseFromString(html, "text/html");
  const root = documentFragment.body;
  const meta = {
    strippedStyles: 0,
    zeroWidthRemoved: 0,
    removedNodes: 0,
  };

  root.querySelectorAll("script, style, meta, link, noscript").forEach((node) => {
    meta.removedNodes += 1;
    node.remove();
  });

  for (const element of root.querySelectorAll("*")) {
    if (element.hasAttribute("style")) {
      meta.strippedStyles += 1;
    }
    [...element.attributes].forEach((attribute) => {
      if (attribute.name === "href" || attribute.name === "colspan" || attribute.name === "rowspan") {
        return;
      }
      element.removeAttribute(attribute.name);
    });
  }

  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let current = walker.nextNode();
  while (current) {
    const { normalized, zeroWidthRemoved } = stripInvisibleCharacters(current.textContent || "");
    current.textContent = normalized.replace(/\s+\n/g, "\n");
    meta.zeroWidthRemoved += zeroWidthRemoved;
    current = walker.nextNode();
  }

  return {
    html: root.innerHTML.trim(),
    text: root.textContent || "",
    meta,
  };
}

export function summarizeMeta(path, meta) {
  const chips = [
    `path: ${path}`,
    `wrap: ${meta.wrapWidth} cols`,
  ];

  if (meta.joinedLineBreaks) {
    chips.push(`joined: ${meta.joinedLineBreaks}`);
  }

  if (meta.listItems) {
    chips.push(`list items: ${meta.listItems}`);
  }

  if (meta.tables) {
    chips.push(`tables: ${meta.tables}`);
  }

  if (meta.zeroWidthRemoved) {
    chips.push(`zero-width removed: ${meta.zeroWidthRemoved}`);
  }

  if (meta.strippedStyles) {
    chips.push(`styles stripped: ${meta.strippedStyles}`);
  }

  return chips;
}
