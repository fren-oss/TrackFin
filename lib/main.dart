import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/theme.dart';
import 'root_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF5F0E8),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MaterialApp(
      title: 'TrackFin',
      debugShowCheckedModeBanner: false,
      theme: buildBauhausTheme(),
      home: const TrackFinApp(),
    ),
  );
}
