import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../helpers/logging/log_helper.dart';

enum DialOutcome {
  /// The code was run directly (Android, CALL_PHONE granted).
  called,

  /// The dialer opened with the code typed in: the user presses call.
  dialerOpened,

  /// The code was copied to the clipboard: iOS refuses to dial `*` and `#`,
  /// and device codes are best pasted in the dialer.
  copied,

  failed,
}

/// What the network answered to a code run in the background.
sealed class UssdResult {
  const UssdResult();
}

/// The network's text (a balance, a confirmation, or a menu that can only
/// be answered in the dialer).
class UssdAnswered extends UssdResult {
  final String text;

  const UssdAnswered(this.text);
}

/// No answer to show: not available here (iOS, Android < 8, no permission)
/// or the network failed. The code should run the usual way instead.
class UssdUnavailable extends UssdResult {
  const UssdUnavailable();
}

/// Rows the legacy Java app saved: personal codes and favorites.
typedef LegacyData = ({List<LegacyCode> codes, String? country});

typedef LegacyCode = ({String description, String code, String fragment, bool isNative, bool isFavorite});

/// Dialing and SIM detection, through the `ussd_codes/telephony` channel of
/// the Android `MainActivity`. Everything degrades gracefully elsewhere.
class TelephonyService {
  static const _channel = MethodChannel('ussd_codes/telephony');

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android && !kIsWeb;

  /// MCC+MNC of the SIM cards in the phone (Android only).
  Future<List<String>> simOperators() async {
    if (!_isAndroid) return const [];
    try {
      return (await _channel.invokeListMethod<String>('getSimOperators')) ?? const [];
    } on PlatformException catch (e) {
      LogHelper.w('Unable to read SIM operators', error: e);
      return const [];
    }
  }

  /// ISO codes (lowercase) of the countries whose network the phone is on,
  /// even when roaming (Android only). Empty without signal.
  Future<List<String>> networkCountries() async {
    if (!_isAndroid) return const [];
    try {
      return (await _channel.invokeListMethod<String>('getNetworkCountries')) ?? const [];
    } on PlatformException catch (e) {
      LogHelper.w('Unable to read the network country', error: e);
      return const [];
    }
  }

  /// Runs [code]. With [direct], asks for the phone permission once and
  /// calls straight away; otherwise (or if refused) opens the dialer with the
  /// code. Device codes are also copied, since some dialers only run them
  /// when typed.
  Future<DialOutcome> dial(String code, {required bool direct, bool isDeviceCode = false}) async {
    if (!_isAndroid) {
      await Clipboard.setData(ClipboardData(text: code));
      return DialOutcome.copied;
    }

    if (isDeviceCode) {
      await Clipboard.setData(ClipboardData(text: code));
    }

    final canCall = direct && !isDeviceCode && await _ensureCallPermission();
    try {
      final outcome = await _channel.invokeMethod<String>('dial', {'code': code, 'direct': canCall});
      return switch (outcome) {
        'called' => DialOutcome.called,
        'dialerOpened' => isDeviceCode ? DialOutcome.copied : DialOutcome.dialerOpened,
        _ => DialOutcome.failed,
      };
    } on PlatformException catch (e) {
      LogHelper.e('Unable to dial', error: e);
      return DialOutcome.failed;
    }
  }

  /// Runs [code] in the background and returns the network's answer
  /// (Android 8+, asks for the phone permission once). Never for device
  /// codes, which the network doesn't handle.
  Future<UssdResult> sendUssd(String code, {Duration timeout = const Duration(seconds: 30)}) async {
    if (!_isAndroid || !await _ensureCallPermission()) return const UssdUnavailable();
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('sendUssd', {'code': code}).timeout(timeout);
      final text = result?['response'] as String?;
      return text == null ? const UssdUnavailable() : UssdAnswered(text.trim());
    } on TimeoutException {
      return const UssdUnavailable();
    } on PlatformException catch (e) {
      LogHelper.w('Unable to send the USSD request', error: e);
      return const UssdUnavailable();
    }
  }

  Future<bool> _ensureCallPermission() async {
    final status = await Permission.phone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    return (await Permission.phone.request()).isGranted;
  }

  /// Whether [pickPhoneNumber] can open a contact picker here.
  bool get canPickContact => _isAndroid;

  /// A phone number chosen in the system contact picker, as saved in the
  /// contact (Android only). Null when cancelled.
  Future<String?> pickPhoneNumber() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('pickPhoneNumber');
    } on PlatformException catch (e) {
      LogHelper.w('Unable to pick a contact', error: e);
      return null;
    }
  }

  /// Whether codes can be pinned to the home screen here (Android).
  bool get canPinShortcut => _isAndroid;

  /// The code a home screen shortcut opened the app on, once.
  Future<String?> takeLaunchCodeId() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('takeLaunchCodeId');
    } on PlatformException catch (e) {
      LogHelper.w('Unable to read the launch shortcut', error: e);
      return null;
    }
  }

  /// Calls [onOpen] with the code of a shortcut tapped while the app runs.
  void onShortcutOpened(void Function(String codeId) onOpen) {
    if (!_isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openCode') onOpen(call.arguments as String);
    });
  }

  /// The shortcuts of the app icon (long press), most important first.
  Future<void> setShortcuts(List<({String id, String label})> codes) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('setShortcuts', {
        'codes': [
          for (final code in codes) {'id': code.id, 'label': code.label},
        ],
      });
    } on PlatformException catch (e) {
      LogHelper.w('Unable to set the shortcuts', error: e);
    }
  }

  /// The code of the Quick Settings tile (Android 7+), null for none.
  Future<void> setTileCode(({String id, String label, String code})? tile) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('setTileCode', {'id': tile?.id, 'label': tile?.label, 'code': tile?.code});
    } on PlatformException catch (e) {
      LogHelper.w('Unable to set the tile code', error: e);
    }
  }

  /// Asks the launcher to pin a shortcut to the code. False when it can't.
  Future<bool> pinShortcut({required String id, required String label}) async {
    if (!_isAndroid) return false;
    try {
      return (await _channel.invokeMethod<bool>('pinShortcut', {'id': id, 'label': label})) ?? false;
    } on PlatformException catch (e) {
      LogHelper.w('Unable to pin the shortcut', error: e);
      return false;
    }
  }

  /// Opens the Play In-App Review flow (Android only). Returns whether it ran.
  Future<bool> requestReview() async {
    if (!_isAndroid) return false;
    try {
      return (await _channel.invokeMethod<bool>('requestReview')) ?? false;
    } on PlatformException catch (e) {
      LogHelper.w('Unable to request a review', error: e);
      return false;
    }
  }

  /// What the legacy app saved, if it was installed before this version.
  Future<LegacyData?> readLegacyData() async {
    if (!_isAndroid) return null;
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('readLegacyData');
      if (data == null) return null;
      return (
        codes: [
          for (final row in (data['codes'] as List<dynamic>).cast<Map<dynamic, dynamic>>())
            (
              description: row['description'] as String? ?? '',
              code: row['code'] as String? ?? '',
              fragment: row['fragment'] as String? ?? '',
              isNative: row['isNative'] as bool? ?? false,
              isFavorite: row['isFavorite'] as bool? ?? false,
            ),
        ],
        country: data['country'] as String?,
      );
    } on PlatformException catch (e) {
      LogHelper.w('Unable to read legacy data', error: e);
      return null;
    }
  }
}
