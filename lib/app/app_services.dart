import '../core/config/app_config.dart';
import '../core/services/share_service.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/categories/domain/category.dart';
import '../features/confessions/domain/confession_repository.dart';
import '../features/profile/domain/profile_repository.dart';
import '../features/reports/domain/report_repository.dart';

/// Everything the presentation layer needs, resolved once at start-up.
/// UI and BLoCs depend only on these interfaces.
class AppServices {
  const AppServices({
    required this.config,
    required this.auth,
    required this.profiles,
    required this.confessions,
    required this.reports,
    required this.categories,
    required this.share,
  });

  final AppConfig config;
  final AuthRepository auth;
  final ProfileRepository profiles;
  final ConfessionRepository confessions;
  final ReportRepository reports;
  final CategoryCatalog categories;
  final ShareService share;
}
