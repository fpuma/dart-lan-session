import 'dart:io';
import 'dart:typed_data';

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

  Future<void> start(int port, MessageCallback onMessage) async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
      reusePort: true,
    );

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
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
  }
}
