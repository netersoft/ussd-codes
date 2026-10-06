import '../shared_preferences/keys.dart';
import '../shared_preferences/service.dart';
import '../telephony/service.dart';

/// Asks once for a store review, like the legacy app: after [minDays] days
/// of use and [minLaunches] launches, through the Play In-App Review flow.
/// Play decides whether the dialog actually shows (it limits how often).
class ReviewPrompt {
  static const minDays = 10;
  static const minLaunches = 10;

  final SharedPreferencesService _prefs;
  final TelephonyService _telephony;
  final DateTime Function() _now;

  ReviewPrompt(this._prefs, this._telephony, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  Future<void> onLaunch() async {
    final now = _now();
    final firstLaunch = _prefs.getInt(PrefKeys.firstLaunch);
    if (firstLaunch == null) await _prefs.setInt(PrefKeys.firstLaunch, now.millisecondsSinceEpoch);
    final launches = (_prefs.getInt(PrefKeys.launchCount) ?? 0) + 1;
    await _prefs.setInt(PrefKeys.launchCount, launches);

    if (_prefs.getBool(PrefKeys.reviewRequested) ?? false) return;
    final usedFor = now.difference(DateTime.fromMillisecondsSinceEpoch(firstLaunch ?? now.millisecondsSinceEpoch));
    if (launches < minLaunches || usedFor.inDays < minDays) return;

    if (await _telephony.requestReview()) await _prefs.setBool(PrefKeys.reviewRequested, true);
  }
}
