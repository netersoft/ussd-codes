import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../enums/app_brightness.dart';
import '../helpers/logging/log_helper.dart';
import '../helpers/router/navigation_helper.dart';
import '../routes/app_route.dart';
import '../services/di/locator.dart';
import '../services/i18n/locale_preference.dart';
import '../services/i18n/translations.g.dart';
import '../services/shared_preferences/keys.dart';
import '../services/shared_preferences/service.dart';

part 'settings_provider.g.dart';

final _navigationHelper = locator<NavigationHelper>();

/// The app id on the Play Store (same as the legacy Java app's).
const playStoreAppId = 'com.neteru.mobileussdcodex';

@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  @override
  SettingsState build() => const SettingsState();

  final SharedPreferencesService prefs = locator<SharedPreferencesService>();

  static const _playStoreUrl = 'https://play.google.com/store/apps/details?id=$playStoreAppId';

  /// Where users send code suggestions and corrections.
  static String get contactEmail => dotenv.maybeGet('APP_CONTACT_EMAIL') ?? '';

  String get _shareMessage => '${t.installApp}\n$_playStoreUrl';

  Future<void> share(ShareOptions options) async {
    try {
      switch (options) {
        case ShareOptions.whatsapp:
          unawaited(
            launchUrl(
              Uri.parse(
                "whatsapp:${Platform.isIOS ? '//wa.me/' : '//send?'}text=${Uri.encodeComponent(_shareMessage)}",
              ),
            ),
          );
        case ShareOptions.email:
          unawaited(launchUrl(Uri(scheme: 'mailto', query: _encodeQuery({'subject': t.appName, 'body': _shareMessage}))));
        case ShareOptions.sms:
          unawaited(launchUrl(Uri(scheme: 'sms', query: _encodeQuery({'body': _shareMessage}))));
        case ShareOptions.free:
          var ctx = _navigationHelper.navigatorKey.currentContext;
          if (ctx != null) {
            final box = ctx.findRenderObject() as RenderBox?;
            await SharePlus.instance.share(
              ShareParams(
                text: _shareMessage,
                subject: t.share,
                sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
              ),
            );
          }
      }
    } catch (e) {
      LogHelper.w('Unable to share the app', error: e);
    }
  }

  Future<void> rateApp() async {
    final opened = await launchUrl(Uri.parse('market://details?id=$playStoreAppId'), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened) await launchUrl(Uri.parse(_playStoreUrl), mode: LaunchMode.externalApplication);
  }

  /// Opens the mail app to [contactEmail]. Returns false when none could open.
  Future<bool> sendEmail({required String subject, String body = ''}) async {
    if (contactEmail.isEmpty) return false;
    final uri = Uri(scheme: 'mailto', path: contactEmail, query: _encodeQuery({'subject': subject, 'body': body}));
    return launchUrl(uri).catchError((_) => false);
  }

  // mailto/sms queries must use %20 for spaces, not the "+" that
  // Uri(queryParameters:) produces.
  static String _encodeQuery(Map<String, String> params) =>
      params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');

  Future<void> changeLanguage(String newValue) async {
    final navigator = _navigationHelper.navigatorKey.currentState;
    await LocalePreference.save(prefs, newValue);

    try {
      _navigationHelper.go(const SettingsRoute().location);
      if (navigator != null && navigator.mounted) {
        Phoenix.rebirth(navigator.context);
      }
    } catch (e) {
      _navigationHelper.pushReplacement(const MainRoute().location);
    }
  }

  String? getAppBrightness() => prefs.getString(
    PrefKeys.brightness,
    defaultValue: AppBrightness.system.name,
  );

  void setAppBrightness(String appBrightness, {bool relaunch = true}) {
    prefs.setString(PrefKeys.brightness, appBrightness);

    if (relaunch) {
      try {
        _navigationHelper.go(const SettingsRoute().location);
        var ctx = _navigationHelper.navigatorKey.currentContext;
        if (ctx != null) Phoenix.rebirth(ctx);
      } catch (e) {
        _navigationHelper.pushReplacement(const MainRoute().location);
      }
    }
  }
}

class SettingsState {
  final bool isLoading;

  const SettingsState({this.isLoading = false});

  SettingsState copyWith({bool? isLoading}) => SettingsState(isLoading: isLoading ?? this.isLoading);
}

enum ShareOptions { whatsapp, email, free, sms }
