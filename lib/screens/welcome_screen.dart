import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Shown once, right after onboarding completes. Pure presentation:
/// no images (none exist in the project yet) and no data loading.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onContinue;
  const WelcomeScreen({super.key, required this.onContinue});

  Future<void> _share() async {
    // Deliberately no link: the app has no store listing or website yet,
    // and inventing a URL here would be wrong.
    await SharePlus.instance.share(
      ShareParams(text: 'Check out Stanza - news, one stanza at a time.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stanza',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('News, one stanza at a time.',
                        style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 40),
                    Text.rich(
                      TextSpan(
                        text: 'Welcome to ',
                        children: [
                          TextSpan(
                            text: 'Stanza.',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text('Thank you for being here.',
                        style: TextStyle(color: Colors.white54, fontSize: 16)),
                    const SizedBox(height: 24),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Hi, I'm Pratham 👋",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            Text(
                              "I'm a college student and Stanza is my dream project. "
                              'I built this app to make news simple, engaging and easy to keep up with.',
                              style: TextStyle(color: Colors.white70, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.eco_outlined,
                            title: 'A student project',
                            body: 'Built with passion and curiosity.',
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.favorite_border,
                            title: 'Your support matters',
                            body: 'Sharing the app helps a lot.',
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.groups_outlined,
                            title: 'Growing together',
                            body: 'Your feedback helps me improve.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.ios_share),
                        title: const Text('Share Stanza'),
                        subtitle: const Text('If you like the app, consider sharing it with your friends.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _share,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onContinue,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Start exploring'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoTile({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
