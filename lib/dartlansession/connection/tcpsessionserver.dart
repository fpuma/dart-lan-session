import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

class TcpSessionServer {
  ServerSocket? _server;
  final Map<int, Socket> _clients = {};
  int _nextClientId = 1;

  bool get isListening => _server != null;

  Future<void> startListening(
    void Function(int clientId, Uint8List data) onData,
    void Function(int clientId) onConnected,
    void Function(int clientId) onDisconnected,
    {int port = 0}
  ) async {
    //How to handle port already in use?
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);

    _server!.listen((Socket socket) {
      final clientId = _nextClientId++;
      _clients[clientId] = socket;

      onConnected(clientId);

      socket.listen(
        (data) {
          onData(clientId, data);
        },
        onDone: () => _handleDisconnect(clientId, onDisconnected),
        onError: (_) => _handleDisconnect(clientId, onDisconnected),
      );
    });
  }

  Future<void> stopListening() async {
    for (final socket in _clients.values) {
      await socket.close();
    }
    _clients.clear();

    await _server?.close();
    _server = null;
  }

  void broadcast(dynamic data) {
    final bytes = _normalizeData(data);
    for (final socket in _clients.values) {
      socket.add(bytes);
    }
  }

  void sendMessage(int clientId, dynamic data) {
    final socket = _clients[clientId];
    if (socket == null) return;

    final bytes = _normalizeData(data);
    socket.add(bytes);
  }

  // ---------------------------
  // Internal helpers
  // ---------------------------

  void _handleDisconnect(
    int clientId,
    void Function(int clientId)? onDisconnected,
  ) {
    final socket = _clients.remove(clientId);
    socket?.close();
    onDisconnected?.call(clientId);
  }

  Uint8List _normalizeData(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String) return Uint8List.fromList(utf8.encode(data));

    throw ArgumentError("Data must be String, List<int>, or Uint8List");
  }
}
