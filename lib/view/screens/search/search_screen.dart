import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/catalog/search.dart';
import '../../../core/providers/catalog_provider.dart';
import '../../../core/providers/library_provider.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../components/codes/code_tile.dart';
import '../../components/misc/status.dart';
import '../../themes/app_theme.dart';

/// Searches every code: all countries, personal codes and device codes.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _maxResults = 200;

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ResolvedCode> _search(String query) {
    final catalog = ref.read(currentCatalogProvider).requireValue;
    final country = ref.read(selectedCountryProvider) ?? ref.read(simCatalogOperatorsProvider).firstOrNull?.countryId;

    final custom = [
      for (final code in ref.read(customCodesProvider)) (code: code.toUssdCode(), operator: catalog.operatorById(code.operatorId), isCustom: true),
    ];
    final fromCatalog = [for (final entry in catalog.entries) (code: entry.code, operator: entry.operator, isCustom: false)];

    final results = [
      for (final result in [...custom, ...fromCatalog])
        if (matchesQuery(code: result.code, operator: result.operator, query: query)) result,
    ];
    // The current country's codes first, each group in catalog order.
    bool isLocal(ResolvedCode result) => result.operator?.countryId == country;
    return [...results.where(isLocal), ...results.whereNot(isLocal)].take(_maxResults).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(currentCatalogProvider)
      ..watch(customCodesProvider);
    final query = _controller.text.trim();
    final results = query.isEmpty ? const <ResolvedCode>[] : _search(query);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.getAppbarBgColor(),
        foregroundColor: Colors.white,
        title: TextField(
          controller: _controller,
          autofocus: true,
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: context.t.searchHint,
            hintStyle: const TextStyle(color: Colors.white70),
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(_controller.clear),
            ),
        ],
      ),
      body: query.isEmpty
          ? Status(icon: Icons.search, text: context.t.searchEmptyHint)
          : results.isEmpty
          ? Status(icon: Icons.search_off, text: context.t.noResults)
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                for (final result in results) CodeTile(code: result.code, operator: result.operator, isCustom: result.isCustom, showOperator: true),
              ],
            ),
    );
  }
}
