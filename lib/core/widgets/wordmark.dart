import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../config/app_config.dart';

/// "Let's Spill" set purely in type, no logo image.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 44, this.showTagline = false});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = context.text.displayLarge!;
    return Semantics(
      header: true,
      label: AppConfig.appName,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: "Let's ",
                  style: base.copyWith(fontSize: size).withWeight(500),
                ),
                TextSpan(
                  text: 'Spill',
                  style: base.copyWith(fontSize: size).withWeight(850),
                ),
                TextSpan(
                  text: '.',
                  style: base.copyWith(fontSize: size, color: t.inkMuted),
                ),
              ],
            ),
          ),
          if (showTagline) ...[
            SizedBox(height: size * 0.18),
            Text(
              AppConfig.tagline,
              style: context.text.titleMedium!
                  .copyWith(color: t.inkMuted, letterSpacing: 0.2)
                  .withWeight(500),
            ),
          ],
        ],
      ),
    );
  }
}
