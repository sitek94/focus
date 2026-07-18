#!/usr/bin/env swift
import Foundation

/// Rejects unsafe concurrency escapes in shipped/test Swift sources.
/// Banned: @unchecked Sendable, nonisolated(unsafe), MainActor.assumeIsolated, @preconcurrency

let roots = ["Sources", "Tests", "CLI", "Apps"]
let banned: [(String, String)] = [
  (#"@unchecked\s+Sendable"#, "@unchecked Sendable"),
  (#"nonisolated\s*\(\s*unsafe\s*\)"#, "nonisolated(unsafe)"),
  (#"MainActor\s*\.\s*assumeIsolated"#, "MainActor.assumeIsolated"),
  (#"@preconcurrency"#, "@preconcurrency"),
]

let fileManager = FileManager.default
var violations: [(String, String, Int)] = []

func walk(_ path: String) -> [String] {
  var results: [String] = []
  guard let enumerator = fileManager.enumerator(atPath: path) else { return results }
  while let relative = enumerator.nextObject() as? String {
    if relative.hasSuffix(".swift") {
      results.append((path as NSString).appendingPathComponent(relative))
    }
  }
  return results
}

let patterns: [(NSRegularExpression, String)] = banned.compactMap { pattern, label in
  guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
  return (regex, label)
}

for root in roots {
  guard fileManager.fileExists(atPath: root) else { continue }
  for file in walk(root) {
    guard let contents = try? String(contentsOfFile: file, encoding: .utf8) else {
      continue
    }
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
    for (index, line) in lines.enumerated() {
      let lineString = String(line)
      let range = NSRange(lineString.startIndex..., in: lineString)
      for (regex, label) in patterns {
        if regex.firstMatch(in: lineString, range: range) != nil {
          violations.append((file, label, index + 1))
        }
      }
    }
  }
}

if violations.isEmpty {
  print("check-concurrency-safety: ok")
  exit(0)
}

fputs("check-concurrency-safety: found banned concurrency escapes:\n", stderr)
for (file, label, line) in violations {
  fputs("  \(file):\(line): \(label)\n", stderr)
}
exit(1)
