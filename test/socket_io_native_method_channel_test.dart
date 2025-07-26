import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_native_client/socket_connection_options.dart';
import 'package:socket_io_native_client/socket_io_native_client_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelSocketIoNative platform = MethodChannelSocketIoNative();
  const MethodChannel channel = MethodChannel('devarsh/command');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall methodCall,
    ) async {
      switch (methodCall.method) {
        case 'connect':
          final args = methodCall.arguments as Map<String, dynamic>;
          final url = args['url'] as String;

          if (url.isEmpty) {
            throw PlatformException(code: 'INVALID_URL', message: 'URL cannot be empty');
          }
          if (url == 'invalid://url') {
            throw PlatformException(code: 'CONNECTION_FAILED', message: 'Connection failed');
          }
          if (url == 'timeout://url') {
            throw PlatformException(code: 'CONNECTION_TIMEOUT', message: 'Connection timeout');
          }
          return 'test-socket-id';

        case 'listen':
          final args = methodCall.arguments as Map<String, dynamic>;
          final eventName = args['event'] as String;

          if (eventName.isEmpty) {
            throw PlatformException(code: 'EVENT_ERROR', message: 'Event name cannot be empty');
          }
          if (eventName == 'not_connected_event') {
            throw PlatformException(code: 'NOT_CONNECTED', message: 'Socket is not connected');
          }
          return null;

        case 'unlisten':
          final args = methodCall.arguments as Map<String, dynamic>;
          final eventName = args['event'] as String;

          if (eventName.isEmpty) {
            throw PlatformException(code: 'EVENT_ERROR', message: 'Event name cannot be empty');
          }
          return null;

        case 'emit':
          final args = methodCall.arguments as Map<String, dynamic>;
          final eventName = args['event'] as String;

          if (eventName.isEmpty) {
            throw PlatformException(code: 'EMISSION_FAILED', message: 'Event name cannot be empty');
          }
          if (eventName == 'not_connected_event') {
            throw PlatformException(code: 'NOT_CONNECTED', message: 'Socket is not connected');
          }
          return null;

        case 'disconnect':
          return null;

        default:
          throw UnimplementedError('Method ${methodCall.method} not implemented');
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('Successful Operations', () {
    test('connect with valid URL returns socket ID', () async {
      final result = await platform.connect('http://localhost:3001');
      expect(result, 'test-socket-id');
    });

    test('connect with options works correctly', () async {
      final options = SocketConnectionOptions(transports: ['websocket'], reconnection: true, timeout: 5000);

      final result = await platform.connect('http://localhost:3001', options: options);
      expect(result, 'test-socket-id');
    });

    test('listen to valid event completes', () async {
      await expectLater(platform.listen('test_event'), completes);
    });

    test('unlisten from valid event completes', () async {
      await expectLater(platform.unlisten('test_event'), completes);
    });

    test('emit valid event completes', () async {
      await expectLater(platform.emit('test_event', {'data': 'test'}), completes);
    });

    test('disconnect completes', () async {
      await expectLater(platform.disconnect(), completes);
    });
  });

  group('Connection Error Handling', () {
    test('connect with empty URL throws SocketInvalidUrlException', () async {
      await expectLater(
        platform.connect(''),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('SocketInvalidUrlException') &&
                e.toString().contains('URL cannot be empty'),
          ),
        ),
      );
    });

    test('connect with invalid URL format throws SocketInvalidUrlException', () async {
      await expectLater(
        platform.connect('not-a-valid-url'),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('SocketInvalidUrlException') &&
                e.toString().contains('Invalid URL format'),
          ),
        ),
      );
    });

    test('connect failure throws SocketConnectionException', () async {
      await expectLater(
        platform.connect('invalid://url'),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('SocketConnectionException') &&
                e.toString().contains('Connection failed'),
          ),
        ),
      );
    });

    test('connect timeout throws SocketTimeoutException', () async {
      await expectLater(
        platform.connect('timeout://url'),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('SocketTimeoutException') &&
                e.toString().contains('Connection timeout'),
          ),
        ),
      );
    });
  });

  group('Event Error Handling', () {
    test('listen with empty event name throws SocketEventException', () async {
      await expectLater(
        platform.listen(''),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('SocketEventException') &&
                e.toString().contains('Event name cannot be empty'),
          ),
        ),
      );
    });

    test('listen when not connected throws SocketNotConnectedException', () async {
      await expectLater(
        platform.listen('not_connected_event'),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('SocketNotConnectedException') &&
                e.toString().contains('Socket is not connected'),
          ),
        ),
      );
    });

    test('unlisten with empty event name throws SocketEventException', () async {
      await expectLater(
        platform.unlisten(''),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('SocketEventException') &&
                e.toString().contains('Event name cannot be empty'),
          ),
        ),
      );
    });
  });

  group('Emission Error Handling', () {
    test('emit with empty event name throws SocketEmissionException', () async {
      await expectLater(
        platform.emit('', {'data': 'test'}),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('SocketEmissionException') &&
                e.toString().contains('Event name cannot be empty'),
          ),
        ),
      );
    });

    test('emit when not connected throws SocketNotConnectedException', () async {
      await expectLater(
        platform.emit('not_connected_event', {'data': 'test'}),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('SocketNotConnectedException') &&
                e.toString().contains('Socket is not connected'),
          ),
        ),
      );
    });
  });

  group('URL Validation', () {
    test('validates HTTP URLs correctly', () async {
      await expectLater(platform.connect('http://localhost:3001'), completes);
      await expectLater(platform.connect('https://example.com'), completes);
    });

    test('validates WebSocket URLs correctly', () async {
      await expectLater(platform.connect('ws://localhost:3001'), completes);
      await expectLater(platform.connect('wss://example.com'), completes);
    });

    test('rejects invalid URL schemes', () async {
      await expectLater(
        platform.connect('ftp://example.com'),
        throwsA(predicate((e) => e.toString().contains('SocketInvalidUrlException'))),
      );
    });

    test('rejects malformed URLs', () async {
      await expectLater(
        platform.connect('://invalid'),
        throwsA(predicate((e) => e.toString().contains('SocketInvalidUrlException'))),
      );
    });
  });
}
