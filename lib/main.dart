
import 'package:fight_report/view/MainView.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight
  ]).then((_) {
    runApp(MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.blueAccent,
      ),
      home:MainView(),
    ));
  });
}

