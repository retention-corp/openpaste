import test from "node:test";
import assert from "node:assert/strict";

import { formatPlainText } from "../formatter.js";

test("joins wrapped paragraph lines", () => {
  const input = `This paragraph was wrapped by a terminal at eighty columns so the text\ncontinues on the next line even though it should read as one sentence.`;

  const result = formatPlainText(input);

  assert.equal(
    result.cleanText,
    "This paragraph was wrapped by a terminal at eighty columns so the text continues on the next line even though it should read as one sentence.",
  );
  assert.equal(result.meta.joinedLineBreaks, 1);
});

test("preserves and repairs list items", () => {
  const input = `Key findings:\n- auth.ts has 3 potential security\nissues\n- utils/format.ts lacks error\nhandling`;

  const result = formatPlainText(input);

  assert.match(result.cleanText, /- auth\.ts has 3 potential security issues/);
  assert.match(result.cleanText, /- utils\/format\.ts lacks error handling/);
  assert.equal(result.meta.listItems, 2);
});

test("renders pipe tables as html tables", () => {
  const input = `| Route | ETA |\n| --- | --- |\n| Seoul | 2 days |\n| Tokyo | 1 day |`;

  const result = formatPlainText(input);

  assert.match(result.html, /<table>/);
  assert.match(result.html, /<th>Route<\/th>/);
  assert.match(result.html, /<td>Tokyo<\/td>/);
  assert.equal(result.meta.tables, 1);
});
