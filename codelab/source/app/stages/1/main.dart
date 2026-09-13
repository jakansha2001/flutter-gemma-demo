import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'download_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // flutter_gemma's core ships without an inference engine. Register the
  // engine package you added: LiteRtLmEngine runs .litertlm models.
  await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);

  runApp(const GemmaApp());
}

class GemmaApp extends StatelessWidget {
  const GemmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On-Device Gemma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A73E8),
        brightness: Brightness.dark,
      ),
      home: const DownloadScreen(),
    );
  }
}
