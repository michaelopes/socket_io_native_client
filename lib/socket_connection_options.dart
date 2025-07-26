/// Platform-specific options for Android.
class ExtraAndroidSocketOptions {
  /// Options for the underlying Engine.IO transport.
  final Map<String, List<String>> extraHeaders;

  ExtraAndroidSocketOptions({required this.extraHeaders});

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};
    map['setExtraHeaders'] = extraHeaders;
    return map;
  }
}

/// Platform-specific options for iOS.
class ExtraIOSSocketOptions {
  /// Whether to show native library logs.
  final bool? log;

  /// Whether to use gzip compression.
  final bool? compress;

  /// Forces the client to use polling.
  final bool? forcePolling;

  /// Forces the client to use WebSockets.
  final bool? forceWebsockets;

  /// Any extra headers to send with requests.
  final Map<String, String>? extraHeaders;

  ExtraIOSSocketOptions({
    this.log,
    this.compress,
    this.forcePolling,
    this.forceWebsockets,
    this.extraHeaders,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};
    if (log != null) map['log'] = log;
    if (compress != null) map['compress'] = compress;
    if (forcePolling != null) map['forcePolling'] = forcePolling;
    if (forceWebsockets != null) map['forceWebsockets'] = forceWebsockets;
    if (extraHeaders != null) map['extraHeaders'] = extraHeaders;
    return map;
  }
}

/// A comprehensive class for all socket connection options.
class SocketConnectionOptions {
  // --- Common Properties ---

  /// The path on the server to connect to.
  final String? path;

  /// A list of transports to use. e.g., ['websocket', 'polling'].
  final List<String>? transports;

  /// Whether to automatically reconnect on disconnection.
  final bool? reconnection;

  /// Number of reconnection attempts. Use -1 for infinite.
  final int? reconnectionAttempts;

  /// Delay between reconnection attempts (in milliseconds).
  final int? reconnectionDelay;

  /// Maximum delay between reconnection attempts (in milliseconds).
  final int? reconnectionDelayMax;

  /// A factor to randomize the reconnection delay. e.g., 0.5.
  final double? randomizationFactor;

  /// Connection timeout duration (in milliseconds).
  final int? timeout;

  /// Extra query parameters to send with the connection request.
  final String? query;

  /// Authentication data to send with the connection.
  final Map<String, String>? auth;

  /// Whether to use a secure connection (wss/https).
  final bool? secure;

  /// If true, creates a new connection, bypassing any existing multiplexed connection.
  final bool? forceNew;

  // --- Platform-Specific Properties ---
  final ExtraIOSSocketOptions? extraIOSConfig;
  final ExtraAndroidSocketOptions? androidConfig;

  SocketConnectionOptions({
    // Common
    this.path,
    this.transports,
    this.reconnection,
    this.reconnectionAttempts,
    this.reconnectionDelay,
    this.reconnectionDelayMax,
    this.randomizationFactor,
    this.timeout,
    this.query,
    this.auth,
    this.secure,
    this.forceNew,
    // Platform-specific
    this.extraIOSConfig,
    this.androidConfig,
  });

  /// Converts this object into a map for the platform channel.
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};
    // Common properties
    if (path != null) map['path'] = path;
    if (transports != null) map['transports'] = transports;
    if (reconnection != null) map['reconnection'] = reconnection;
    if (reconnectionAttempts != null) map['reconnectionAttempts'] = reconnectionAttempts;
    if (reconnectionDelay != null) map['reconnectionDelay'] = reconnectionDelay;
    if (reconnectionDelayMax != null) map['reconnectionDelayMax'] = reconnectionDelayMax;
    if (randomizationFactor != null) map['randomizationFactor'] = randomizationFactor;
    if (timeout != null) map['timeout'] = timeout;
    if (query != null) map['query'] = query;
    if (auth != null) map['auth'] = auth;
    if (secure != null) map['secure'] = secure;
    if (forceNew != null) map['forceNew'] = forceNew;
    // Platform-specific configs are nested
    if (extraIOSConfig != null) map['extraIOSConfig'] = extraIOSConfig!.toMap();
    if (androidConfig != null) map['androidConfig'] = androidConfig!.toMap();
    return map;
  }
}
