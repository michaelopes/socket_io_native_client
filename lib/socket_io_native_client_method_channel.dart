import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'socket_connection_options.dart';
import 'socket_io_native_client_platform_interface.dart';

/// An implementation of [SocketIoNativePlatform] that uses method channels.
class MethodChannelSocketIoNative extends SocketIoNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('devarsh/command');

  @override
  Future<String?> connect(String url, {SocketConnectionOptions? options}) async {
    try {
      // Validate URL
      if (url.isEmpty) {
        throw SocketInvalidUrlException('URL cannot be empty');
      }

      final uri = Uri.tryParse(url);
      if (uri == null ||
          (!uri.hasScheme || (!uri.scheme.startsWith('http') && !uri.scheme.startsWith('ws')))) {
        throw SocketInvalidUrlException('Invalid URL format: $url');
      }

      final data = <String, dynamic>{'url': url};
      if (options != null) {
        data.addAll({'options': options.toMap()});
      }

      final result = await methodChannel.invokeMethod<String>('connect', data);
      return result;
    } on PlatformException catch (e) {
      _handlePlatformException(e, 'connect');
    } catch (e) {
      if (e is SocketException) {
        rethrow;
      }
      throw SocketConnectionException('Unexpected error during connection: $e');
    }
  }

  @override
  Future<void> listen(String eventName) async {
    try {
      if (eventName.isEmpty) {
        throw SocketEventException('Event name cannot be empty');
      }

      await methodChannel.invokeMethod('listen', {'event': eventName});
    } on PlatformException catch (e) {
      _handlePlatformException(e, 'listen');
    } catch (e) {
      if (e is SocketException) {
        rethrow;
      }
      throw SocketEventException('Unexpected error while listening to event "$eventName": $e');
    }
  }

  @override
  Future<void> unlisten(String eventName) async {
    try {
      if (eventName.isEmpty) {
        throw SocketEventException('Event name cannot be empty');
      }

      await methodChannel.invokeMethod('unlisten', {'event': eventName});
    } on PlatformException catch (e) {
      _handlePlatformException(e, 'unlisten');
    } catch (e) {
      if (e is SocketException) {
        rethrow;
      }
      throw SocketEventException('Unexpected error while unlistening from event "$eventName": $e');
    }
  }

  @override
  Future<void> emit(String eventName, dynamic data) async {
    try {
      if (eventName.isEmpty) {
        throw SocketEmissionException('Event name cannot be empty');
      }

      await methodChannel.invokeMethod('emit', {'event': eventName, 'data': data});
    } on PlatformException catch (e) {
      _handlePlatformException(e, 'emit');
    } catch (e) {
      if (e is SocketException) {
        rethrow;
      }
      throw SocketEmissionException('Unexpected error while emitting event "$eventName": $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await methodChannel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      _handlePlatformException(e, 'disconnect');
    } catch (e) {
      if (e is SocketException) {
        rethrow;
      }
      throw SocketDisconnectionException('Unexpected error during disconnection: $e');
    }
  }

  /// Handles platform exceptions and converts them to appropriate Socket exceptions.
  Never _handlePlatformException(PlatformException e, String operation) {
    final code = e.code;
    final message = e.message ?? 'Unknown error';

    switch (code) {
      case 'CONNECTION_FAILED':
        throw SocketConnectionException(message, code: code);
      case 'CONNECTION_TIMEOUT':
        throw SocketTimeoutException(message, code: code);
      case 'INVALID_URL':
        throw SocketInvalidUrlException(message, code: code);
      case 'NOT_CONNECTED':
        throw SocketNotConnectedException(message, code: code);
      case 'EVENT_ERROR':
        throw SocketEventException(message, code: code);
      case 'EMISSION_FAILED':
        throw SocketEmissionException(message, code: code);
      case 'DISCONNECTION_FAILED':
        throw SocketDisconnectionException(message, code: code);
      default:
        // Map operation-specific errors
        switch (operation) {
          case 'connect':
            throw SocketConnectionException(message, code: code);
          case 'listen':
          case 'unlisten':
            throw SocketEventException(message, code: code);
          case 'emit':
            throw SocketEmissionException(message, code: code);
          case 'disconnect':
            throw SocketDisconnectionException(message, code: code);
          default:
            throw GenericSocketException(message, code: code);
        }
    }
  }
}
