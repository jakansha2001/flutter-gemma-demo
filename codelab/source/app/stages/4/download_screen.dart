import 'package:flutter/material.dart';

import 'gemma_service.dart';
import 'home_screen.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  bool _checking = true;
  bool _downloading = false;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  Future<void> _checkInstalled() async {
    if (await GemmaService.isInstalled()) {
      _openHome();
    } else if (mounted) {
      setState(() => _checking = false);
    }
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await GemmaService.install(
        onProgress: (percent) {
          if (mounted) setState(() => _progress = percent);
        },
      );
      _openHome();
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '$e';
        });
      }
    }
  }

  void _openHome() {
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _checking
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text('Gemma 4 E2B', style: text.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      'About 2.6 GB. Downloaded once, then it runs offline.',
                      style: text.bodyLarge,
                    ),
                    const Spacer(),
                    if (_downloading) ...[
                      LinearProgressIndicator(value: _progress / 100),
                      const SizedBox(height: 12),
                      Text('$_progress%'),
                    ] else
                      FilledButton.icon(
                        onPressed: _download,
                        icon: const Icon(Icons.download),
                        label: const Text('Download model'),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
