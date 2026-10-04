import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../app_services.dart';

typedef ServicesFactory = Future<AppServices> Function(AppConfig config);

enum AppInitStatus { loading, ready, failure }

class AppInitState extends Equatable {
  const AppInitState._({
    required this.status,
    this.services,
    this.errorMessage,
    this.setupSteps = const [],
  });

  const AppInitState.loading() : this._(status: AppInitStatus.loading);

  const AppInitState.ready(AppServices services)
    : this._(status: AppInitStatus.ready, services: services);

  const AppInitState.failure(String message, {List<String> setupSteps = const []})
    : this._(
        status: AppInitStatus.failure,
        errorMessage: message,
        setupSteps: setupSteps,
      );

  final AppInitStatus status;
  final AppServices? services;
  final String? errorMessage;

  /// Present when the failure is a missing Firebase configuration.
  final List<String> setupSteps;

  @override
  List<Object?> get props => [status, services, errorMessage, setupSteps];
}

/// Drives the splash screen: initialises the selected data mode safely and
/// exposes a retry path on failure.
class AppInitCubit extends Cubit<AppInitState> {
  AppInitCubit({
    required this.config,
    required ServicesFactory createServices,
    this.minimumSplash = const Duration(milliseconds: 700),
  }) : _createServices = createServices,
       super(const AppInitState.loading());

  final AppConfig config;
  final ServicesFactory _createServices;

  /// Keeps the wordmark on screen briefly so start-up doesn't flicker.
  final Duration minimumSplash;

  bool _running = false;

  Future<void> initialize() async {
    if (_running) return;
    _running = true;
    emit(const AppInitState.loading());
    final started = DateTime.now();
    try {
      final services = await _createServices(config);
      final elapsed = DateTime.now().difference(started);
      if (elapsed < minimumSplash) {
        await Future<void>.delayed(minimumSplash - elapsed);
      }
      if (!isClosed) emit(AppInitState.ready(services));
    } on ConfigurationException catch (e) {
      if (!isClosed) {
        emit(AppInitState.failure(e.message, setupSteps: e.setupSteps));
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          AppInitState.failure(
            "Let's Spill couldn't start. ${asAppException(e).message}",
          ),
        );
      }
    } finally {
      _running = false;
    }
  }
}
