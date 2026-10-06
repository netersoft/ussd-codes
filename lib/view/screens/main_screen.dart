import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalog/models.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/routes/app_route.dart';
import '../../core/services/i18n/translations.g.dart';
import '../components/codes/code_texts.dart';
import '../components/misc/status.dart';
import '../modals/run_code_sheet.dart';
import '../themes/app_theme.dart';
import 'device/device_codes_screen.dart';
import 'favorites/favorites_screen.dart';
import 'operators/operators_screen.dart';
import 'plans/plans_screen.dart';

/// The app shell: operators' codes, favorites and device codes tabs.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _index = 0;

  late final AppLifecycleListener _lifecycle;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    AppTheme.setStatusBarColor();
    // The user may have travelled while the app was in the background.
    _lifecycle = AppLifecycleListener(onResume: _followNetwork);

    // The native splash stays up until the catalog is ready.
    ref.listenManual(appStartupProvider, (_, startup) {
      if (!startup.isLoading) FlutterNativeSplash.remove();
      if (startup.value case final country?) _showCountryDetected(country);
      if (startup.hasValue && !_started) _onStarted();
    }, fireImmediately: true);

    ref.read(telephonyServiceProvider).onShortcutOpened(_openCode);
  }

  /// Once the catalog is ready: keeps the app icon's shortcuts in sync and
  /// opens the code of the shortcut that launched the app, if any.
  Future<void> _onStarted() async {
    _started = true;
    ref
      ..listenManual(favoriteShortcutsProvider, (_, _) {}, fireImmediately: true)
      ..listenManual(quickSettingsTileProvider, (_, _) {}, fireImmediately: true);
    final codeId = await ref.read(telephonyServiceProvider).takeLaunchCodeId();
    if (codeId != null) _openCode(codeId);
  }

  /// Opens the run sheet of a code chosen from a home screen shortcut: it
  /// still asks for confirmation, since codes can spend money.
  void _openCode(String codeId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final entry = ref.read(resolvedCodeProvider(codeId));
      if (entry == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.codeNotFound), behavior: SnackBarBehavior.floating));
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
      showRunCodeSheet(context, code: entry.code, operator: entry.operator);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _followNetwork() async {
    final catalog = ref.read(currentCatalogProvider).value;
    if (catalog == null || !ref.read(appStartupProvider).hasValue) return;
    final country = await ref.read(selectedCountryProvider.notifier).followNetwork(catalog);
    if (country != null && mounted) _showCountryDetected(country);
  }

  void _showCountryDetected(Country country) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.countryDetected(country: country.displayName)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(appStartupProvider);

    if (startup.isLoading) return const Scaffold(body: SizedBox.shrink());
    if (startup.hasError) {
      return Scaffold(
        body: Status(
          icon: Icons.error_outline,
          text: context.t.anErrorOccurred,
          footerWidget: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: FilledButton(onPressed: () => ref.invalidate(appStartupProvider), child: Text(context.t.retry)),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [OperatorsScreen(), PlansScreen(), FavoritesScreen(), DeviceCodesScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.cell_tower), label: context.t.operators),
          NavigationDestination(icon: const Icon(Icons.data_usage), label: context.t.plansTab),
          NavigationDestination(icon: const Icon(Icons.star_border), selectedIcon: const Icon(Icons.star), label: context.t.favorites),
          NavigationDestination(icon: const Icon(Icons.smartphone), label: context.t.phoneCodes),
        ],
      ),
    );
  }
}

/// Search and settings, in every tab's app bar.
class MainAppBarActions extends StatelessWidget {
  const MainAppBarActions({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: context.t.search,
        icon: const Icon(Icons.search),
        onPressed: () => const SearchRoute().push<void>(context),
      ),
      IconButton(
        tooltip: context.t.settings,
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => const SettingsRoute().push<void>(context),
      ),
    ],
  );
}

/// The app bar style shared by the main tabs.
AppBar mainAppBar({required Widget title, PreferredSizeWidget? bottom}) => AppBar(
  title: title,
  actions: const [MainAppBarActions()],
  bottom: bottom,
  backgroundColor: AppTheme.getAppbarBgColor(),
  foregroundColor: Colors.white,
);
