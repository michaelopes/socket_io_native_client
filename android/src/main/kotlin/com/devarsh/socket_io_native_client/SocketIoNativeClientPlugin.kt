package com.devarsh.socket_io_native_client

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.socket.client.IO
import io.socket.client.Socket
import org.json.JSONObject
import java.net.URISyntaxException

/** SocketIoNativeClientPlugin */
class SocketIoNativeClientPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var commandChannel : MethodChannel
    private lateinit var eventChannel : EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var socket: Socket? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        commandChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "devarsh/command")
        commandChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "devarsh/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        try {
            when (call.method) {
                "connect" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("INVALID_URL", "URL cannot be empty", null)
                        return
                    }

                    val options = call.argument<Map<String, Any>>("options")
                    connectSocket(url, options, result)
                }
                "disconnect" -> {
                    disconnectSocket(result)
                }
                "emit" -> {
                    val event = call.argument<String>("event")
                    val data = call.argument<Any>("data")

                    if (event.isNullOrEmpty()) {
                        result.error("EVENT_ERROR", "Event name cannot be empty", null)
                        return
                    }

                    emitEvent(event, data, result)
                }
                "listen" -> {
                    val event = call.argument<String>("event")

                    if (event.isNullOrEmpty()) {
                        result.error("EVENT_ERROR", "Event name cannot be empty", null)
                        return
                    }

                    listenToEvent(event, result)
                }
                "unlisten" -> {
                    val event = call.argument<String>("event")

                    if (event.isNullOrEmpty()) {
                        result.error("EVENT_ERROR", "Event name cannot be empty", null)
                        return
                    }

                    unlistenFromEvent(event, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e("SocketIoNativeClientPlugin", "Error in onMethodCall: ${e.message}", e)
            result.error("UNEXPECTED_ERROR", "An unexpected error occurred: ${e.message}", e.toString())
        }
    }

    private fun connectSocket(url: String, options: Map<String, Any>?, result: Result) {
        try {
            sendEvent("status", mapOf("status" to "connecting"))

            // Disconnect existing socket if any
            socket?.disconnect()

            // Validate URL
            try {
                java.net.URI(url)
            } catch (e: URISyntaxException) {
                sendEvent("status", mapOf("status" to "error", "reason" to "Invalid URL format"))
                result.error("INVALID_URL", "Invalid URL format: $url", e.toString())
                return
            }
            val optsBuilder = IO.Options.builder()
            optsBuilder.setUpgrade(true)
            try {
                // --- Common Properties ---
                options?.let { opts ->
                    (opts["reconnection"] as? Boolean)?.let { optsBuilder.setReconnection(it) }
                    (opts["reconnectionAttempts"] as? Number)?.let { optsBuilder.setReconnectionAttempts(it.toInt()) }
                    (opts["reconnectionDelay"] as? Number)?.let { optsBuilder.setReconnectionDelay(it.toLong()) }
                    (opts["reconnectionDelayMax"] as? Number)?.let { optsBuilder.setReconnectionDelayMax(it.toLong()) }
                    (opts["randomizationFactor"] as? Number)?.let { optsBuilder.setRandomizationFactor(it.toDouble()) }
                    (opts["timeout"] as? Number)?.let { optsBuilder.setTimeout(it.toLong()) }
                    (opts["path"] as? String)?.let { optsBuilder.setPath(it) }
                    (opts["forceNew"] as? Boolean)?.let { optsBuilder.setForceNew(it) }
                    (opts["secure"] as? Boolean)?.let { optsBuilder.setSecure(it) }
                    (opts["auth"] as? Map<String, String>)?.let { optsBuilder.setAuth(it) }
                    (opts["query"] as? String)?.let { optsBuilder.setQuery(it) }
                    val transportSet = (options.get("transports") as? List<String>)
                        ?.map { it.toString() }
                        ?.toMutableSet() ?: mutableSetOf()
                    transportSet.add("websocket")
                    optsBuilder.setTransports(transportSet.toTypedArray())
                    // --- Android-Specific Properties ---
                    (options.get("androidConfig") as? Map<String, Any>)?.let { androidConfig ->
                        (androidConfig.get("setExtraHeaders") as Map<String,List<String>>)?.let { optsBuilder.setExtraHeaders(it) }
                    }
                }

                if(socket != null){
                    socket?.disconnect()
                    socket = null
                }

                val opts = optsBuilder.build()
                socket = IO.socket(url, opts)

                socket?.let { sock ->
                    // Connection event handlers
                    sock.on(Socket.EVENT_CONNECT) {
                        val statusData = mapOf("status" to "connected", "socketId" to sock.id())
                        sendEvent("status", statusData)
                    }

                    sock.on(Socket.EVENT_CONNECT_ERROR) { args ->
                        val errorMessage = if (args.isNotEmpty()) args[0].toString() else "Connection failed"
                        Log.e("SocketIoNativeClientPlugin", "Connection error: $errorMessage")
                        sendEvent("status", mapOf("status" to "error", "reason" to errorMessage))
                    }

                    sock.on(Socket.EVENT_DISCONNECT) {
                        sendEvent("status", mapOf("status" to "disconnected"))
                    }

                    sock.connect()
                    result.success(null)
                } ?: run {
                    result.error("CONNECTION_FAILED", "Failed to create socket instance", null)
                }

            } catch (e: Exception) {
                Log.e("SocketIoNativeClientPlugin", "Error configuring socket: ${e.message}", e)
                sendEvent("status", mapOf("status" to "error", "reason" to e.message))
                result.error("CONNECTION_FAILED", "Failed to configure socket: ${e.message}", e.toString())
            }

        } catch (e: Exception) {
            Log.e("SocketIoNativeClientPlugin", "Error in connectSocket: ${e.message}", e)
            sendEvent("status", mapOf("status" to "error", "reason" to e.message))
            result.error("CONNECTION_FAILED", "Connection failed: ${e.message}", e.toString())
        }
    }

    private fun disconnectSocket(result: Result) {
        try {
            socket?.disconnect()
            socket = null
            result.success(null)
        } catch (e: Exception) {
            Log.e("SocketIoNativeClientPlugin", "Error disconnecting: ${e.message}", e)
            result.error("DISCONNECTION_FAILED", "Failed to disconnect: ${e.message}", e.toString())
        }
    }

    private fun emitEvent(event: String, data: Any?, result: Result) {
        try {
            val sock = socket
            if (sock == null || !sock.connected()) {
                result.error("NOT_CONNECTED", "Socket is not connected", null)
                return
            }

            when (data) {
                is Map<*, *> -> sock.emit(event, JSONObject(data as Map<String, Any>))
                is List<*> -> sock.emit(event, *data.toTypedArray())
                null -> sock.emit(event)
                else -> sock.emit(event, data)
            }

            result.success(null)
        } catch (e: Exception) {
            Log.e("SocketIoNativeClientPlugin", "Error emitting event: ${e.message}", e)
            result.error("EMISSION_FAILED", "Failed to emit event '$event': ${e.message}", e.toString())
        }
    }

    private fun listenToEvent(event: String, result: Result) {
        try {
            val sock = socket
            if (sock == null || !sock.connected()) {
                result.error("NOT_CONNECTED", "Socket is not connected", null)
                return
            }

            sock.on(event) { args ->
                try {
                    val data = if (args.isNotEmpty()) args[0] else null
                    val payload = mapOf("event" to event, "data" to data)
                    sendEvent("socket_event", payload)
                } catch (e: Exception) {
                    Log.e("SocketIoNativeClientPlugin", "Error processing event '$event': ${e.message}", e)
                }
            }

            result.success(null)
        } catch (e: Exception) {
            Log.e("SocketIoNativeClientPlugin", "Error listening to event: ${e.message}", e)
            result.error("EVENT_ERROR", "Failed to listen to event '$event': ${e.message}", e.toString())
        }
    }

    private fun unlistenFromEvent(event: String, result: Result) {
        try {
            socket?.off(event)
            result.success(null)
        } catch (e: Exception) {
            Log.e("SocketIoNativeClientPlugin", "Error unlistening from event: ${e.message}", e)
            result.error("EVENT_ERROR", "Failed to unlisten from event '$event': ${e.message}", e.toString())
        }
    }

    private fun sendEvent(type: String, payload: Any) {
        try {
            val event = mapOf("type" to type, "payload" to payload)
            // Ensure we're on the main thread for Flutter platform channel communication
            if (Looper.myLooper() == Looper.getMainLooper()) {
                eventSink?.success(event)
            } else {
                mainHandler.post {
                    try {
                        eventSink?.success(event)
                    } catch (e: Exception) {
                        Log.e("SocketIoNativeClientPlugin", "Error sending event on main thread: ${e.message}", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("SocketIoNativeClientPlugin", "Error sending event: ${e.message}", e)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        commandChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        socket?.disconnect()
        socket = null
    }

    // --- EventChannel.StreamHandler methods ---
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}