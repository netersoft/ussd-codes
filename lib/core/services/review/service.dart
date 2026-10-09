import '../shared_preferences/keys.dart';
import '../shared_preferences/service.dart';
import '../telephony/service.dart';

/// Asks once for a store review, through the Play In-App Review flow, right
/// after a code worked: once the operator's reply was read in the app (when
/// its sheet closes), or once the user is back from the phone app the code
/// ran in. Only for someone who uses the app: [minLaunches] launches, at
/// least [minDays] days after the first one. Asked once in the app's life;
/// Play then decides whether the dialog actually shows (it limits how often).
class ReviewPrompt {
  static const minDays = 3;
  static const minLaunches = 5;

  final SharedPreferencesService _prefs;
  final TelephonyService _telephony;
  final DateTime Function() _now;

  /// A reply was shown in the run sheet, still open.
  bool _answered = false;

  /// A code went to the phone app: the app is in the background until the
  /// user comes back.
  bool _inPhoneApp = false;

  ReviewPrompt(this._prefs, this._telephony, {DateTime Function()? now}) : _now = now ?? DateTime.now;

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
    if (_prefs.getBool(PrefKeys.reviewRequested) ?? false) return;
    final firstLaunch = _prefs.getInt(PrefKeys.firstLaunch);
    final launches = _prefs.getInt(PrefKeys.launchCount) ?? 0;
    if (firstLaunch == null || launches < minLaunches) return;
    if (_now().difference(DateTime.fromMillisecondsSinceEpoch(firstLaunch)).inDays < minDays) return;

    if (await _telephony.requestReview()) await _prefs.setBool(PrefKeys.reviewRequested, true);
  }
}
