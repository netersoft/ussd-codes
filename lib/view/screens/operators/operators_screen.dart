import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/catalog/models.dart';
import '../../../core/providers/catalog_provider.dart';
import '../../../core/providers/library_provider.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../components/codes/code_texts.dart';
import '../../components/codes/code_tile.dart';
import '../../components/misc/status.dart';
import '../../modals/add_code_sheet.dart';
import '../../modals/country_picker_sheet.dart';
import '../main_screen.dart';

/// The codes of the selected country, one tab per operator. Opens on the
/// country and operator of the phone's SIM until the user picks a country.
class OperatorsScreen extends ConsumerWidget {
  const OperatorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(currentCatalogProvider).requireValue;
    final simOperators = ref.watch(simCatalogOperatorsProvider);
    final selectedId = ref.watch(selectedCountryProvider);

    final country = catalog.countryById(selectedId) ?? catalog.countryById(simOperators.firstOrNull?.countryId) ?? catalog.countries.first;
    final operators = country.operators;
    final simIds = simOperators.map((op) => op.id).toSet();
    final initialIndex = operators.indexWhere((op) => simIds.contains(op.id));

    return DefaultTabController(
      // Rebuilt when the country or the detected SIM changes, to open on the
      // right tab.
      key: ValueKey('${country.id}/${simIds.join(',')}'),
      length: operators.length,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      child: Scaffold(
        appBar: mainAppBar(
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showCountryPickerSheet(context, currentCountryId: country.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(country.displayName, overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          bottom: TabBar(
            isScrollable: operators.length > 3,
            tabAlignment: operators.length > 3 ? TabAlignment.start : TabAlignment.fill,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            dividerColor: Colors.transparent,
            tabs: [
              for (final op in operators)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(op.name, overflow: TextOverflow.ellipsis)),
                      if (simIds.contains(op.id)) ...[
                        const SizedBox(width: 6),
                        Tooltip(message: context.t.mySim, child: const Icon(Icons.sim_card_outlined, size: 16)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: TabBarView(children: [for (final op in operators) OperatorCodesList(operator: op)]),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () => showAddCodeSheet(context, operator: operators[DefaultTabController.of(context).index]),
            icon: const Icon(Icons.add),
            label: Text(context.t.addCode),
          ),
        ),
      ),
    );
  }
}

/// An operator's codes: favorites first (as in the legacy app), then the
/// user's own codes, then the catalog's by category.
class OperatorCodesList extends ConsumerWidget {
  final Operator operator;

  const OperatorCodesList({required this.operator, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoritesProvider).toSet();
    final custom = ref.watch(customCodesProvider).where((code) => code.operatorId == operator.id).toList();
    final favorites = [
      for (final code in custom)
        if (favoriteIds.contains(code.id)) (code: code.toUssdCode(), isCustom: true),
      for (final code in operator.codes)
        if (favoriteIds.contains(code.id)) (code: code, isCustom: false),
    ];
    final byCategory = groupBy(operator.codes.where((code) => !favoriteIds.contains(code.id)), (UssdCode code) => code.category);
    final otherCustom = custom.where((code) => !favoriteIds.contains(code.id)).toList();

    final items = <Widget>[
      if (operator.formerName != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(operator.displayName, style: Theme.of(context).textTheme.bodySmall),
        ),
      if (favorites.isNotEmpty) ...[
        SectionHeader(context.t.favorites),
        for (final favorite in favorites) CodeTile(code: favorite.code, operator: operator, isCustom: favorite.isCustom),
      ],
      if (otherCustom.isNotEmpty) ...[
        SectionHeader(context.t.myCodes),
        for (final code in otherCustom) CodeTile(code: code.toUssdCode(), operator: operator, isCustom: true),
      ],
      for (final category in CodeCategory.values)
        if (byCategory[category] case final codes?) ...[
          SectionHeader(category.label(context.t)),
          for (final code in codes) CodeTile(code: code, operator: operator),
        ],
    ];

    if (operator.codes.isEmpty && custom.isEmpty) {
      return Status(icon: Icons.inbox_outlined, text: context.t.noCodes);
    }

    // Bottom padding keeps the last code clear of the add button.
    return ListView(padding: const EdgeInsets.only(bottom: 88), children: items);
  }
}
