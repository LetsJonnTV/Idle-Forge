import 'package:flutter/material.dart';

/// Reusable "Coming Soon" screen for unimplemented features.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.featureName,
    required this.featureIcon,
    this.description,
  });

  final String featureName;
  final IconData featureIcon;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF191919) : const Color(0xFFF4F4F4);
    final textPrimary = isDark
        ? const Color(0xFFE2E2E2)
        : const Color(0xFF1A1A1A);
    final textSecondary = isDark
        ? const Color(0xFF888888)
        : const Color(0xFF666666);
    final accent = const Color(0xFFD4A84B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          featureName,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(featureIcon, size: 72, color: accent.withAlpha(180)),
              const SizedBox(height: 20),
              Text(
                featureName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withAlpha(40),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withAlpha(80)),
                ),
                child: Text(
                  '🚧  Coming Soon',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description ??
                    'This feature is currently in development.\nStay tuned for future updates!',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
