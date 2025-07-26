import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:socket_io_native_client/socket_io_native_client.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Socket.IO Native Demo', home: SocketDemoScreen());
  }
}

class SocketDemoScreen extends StatefulWidget {
  const SocketDemoScreen({super.key});

  @override
  State<SocketDemoScreen> createState() => _SocketDemoScreenState();
}

// Helper function to create a consistent room name between two users
String createChatRoomName(String userId1, String userId2) {
  List<String> ids = [userId1, userId2];
  ids.sort(); // Sort the IDs alphabetically
  return ids.join('-'); // Join them with a hyphen
}

class _SocketDemoScreenState extends State<SocketDemoScreen> {
  final SocketIoNative _socketService = SocketIoNative();
  final TextEditingController _urlController = TextEditingController(text: 'http://localhost:3001');
  final TextEditingController _otherUserIdController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _mySocketId = "Not connected";
  String _chatRoomName = "";
  String _connectionStatus = "Disconnected";
  final List<String> _chatMessages = [];
  final List<String> _beforeConnectionTestMessages = [];

  @override
  void initState() {
    super.initState();
    _listenToStatusUpdates();
    _demonstrateBeforeConnectionFeature();
  }

  void _demonstrateBeforeConnectionFeature() {
    log("🧪 Testing before-connection functionality...");
    setState(() {
      _beforeConnectionTestMessages.add("🧪 Testing before-connection functionality...");
    });

    try {
      // Test 1: Set up listeners before connection - should not throw error
      _socketService.on('test_event_early', (data) {
        log("📩 Early listener received: $data");
        setState(() {
          _beforeConnectionTestMessages.add("📩 Early listener received: $data");
        });
      });

      _socketService.on('welcome', (data) {
        log("👋 Welcome event received: $data");
        setState(() {
          _beforeConnectionTestMessages.add("👋 Welcome event: $data");
        });
      });

      setState(() {
        _beforeConnectionTestMessages.add("✅ Successfully set up listeners before connection");
      });
      log("✅ Successfully set up listeners before connection");

      // Test 2: Try to emit before connection - should not throw error
      _socketService.emit('early_emit_test', {
        'message': 'This should be ignored',
        'timestamp': DateTime.now().toIso8601String(),
      });

      setState(() {
        _beforeConnectionTestMessages.add("✅ Successfully called emit before connection (ignored)");
      });
      log("✅ Successfully called emit before connection (ignored)");
    } catch (e) {
      log("❌ Error during before-connection test: $e");
      setState(() {
        _beforeConnectionTestMessages.add("❌ Error: $e");
      });
    }
  }

  void _testAfterConnection() {
    // Test emit after connection works
    _socketService.emit('test_event_early', {
      'message': 'Testing early listener after connection',
      'timestamp': DateTime.now().toIso8601String(),
    });
    log("📤 Sent test event to early listener after connection");
  }

  void _listenToStatusUpdates() {
    _socketService.statusStream.listen((status) {
      setState(() {
        switch (status) {
          case ConnectionStatus.connecting:
            _connectionStatus = "Connecting...";
            break;
          case ConnectionStatus.connected:
            _connectionStatus = "Connected";
            // Test that early listeners work after connection
            _testAfterConnection();
            break;
          case ConnectionStatus.disconnected:
            _connectionStatus = "Disconnected";
            _mySocketId = "Not connected";
            break;
          case ConnectionStatus.error:
            _connectionStatus = "Error";
            break;
        }
      });
    });
  }

  void _connectToServer() async {
    if (_urlController.text.isEmpty) return;

    try {
      await _socketService.connect(
        _urlController.text,
        onSocketIdReceived: (socketId) {
          setState(() {
            _mySocketId = socketId;
          });
          log("Socket ID received: $socketId");
        },
        extraOptions: SocketConnectionOptions(
          forceNew: true,
          transports: ['websocket'],
          reconnectionAttempts: 10,
          reconnectionDelay: 1000,
          reconnectionDelayMax: 5000,
          reconnection: true,
          timeout: 10000,
        ),
      );

      // Set up event listeners
      _socketService.on('receive_message', (data) {
        log("Message received: $data");
        if (mounted) {
          setState(() {
            _chatMessages.insert(0, data.toString());
          });
        }
      });

      _socketService.on('room_notification', (data) {
        log("Room notification: $data");
        if (mounted) {
          setState(() {
            _chatMessages.insert(0, "📢 ${data.toString()}");
          });
        }
      });

      // Set up connection callbacks
      _socketService.onConnected(() {
        log("Socket connected successfully");
      });

      _socketService.onDisconnected(() {
        log("Socket disconnected");
      });

      _socketService.onError((reason) {
        log("Socket error: $reason");
        if (mounted) {
          setState(() {
            _connectionStatus = "Error: $reason";
          });
        }
      });
    } catch (e) {
      log("Connection error: $e");
    }
  }

  void _disconnectFromServer() async {
    await _socketService.disconnect();
  }

  void _joinChat() {
    if (_otherUserIdController.text.isEmpty || _mySocketId == "Not connected") return;

    // 1. Create the unique room name
    final roomName = createChatRoomName(_mySocketId, _otherUserIdController.text);
    setState(() => _chatRoomName = roomName);

    // 2. Join the room
    _socketService.emit("join_room", {"senderId": _mySocketId, "room": roomName});

    setState(() {
      _chatMessages.insert(0, "🚪 Joined room: $roomName");
    });
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty || _chatRoomName.isEmpty) return;

    // 3. Send a message to the room
    _socketService.emit("send_message", {
      "message": _messageController.text,
      "senderId": _mySocketId,
      "room": _chatRoomName,
    });

    setState(() {
      _chatMessages.insert(0, "📤 You: ${_messageController.text}");
    });

    _messageController.clear();
  }

  void _sendCustomEvent() {
    _socketService.emit("custom_event", {
      "data": "Hello from Flutter!",
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "senderId": _mySocketId,
    });
  }

  void _testDisconnectedEmit() {
    _socketService.emit("test_while_disconnected", {
      "message": "This should be ignored when disconnected",
      "timestamp": DateTime.now().toIso8601String(),
    });
    setState(() {
      _beforeConnectionTestMessages.add("📤 Tried emit while disconnected (should be ignored)");
    });
  }

  @override
  void dispose() {
    _socketService.off('receive_message');
    _socketService.off('room_notification');
    _socketService.off('test_event_early');
    _socketService.off('welcome');
    _socketService.disconnect();
    _socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Socket.IO Native Demo"),
        backgroundColor: _connectionStatus == "Connected" ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Before Connection Test Section
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🧪 Before Connection Test",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blue.shade800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "This demonstrates that emit() and on() can be called before connection without errors.",
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        itemCount: _beforeConnectionTestMessages.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Text(
                            _beforeConnectionTestMessages[index],
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_connectionStatus == "Disconnected")
                      ElevatedButton.icon(
                        onPressed: _testDisconnectedEmit,
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text("Test Emit While Disconnected", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Connection Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Connection", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text(
                      "Status: $_connectionStatus",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _connectionStatus == "Connected" ? Colors.green : Colors.red,
                      ),
                    ),
                    Text("Socket ID: $_mySocketId"),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: "Server URL",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _connectionStatus == "Connected" ? null : _connectToServer,
                          child: const Text("Connect"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _connectionStatus == "Connected" ? _disconnectFromServer : null,
                          child: const Text("Disconnect"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _connectionStatus == "Connected" ? _sendCustomEvent : null,
                          child: const Text("Test Event"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Chat Section
            if (_connectionStatus == "Connected") ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("1-on-1 Chat Demo", style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _otherUserIdController,
                        decoration: const InputDecoration(
                          labelText: "Enter other user's Socket ID",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _joinChat, child: const Text("Join Chat")),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Message Section
            if (_chatRoomName.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Chatting in room: $_chatRoomName",
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                labelText: "Enter message",
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(onPressed: _sendMessage, child: const Text("Send")),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Messages List
            if (_chatMessages.isNotEmpty) ...[
              Text("Messages", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Expanded(
                child: Card(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) => ListTile(title: Text(_chatMessages[index]), dense: true),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
