import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'socket_connection_options.dart';
import 'socket_io_native_client_platform_interface.dart';

export 'socket_connection_options.dart';
export 'socket_io_native_client_platform_interface.dart'
    show
        SocketException,
        SocketConnectionException,
        SocketTimeoutException,
        SocketInvalidUrlException,
        SocketNotConnectedException,
        SocketEventException,
        SocketEmissionException,
        SocketDisconnectionException,
        GenericSocketException;

/// Main Socket.IO service class providing comprehensive Socket.IO client functionality.
///
/// This class implements a singleton pattern to ensure only one Socket.IO connection
/// exists throughout the application lifecycle.
class SocketIoNative {
  // Singleton implementation
  static SocketIoNative? _instance;

  // Channels for communication
  static const _eventChannel = EventChannel('devarsh/events');

  // Stream controller for connection status
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  String socketId = '';
  final Map<String, Function(dynamic)> _eventListeners = {};
  final Map<String, Function(dynamic)> _pendingListeners = {};
  Function()? _onConnectCallback;
  Function()? _onConnectingCallback;
  Function()? _onDisconnectCallback;
  Function(String reason)? _onErrorCallback;
  Function(String socketId)? _onSocketIdReceivedCallback;

  bool _isListening = false;
  bool _isConnected = false;
  String? _lastUrl;
  SocketConnectionOptions? _lastOptions;

  // Public stream for the UI to listen to
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// Returns true if the socket is currently connected.
  bool get isConnected => _isConnected;

  /// Private constructor for singleton pattern.
  SocketIoNative._internal();

  /// Returns the singleton instance of SocketIoNative.
  ///
  /// Creates a new instance if none exists, otherwise returns the existing instance.
  /// This ensures only one Socket.IO connection exists throughout the app.
  factory SocketIoNative() {
    _instance ??= SocketIoNative._internal();
    return _instance!;
  }

  /// Returns the singleton instance if it exists, null otherwise.
  ///
  /// Useful for checking if an instance has been created without creating one.
  static SocketIoNative? get instance => _instance;

  /// Destroys the singleton instance.
  ///
  /// This should only be called when you want to completely reset the Socket.IO connection
  /// and clean up all resources. After calling this, the next call to SocketIoNative()
  /// will create a fresh instance.
  static void destroyInstance() {
    _instance?.dispose();
    _instance = null;
  }

  void _listenToEvents() {
    if (_isListening) return;
    _isListening = true;

    try {
      _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          try {
            final Map<String, dynamic> eventMap = Map<String, dynamic>.from(event);
            final String type = eventMap['type'];
            final dynamic payload = eventMap['payload'];

            switch (type) {
              case 'status':
                _statusController.add(_parseStatus(payload as Map<Object?, Object?>));
                break;
              case 'socket_event':
                final String eventName = payload['event'];
                final dynamic data = payload['data'];
                if (_eventListeners.containsKey(eventName)) {
                  try {
                    _eventListeners[eventName]!(data);
                  } catch (e) {
                    debugPrint("Error in event callback for '$eventName': $e");
                  }
                }
                break;
              default:
                debugPrint("Received unknown event type: $type");
            }
          } catch (e) {
            debugPrint("Error processing event: $e");
          }
        },
        onError: (dynamic error) {
          debugPrint("EventChannel Error: $error");
          _isConnected = false;
          _statusController.add(ConnectionStatus.error);
          _onErrorCallback?.call("EventChannel error: $error");
        },
      );
    } catch (e) {
      debugPrint("Error setting up event listener: $e");
    }
  }

  /// Registers all pending listeners when connection is established
  Future<void> _registerPendingListeners() async {
    if (_pendingListeners.isEmpty) return;

    debugPrint("Registering ${_pendingListeners.length} pending listeners");

    for (final entry in _pendingListeners.entries) {
      try {
        await SocketIoNativePlatform.instance.listen(entry.key);
        _eventListeners[entry.key] = entry.value;
        debugPrint("Successfully registered pending listener for '${entry.key}'");
      } catch (e) {
        debugPrint("Failed to register pending listener for '${entry.key}': $e");
      }
    }

    _pendingListeners.clear();
  }

  // --- Public API ---

  /// Connects to the socket server.
  ///
  /// [url] - The socket server URL
  /// [onSocketIdReceived] - Callback when socket ID is received
  /// [extraOptions] - Additional connection options
  ///
  /// If already connected:
  /// - Returns existing connection if connecting to the same URL with same options
  /// - Disconnects and reconnects if URL or options are different
  ///
  /// Returns the socket ID if connection is successful.
  /// Throws [SocketConnectionException] if connection fails.
  /// Throws [SocketTimeoutException] if connection times out.
  /// Throws [SocketInvalidUrlException] if URL is invalid.
  Future<String?> connect(
    String url, {
    required Function(String) onSocketIdReceived,
    SocketConnectionOptions? extraOptions,
  }) async {
    try {
      // Check if already connected
      if (_isConnected) {
        // If connecting to the same URL with same options, return existing connection
        if (_lastUrl == url && _optionsAreEqual(_lastOptions, extraOptions)) {
          debugPrint('Already connected to the same URL with same options. Skipping reconnection.');
          _onSocketIdReceivedCallback = onSocketIdReceived; // Update callback
          onSocketIdReceived(socketId);
          return socketId;
        } else {
          // Different URL or options, disconnect first
          debugPrint('Already connected to different URL/options. Disconnecting first...');
          await disconnect();
          // Small delay to ensure clean disconnection
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // Start listening to events when connecting
      _listenToEvents();

      _onSocketIdReceivedCallback = onSocketIdReceived;
      _lastUrl = url;
      _lastOptions = extraOptions;

      // Update status to connecting
      _statusController.add(ConnectionStatus.connecting);

      final result = await SocketIoNativePlatform.instance.connect(url, options: extraOptions);

      if (result != null) {
        _isConnected = true;
        socketId = result;

        // Register any pending listeners now that we're connected
        await _registerPendingListeners();
      }

      return result;
    } catch (e) {
      _isConnected = false;
      _statusController.add(ConnectionStatus.error);

      if (e is SocketException) {
        _onErrorCallback?.call(e.message);
        rethrow;
      } else {
        final errorMessage = 'Connection failed: $e';
        _onErrorCallback?.call(errorMessage);
        throw SocketConnectionException(errorMessage);
      }
    }
  }

  /// Listens to a specific event from the socket.
  ///
  /// [eventName] - The name of the event to listen to
  /// [callback] - Function to call when the event is received
  ///
  /// This method will not throw errors if called before connection.
  /// If not connected, the listener will be stored and registered when connection is established.
  Future<void> on(String eventName, Function(dynamic) callback) async {
    try {
      if (!_isConnected) {
        // Store the listener for when we connect
        _pendingListeners[eventName] = callback;
        debugPrint("Stored pending listener for '$eventName' (not connected)");
        return;
      }

      if (!_eventListeners.containsKey(eventName)) {
        await SocketIoNativePlatform.instance.listen(eventName);
        _eventListeners.addAll({eventName: callback});
      } else {
        // Update callback for existing event
        _eventListeners[eventName] = callback;
      }
    } catch (e) {
      if (e is SocketNotConnectedException) {
        // Store the listener for when we connect
        _pendingListeners[eventName] = callback;
        debugPrint("Stored pending listener for '$eventName' (connection exception caught)");
        return;
      }

      if (e is SocketException) {
        rethrow;
      } else {
        throw SocketEventException('Failed to listen to event "$eventName": $e');
      }
    }
  }

  /// Stops listening to a specific event.
  ///
  /// [eventName] - The name of the event to stop listening to
  ///
  /// Throws [SocketEventException] if unlisten fails.
  Future<void> off(String eventName) async {
    try {
      // Remove from pending listeners if exists
      _pendingListeners.remove(eventName);

      if (_eventListeners.containsKey(eventName)) {
        await SocketIoNativePlatform.instance.unlisten(eventName);
        _eventListeners.remove(eventName);
      }
    } catch (e) {
      if (e is SocketException) {
        rethrow;
      } else {
        throw SocketEventException('Failed to stop listening to event "$eventName": $e');
      }
    }
  }

  /// Emits an event to the socket.
  ///
  /// [eventName] - The name of the event to emit
  /// [data] - The data to send with the event
  ///
  /// This method will not throw errors if called before connection.
  /// If not connected, the emit call will be silently ignored.
  Future<void> emit(String eventName, dynamic data) async {
    try {
      if (!_isConnected) {
        debugPrint("Ignoring emit for '$eventName' (not connected)");
        return;
      }

      await SocketIoNativePlatform.instance.emit(eventName, data);
    } catch (e) {
      if (e is SocketNotConnectedException) {
        debugPrint("Ignoring emit for '$eventName' (connection exception caught)");
        return;
      }

      if (e is SocketException) {
        rethrow;
      } else {
        throw SocketEmissionException('Failed to emit event "$eventName": $e');
      }
    }
  }

  /// Disconnects from the socket server.
  ///
  /// Throws [SocketDisconnectionException] if disconnection fails.
  Future<void> disconnect() async {
    try {
      await SocketIoNativePlatform.instance.disconnect();
      _isConnected = false;
      _statusController.add(ConnectionStatus.disconnected);
    } catch (e) {
      if (e is SocketException) {
        rethrow;
      } else {
        throw SocketDisconnectionException('Failed to disconnect: $e');
      }
    }
  }

  /// Attempts to reconnect using the last connection parameters.
  ///
  /// Throws [SocketConnectionException] if no previous connection info or reconnection fails.
  Future<String?> reconnect() async {
    if (_lastUrl == null) {
      throw SocketConnectionException('Cannot reconnect: No previous connection information');
    }

    if (_onSocketIdReceivedCallback == null) {
      throw SocketConnectionException('Cannot reconnect: No socket ID callback available');
    }

    return await connect(
      _lastUrl!,
      onSocketIdReceived: _onSocketIdReceivedCallback!,
      extraOptions: _lastOptions,
    );
  }

  /// Sets the callback for when the socket successfully connects.
  void onConnected(Function() callback) {
    _onConnectCallback = callback;
  }

  /// Sets the callback for when the socket is in the process of connecting.
  void onConnecting(Function() callback) {
    _onConnectingCallback = callback;
  }

  /// Sets the callback for when the socket disconnects.
  void onDisconnected(Function() callback) {
    _onDisconnectCallback = callback;
  }

  /// Sets the callback for when a connection error occurs.
  void onError(Function(String reason) callback) {
    _onErrorCallback = callback;
  }

  /// Cleans up resources.
  void dispose() {
    try {
      _statusController.close();
      _eventListeners.clear();
      _pendingListeners.clear();
      _isListening = false;
      _isConnected = false;
    } catch (e) {
      debugPrint("Error during dispose: $e");
    }
  }

  /// Helper method to compare two SocketConnectionOptions for equality
  bool _optionsAreEqual(SocketConnectionOptions? options1, SocketConnectionOptions? options2) {
    // Both null
    if (options1 == null && options2 == null) return true;

    // One is null, other is not
    if (options1 == null || options2 == null) return false;

    // Compare key properties (handle nullable lists and check available properties)
    final transports1 = options1.transports?.join(',') ?? '';
    final transports2 = options2.transports?.join(',') ?? '';

    return transports1 == transports2 &&
        options1.reconnection == options2.reconnection &&
        options1.reconnectionAttempts == options2.reconnectionAttempts &&
        options1.timeout == options2.timeout &&
        options1.forceNew == options2.forceNew;
  }

  ConnectionStatus _parseStatus(Map<Object?, Object?> status) {
    try {
      switch (status['status']) {
        case 'connecting':
          _isConnected = false;
          _onConnectingCallback?.call();
          return ConnectionStatus.connecting;
        case 'connected':
          _isConnected = true;
          socketId = status['socketId'] as String? ?? "";
          if (socketId.isNotEmpty) {
            _onSocketIdReceivedCallback?.call(socketId);
          }
          _onConnectCallback?.call();

          // Register pending listeners when connected
          _registerPendingListeners();

          return ConnectionStatus.connected;
        case 'disconnected':
          _isConnected = false;
          _onDisconnectCallback?.call();
          return ConnectionStatus.disconnected;
        case 'error':
          _isConnected = false;
          final String reason = status['reason'] as String? ?? 'Unknown error';
          _onErrorCallback?.call(reason);
          return ConnectionStatus.error;
        default:
          _isConnected = false;
          return ConnectionStatus.error;
      }
    } catch (e) {
      debugPrint("Error parsing status: $e");
      _isConnected = false;
      return ConnectionStatus.error;
    }
  }
}

/// Enumeration of possible connection statuses.
enum ConnectionStatus {
  /// Socket is in the process of connecting.
  connecting,

  /// Socket is successfully connected.
  connected,

  /// Socket is disconnected.
  disconnected,

  /// Socket connection encountered an error.
  error,
}

/// Represents a chat message received from the socket.
class ChatMessage {
  final String message;
  final String senderId;

  ChatMessage({required this.message, required this.senderId});

  /// Factory to create a ChatMessage from the map received from native
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      message: map['message'] as String? ?? '',
      senderId: map['senderId'] as String? ?? 'Unknown',
    );
  }

  /// Converts the ChatMessage to a map for sending to native
  Map<String, dynamic> toMap() {
    return {'message': message, 'senderId': senderId};
  }
}
