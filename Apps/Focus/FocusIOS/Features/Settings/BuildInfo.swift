import Foundation

/// Marketing version, build number, and optional git commit from Info.plist.
enum BuildInfo {
  static var marketingVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
  }

  static var buildNumber: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
  }

  /// Full commit SHA when set by deploy (`FOCUS_GIT_COMMIT`); `local` for ad-hoc builds.
  static var gitCommit: String {
    let raw = Bundle.main.object(forInfoDictionaryKey: "FocusGitCommit") as? String
    let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? "local" : trimmed
  }

  static var shortCommit: String {
    let commit = gitCommit
    guard commit.count > 7, commit != "local" else { return commit }
    return String(commit.prefix(7))
  }

  /// e.g. `Focus 0.1.0 (3) · b04355a`
  static var label: String {
    "Focus \(marketingVersion) (\(buildNumber)) · \(shortCommit)"
  }
}
