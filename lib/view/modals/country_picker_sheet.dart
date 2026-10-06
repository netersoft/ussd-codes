import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalog/models.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/services/i18n/translations.g.dart';
import '../components/codes/code_texts.dart';

Future<void> showCountryPickerSheet(BuildContext context, {required String currentCountryId}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => CountryPickerSheet(currentCountryId: currentCountryId),
);

class CountryPickerSheet extends ConsumerWidget {
  final String currentCountryId;

  const CountryPickerSheet({required this.currentCountryId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(currentCatalogProvider).requireValue;
    final simCountries = ref.watch(simCatalogOperatorsProvider).map((op) => op.countryId).toSet();
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(context.t.chooseCountry, style: theme.textTheme.titleLarge),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final Country country in catalog.countries)
                ListTile(
                  leading: Text(country.flag, style: const TextStyle(fontSize: 28)),
                  title: Text(country.name.text),
                  subtitle: Text(country.operators.map((op) => op.name).join(' · ')),
                  selected: country.id == currentCountryId,
                  trailing: simCountries.contains(country.id)
                      ? Tooltip(message: context.t.mySim, child: const Icon(Icons.sim_card_outlined))
                      : (country.id == currentCountryId ? const Icon(Icons.check) : null),
                  onTap: () {
                    ref.read(selectedCountryProvider.notifier).select(country.id);
                    context.pop();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
