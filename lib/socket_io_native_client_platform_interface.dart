import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'socket_connection_options.dart';
import 'socket_io_native_client_method_channel.dart';

abstract class SocketIoNativePlatform extends PlatformInterface {
  /// Constructs a SocketIoNativePlatform.
  SocketIoNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static SocketIoNativePlatform _instance = MethodChannelSocketIoNative();

  /// The default instance of [SocketIoNativePlatform] to use.
  ///
  /// Defaults to [MethodChannelSocketIoNative].
  static SocketIoNativePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SocketIoNativePlatform] when
  /// they register themselves.
  static set instance(SocketIoNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Connects to the socket server.
  ///
  /// Throws [SocketConnectionException] if connection fails.
  /// Throws [SocketTimeoutException] if connection times out.
  /// Throws [SocketInvalidUrlException] if URL is invalid.
  Future<String?> connect(String url, {SocketConnectionOptions? options}) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  /// Listens to a specific event from the socket.
  ///
  /// Throws [SocketNotConnectedException] if not connected.
  /// Throws [SocketEventException] if event listening fails.
  Future<void> listen(String eventName) {
    throw UnimplementedError('listen() has not been implemented.');
  }

  /// Stops listening to a specific event.
  ///
  /// Throws [SocketNotConnectedException] if not connected.
  /// Throws [SocketEventException] if unlisten fails.
  Future<void> unlisten(String eventName) {
    throw UnimplementedError('unlisten() has not been implemented.');
  }

  /// Emits an event to the socket.
  ///
  /// Throws [SocketNotConnectedException] if not connected.
  /// Throws [SocketEmissionException] if emission fails.
  Future<void> emit(String eventName, dynamic data) {
    throw UnimplementedError('emit() has not been implemented.');
  }

  /// Disconnects from the socket server.
  ///
  /// Throws [SocketDisconnectionException] if disconnection fails.
  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }
}

/// Base class for all Socket.IO exceptions.
abstract class SocketException implements Exception {
  final String message;
  final String? code;

  SocketException(this.message, {this.code});

  @override
  String toString() => 'SocketException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when connection to socket server fails.
class SocketConnectionException extends SocketException {
  SocketConnectionException(super.message, {super.code});

  @override
  String toString() => 'SocketConnectionException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when connection times out.
class SocketTimeoutException extends SocketException {
  SocketTimeoutException(super.message, {super.code});

  @override
  String toString() => 'SocketTimeoutException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when URL is invalid.
class SocketInvalidUrlException extends SocketException {
  SocketInvalidUrlException(super.message, {super.code});

  @override
  String toString() => 'SocketInvalidUrlException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when trying to perform operations on a disconnected socket.
class SocketNotConnectedException extends SocketException {
  SocketNotConnectedException(super.message, {super.code});

  @override
  String toString() => 'SocketNotConnectedException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when event operations fail.
class SocketEventException extends SocketException {
  SocketEventException(super.message, {super.code});

  @override
  String toString() => 'SocketEventException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when event emission fails.
class SocketEmissionException extends SocketException {
  SocketEmissionException(super.message, {super.code});

  @override
  String toString() => 'SocketEmissionException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when disconnection fails.
class SocketDisconnectionException extends SocketException {
  SocketDisconnectionException(super.message, {super.code});

  @override
  String toString() => 'SocketDisconnectionException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Generic Socket.IO exception for unclassified errors.
class GenericSocketException extends SocketException {
  GenericSocketException(super.message, {super.code});

  @override
  String toString() => 'GenericSocketException: $message${code != null ? ' (Code: $code)' : ''}';
}
