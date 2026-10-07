import 'package:shared_preferences/shared_preferences.dart';

/// Minimal async key-value persistence (device settings).
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Device storage via `shared_preferences` (NSUserDefaults / SharedPreferences
/// / localStorage on web). Only non-secret preferences are written here.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore._(this._prefs);

  static Future<SharedPreferencesStore> create() async {
    return SharedPreferencesStore._(await SharedPreferences.getInstance());
  }

  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(key);
  }
}

/// Volatile store for tests and as a fallback if device storage fails.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? seed]) : _data = {...?seed};

  final Map<String, String> _data;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

/// Opens device storage, falling back to memory if it is unavailable.
Future<KeyValueStore> openDeviceStore() async {
  try {
    return await SharedPreferencesStore.create();
  } catch (_) {
    return InMemoryKeyValueStore();
  }
}
