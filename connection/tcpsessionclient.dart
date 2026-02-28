import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

export 'dart:typed_data';

class TcpSessionClient {
  Socket? _socket;

  bool get isConnected => _socket != null;

  Future<bool> connect(
    String serverIp,
    int port,
    void Function(Uint8List data) onData,
    void Function() onConnected,
    void Function() onDisconnected,
  ) async {
    try {
      _socket = await Socket.connect(serverIp, port);
    } catch (e) {
      return false;
    }

    if (_socket == null) {
      return false;
    }

    onConnected();

    _socket!.listen(
      (data) {
        onData(data);
      },
      onDone: () {
        disconnect();
        onDisconnected();
      },
      onError: (_) {
        disconnect();
        onDisconnected();
      },
    );

    return true;
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }

  void sendMessage(dynamic data) {
    if (_socket == null) return;

    final bytes = _normalizeData(data);
    _socket!.add(bytes);
  }

  // ---------------------------
  // Internal helpers
  // ---------------------------

  Uint8List _normalizeData(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String) return Uint8List.fromList(utf8.encode(data));

    throw ArgumentError("Data must be String, List<int>, or Uint8List");
  }
}
