/// CLI ↔ app control protocol: versioned JSON envelopes, framing, and Unix sockets.
public enum FocusControlModule {
  public static let moduleName = "FocusControl"

  /// Marketing version advertised by the portable CLI client envelope.
  public static let clientVersion = "0.1.0"

  /// Build number advertised by the portable CLI client envelope.
  public static let clientBuild = "1"
}
