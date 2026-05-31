import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/settings_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _finishOnboarding(BuildContext context,
      {bool goToSettings = false}) async {
    final settings = context.read<SettingsState>();
    await settings.setOnboardingCompleted(true);
    if (!context.mounted) return;

    if (goToSettings) {
      Navigator.pushReplacementNamed(context, '/settings');
    } else {
      Navigator.pushReplacementNamed(context, '/notes');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(theme, colorScheme),
                  _buildWhyPage(theme, colorScheme),
                ],
              ),
            ),
            _buildBottomControls(colorScheme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WELCOME TO STONEPAD',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child:
                Icon(Icons.menu_book, size: 48, color: colorScheme.onPrimary),
          ),
          const SizedBox(height: 32),
          Text(
            'Notes that\nstay yours.',
            style: theme.textTheme.headlineLarge
                ?.copyWith(fontSize: 40, height: 1.1),
          ),
          const SizedBox(height: 24),
          Text(
            'Plain Markdown on your phone - synced to a server you own, or to no one\'s at all.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyPage(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yours, end to end.',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 48),
          _buildFeatureRow(
            icon: Icons.cloud_off,
            title: 'Works fully offline',
            desc:
                'Every note is a file on your device. No account, no internet needed.',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(
            icon: Icons.dns,
            title: 'Sync to your own server',
            desc:
                'Self-host on a Pi, NAS, or VPS - or relay through a free cloud tier.',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(
            icon: Icons.edit_document,
            title: 'Rich editing, plain Markdown',
            desc:
                'Tables, checklists, and styles - all saved as portable .md files.',
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
      {required IconData icon,
      required String title,
      required String desc,
      required ColorScheme colorScheme}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(desc,
                  style: TextStyle(
                      color: colorScheme.onSurfaceVariant, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_currentPage == 0) {
                  _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                } else {
                  _finishOnboarding(context, goToSettings: true);
                }
              },
              child: Text(_currentPage == 0
                  ? 'Continue →'
                  : 'Setup server connection →'),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              if (_currentPage == 0) {
                _finishOnboarding(context, goToSettings: true);
              } else {
                _finishOnboarding(context, goToSettings: false);
              }
            },
            child: Text(
              _currentPage == 0
                  ? 'I already have a server'
                  : 'Skip - use Stonepad offline',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
