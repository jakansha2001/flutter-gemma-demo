import 'package:flutter/material.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:gemma_vision_demo/screens/chat_screen.dart';

class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  // Gemma 3 Nano E2B (gated model, ~3.1GB, multimodal vision)
  static const String _modelUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task';
  static const String _modelName = 'gemma-3n-E2B-it-int4.task';

  bool _isChecking = true;
  bool _isInstalled = false;
  bool _isDownloading = false;
  int _downloadProgress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkIfModelExists();
  }

  Future<void> _checkIfModelExists() async {
    try {
      final installed = await FlutterGemma.isModelInstalled(_modelName);
      setState(() {
        _isInstalled = installed;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _isChecking = false;
        _errorMessage = 'Error checking model: $e';
      });
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _errorMessage = null;
    });

    try {
      await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromNetwork(
            _modelUrl,
            foreground:
                true, // ← ADD THIS — forces foreground service, more reliable for large files
          )
          .withProgress((progress) {
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
              });
            }
          })
          .install();

      setState(() {
        _isDownloading = false;
        _isInstalled = true;
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Download failed: $e';
      });
    }
  }

  void _goToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gemma 3 Nano E2B',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Multimodal · 2B params · 3.1 GB',
                style: TextStyle(
                  color: Color(0xFFFF5722),
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              if (_isChecking)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5722)),
                )
              else if (_errorMessage != null)
                _buildErrorView()
              else if (_isInstalled)
                _buildReadyView()
              else if (_isDownloading)
                _buildDownloadingView()
              else
                _buildDownloadPromptView(),
              const Spacer(),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadPromptView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Download the model once. Run it forever.',
          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _downloadModel,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'Download Model',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Downloading model...',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _downloadProgress / 100,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5722)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$_downloadProgress%',
          style: const TextStyle(
            color: Color(0xFFFF5722),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This is a one-time download. After this, inference is free.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildReadyView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFFFF5722), size: 32),
            const SizedBox(width: 12),
            const Text(
              'Model ready on-device',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _goToChat,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'Start Chat →',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Error',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() => _errorMessage = null);
              _downloadModel();
            },
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFFFF5722)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT THIS MODEL',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Gemma 3 Nano E2B — Google\'s on-device multimodal AI. '
            'Understands text and images. Runs entirely on your phone. '
            'No data leaves this device.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
