import '../../settings/domain/app_settings.dart';
import 'user_profile.dart';

/// The signed-in user's private profile (Cloud Firestore).
abstract interface class ProfileRepository {
  /// Returns the profile, or `null` if onboarding hasn't been completed.
  Future<UserProfile?> fetchProfile();

  /// Whether [username] is free (or already belongs to this user).
  Future<bool> isUsernameAvailable(String username);

  /// Atomically claims the username and saves the profile.
  /// Throws `UsernameTakenException` if someone else got the name first.
  Future<UserProfile> completeOnboarding(OnboardingChoices choices);

  /// Updates only the reading preferences.
  Future<UserProfile> updatePreferredCategories(List<String> categoryIds);

  /// Saves app settings to the account so they follow the user.
  Future<void> updateSettings(AppSettings settings);

  /// Deletes the profile and releases the username.
  Future<void> deleteProfile();
}
