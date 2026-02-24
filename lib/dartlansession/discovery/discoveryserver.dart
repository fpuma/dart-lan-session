import 'dart:io';
import 'dart:typed_data';

export 'dart:io';
export 'dart:typed_data';

typedef MessageCallback =
    (bool, Uint8List) Function(
      InternetAddress address,
      int port,
      Uint8List data,
    );

class DiscoveryServer {
  RawDatagramSocket? _socket;

  DiscoveryServer();

  bool get isListening => _socket != null;
  int get port => _socket?.port ?? 0;
  InternetAddress get address => _socket?.address ?? InternetAddress.anyIPv4;

  Future<(InternetAddress, int)> start(
    MessageCallback onMessage, {
    int port = 0,
  }) async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (e) {
      _socket = null;
      return (InternetAddress.anyIPv4, 0);
    }

    if (_socket == null) {
      return (InternetAddress.anyIPv4, 0);
    }

    // Listen for incoming datagrams
    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram == null) return;

        final (shouldReply, replyData) = onMessage.call(
          datagram.address,
          datagram.port,
          datagram.data,
        );

        if (shouldReply) {
          _socket!.send(replyData, datagram.address, datagram.port);
        }
      }
    });

    InternetAddress resultAddress = _socket?.address ?? InternetAddress.anyIPv4;
    int resultPort = _socket?.port ?? 0;

    return (resultAddress, resultPort);
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }
}
