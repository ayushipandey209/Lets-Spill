import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/key_value_store.dart';
import '../domain/app_settings.dart';

/// Holds [AppSettings] for the whole app.
///
/// Settings are applied instantly, saved on the device, and pushed to the
/// signed-in user's Firestore profile through [remoteSaver] so they follow
/// the account to other devices.
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit({required KeyValueStore store})
    : _store = store,
      super(const AppSettings());

  static const storageKey = 'lets_spill.settings.v1';

  final KeyValueStore _store;

  /// Set while someone is signed in. Errors are swallowed: the setting still
  /// applies on this device and is retried with the next change.
  Future<void> Function(AppSettings settings)? remoteSaver;

  Future<void> load() async {
    try {
      final raw = await _store.read(storageKey);
      if (raw == null || isClosed) return;
      emit(AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (_) {
      // Corrupt or unavailable storage: keep the defaults.
    }
  }

  Future<void> update(AppSettings next) async {
    if (next == state || isClosed) return;
    emit(next);
    await _persist(next);
    final saver = remoteSaver;
    if (saver != null) {
      try {
        await saver(next);
      } catch (_) {}
    }
  }

  /// Applies settings stored on the account (called after sign-in).
  Future<void> adoptRemote(AppSettings remote) async {
    if (remote == state || isClosed) return;
    emit(remote);
    await _persist(remote);
  }

  Future<void> _persist(AppSettings settings) async {
    try {
      await _store.write(storageKey, jsonEncode(settings.toJson()));
    } catch (_) {}
  }
}
