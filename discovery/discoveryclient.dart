import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

export 'dart:io';
export 'dart:typed_data';

class DiscoveryClient {
  bool _isDiscovering = false;

  DiscoveryClient();

  bool get isDiscovering => _isDiscovering;

  Future<List<(InternetAddress, int, Uint8List)>> discoverServers(
    int port,
    Uint8List data,
    Duration timeout,
  ) async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
      reusePort: true,
    );

    final servers = <(InternetAddress, int, Uint8List)>[];

    socket.broadcastEnabled = true;

    // Send broadcast
    socket.send(data, InternetAddress("255.255.255.255"), port);

    // Listen for replies
    final completer = Completer<List<(InternetAddress, int, Uint8List)>>();

    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          servers.add((datagram.address, datagram.port, datagram.data));
        }
      }
    });

    _isDiscovering = true;

    // Stop after timeout
    Future.delayed(timeout, () {
      socket.close();
      if (!completer.isCompleted) {
        completer.complete(servers);
        _isDiscovering = false;
      }
    });

    return completer.future;
  }
}
