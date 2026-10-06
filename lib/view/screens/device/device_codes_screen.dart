import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/catalog_provider.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../components/codes/code_tile.dart';
import '../main_screen.dart';

/// Codes the phone itself handles (IMEI, test menus...), whatever the SIM.
class DeviceCodesScreen extends ConsumerWidget {
  const DeviceCodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(deviceCodesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: mainAppBar(title: Text(context.t.phoneCodes)),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            elevation: 0,
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: ListTile(
              leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
              title: Text(context.t.deviceCodesNotice, style: theme.textTheme.bodySmall),
            ),
          ),
          for (final code in codes) CodeTile(code: code),
        ],
      ),
    );
  }
}
