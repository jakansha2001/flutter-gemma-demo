import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:gemma_vision_demo/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env
  await dotenv.load(fileName: ".env");

  // Initialize flutter_gemma with HuggingFace token
  FlutterGemma.initialize(
    huggingFaceToken: dotenv.env['HUGGINGFACE_TOKEN'],
    maxDownloadRetries: 10,
  );

  runApp(const GemmaDemoApp());
}

class GemmaDemoApp extends StatelessWidget {
  const GemmaDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma Vision Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro',
      ),
      home: const HomeScreen(),
    );
  }
}