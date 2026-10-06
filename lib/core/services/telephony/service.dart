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
