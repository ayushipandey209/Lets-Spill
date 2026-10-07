import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../utils/ui_notice.dart';

/// Centers content and caps its width for tablets, desktop and web.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Horizontal padding that grows on wide screens so slivers line up with
/// [ContentWidth].
EdgeInsets responsiveHorizontalPadding(
  BuildContext context, {
  double maxWidth = AppSpacing.maxContentWidth,
  double side = AppSpacing.lg,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final gutter = width > maxWidth + side * 2 ? (width - maxWidth) / 2 : side;
  return EdgeInsets.symmetric(horizontal: gutter);
}

/// Black filled button that swaps its label for a spinner while busy and
/// ignores taps meanwhile.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final child = AnimatedSwitcher(
      duration: AppMotion.fast,
      child: busy
          ? SizedBox(
              key: const ValueKey('busy'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.onInk),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: t.onInk),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
    final button = Semantics(
      button: true,
      label: busy ? '$label, in progress' : null,
      child: FilledButton(onPressed: busy ? () {} : onPressed, child: child),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? OutlinedButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label),
          );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Small uppercase label used for categories and section eyebrows.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.text.labelSmall!.copyWith(
        color: color ?? context.tokens.inkMuted,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: context.text.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A quiet bordered note: reminders, privacy notes, setup hints.
class NoteBox extends StatelessWidget {
  const NoteBox({
    super.key,
    required this.child,
    this.icon = Icons.info_outline,
    this.tone = NoteTone.neutral,
  });

  final Widget child;
  final IconData icon;
  final NoteTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = tone == NoteTone.error ? t.error : t.ink;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadii.input,
        border: Border.all(color: tone == NoteTone.error ? t.error : t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DefaultTextStyle.merge(
              style: context.text.bodySmall!.copyWith(color: color),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

enum NoteTone { neutral, error }

/// Centered message with an optional action, for empty and error states.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.border),
              color: t.surface,
            ),
            child: Icon(icon, color: t.ink),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: context.text.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              style: context.text.bodyMedium!.copyWith(color: t.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
              icon: Icons.refresh,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows a [UiNotice] as a SnackBar.
void showNotice(BuildContext context, UiNotice notice) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (notice.isError) ...[
              Icon(
                Icons.error_outline,
                size: 18,
                color: context.tokens.onInk,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(child: Text(notice.message)),
          ],
        ),
      ),
    );
}

void showMessage(BuildContext context, String message, {bool isError = false}) =>
    showNotice(context, UiNotice(message, isError: isError));

/// Thin divider with design-token colour.
class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key, this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, indent: indent, endIndent: indent);
}

/// A compact text style helper for metadata.
TextStyle metaStyle(BuildContext context) =>
    context.text.labelMedium!.copyWith(color: context.tokens.inkMuted).withWeight(550);
