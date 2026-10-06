import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/library_provider.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../components/codes/code_tile.dart';
import '../../components/misc/status.dart';
import '../main_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Most recent first; ids the catalog no longer has are skipped (but kept,
    // in case a later catalog brings the code back).
    final favorites = [
      for (final id in ref.watch(favoritesProvider).reversed) ?ref.watch(resolvedCodeProvider(id)),
    ];

    return Scaffold(
      appBar: mainAppBar(title: Text(context.t.favorites)),
      body: favorites.isEmpty
          ? Status(icon: Icons.star_border, title: context.t.noFavorites, text: context.t.noFavoritesHint)
          : ListView(
              children: [
                for (final favorite in favorites) CodeTile(code: favorite.code, operator: favorite.operator, isCustom: favorite.isCustom, showOperator: true),
              ],
            ),
    );
  }
}
