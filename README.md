# socket_io_native_client

**Highlight**: This plugin implements the official Socket.IO library for Android and iOS, providing better control over socket connections. It also solves the issue of listening to messages emitted in a room, which was not possible with other Socket.IO packages.

A Flutter plugin for Socket.IO client with native platform support for Android and iOS.

## Features

- **Real-time Communication**: Full Socket.IO client implementation with event-driven architecture
- **Platform Native**: Uses native Socket.IO libraries for optimal performance
- **Comprehensive Configuration**: Platform-specific options for iOS and Android
- **Connection Management**: Automatic reconnection, connection status monitoring
- **Event Handling**: Listen to custom events and emit data to the server
- **Chat Support**: Built-in support for real-time messaging applications

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  socket_io_native_client: ^1.0.0
```

## Platform Setup

### Android

**Important**: For HTTP connections (non-HTTPS), you must add the following to your `android/app/src/main/AndroidManifest.xml` file in the `<application>` tag:

```xml
<application
    android:usesCleartextTraffic="true"
    ... >
    ...
</application>
```

This is **essential** for connecting to Socket.IO servers over HTTP (like `http://localhost:3001` during development).

No additional setup required for the plugin itself. The plugin will automatically configure the native Socket.IO Android library.

### iOS

No additional setup required. The plugin will automatically configure the native Socket.IO iOS library.

## Usage

### Basic Connection

**Note**: `SocketIoNative` implements a singleton pattern. Multiple calls to `SocketIoNative()` will return the same instance, ensuring only one Socket.IO connection exists throughout your app.

```dart
import 'package:socket_io_native_client/socket_io_native_client.dart';

class MySocketService {
  final SocketIoNative _socket = SocketIoNative(); // Always returns the same instance

  Future<void> connect() async {
    await _socket.connect(
      'http://localhost:3001',
      onSocketIdReceived: (socketId) {
        print('Connected with ID: $socketId');
      },
      extraOptions: SocketConnectionOptions(
        transports: ['websocket'],
        reconnection: true,
        reconnectionAttempts: 10,
        timeout: 10000,
      ),
    );
  }
}
```

### Listening to Events

```dart
// Listen to custom events
await _socket.on('message', (data) {
  print('Received message: $data');
});

// Listen to connection status changes
_socket.statusStream.listen((status) {
  switch (status) {
    case ConnectionStatus.connected:
      print('Socket connected');
      break;
    case ConnectionStatus.disconnected:
      print('Socket disconnected');
      break;
    case ConnectionStatus.connecting:
      print('Socket connecting...');
      break;
    case ConnectionStatus.error:
      print('Socket error occurred');
      break;
  }
});
```

### Emitting Events

```dart
// Send a simple message
await _socket.emit('message', 'Hello Server!');

// Send complex data
await _socket.emit('user_action', {
  'action': 'join_room',
  'room': 'general',
  'userId': 'user123',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});
```

### Connection Callbacks

```dart
// Set up connection callbacks
_socket.onConnected(() {
  print('Successfully connected to server');
});

_socket.onDisconnected(() {
  print('Disconnected from server');
});

_socket.onError((reason) {
  print('Connection error: $reason');
});
```

### Advanced Configuration

```dart
await _socket.connect(
  'https://your-server.com',
  onSocketIdReceived: (socketId) => print('ID: $socketId'),
  extraOptions: SocketConnectionOptions(
    // Common options
    path: '/socket.io/',
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: -1, // Infinite
    reconnectionDelay: 1000,
    reconnectionDelayMax: 5000,
    randomizationFactor: 0.5,
    timeout: 20000,
    forceNew: true,
    secure: true,
    
    // Authentication
    auth: {
      'token': 'your-auth-token',
      'userId': 'user123',
    },
    
    // Query parameters
    query: {
      'version': '1.0',
      'platform': 'flutter',
    },
    
    // iOS-specific options
    extraIOSConfig: ExtraIOSSocketOptions(
      log: true,
      compress: true,
      forceWebsockets: true,
      extraHeaders: {
        'Authorization': 'Bearer token',
        'Custom-Header': 'value',
      },
    ),
    
    // Android-specific options
    androidConfig: ExtraAndroidSocketOptions(
      extraHeaders: {
        'Authorization': ['Bearer token'],
        'Custom-Header': ['value'],
      },
    ),
  ),
);
```

### Chat Application Example

```dart
class ChatService {
  final SocketIoNative _socket = SocketIoNative();
  String? _currentRoom;
  
  Future<void> joinChat(String serverUrl, String username) async {
    await _socket.connect(
      serverUrl,
      onSocketIdReceived: (socketId) {
        print('Chat connected: $socketId');
      },
    );
    
    // Listen for incoming messages
    await _socket.on('receive_message', (data) {
      final message = ChatMessage.fromMap(data);
      // Handle received message
      onMessageReceived(message);
    });
    
    // Listen for room notifications
    await _socket.on('room_notification', (data) {
      print('Room update: $data');
    });
  }
  
  Future<void> joinRoom(String roomName) async {
    _currentRoom = roomName;
    await _socket.emit('join_room', {
      'room': roomName,
      'username': 'current_user',
    });
  }
  
  Future<void> sendMessage(String message) async {
    if (_currentRoom != null) {
      await _socket.emit('send_message', {
        'room': _currentRoom,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
  
  void onMessageReceived(ChatMessage message) {
    // Update UI with new message
  }
  
  Future<void> disconnect() async {
    await _socket.off('receive_message');
    await _socket.off('room_notification');
    await _socket.disconnect();
    _socket.dispose();
  }
}
```

### Singleton Pattern Usage

```dart
// These all return the same instance
final socket1 = SocketIoNative();
final socket2 = SocketIoNative();
print(identical(socket1, socket2)); // true

// Check if instance exists without creating one
if (SocketIoNative.instance != null) {
  print('Socket instance already exists');
}

// Completely destroy the singleton (rarely needed)
SocketIoNative.destroyInstance(); // Disconnects and cleans up
final newSocket = SocketIoNative(); // Creates fresh instance
```

### Cleanup

Always dispose of the socket service when done:

```dart
@override
void dispose() {
  // Remove specific event listeners
  _socket.off('message');
  _socket.off('custom_event');
  
  // Disconnect from server
  _socket.disconnect();
  
  // Clean up resources (or use destroyInstance for complete cleanup)
  _socket.dispose();
  
  super.dispose();
}
```

## API Reference

### SocketIoNative

| Method | Description |
|--------|-------------|
| `connect(url, {onSocketIdReceived, extraOptions})` | Connect to Socket.IO server |
| `on(eventName, callback)` | Listen to a specific event |
| `off(eventName)` | Stop listening to an event |
| `emit(eventName, data)` | Send an event to the server |
| `disconnect()` | Disconnect from server |
| `dispose()` | Clean up all resources |
| `onConnected(callback)` | Set callback for connection |
| `onDisconnected(callback)` | Set callback for disconnection |
| `onError(callback)` | Set callback for errors |

### SocketConnectionOptions

Comprehensive configuration options for Socket.IO connection with platform-specific settings.

### ConnectionStatus

Enum representing socket connection states:
- `connecting` - Socket is attempting to connect
- `connected` - Socket is successfully connected
- `disconnected` - Socket is disconnected
- `error` - Socket encountered an error

## Example App

The example app demonstrates:
- Real-time server connection
- 1-on-1 chat functionality
- Connection status monitoring
- Event emission and listening
- Proper resource cleanup

Run the example:

```bash
cd example
flutter run
```

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
