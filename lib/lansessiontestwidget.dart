import 'dart:io';

import 'package:flutter/material.dart';
import 'dartlansession/connection/tcpsessionclient.dart';
import 'dartlansession/connection/tcpsessionserver.dart';
import 'dartlansession/discovery/discoveryclient.dart';
import 'dartlansession/discovery/discoveryserver.dart';
import 'dart:typed_data';
import 'dart:convert';

class LanSessionTestWidget extends StatefulWidget {
  const LanSessionTestWidget({super.key});

  @override
  State<LanSessionTestWidget> createState() => _LanSessionTestWidgetState();
}

class _LanSessionTestWidgetState extends State<LanSessionTestWidget> {
  late TcpSessionClient _tcpSessionClient;
  late TcpSessionServer _tcpSessionServer;
  late DiscoveryClient _discoveryClient;
  late DiscoveryServer _discoveryServer;

  int _port = 4444;

  final List<int> _connectedClients = [];
  final List<(InternetAddress, int, Uint8List)> _discoveredServers = [];
  (InternetAddress, int)? _connectedServer;

  @override
  void initState() {
    super.initState();
    _initializeInstances();
  }

  void _initializeInstances() {
    _tcpSessionClient = TcpSessionClient();
    _tcpSessionServer = TcpSessionServer();
    _discoveryClient = DiscoveryClient();
    _discoveryServer = DiscoveryServer();
  }

  @override
  void dispose() {
    // Clean up resources if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result;

    if (_discoveryServer.isListening) {
      result = Column(
        children: [
          Text("Server is listening"),
          Text("Connected clients: ${_connectedClients.length}"),
          TextButton(
            onPressed: () {
              setState(() {
                _discoveryServer.stop();
                _tcpSessionServer.stopListening();
              });
            },
            child: Text("Stop Server"),
          ),
        ],
      );
    } else if (_connectedServer != null) {
      final (address, port) = _connectedServer!;
      result = Column(
        children: [
          Text("Connected to server: ${address.address}:$port"),
          TextButton(
            onPressed: () {
              setState(() {
                _tcpSessionClient.disconnect();
                _connectedServer = null;
              });
            },
            child: Text("Disconnect"),
          ),
        ],
      );
    } else if (_discoveryClient.isDiscovering) {
      result = Text("Discovering servers...");
    } else if (_discoveredServers.isNotEmpty) {
      result = Column(
        children: [
          Text("Discovered servers:"),
          ..._discoveredServers.map((element) {
            final (address, port, data) = element;
            return TextButton(
              child: Text("$address:$port"),
              onPressed: () {
                // Connect to the server when button is pressed
                _tcpSessionClient.connect(
                  address.address,
                  port,
                  (data) {
                    // Handle incoming data from server
                  },
                  () {
                    // Handle successful connection
                    setState(() {
                      _discoveredServers.clear();
                      _connectedServer = (address, port);
                    });
                  },
                  () {
                    // Handle disconnection
                    setState(() {
                      _connectedServer = null;
                    });
                  },
                );
              },
            );
          }),
          TextButton(
            onPressed: () {
              setState(() {
                _discoveredServers.clear();
              });
            },
            child: Text("Clear"),
          ),
        ],
      );
    } else {
      result = Column(
        children: [
          SizedBox(
            width: 50,
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Port',
                hintText: 'Enter port number',
              ),
              onChanged: (value) {
                final parsedPort = int.tryParse(value);
                if (parsedPort != null) {
                  setState(() {
                    _port = parsedPort;
                  });
                }
              },
            ),
          ),

          TextButton(
            child: Text("Open Server"),
            onPressed: () {
              setState(() {
                _tcpSessionServer.startListening(
                  _port,
                  (clientId, data) {
                    // Handle data from client
                  },
                  (clientId) {
                    // Handle new client connection
                    setState(() {
                      _connectedClients.add(clientId);
                    });
                  },
                  (clientId) {
                    // Handle client disconnection
                    setState(() {
                      _connectedClients.remove(clientId);
                    });
                  },
                );
                _discoveryServer.start(_port, (address, port, data) {
                  final message = utf8.decode(data);
                  final shouldReply = message == "DISCOVER_SERVER";
                  final replyData = Uint8List.fromList(
                    utf8.encode("SERVER_HERE"),
                  );
                  return (shouldReply, replyData);
                });
              });
            },
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _discoveryClient
                    .discoverServers(
                      _port,
                      Uint8List.fromList(utf8.encode("DISCOVER_SERVER")),
                      Duration(seconds: 2),
                    )
                    .then((serversResponses) {
                      setState(() {
                        _discoveredServers.clear();
                        for (final (address, port, data) in serversResponses) {
                          if (utf8.decode(data) == "SERVER_HERE") {
                            _discoveredServers.add((address, port, data));
                          }
                        }
                      });
                    });
              });
            },
            child: Text("Discover servers"),
          ),
        ],
      );
    }

    //result = Text("Test");

    return result;
  }
}
