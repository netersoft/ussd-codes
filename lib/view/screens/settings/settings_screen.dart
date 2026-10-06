import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../../core/catalog/catalog_repository.dart';
import '../../../core/enums/app_brightness.dart';
import '../../../core/helpers/ui/dialog_helper.dart';
import '../../../core/providers/catalog_provider.dart';
import '../../../core/providers/library_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/routes/app_route.dart';
import '../../../core/services/i18n/config.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../components/codes/code_texts.dart';
import '../../components/misc/floating_modal.dart';
import '../../themes/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      elevation: 0.0,
      title: Text(
        context.t.settings,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: AppTheme.getAppbarBgColor(),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () {
          context.pop();
        },
      ),
    ),
    body: const SettingsListWrapper(),
  );
}

class SettingsListWrapper extends ConsumerWidget {
  const SettingsListWrapper({super.key});

  Future<void> _checkCatalogUpdate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    messenger.showSnackBar(SnackBar(content: Text('${t.loading}…'), behavior: SnackBarBehavior.floating));

    final result = await ref.read(currentCatalogProvider.notifier).checkForUpdate();

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(switch (result) {
            CatalogUpdateResult.updated => t.catalogUpdated,
            CatalogUpdateResult.upToDate => t.catalogUpToDate,
            CatalogUpdateResult.failed => t.catalogUpdateFailed,
            CatalogUpdateResult.notConfigured => t.catalogRemoteDisabled,
          }),
        ),
      );
  }

  /// Lets the user pick the Quick Settings tile's code among the favorites.
  void _pickTileCode(BuildContext context, WidgetRef ref) {
    final favorites = [
      for (final id in ref.read(favoritesProvider).reversed) ?ref.read(resolvedCodeProvider(id)),
    ];
    final choice = ref.read(tileCodeChoiceProvider);
    showFloatingModalBottomSheet<void>(
      context: context,
      builder: (context) => Material(
        child: SafeArea(
          top: false,
          child: RadioGroup<String?>(
            groupValue: favorites.any((favorite) => favorite.code.id == choice) ? choice : null,
            onChanged: (id) {
              ref.read(tileCodeChoiceProvider.notifier).set(id);
              context.pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String?>(title: Text(context.t.quickTileLatestFavorite), value: null),
                for (final favorite in favorites)
                  RadioListTile<String?>(
                    title: Text(favorite.code.label.text),
                    subtitle: favorite.operator == null ? null : Text(favorite.operator!.displayName),
                    value: favorite.code.id,
                  ),
                if (favorites.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(context.t.quickTileNoFavorites, style: TextStyle(color: Theme.of(context).hintColor)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider.notifier);
    final directCall = ref.watch(directCallProvider);
    final tileChoice = ref.watch(tileCodeChoiceProvider);
    final tileCode = ref.watch(tileCodeProvider);
    final catalog = ref.watch(currentCatalogProvider).value;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    var currentLang = I18nConfig.langItems.firstWhereOrNull(
      (item) => item.code == LocaleSettings.instance.currentLocale.languageCode,
    );

    return SettingsList(
      sections: [
        SettingsSection(
          title: Text(context.t.preferences),
          tiles: <SettingsTile>[
            SettingsTile.navigation(
              leading: const Icon(Icons.language),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currentLang?.label[currentLang.code] ?? ''),
                  const Icon(Icons.chevron_right),
                ],
              ),
              title: Text(context.t.language),
              onPressed: (context) => {
                showFloatingModalBottomSheet(
                  context: context,
                  builder: (context) => Material(
                    child: SafeArea(
                      top: false,
                      child: RadioGroup<String>(
                        groupValue: LocaleSettings.instance.currentLocale.languageCode,
                        onChanged: (value) {
                          if (value != LocaleSettings.instance.currentLocale.languageCode) {
                            settings.changeLanguage(value!);
                            context.pop();
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: I18nConfig.langItems
                              .map<Widget>(
                                (item) => RadioListTile(
                                  title: Text(item.label[currentLang?.code]!),
                                  value: item.code,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              },
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.format_paint),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.getAppBrightness() == AppBrightness.system.name
                        ? context.t.system
                        : settings.getAppBrightness() == AppBrightness.light.name
                        ? context.t.light
                        : context.t.dark,
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              title: Text(context.t.theme),
              onPressed: (context) => {
                showFloatingModalBottomSheet(
                  context: context,
                  builder: (context) => Material(
                    child: SafeArea(
                      top: false,
                      child: RadioGroup<String>(
                        groupValue: settings.getAppBrightness(),
                        onChanged: (value) {
                          if (value != settings.getAppBrightness()) {
                            settings.setAppBrightness(value!);
                            context.pop();
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile(
                              title: Text(context.t.light),
                              value: AppBrightness.light.name,
                            ),
                            RadioListTile(
                              title: Text(context.t.dark),
                              value: AppBrightness.dark.name,
                            ),
                            RadioListTile(
                              title: Text(context.t.system),
                              value: AppBrightness.system.name,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              },
            ),
            if (isAndroid)
              SettingsTile.switchTile(
                leading: const Icon(Icons.call),
                title: Text(context.t.directCall),
                description: Text(context.t.directCallDescription),
                initialValue: directCall,
                onToggle: (value) => ref.read(directCallProvider.notifier).set(value),
              ),
            if (isAndroid)
              SettingsTile.navigation(
                leading: const Icon(Icons.grid_view),
                title: Text(context.t.quickTile),
                description: Text(context.t.quickTileDescription),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        tileChoice == null ? context.t.quickTileLatestFavorite : (tileCode?.code.label.text ?? ''),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onPressed: (context) => _pickTileCode(context, ref),
              ),
          ],
        ),
        SettingsSection(
          title: Text(context.t.catalog),
          tiles: <SettingsTile>[
            SettingsTile.navigation(
              leading: const Icon(Icons.sync),
              title: Text(context.t.checkForUpdate),
              description: catalog == null ? null : Text(context.t.catalogVersion(version: catalog.version, date: catalog.updatedAt)),
              onPressed: (context) => _checkCatalogUpdate(context, ref),
            ),
          ],
        ),
        SettingsSection(
          title: Text(context.t.about),
          tiles: <SettingsTile>[
            SettingsTile.navigation(
              leading: const Icon(Icons.info),
              trailing: const Icon(Icons.chevron_right),
              title: Text(context.t.about),
              onPressed: (context) => {
                DialogHelper.showContent(
                  context,
                  title: Text(
                    context.t.about,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset('assets/images/launcher/icon.svg', width: 96.0),
                      const SizedBox(height: 12),
                      Text(
                        context.t.appName,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (ctx, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              'Version ${snapshot.data!.version}',
                              style: const TextStyle(fontSize: 14.0),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 25),
                      Text(
                        context.t.appDescription,
                        style: const TextStyle(fontSize: 16.0),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.t.licenseNotice,
                        style: const TextStyle(fontSize: 12.0),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              },
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.privacy_tip),
              trailing: const Icon(Icons.chevron_right),
              title: Text(context.t.privacyPolicy),
              onPressed: (context) => const PrivacyPolicyRoute().push<void>(context),
            ),
            if (Settings.contactEmail.isNotEmpty)
              SettingsTile.navigation(
                leading: const Icon(Icons.mail_outline),
                trailing: const Icon(Icons.chevron_right),
                title: Text(context.t.contactUs),
                description: Text(context.t.contactUsDescription),
                onPressed: (context) => settings.sendEmail(subject: context.t.suggestCodesSubject),
              ),
            if (isAndroid)
              SettingsTile.navigation(
                leading: const Icon(Icons.star_rate_outlined),
                trailing: const Icon(Icons.chevron_right),
                title: Text(context.t.rateApp),
                onPressed: (context) => settings.rateApp(),
              ),
            SettingsTile.navigation(
              leading: const Icon(Icons.campaign),
              trailing: const Icon(Icons.chevron_right),
              title: Text(context.t.recommandApp),
              onPressed: (context) => {
                showFloatingModalBottomSheet(
                  context: context,
                  builder: (context) => Material(
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            title: Text(context.t.byEmail),
                            trailing: const Icon(
                              Icons.email,
                              size: 21.0,
                            ),
                            onTap: () => settings.share(ShareOptions.email),
                          ),
                          ListTile(
                            title: Text(context.t.bySms),
                            trailing: const Icon(
                              Icons.sms,
                              size: 21.0,
                            ),
                            onTap: () => settings.share(ShareOptions.sms),
                          ),
                          ListTile(
                            title: Text(context.t.share),
                            trailing: const Icon(
                              Icons.share,
                              size: 21.0,
                            ),
                            onTap: () => settings.share(ShareOptions.free),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              },
            ),
          ],
        ),
      ],
    );
  }
}
