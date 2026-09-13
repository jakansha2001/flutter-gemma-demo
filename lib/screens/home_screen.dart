import 'package:flutter/material.dart';
import 'package:gemma_vision_demo/gemma/gemma_service.dart';
import 'package:gemma_vision_demo/gemma/model_catalog.dart';
import 'package:gemma_vision_demo/screens/chat_screen.dart';
import 'package:gemma_vision_demo/screens/model_download_screen.dart';
import 'package:gemma_vision_demo/screens/tools_screen.dart';
import 'package:gemma_vision_demo/screens/voice_screen.dart';
import 'package:gemma_vision_demo/theme.dart';

/// Task picker. Every demo needs the weights on disk, so each tile routes
/// through [ModelDownloadScreen], which forwards straight through once the
/// model is installed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool? _installed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A download can finish while the app is backgrounded (Android foreground
    // service), so re-check the badge on resume.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final installed = await GemmaService.instance.isInstalled();
      if (mounted) setState(() => _installed = installed);
    } catch (_) {
      // A status badge is not worth an error screen — show "not ready".
      if (mounted) setState(() => _installed = false);
    }
  }

  Future<void> _open(Widget destination) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ModelDownloadScreen(next: destination)),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGlow),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.accent,
            backgroundColor: AppColors.surface,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
              children: [
                const Text('No Server.', style: AppText.hero),
                const Text('No Bills.', style: AppText.hero),
                const Text('No Internet.', style: AppText.hero),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.accentGradient.createShader(bounds),
                  child: Text(
                    'No Problem.',
                    style: AppText.hero.copyWith(
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Gap.lg,
                const Text(
                  'Gemma 4 E2B — vision, reasoning, tools and speech, '
                  'running entirely on this device.',
                  style: AppText.body,
                ),
                Gap.md,
                _StatusPill(installed: _installed),
                Gap.xl,
                _DemoTile(
                  icon: Icons.image_outlined,
                  accent: AppColors.vision,
                  title: 'Vision chat',
                  subtitle: 'Show it a photo and ask about it. Streaming, offline.',
                  badge: 'MULTIMODAL',
                  onTap: () => _open(const ChatScreen()),
                ),
                _DemoTile(
                  icon: Icons.psychology_outlined,
                  accent: AppColors.thinking,
                  title: 'Thinking mode',
                  subtitle: 'Watch the model reason before it commits to an answer.',
                  badge: 'NEW IN 1.x',
                  onTap: () => _open(const ChatScreen(thinking: true)),
                ),
                _DemoTile(
                  icon: Icons.build_outlined,
                  accent: AppColors.tool,
                  title: 'Function calling',
                  subtitle: 'It calls your Dart, then answers with the result.',
                  badge: 'NEW IN 1.x',
                  onTap: () => _open(const ToolsScreen()),
                ),
                _DemoTile(
                  icon: Icons.graphic_eq,
                  accent: AppColors.voice,
                  title: 'Voice loop',
                  subtitle: 'Speak → transcribe → answer → speak back. Three models, no cloud.',
                  badge: 'NEW IN 1.x',
                  onTap: () => _open(const VoiceScreen()),
                ),
                Gap.md,
                const _FooterNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.installed});

  final bool? installed;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (installed) {
      null => (Icons.hourglass_empty_rounded, 'Checking…', AppColors.textTertiary),
      true => (Icons.offline_bolt_rounded, 'Model ready · works offline', AppColors.success),
      false => (
        Icons.cloud_download_outlined,
        'Model not downloaded · ${Models.llmSize}',
        AppColors.textSecondary,
      ),
    };
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: color.withValues(alpha: .28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              Gap.wSm,
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                Gap.wMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(title, style: AppText.heading)),
                          Gap.wSm,
                          TagChip(label: badge, color: accent),
                        ],
                      ),
                      Gap.xs,
                      Text(subtitle, style: AppText.bodySmall),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.bgElevated,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppColors.textTertiary,
          ),
          Gap.wSm,
          const Expanded(
            child: Text(
              'The network is used exactly once, to download the model. '
              'After that you can switch on airplane mode and everything here '
              'still works — no prompt ever leaves the device.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
