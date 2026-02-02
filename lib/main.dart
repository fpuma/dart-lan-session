import 'package:flutter/material.dart';
import 'lansessiontestwidget.dart';
import 'dart:io';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {

    const double sepSize = 20.0;

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              LanSessionTestWidget(),
              SizedBox(width: sepSize),
              LanSessionTestWidget(),
              SizedBox(width: sepSize),
              LanSessionTestWidget(),
              SizedBox(width: sepSize),
              LanSessionTestWidget(),
              SizedBox(width: sepSize),
              LanSessionTestWidget(),
              SizedBox(width: sepSize),
              Text(InternetAddress.anyIPv4.address.toString()),
              SizedBox(width: sepSize),
              Text(InternetAddress.loopbackIPv4.address.toString()),
            ],
          ),
        ),
      ),
    );
  }
}
