import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// Light, dark or follow the phone.
enum AppThemePreference {
  system('Match device'),
  light('Light'),
  dark('Dark');

  const AppThemePreference(this.label);
  final String label;

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
}

/// Reading size. Multiplies the device's own text size setting.
enum TextSizePreference {
  small('Small', 0.92),
  standard('Default', 1.0),
  large('Large', 1.1),
  extraLarge('Extra large', 1.22);

  const TextSizePreference(this.label, this.scale);
  final String label;
  final double scale;
}

/// How confessions are laid out in feeds.
enum FeedLayout {
  card('Card', 'Full cards with a longer preview'),
  compact('Compact', 'Tighter rows, more posts on screen');

  const FeedLayout(this.label, this.description);
  final String label;
  final String description;
}

/// Which sort the home feed opens on.
enum DefaultFeed {
  forYou('For you'),
  hot('Hot'),
  latest('New'),
  top('Top');

  const DefaultFeed(this.label);
  final String label;
}

/// Who new confessions are posted as, unless changed on the post itself.
enum PostIdentity {
  anonymous('Anonymous'),
  handle('My anonymous name');

  const PostIdentity(this.label);
  final String label;
}

/// Every user preference. Saved on the device (so the theme applies before
/// sign-in) and in `users/{uid}.settings` (so it follows the account).
class AppSettings extends Equatable {
  const AppSettings({
    this.theme = AppThemePreference.system,
    this.textSize = TextSizePreference.standard,
    this.feedLayout = FeedLayout.card,
    this.defaultFeed = DefaultFeed.forYou,
    this.showMature = true,
    this.blurMature = true,
    this.postIdentity = PostIdentity.anonymous,
    this.mutedCategoryIds = const [],
    this.showConfessionOfDay = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.analyticsEnabled = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppSettings();
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    bool flag(String key, bool fallback) {
      final v = json[key];
      return v is bool ? v : fallback;
    }

    const d = AppSettings();
    return AppSettings(
      theme: pick(AppThemePreference.values, json['theme'], d.theme),
      textSize: pick(TextSizePreference.values, json['textSize'], d.textSize),
      feedLayout: pick(FeedLayout.values, json['feedLayout'], d.feedLayout),
      defaultFeed: pick(DefaultFeed.values, json['defaultFeed'], d.defaultFeed),
      showMature: flag('showMature', d.showMature),
      blurMature: flag('blurMature', d.blurMature),
      postIdentity: pick(
        PostIdentity.values,
        json['postIdentity'],
        d.postIdentity,
      ),
      mutedCategoryIds: (json['mutedCategoryIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      showConfessionOfDay: flag('showConfessionOfDay', d.showConfessionOfDay),
      haptics: flag('haptics', d.haptics),
      reduceMotion: flag('reduceMotion', d.reduceMotion),
      analyticsEnabled: flag('analyticsEnabled', d.analyticsEnabled),
    );
  }

  final AppThemePreference theme;
  final TextSizePreference textSize;
  final FeedLayout feedLayout;
  final DefaultFeed defaultFeed;

  /// Adults only: show posts marked 18+ at all.
  final bool showMature;

  /// Adults only: blur 18+ posts in feeds until tapped.
  final bool blurMature;
  final PostIdentity postIdentity;

  /// Categories hidden from every feed.
  final List<String> mutedCategoryIds;
  final bool showConfessionOfDay;
  final bool haptics;
  final bool reduceMotion;
  final bool analyticsEnabled;

  Map<String, dynamic> toJson() => {
    'theme': theme.name,
    'textSize': textSize.name,
    'feedLayout': feedLayout.name,
    'defaultFeed': defaultFeed.name,
    'showMature': showMature,
    'blurMature': blurMature,
    'postIdentity': postIdentity.name,
    'mutedCategoryIds': mutedCategoryIds,
    'showConfessionOfDay': showConfessionOfDay,
    'haptics': haptics,
    'reduceMotion': reduceMotion,
    'analyticsEnabled': analyticsEnabled,
  };

  AppSettings copyWith({
    AppThemePreference? theme,
    TextSizePreference? textSize,
    FeedLayout? feedLayout,
    DefaultFeed? defaultFeed,
    bool? showMature,
    bool? blurMature,
    PostIdentity? postIdentity,
    List<String>? mutedCategoryIds,
    bool? showConfessionOfDay,
    bool? haptics,
    bool? reduceMotion,
    bool? analyticsEnabled,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      textSize: textSize ?? this.textSize,
      feedLayout: feedLayout ?? this.feedLayout,
      defaultFeed: defaultFeed ?? this.defaultFeed,
      showMature: showMature ?? this.showMature,
      blurMature: blurMature ?? this.blurMature,
      postIdentity: postIdentity ?? this.postIdentity,
      mutedCategoryIds: mutedCategoryIds ?? this.mutedCategoryIds,
      showConfessionOfDay: showConfessionOfDay ?? this.showConfessionOfDay,
      haptics: haptics ?? this.haptics,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    );
  }

  @override
  List<Object?> get props => [
    theme,
    textSize,
    feedLayout,
    defaultFeed,
    showMature,
    blurMature,
    postIdentity,
    mutedCategoryIds,
    showConfessionOfDay,
    haptics,
    reduceMotion,
    analyticsEnabled,
  ];
}
