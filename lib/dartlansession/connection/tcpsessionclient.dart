import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

class TcpSessionClient {
  Socket? _socket;

  // Callbacks
  void Function()? _onConnected;
  void Function()? _onDisconnected;
  void Function(Uint8List data)? _onMessage;

  Future<void> connect(String serverIp, int port) async {
    _socket = await Socket.connect(serverIp, port);

    _onConnected?.call();

    _socket!.listen(
      (data) {
        _onMessage?.call(Uint8List.fromList(data));
      },
      onDone: () {
        _handleDisconnect();
      },
      onError: (_) {
        _handleDisconnect();
      },
    );
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }

  void onConnected(void Function() callback) {
    _onConnected = callback;
  }

  void onDisconnected(void Function() callback) {
    _onDisconnected = callback;
  }

  void onMessage(void Function(Uint8List data) callback) {
    _onMessage = callback;
  }

  void sendMessage(dynamic data) {
    if (_socket == null) return;

    final bytes = _normalizeData(data);
    _socket!.add(bytes);
  }

  // ---------------------------
  // Internal helpers
  // ---------------------------

  void _handleDisconnect() {
    _socket = null;
    _onDisconnected?.call();
  }

  Uint8List _normalizeData(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String) return Uint8List.fromList(utf8.encode(data));

    throw ArgumentError("Data must be String, List<int>, or Uint8List");
  }
}