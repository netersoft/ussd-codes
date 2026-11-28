abstract class PrefKeys {
  static const brightness = 'appBrightness';
  static const language = 'appLanguage';

  static const selectedCountry = 'selectedCountry';
  static const detectedCountry = 'detectedCountry';
  static const directCall = 'directCall';
  static const tileCode = 'tileCode';
  static const favorites = 'favorites';
  static const customCodes = 'customCodes';
  static const catalogLastCheck = 'catalogLastCheck';
  static const legacyImported = 'legacyImported';
  static const firstLaunch = 'firstLaunch';
  static const launchCount = 'launchCount';
  static const reviewRequested = 'reviewRequested';

  /// When the in-app review sheet was requested (ms since epoch), the store dialog waits after it.
  static const reviewRequestedAt = 'reviewRequestedAt';

  /// How many times the store dialog was shown, and when last (ms since epoch).
  static const rateDialogCount = 'rateDialogCount';
  static const rateDialogLastAt = 'rateDialogLastAt';

  /// The user rated, or asked not to be asked again.
  static const rateDone = 'rateDone';
}
