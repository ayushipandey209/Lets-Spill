import 'package:equatable/equatable.dart';

/// Immutable, app-wide configuration.
///
/// * **Accounts** are real: Google sign-in through Firebase Authentication,
///   with the private profile (anonymous username, age range, reading
///   preferences) stored in Cloud Firestore.
/// * **Confession content** comes from the bundled JSON in `assets/mock/`
///   for now. Likes, reactions, saves, views and the user's own posts are
///   kept on the device, keyed by the Firebase user id.
class AppConfig extends Equatable {
  const AppConfig({
    this.maxConfessionLength = 2000,
    this.minConfessionLength = 10,
    this.maxReportDetailsLength = 500,
    this.feedPageSize = 15,
    this.viewThreshold = const Duration(seconds: 15),
    this.contentLatency = const Duration(milliseconds: 250),
    this.privacyPolicyUrl,
    this.communityGuidelinesUrl,
    this.supportContact,
  });

  /// Reads optional production links from `--dart-define` values.
  factory AppConfig.fromEnvironment() {
    const privacy = String.fromEnvironment('PRIVACY_POLICY_URL');
    const guidelines = String.fromEnvironment('GUIDELINES_URL');
    const support = String.fromEnvironment('SUPPORT_CONTACT');
    return AppConfig(
      privacyPolicyUrl: privacy.isEmpty ? null : privacy,
      communityGuidelinesUrl: guidelines.isEmpty ? null : guidelines,
      supportContact: support.isEmpty ? null : support,
    );
  }

  static const appName = "Let's Spill";
  static const tagline = 'Your secrets. Their stories.';
  static const shortDescription =
      'Read confessions, share secrets, and discover real-life stories.';

  /// Maximum characters allowed in a confession.
  final int maxConfessionLength;

  /// Minimum characters (after trimming) for a confession to be postable.
  final int minConfessionLength;

  final int maxReportDetailsLength;

  /// Number of confessions shown per page. Never load everything at once.
  final int feedPageSize;

  /// How long a reader must stay on a confession before a view is counted.
  final Duration viewThreshold;

  /// Small artificial delay on local content so loading states feel natural.
  final Duration contentLatency;

  /// Production links. `null` means "placeholder — must be set before launch".
  final String? privacyPolicyUrl;
  final String? communityGuidelinesUrl;
  final String? supportContact;

  AppConfig copyWith({Duration? contentLatency, Duration? viewThreshold}) {
    return AppConfig(
      maxConfessionLength: maxConfessionLength,
      minConfessionLength: minConfessionLength,
      maxReportDetailsLength: maxReportDetailsLength,
      feedPageSize: feedPageSize,
      viewThreshold: viewThreshold ?? this.viewThreshold,
      contentLatency: contentLatency ?? this.contentLatency,
      privacyPolicyUrl: privacyPolicyUrl,
      communityGuidelinesUrl: communityGuidelinesUrl,
      supportContact: supportContact,
    );
  }

  @override
  List<Object?> get props => [
    maxConfessionLength,
    minConfessionLength,
    maxReportDetailsLength,
    feedPageSize,
    viewThreshold,
    contentLatency,
    privacyPolicyUrl,
    communityGuidelinesUrl,
    supportContact,
  ];
}
