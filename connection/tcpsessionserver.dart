import 'dart:io';
import 'dart:typed_data';

export 'dart:io';
export 'dart:typed_data';

class TcpSessionServer {
  ServerSocket? _server;
  final Map<int, Socket> _clients = {};
  int _nextClientId = 1;

  bool get isListening => _server != null;
  int get port => _server?.port ?? 0;

  Future<(InternetAddress, int)> startListening(
    void Function(int clientId, Uint8List data) onData,
    void Function(int clientId) onConnected,
    void Function(int clientId) onDisconnected, {
    int port = 0,
  }) async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    } catch (e) {
      _server = null;
      return (InternetAddress.anyIPv4, 0);
    }

    if (_server == null) {
      return (InternetAddress.anyIPv4, 0);
    }

    // This listens for new client connections
    _server!.listen((Socket socket) {
      final clientId = _nextClientId++;
      _clients[clientId] = socket;

      // This listens for data sent from the connected client
      socket.listen(
        (data) {
          onData(clientId, data);
        },
        onDone: () => _handleDisconnect(clientId, onDisconnected),
        onError: (_) => _handleDisconnect(clientId, onDisconnected),
      );

      socket.add(_clientIdToBytes(clientId));
      onConnected(clientId);
    });

    return (_server!.address, _server!.port);
  }

  Future<void> stopListening() async {
    for (final socket in _clients.values) {
      await socket.close();
    }
    _clients.clear();

    await _server?.close();
    _server = null;
  }

  void broadcast(Uint8List data) {
    _clients.forEach((clientId, socket) {
      final messageWithHeader = _addClientIdHeader(clientId, data);
      socket.add(messageWithHeader);
    });
  }

  void sendMessage(int clientId, Uint8List data) {
    final socket = _clients[clientId];
    
    if (socket == null) return;

    final messageWithHeader = _addClientIdHeader(clientId, data);
    socket.add(messageWithHeader);
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

  Uint8List _clientIdToBytes(int clientId) {
    final byteData = ByteData(4);
    byteData.setInt32(0, clientId, Endian.little);
    return byteData.buffer.asUint8List();
  }

  Uint8List _addClientIdHeader(int clientId, Uint8List data) {
    Uint8List clientIdBytes = _clientIdToBytes(clientId);

    final messageWithHeader = Uint8List(clientIdBytes.length + data.length);
    messageWithHeader.setRange(0, clientIdBytes.length, clientIdBytes);
    messageWithHeader.setRange(clientIdBytes.length, messageWithHeader.length, data);
    return messageWithHeader;
  }
}
