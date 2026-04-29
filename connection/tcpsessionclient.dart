import 'dart:io';
import 'dart:typed_data';

export 'dart:typed_data';

class TcpSessionClient {
  Socket? _socket;
  int _clientId = -1;

  bool get isConnected => _socket != null;
  int get clientId => _clientId;

  Future<bool> connect(
    String serverIp,
    int port,
    void Function(Uint8List data) onData,
    void Function(int) onConnected,
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

    _socket!.listen(
      (data) {
        _internalOnData(data, onData, onConnected);
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
    _clientId = -1;
    _socket = null;
  }

  void sendMessage(Uint8List data) {
    if (_socket == null) return;

    _socket!.add(data);
  }

  void _internalOnData(Uint8List data, Function(Uint8List) onData, Function(int) onConnected) {
    if (data.length < 4) {
      throw Exception("Received data is too short to contain client ID");
    }

    if(data.length == 4) {
      // This is the initial message from the server containing the client ID
      if(_clientId != -1) {
        throw Exception("Received client ID message, but client ID is already set");
      }

      _clientId = ByteData.sublistView(data).getInt32(0, Endian.little);
      onConnected(_clientId);
      return;
    }

    final msgClientId = ByteData.sublistView(data).getInt32(0, Endian.little);

    if(msgClientId != _clientId) {
      throw Exception("Received message with client ID $msgClientId, but expected $_clientId");
    }

    final msgData = ByteData.sublistView(data).buffer.asUint8List(4); // Skip the first 4 bytes (client ID header)
    onData(msgData);
  }

}
