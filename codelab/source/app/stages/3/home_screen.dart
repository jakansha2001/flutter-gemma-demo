import 'package:flutter/material.dart';

import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On-Device Gemma')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          DemoTile(
            icon: Icons.chat_bubble_outline,
            title: 'Chat & vision',
            subtitle: 'Ask about text or a photo',
            screen: ChatScreen(),
          ),
          DemoTile(
            icon: Icons.psychology_outlined,
            title: 'Thinking',
            subtitle: 'Watch the reasoning stream before the answer',
            screen: ChatScreen(thinking: true),
          ),
        ],
      ),
    );
  }
}

class DemoTile extends StatelessWidget {
  const DemoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.screen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => screen)),
      ),
    );
  }
}
