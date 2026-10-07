import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Centralized contract for push notifications and messaging.
abstract class NotificationService {
  Future<void> initialize();
  Future<void> login(String externalId);
  Future<void> logout();
  Future<void> addTag(String key, String value);
  Future<void> removeTag(String key);
  Future<void> requestPushPermission();
  void addPushSubscriptionObserver(
    void Function(String subscriptionId) onRegistered,
  );
  String? get currentSubscriptionId;
}

/// Centralized OneSignal SDK integration wrapper.
///
/// Encapsulates all direct OneSignal SDK calls, manages lifecycle, user identity,
/// tags, logging levels, and push subscription observers.
class OneSignalService implements NotificationService {
  OneSignalService({this.appId = '1ba2cc91-1cab-4be4-ae58-f7d5d13f730e'});

  final String appId;
  bool _initialized = false;
  OnPushSubscriptionChangeObserver? _retainedObserver;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }
      OneSignal.initialize(appId);
      _initialized = true;
    } catch (e) {
      debugPrint('OneSignal initialization error: $e');
    }
  }

  @override
  Future<void> login(String externalId) async {
    try {
      await OneSignal.login(externalId);
    } catch (e) {
      debugPrint('OneSignal login error: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('OneSignal logout error: $e');
    }
  }

  @override
  Future<void> addTag(String key, String value) async {
    try {
      OneSignal.User.addTagWithKey(key, value);
    } catch (e) {
      debugPrint('OneSignal addTag error: $e');
    }
  }

  @override
  Future<void> removeTag(String key) async {
    try {
      OneSignal.User.removeTag(key);
    } catch (e) {
      debugPrint('OneSignal removeTag error: $e');
    }
  }

  @override
  Future<void> requestPushPermission() async {
    try {
      await OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint('OneSignal requestPermission error: $e');
    }
  }

  @override
  String? get currentSubscriptionId => OneSignal.User.pushSubscription.id;

  @override
  void addPushSubscriptionObserver(
    void Function(String subscriptionId) onRegistered,
  ) {
    // 1. Evaluate immediately if already registered with a real server ID
    final currentId = OneSignal.User.pushSubscription.id;
    if (_isServerAssigned(currentId)) {
      onRegistered(currentId!);
    }

    // 2. Retain observer in instance state to prevent garbage collection
    _retainedObserver = (OSPushSubscriptionChangedState state) {
      final newId = state.current.id;
      if (_isServerAssigned(newId)) {
        onRegistered(newId!);
      }
    };
    OneSignal.User.pushSubscription.addObserver(_retainedObserver!);
  }

  static bool _isServerAssigned(String? id) {
    if (id == null || id.isEmpty) return false;
    if (id.startsWith('local-')) return false;
    return true;
  }
}

/// No-op implementation for tests or unsupported environments.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> login(String externalId) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> addTag(String key, String value) async {}

  @override
  Future<void> removeTag(String key) async {}

  @override
  Future<void> requestPushPermission() async {}

  @override
  void addPushSubscriptionObserver(
    void Function(String subscriptionId) onRegistered,
  ) {}

  @override
  String? get currentSubscriptionId => null;
}
