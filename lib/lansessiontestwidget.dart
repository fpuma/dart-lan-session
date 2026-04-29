import 'package:flutter/material.dart';
import 'dartlansession/connection/tcpsessionclient.dart';
import 'dartlansession/connection/tcpsessionserver.dart';
import 'dartlansession/discovery/discoveryclient.dart';
import 'dartlansession/discovery/discoveryserver.dart';
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
  (InternetAddress, int, int)? _connectedServer;

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

  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  final List<String> _logMessages = [];

  @override
  Widget build(BuildContext context) {
    Widget result;

    List<Widget> logWidgets = [];

    for (final log in _logMessages) {
      logWidgets.add(Text(log));
    }

    if (_discoveryServer.isListening) {
      result = Column(
        children: [
          Text("Server is listening on port: ${_discoveryServer.port}"),
          Text("Connected clients: ${_connectedClients.length}"),
          TextButton(
            onPressed: () {
              setState(() {
                _discoveryServer.stop();
                _tcpSessionServer.stopListening();
                _logMessages.clear();
              });
            },
            child: Text("Stop Server"),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _clientIdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'ClientId',
                hintText: 'Enter client ID',
              ),
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'Msg',
                hintText: 'Enter message',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final clientId = int.tryParse(_clientIdController.text);
                final data = utf8.encode(_messageController.text);
                _tcpSessionServer.sendMessage(clientId!, data);
                _messageController.clear();
                _clientIdController.clear();
              });
            },
            child: Text("Send"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final data = utf8.encode(_messageController.text);
                _tcpSessionServer.broadcast(data);
                _messageController.clear();
              });
            },
            child: Text("Broadcast"),
          ),
          ...logWidgets
        ],
      );
    } else if (_connectedServer != null) {
      final (address, port, clientId) = _connectedServer!;
      result = Column(
        children: [
          Text(
            "Connected to server: ${address.address.toString()}:$port (Client ID: $clientId)",
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _tcpSessionClient.disconnect();
                _connectedServer = null;
              });
            },
            child: Text("Disconnect"),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'Msg',
                hintText: 'Enter message',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final data = utf8.encode(_messageController.text);
                _tcpSessionClient.sendMessage(data);
                _messageController.clear();
              });
            },
            child: Text("Send"),
          ),
          ...logWidgets
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
                    setState(() {
                      _logMessages.add(utf8.decode(data));
                    });
                  },
                  (int clientId) {
                    // Handle successful connection
                    setState(() {
                      _discoveredServers.clear();
                      _connectedServer = (address, port, clientId);
                    });
                  },
                  () {
                    // Handle disconnection
                    setState(() {
                      _connectedServer = null;
                      _logMessages.clear();
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
                _tcpSessionServer
                    .startListening(
                      (clientId, data) {
                        // Handle incoming data from clients
                        setState(() {
                          _logMessages.add("($clientId): ${utf8.decode(data)}");
                        });
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
                      port: _port,
                    )
                    .then((addressNPort) {
                      final (address, port) = addressNPort;

                      if (port == 0) {
                        return;
                      }

                      _discoveryServer.start((address, port, data) {
                        final message = utf8.decode(data);
                        final shouldReply = message == "DISCOVER_SERVER";
                        final replyData = Uint8List.fromList(
                          utf8.encode("SERVER_HERE"),
                        );
                        return (shouldReply, replyData);
                      }, port: _port);
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
