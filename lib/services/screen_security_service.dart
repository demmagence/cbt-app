import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service that prevents screenshots and screen recording during exams.
///
/// Uses Android's `FLAG_SECURE` via a platform MethodChannel.
class ScreenSecurityService {
  ScreenSecurityService._();

  static final ScreenSecurityService instance = ScreenSecurityService._();

  static const _channel = MethodChannel('com.cbt_app/screen_security');

  bool _isEnabled = false;

  /// Whether screenshot prevention is currently active.
  bool get isEnabled => _isEnabled;

  /// Enables screenshot/screen recording prevention.
  /// Adds `FLAG_SECURE` to the Android window.
  Future<void> enable() async {
    if (_isEnabled) return;
    try {
      await _channel.invokeMethod('enableScreenSecurity');
      _isEnabled = true;
    } on PlatformException catch (e) {
      debugPrint('ScreenSecurityService.enable() failed: ${e.message}');
    } on MissingPluginException {
      debugPrint('ScreenSecurityService: Android channel is unavailable.');
    }
  }

  /// Disables screenshot/screen recording prevention.
  /// Clears `FLAG_SECURE` from the Android window.
  Future<void> disable() async {
    if (!_isEnabled) return;
    try {
      await _channel.invokeMethod('disableScreenSecurity');
      _isEnabled = false;
    } on PlatformException catch (e) {
      debugPrint('ScreenSecurityService.disable() failed: ${e.message}');
    } on MissingPluginException {
      debugPrint('ScreenSecurityService: Android channel is unavailable.');
    }
  }
}
