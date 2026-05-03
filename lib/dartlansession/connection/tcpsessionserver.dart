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

      sendMessage(clientId, Uint8List(0)); // Send an empty message to trigger the client to set its client ID
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
      final messageWithHeader = _addHeader(clientId, data);
      socket.add(messageWithHeader);
    });
  }

  void sendMessage(int clientId, Uint8List data) {
    final socket = _clients[clientId];
    
    if (socket == null) return;

    final messageWithHeader = _addHeader(clientId, data);
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

  Uint8List _intToBytes(int value) {
    final byteData = ByteData(4);
    byteData.setInt32(0, value, Endian.little);
    return byteData.buffer.asUint8List();
  }

  Uint8List _addHeader(int clientId, Uint8List data) {
    Uint8List dataLengthBytes = _intToBytes(data.length);
    Uint8List clientIdBytes = _intToBytes(clientId);

    final messageWithHeader = Uint8List(dataLengthBytes.length + clientIdBytes.length + data.length);
    int cursor = 0;
    messageWithHeader.setRange(cursor, dataLengthBytes.length, dataLengthBytes);
    cursor += dataLengthBytes.length;

    messageWithHeader.setRange(cursor, cursor + clientIdBytes.length, clientIdBytes);
    cursor += clientIdBytes.length;

    if(data.isNotEmpty) {
      messageWithHeader.setRange(cursor, messageWithHeader.length, data);
    }
    return messageWithHeader;
  }
}
