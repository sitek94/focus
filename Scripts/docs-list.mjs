#!/usr/bin/env node
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const DOCS_DIR = join(dirname(fileURLToPath(import.meta.url)), "..", "docs");
const EXCLUDED_DIRS = new Set(["archive", "research"]);

function walkMarkdownFiles(dir, base = dir) {
  const entries = readdirSync(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if (entry.name.startsWith(".")) continue;
    const fullPath = join(dir, entry.name);

    if (entry.isDirectory()) {
      if (EXCLUDED_DIRS.has(entry.name)) continue;
      files.push(...walkMarkdownFiles(fullPath, base));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(relative(base, fullPath));
    }
  }

  return files.sort((a, b) => a.localeCompare(b));
}

function extractMetadata(fullPath) {
  const content = readFileSync(fullPath, "utf8");

  if (!content.startsWith("---")) {
    return { summary: null, readWhen: [], error: "missing front matter" };
  }

  const endIndex = content.indexOf("\n---", 3);
  if (endIndex === -1) {
    return { summary: null, readWhen: [], error: "unterminated front matter" };
  }

  const frontMatter = content.slice(3, endIndex).trim();
  const lines = frontMatter.split("\n");

  let summaryLine = null;
  const readWhen = [];
  let collectingReadWhen = false;

  for (const rawLine of lines) {
    const line = rawLine.trim();

    if (line.startsWith("summary:")) {
      summaryLine = line;
      collectingReadWhen = false;
      continue;
    }

    if (line.startsWith("read_when:")) {
      collectingReadWhen = true;
      const inline = line.slice("read_when:".length).trim();
      if (inline.startsWith("[") && inline.endsWith("]")) {
        try {
          const parsed = JSON.parse(inline.replace(/'/g, '"'));
          if (Array.isArray(parsed)) {
            parsed
              .map((v) => String(v).trim())
              .filter(Boolean)
              .forEach((v) => readWhen.push(v));
          }
        } catch {
          /* ignore malformed inline */
        }
      }
      continue;
    }

    if (collectingReadWhen) {
      if (line.startsWith("- ")) {
        const hint = line
          .slice(2)
          .trim()
          .replace(/^['"]|['"]$/g, "");
        if (hint) readWhen.push(hint);
      } else if (line === "") {
        // allow blank spacer lines inside list
      } else {
        collectingReadWhen = false;
      }
    }
  }

  if (!summaryLine) {
    return { summary: null, readWhen, error: "summary key missing" };
  }

  const summaryValue = summaryLine.slice("summary:".length).trim();
  const normalized = summaryValue
    .replace(/^['"]|['"]$/g, "")
    .replace(/\s+/g, " ")
    .trim();

  if (!normalized) {
    return { summary: null, readWhen, error: "summary is empty" };
  }

  if (readWhen.length === 0) {
    return { summary: normalized, readWhen, error: "read_when is empty" };
  }

  return { summary: normalized, readWhen };
}

console.log("Focus docs index (summary + read_when):\n");

const markdownFiles = walkMarkdownFiles(DOCS_DIR);
let failed = false;

for (const relativePath of markdownFiles) {
  const fullPath = join(DOCS_DIR, relativePath);
  const { summary, readWhen, error } = extractMetadata(fullPath);
  if (summary && !error) {
    console.log(`${relativePath} — ${summary}`);
    console.log(`  Read when: ${readWhen.join("; ")}`);
  } else {
    failed = true;
    const reason = error ? ` [${error}]` : "";
    console.error(`ERROR: ${relativePath}${reason}`);
  }
}

if (failed) {
  console.error(
    "\ndocs-list failed: every docs/*.md page needs non-empty summary and read_when.",
  );
  process.exit(1);
}

console.log(
  '\nReminder: when a task matches any "Read when" hint, read that doc before coding.',
);
