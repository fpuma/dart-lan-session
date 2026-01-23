import 'dart:io';
import 'dart:typed_data';

typedef MessageCallback =
    (bool, Uint8List) Function(
      InternetAddress address,
      int port,
      Uint8List data,
    );