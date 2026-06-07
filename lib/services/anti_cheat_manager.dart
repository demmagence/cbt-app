import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exam_session_model.dart';
import 'screen_security_service.dart';

/// Callback type for app switch events.
typedef AppSwitchCallback = void Function(AppSwitchLog log);

/// Singleton utility class for managing anti-cheat measures during exams.
///
/// Features:
/// - App lifecycle monitoring (WidgetsBindingObserver)
/// - Fullscreen immersive mode management
/// - App switch detection with timestamped logging
/// - Violation count tracking
class AntiCheatManager with WidgetsBindingObserver {
  AntiCheatManager._internal();

  static final AntiCheatManager _instance = AntiCheatManager._internal();

  /// Returns the singleton instance of [AntiCheatManager].
  static AntiCheatManager get instance => _instance;

  bool _isEnabled = false;
  DateTime? _appBackgroundTime;
  final List<AppSwitchLog> _appSwitchLogs = [];
  int _appSwitchCount = 0;
  AppSwitchCallback? _onAppSwitchedCallback;

  // Callbacks for lifecycle events
  VoidCallback? _onResumedCallback;

  /// Whether anti-cheat measures are currently enabled.
  bool get isEnabled => _isEnabled;

  /// Activates all anti-cheat measures.
  ///
  /// - Registers the lifecycle observer
  /// - Enables fullscreen immersive mode
  /// - Resets internal counters
  void enable() {
    if (_isEnabled) return;
    _isEnabled = true;
    _appSwitchCount = 0;
    _appSwitchLogs.clear();
    _appBackgroundTime = null;

    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Enable screenshot prevention
    ScreenSecurityService.instance.enable();
  }

  /// Deactivates all anti-cheat measures.
  ///
  /// - Removes the lifecycle observer
  /// - Restores normal system UI
  void disable() {
    if (!_isEnabled) return;
    _isEnabled = false;

    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Disable screenshot prevention
    ScreenSecurityService.instance.disable();

    _onAppSwitchedCallback = null;
    _onResumedCallback = null;
  }

  /// Registers a callback for app switch events.
  ///
  /// The callback receives an [AppSwitchLog] containing the timestamp,
  /// duration (seconds) away from the app, and event type.
  void onAppSwitched(AppSwitchCallback callback) {
    _onAppSwitchedCallback = callback;
  }

  /// Registers a callback invoked when the app resumes from background.
  void onResumed(VoidCallback callback) {
    _onResumedCallback = callback;
  }

  /// Returns the total number of app switches in the current session.
  int getAppSwitchCount() => _appSwitchCount;

  /// Returns the list of timestamped app switch logs.
  List<AppSwitchLog> getAppSwitchLogs() => List.unmodifiable(_appSwitchLogs);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_isEnabled) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // User left the app — record the timestamp
        _appBackgroundTime ??= DateTime.now();
        break;

      case AppLifecycleState.resumed:
        // User returned — re-enforce immersive mode
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

        if (_appBackgroundTime != null) {
          final duration =
              DateTime.now().difference(_appBackgroundTime!).inSeconds;
          if (duration > 0) {
            final log = AppSwitchLog(
              timestamp: _appBackgroundTime!,
              duration: duration,
              type: 'app_switch',
            );
            _appSwitchCount++;
            _appSwitchLogs.add(log);
            _onAppSwitchedCallback?.call(log);
          }
          _appBackgroundTime = null;
        }

        _onResumedCallback?.call();
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }
}
