import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../helpers/ui/rate_dialog.dart';
import '../shared_preferences/keys.dart';
import '../shared_preferences/service.dart';
import '../telephony/service.dart';

/// Asks once for a store review, through the Play In-App Review flow, right
/// after a code worked: once the operator's reply was read in the app (when
/// its sheet closes), or once the user is back from the phone app the code
/// ran in. Only for someone who uses the app: [minLaunches] launches, at
/// least [minDays] days after the first one.
///
/// The Play sheet is requested once in the app's life: Play decides whether
/// it actually shows (it limits how often) and it only collects stars. After
/// it, our own dialog opens the Play Store listing, where a comment can be
/// written: at most [maxDialogs] times, [dialogGap] apart and [dialogDelay]
/// after the sheet, until the user rates or asks not to be asked again.
class ReviewPrompt {
  static const minDays = 1;
  static const minLaunches = 3;
  static const maxDialogs = 3;
  static const dialogDelay = Duration(days: 14);
  static const dialogGap = Duration(days: 30);
  static const playStoreId = 'com.neteru.mobileussdcodex';

  final SharedPreferencesService _prefs;
  final TelephonyService _telephony;
  final DateTime Function() _now;
  final Future<RateChoice?> Function() _ask;
  final Future<void> Function() _openListing;

  /// A reply was shown in the run sheet, still open.
  bool _answered = false;

  /// A code went to the phone app: the app is in the background until the
  /// user comes back.
  bool _inPhoneApp = false;

  ReviewPrompt(
    this._prefs,
    this._telephony, {
    DateTime Function()? now,
    Future<RateChoice?> Function()? ask,
    Future<void> Function()? openListing,
  }) : _now = now ?? DateTime.now,
       _ask = ask ?? showRateDialog,
       _openListing = openListing ?? _openPlayStore;

  /// Counts a launch.
  Future<void> onLaunch() async {
    if (_prefs.getInt(PrefKeys.firstLaunch) == null) await _prefs.setInt(PrefKeys.firstLaunch, _now().millisecondsSinceEpoch);
    await _prefs.setInt(PrefKeys.launchCount, (_prefs.getInt(PrefKeys.launchCount) ?? 0) + 1);
  }

  /// The operator's reply to a code is on screen.
  void onCodeAnswered() => _answered = true;

  /// A code was handed to the phone app (called, or typed in the dialer).
  void onCodeSentToPhoneApp() {
    _answered = false;
    _inPhoneApp = true;
  }

  /// The run sheet closed.
  Future<void> onSheetClosed() async {
    if (!_answered) return;
    _answered = false;
    await _askOnce();
  }

  /// The app is back in the foreground.
  Future<void> onResume() async {
    if (!_inPhoneApp) return;
    _inPhoneApp = false;
    await _askOnce();
  }

  Future<void> _askOnce() async {
    if (_prefs.getBool(PrefKeys.rateDone) ?? false) return;
    final firstLaunch = _prefs.getInt(PrefKeys.firstLaunch);
    final launches = _prefs.getInt(PrefKeys.launchCount) ?? 0;
    if (firstLaunch == null || launches < minLaunches) return;
    final now = _now();
    if (now.difference(DateTime.fromMillisecondsSinceEpoch(firstLaunch)).inDays < minDays) return;

    if (!(_prefs.getBool(PrefKeys.reviewRequested) ?? false)) {
      if (await _telephony.requestReview()) {
        await _prefs.setBool(PrefKeys.reviewRequested, true);
        await _prefs.setInt(PrefKeys.reviewRequestedAt, now.millisecondsSinceEpoch);
      }
      return;
    }
    await _askWithDialog(now);
  }

  Future<void> _askWithDialog(DateTime now) async {
    final sheetAt = _prefs.getInt(PrefKeys.reviewRequestedAt);
    if (sheetAt != null && now.difference(DateTime.fromMillisecondsSinceEpoch(sheetAt)) < dialogDelay) return;
    final count = _prefs.getInt(PrefKeys.rateDialogCount) ?? 0;
    if (count >= maxDialogs) return;
    final lastAt = _prefs.getInt(PrefKeys.rateDialogLastAt);
    if (lastAt != null && now.difference(DateTime.fromMillisecondsSinceEpoch(lastAt)) < dialogGap) return;

    // Counted before showing: an app closed with the dialog open still counts.
    await _prefs.setInt(PrefKeys.rateDialogCount, count + 1);
    await _prefs.setInt(PrefKeys.rateDialogLastAt, now.millisecondsSinceEpoch);
    final choice = await _ask();
    switch (choice) {
      case RateChoice.rate:
        await _prefs.setBool(PrefKeys.rateDone, true);
        await _openListing();
      case RateChoice.never:
        await _prefs.setBool(PrefKeys.rateDone, true);
      case RateChoice.later:
      case null:
        break;
    }
  }

  /// The Play Store app if installed (launchUrl throws when nothing handles market://), the web page otherwise.
  static Future<void> _openPlayStore() async {
    try {
      if (await launchUrl(Uri.parse('market://details?id=$playStoreId'))) return;
    } on PlatformException catch (_) {}
    await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=$playStoreId'), mode: LaunchMode.externalApplication);
  }
}
