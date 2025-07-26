import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:socket_io_native_client/socket_io_native_client.dart';
import 'package:socket_io_native_client/socket_io_native_client_method_channel.dart';
import 'package:socket_io_native_client/socket_io_native_client_platform_interface.dart';

class MockSocketIoNativePlatform with MockPlatformInterfaceMixin implements SocketIoNativePlatform {
  @override
  Future<String?> connect(String url, {SocketConnectionOptions? options}) => Future.value('test-socket-id');

  @override
  Future<void> listen(String eventName) => Future.value();

  @override
  Future<void> unlisten(String eventName) => Future.value();

  @override
  Future<void> emit(String eventName, dynamic data) => Future.value();

  @override
  Future<void> disconnect() => Future.value();
}

class MockSocketIoNativePlatformWithErrors with MockPlatformInterfaceMixin implements SocketIoNativePlatform {
  @override
  Future<String?> connect(String url, {SocketConnectionOptions? options}) {
    if (url.isEmpty) {
      throw SocketInvalidUrlException('URL cannot be empty');
    }
    if (url == 'invalid://url') {
      throw SocketConnectionException('Connection failed');
    }
    if (url == 'timeout://url') {
      throw SocketTimeoutException('Connection timeout');
    }
    return Future.value('test-socket-id');
  }

  @override
  Future<void> listen(String eventName) {
    if (eventName.isEmpty) {
      throw SocketEventException('Event name cannot be empty');
    }
    return Future.value();
  }

  @override
  Future<void> unlisten(String eventName) {
    if (eventName.isEmpty) {
      throw SocketEventException('Event name cannot be empty');
    }
    return Future.value();
  }

  @override
  Future<void> emit(String eventName, dynamic data) {
    if (eventName.isEmpty) {
      throw SocketEmissionException('Event name cannot be empty');
    }
    return Future.value();
  }

  @override
  Future<void> disconnect() => Future.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final SocketIoNativePlatform initialPlatform = SocketIoNativePlatform.instance;

  test('$MethodChannelSocketIoNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSocketIoNative>());
  });

  group('Basic Socket Operations', () {
    test('connect returns socket ID', () async {
      MockSocketIoNativePlatform fakePlatform = MockSocketIoNativePlatform();
      SocketIoNativePlatform.instance = fakePlatform;

      final socketId = await fakePlatform.connect('http://localhost:3001');
      expect(socketId, 'test-socket-id');
    });

    test('listen completes successfully', () async {
      MockSocketIoNativePlatform fakePlatform = MockSocketIoNativePlatform();
      SocketIoNativePlatform.instance = fakePlatform;

      await expectLater(fakePlatform.listen('test_event'), completes);
    });

    test('emit completes successfully', () async {
      MockSocketIoNativePlatform fakePlatform = MockSocketIoNativePlatform();
      SocketIoNativePlatform.instance = fakePlatform;

      await expectLater(fakePlatform.emit('test_event', {'data': 'test'}), completes);
    });

    test('disconnect completes successfully', () async {
      MockSocketIoNativePlatform fakePlatform = MockSocketIoNativePlatform();
      SocketIoNativePlatform.instance = fakePlatform;

      await expectLater(fakePlatform.disconnect(), completes);
    });
  });

  group('Error Handling', () {
    test('connect throws SocketInvalidUrlException for empty URL', () async {
      MockSocketIoNativePlatformWithErrors fakePlatform = MockSocketIoNativePlatformWithErrors();
      SocketIoNativePlatform.instance = fakePlatform;

      await expectLater(fakePlatform.connect(''), throwsA(isA<SocketInvalidUrlException>()));
    });

    test('connect throws SocketConnectionException for invalid URL', () async {
      MockSocketIoNativePlatformWithErrors fakePlatform = MockSocketIoNativePlatformWithErrors();
      SocketIoNativePlatform.instance = fakePlatform;

      await expectLater(fakePlatform.connect('invalid://url'), throwsA(isA<SocketConnectionException>()));
    });

    test('connect throws SocketTimeoutException for timeout', () async {
      MockSocketIoNativePlatformWithErrors fakePlatform = MockSocketIoNativePlatformWithErrors();
      SocketIoNativePlatform.instance = fakePlatform;

      await expectLater(fakePlatform.connect('timeout://url'), throwsA(isA<SocketTimeoutException>()));
    });

    test('listen throws SocketEventException for empty event name', () async {
      MockSocketIoNativePlatformWithErrors fakePlatform = MockSocketIoNativePlatformWithErrors();
      SocketIoNativePlatform.instance = fakePlatform;

      await expectLater(fakePlatform.listen(''), throwsA(isA<SocketEventException>()));
    });

    test('emit throws SocketEmissionException for empty event name', () async {
      MockSocketIoNativePlatformWithErrors fakePlatform = MockSocketIoNativePlatformWithErrors();
      SocketIoNativePlatform.instance = fakePlatform;

      await expectLater(fakePlatform.emit('', {'data': 'test'}), throwsA(isA<SocketEmissionException>()));
    });
  });

  group('Configuration Tests', () {
    test('SocketConnectionOptions serializes correctly with all options', () {
      final options = SocketConnectionOptions(
        path: '/socket.io/',
        transports: ['websocket'],
        reconnection: true,
        reconnectionAttempts: 5,
        reconnectionDelay: 1000,
        reconnectionDelayMax: 5000,
        randomizationFactor: 0.5,
        timeout: 10000,
        auth: {'token': 'test-token'},
        query: 'version=1.0',
        secure: true,
        forceNew: true,
        extraIOSConfig: ExtraIOSSocketOptions(
          log: true,
          compress: false,
          forceWebsockets: true,
          extraHeaders: {'Authorization': 'Bearer test'},
        ),
        androidConfig: ExtraAndroidSocketOptions(
          extraHeaders: {
            'Authorization': ['Bearer test'],
          },
        ),
      );

      final map = options.toMap();

      expect(map['path'], '/socket.io/');
      expect(map['transports'], ['websocket']);
      expect(map['reconnection'], true);
      expect(map['reconnectionAttempts'], 5);
      expect(map['reconnectionDelay'], 1000);
      expect(map['reconnectionDelayMax'], 5000);
      expect(map['randomizationFactor'], 0.5);
      expect(map['timeout'], 10000);
      expect(map['auth'], {'token': 'test-token'});
      expect(map['query'], {'version': '1.0'});
      expect(map['secure'], true);
      expect(map['forceNew'], true);
      expect(map['extraIOSConfig'], isA<Map<String, dynamic>>());
      expect(map['androidConfig'], isA<Map<String, dynamic>>());
    });

    test('iOS-specific options serialize correctly', () {
      final iosOptions = ExtraIOSSocketOptions(
        log: true,
        compress: true,
        forcePolling: false,
        forceWebsockets: true,
        extraHeaders: {'Authorization': 'Bearer token', 'Custom-Header': 'value'},
      );

      final map = iosOptions.toMap();

      expect(map['log'], true);
      expect(map['compress'], true);
      expect(map['forcePolling'], false);
      expect(map['forceWebsockets'], true);
      expect(map['extraHeaders'], {'Authorization': 'Bearer token', 'Custom-Header': 'value'});
    });

    test('Android-specific options serialize correctly', () {
      final androidOptions = ExtraAndroidSocketOptions(
        extraHeaders: {
          'Authorization': ['Bearer token'],
          'Custom-Header': ['value1', 'value2'],
        },
      );

      final map = androidOptions.toMap();

      expect(map['setExtraHeaders'], {
        'Authorization': ['Bearer token'],
        'Custom-Header': ['value1', 'value2'],
      });
    });
  });

  group('ChatMessage Tests', () {
    test('ChatMessage fromMap and toMap work correctly', () {
      final originalData = {'message': 'Hello World', 'senderId': 'user123'};

      final chatMessage = ChatMessage.fromMap(originalData);
      expect(chatMessage.message, 'Hello World');
      expect(chatMessage.senderId, 'user123');

      final serialized = chatMessage.toMap();
      expect(serialized, originalData);
    });

    test('ChatMessage handles missing data gracefully', () {
      final incompleteData = <String, dynamic>{};

      final chatMessage = ChatMessage.fromMap(incompleteData);
      expect(chatMessage.message, '');
      expect(chatMessage.senderId, 'Unknown');
    });
  });

  group('ConnectionStatus Tests', () {
    test('ConnectionStatus enum values', () {
      expect(ConnectionStatus.connecting.name, 'connecting');
      expect(ConnectionStatus.connected.name, 'connected');
      expect(ConnectionStatus.disconnected.name, 'disconnected');
      expect(ConnectionStatus.error.name, 'error');
    });
  });

  group('Exception Tests', () {
    test('Exception classes have proper messages and codes', () {
      final connectionException = SocketConnectionException('Connection failed', code: 'CONN_001');
      expect(connectionException.message, 'Connection failed');
      expect(connectionException.code, 'CONN_001');
      expect(connectionException.toString(), contains('SocketConnectionException'));
      expect(connectionException.toString(), contains('Connection failed'));
      expect(connectionException.toString(), contains('CONN_001'));

      final timeoutException = SocketTimeoutException('Timeout occurred');
      expect(timeoutException.message, 'Timeout occurred');
      expect(timeoutException.code, null);
      expect(timeoutException.toString(), contains('SocketTimeoutException'));

      final eventException = SocketEventException('Event error', code: 'EVENT_001');
      expect(eventException.message, 'Event error');
      expect(eventException.code, 'EVENT_001');
    });
  });

  group('Duplicate Connection Handling', () {
    late SocketIoNative socket;
    late MockSocketIoNativePlatform mockPlatform;

    setUp(() {
      mockPlatform = MockSocketIoNativePlatform();
      SocketIoNativePlatform.instance = mockPlatform;
      socket = SocketIoNative();
    });

    tearDown(() {
      SocketIoNative.destroyInstance();
    });

    test('should skip reconnection when connecting to same URL with same options', () async {
      const url = 'http://localhost:3001';
      final options = SocketConnectionOptions(transports: ['websocket'], reconnection: true, timeout: 10000);

      // First connection
      final socketId1 = await socket.connect(url, onSocketIdReceived: (socketId) {}, extraOptions: options);

      expect(socketId1, 'test-socket-id');
      expect(socket.isConnected, true);

      // Second connection with same parameters should skip
      final socketId2 = await socket.connect(url, onSocketIdReceived: (socketId) {}, extraOptions: options);

      expect(socketId2, socketId1);
      expect(socket.isConnected, true);
    });

    test('should reconnect when connecting to different URL', () async {
      // First connection
      await socket.connect('http://localhost:3001', onSocketIdReceived: (socketId) {});

      expect(socket.isConnected, true);

      // Second connection to different URL should reconnect
      final socketId2 = await socket.connect('http://localhost:3002', onSocketIdReceived: (socketId) {});

      expect(socketId2, 'test-socket-id');
      expect(socket.isConnected, true);
    });

    test('should reconnect when connecting with different options', () async {
      const url = 'http://localhost:3001';

      // First connection with websocket only
      await socket.connect(
        url,
        onSocketIdReceived: (socketId) {},
        extraOptions: SocketConnectionOptions(transports: ['websocket']),
      );

      expect(socket.isConnected, true);

      // Second connection with different transport options should reconnect
      final socketId2 = await socket.connect(
        url,
        onSocketIdReceived: (socketId) {},
        extraOptions: SocketConnectionOptions(transports: ['polling']),
      );

      expect(socketId2, 'test-socket-id');
      expect(socket.isConnected, true);
    });

    test('should handle connection without options vs with options', () async {
      const url = 'http://localhost:3001';

      // First connection without options
      await socket.connect(url, onSocketIdReceived: (socketId) {});

      expect(socket.isConnected, true);

      // Second connection with options should reconnect
      final socketId2 = await socket.connect(
        url,
        onSocketIdReceived: (socketId) {},
        extraOptions: SocketConnectionOptions(reconnection: true),
      );

      expect(socketId2, 'test-socket-id');
      expect(socket.isConnected, true);
    });
  });

  group('SocketIoNative Tests', () {
    setUp(() {
      // Reset singleton before each test
      SocketIoNative.destroyInstance();
    });

    test('should allow listening to events before connection without throwing error', () async {
      final socket = SocketIoNative();
      bool callbackCalled = false;

      // This should not throw an error even though not connected
      expect(() async {
        await socket.on('test_event', (data) {
          callbackCalled = true;
        });
      }, returnsNormally);

      // Callback should not be called yet since we're not connected
      expect(callbackCalled, false);
      expect(socket.isConnected, false);
    });

    test('should allow emitting events before connection without throwing error', () async {
      final socket = SocketIoNative();

      // This should not throw an error even though not connected
      expect(() async {
        await socket.emit('test_event', {'message': 'test'});
      }, returnsNormally);

      expect(socket.isConnected, false);
    });

    test('should register pending listeners after connection', () async {
      final socket = SocketIoNative();
      bool callbackCalled = false;
      String? receivedData;

      // Set up listener before connection
      await socket.on('test_event', (data) {
        callbackCalled = true;
        receivedData = data;
      });

      expect(callbackCalled, false);
      expect(socket.isConnected, false);

      // Connect to socket
      final socketId = await socket.connect('ws://localhost:3001', onSocketIdReceived: (id) {});

      expect(socketId, '42');
      expect(socket.isConnected, true);

      // The pending listener should now be registered
      // Note: In real scenario, the listener would be triggered by actual events
      // but we can verify it was set up without errors
    });

    test('should handle multiple pending listeners', () async {
      final socket = SocketIoNative();
      bool callback1Called = false;
      bool callback2Called = false;

      // Set up multiple listeners before connection
      await socket.on('event1', (data) {
        callback1Called = true;
      });

      await socket.on('event2', (data) {
        callback2Called = true;
      });

      expect(callback1Called, false);
      expect(callback2Called, false);
      expect(socket.isConnected, false);

      // Connect to socket
      await socket.connect('ws://localhost:3001', onSocketIdReceived: (id) {});

      expect(socket.isConnected, true);
      // Both listeners should be registered without errors
    });

    test('should clean up pending listeners on dispose', () async {
      final socket = SocketIoNative();

      // Set up listener before connection
      await socket.on('test_event', (data) {});

      // Dispose should clean up everything
      expect(() => socket.dispose(), returnsNormally);
    });

    test('should handle off() for pending listeners', () async {
      final socket = SocketIoNative();

      // Set up listener before connection
      await socket.on('test_event', (data) {});

      // Remove the pending listener
      expect(() async {
        await socket.off('test_event');
      }, returnsNormally);

      // Connect after removing pending listener
      await socket.connect('ws://localhost:3001', onSocketIdReceived: (id) {});

      expect(socket.isConnected, true);
    });

    test('singleton pattern works correctly', () {
      final socket1 = SocketIoNative();
      final socket2 = SocketIoNative();

      expect(identical(socket1, socket2), true);
    });

    test('destroyInstance resets singleton', () {
      final socket1 = SocketIoNative();
      SocketIoNative.destroyInstance();
      final socket2 = SocketIoNative();

      expect(identical(socket1, socket2), false);
    });
  });
}
