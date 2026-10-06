import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/catalog/models.dart';
import '../../../core/providers/catalog_provider.dart';
import '../../../core/providers/library_provider.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../components/codes/code_texts.dart';
import '../../components/codes/country_title.dart';
import '../../components/misc/status.dart';
import '../../modals/run_code_sheet.dart';
import '../main_screen.dart';

enum _Duration { any, day, week, month }

enum _Sort { perGb, price, volume }

/// Compares the internet bundles of the selected country's operators: by
/// price per GB, price or volume, filtered by length, budget and operator.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  static const _budgets = [500, 1000, 5000];

  _Duration _duration = _Duration.any;
  int? _budget;
  bool _night = false;
  _Sort _sort = _Sort.perGb;

  /// Operators hidden by the user, by id.
  final Set<String> _hiddenOperators = {};

  bool _matches(PlanEntry entry) {
    final plan = entry.plan;
    if (_hiddenOperators.contains(entry.operator.id) || plan.night != _night) return false;
    if (_budget != null && plan.price > _budget!) return false;
    return switch (_duration) {
      _Duration.any => true,
      _Duration.day => plan.validityHours <= 24,
      _Duration.week => plan.validityHours <= 7 * 24,
      _Duration.month => plan.validityHours >= 28 * 24,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final catalog = ref.watch(currentCatalogProvider).requireValue;
    final simOperators = ref.watch(simCatalogOperatorsProvider);
    final country =
        catalog.countryById(ref.watch(selectedCountryProvider)) ?? catalog.countryById(simOperators.firstOrNull?.countryId) ?? catalog.countries.first;
    final all = ref.watch(countryPlansProvider(country.id));
    final operators = [
      for (final op in country.operators)
        if (all.any((entry) => entry.operator == op)) op,
    ];
    final plans = all
        .where(_matches)
        .sorted(
          (a, b) => switch (_sort) {
            _Sort.perGb => a.plan.pricePerGb.compareTo(b.plan.pricePerGb),
            _Sort.price => a.plan.price.compareTo(b.plan.price),
            _Sort.volume => b.plan.volumeMb.compareTo(a.plan.volumeMb),
          },
        );
    final checkedAt = all.map((entry) => entry.plan.checkedAt).sorted().firstOrNull;

    return Scaffold(
      appBar: mainAppBar(title: CountryTitle(country: country)),
      body: all.isEmpty
          ? Status(icon: Icons.data_usage, title: t.plans.title, text: t.plans.notCovered)
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _ChipRow(
                  children: [
                    for (final duration in _Duration.values)
                      ChoiceChip(
                        label: Text(switch (duration) {
                          _Duration.any => t.plans.anyDuration,
                          _Duration.day => t.plans.day,
                          _Duration.week => t.plans.week,
                          _Duration.month => t.plans.month,
                        }),
                        selected: _duration == duration,
                        onSelected: (_) => setState(() => _duration = duration),
                      ),
                    FilterChip(
                      avatar: const Icon(Icons.nightlight_outlined, size: 18),
                      label: Text(t.plans.night),
                      selected: _night,
                      onSelected: (value) => setState(() => _night = value),
                    ),
                  ],
                ),
                _ChipRow(
                  children: [
                    ChoiceChip(label: Text(t.plans.anyBudget), selected: _budget == null, onSelected: (_) => setState(() => _budget = null)),
                    for (final budget in _budgets)
                      ChoiceChip(
                        label: Text(t.plans.upTo(price: formatPrice(budget))),
                        selected: _budget == budget,
                        onSelected: (_) => setState(() => _budget = budget),
                      ),
                  ],
                ),
                if (operators.length > 1)
                  _ChipRow(
                    children: [
                      for (final op in operators)
                        FilterChip(
                          label: Text(op.name),
                          selected: !_hiddenOperators.contains(op.id),
                          onSelected: (shown) => setState(() => shown ? _hiddenOperators.remove(op.id) : _hiddenOperators.add(op.id)),
                        ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: SegmentedButton<_Sort>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: _Sort.perGb, label: Text(t.plans.sortPerGb)),
                      ButtonSegment(value: _Sort.price, label: Text(t.plans.sortPrice)),
                      ButtonSegment(value: _Sort.volume, label: Text(t.plans.sortVolume)),
                    ],
                    selected: {_sort},
                    onSelectionChanged: (selection) => setState(() => _sort = selection.single),
                  ),
                ),
                if (plans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      t.plans.noMatch,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ),
                for (final entry in plans) _PlanTile(entry: entry),
                if (checkedAt != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      t.plans.footer(date: formatDate(DateTime.parse(checkedAt))),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<Widget> children;

  const _ChipRow({required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(spacing: 8, children: children),
  );
}

class _PlanTile extends ConsumerWidget {
  final PlanEntry entry;

  const _PlanTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final plan = entry.plan;
    final stale = plan.freshness(ref.watch(clockProvider)()) == PlanFreshness.stale;
    final volume = formatVolume(plan.volumeMb);
    final validity = formatValidity(t, plan);
    final details = [entry.operator.name, if (plan.note != null) plan.note!.text].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text('$volume · $validity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details),
          if (stale) Text(t.plans.toConfirm, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatPrice(plan.price),
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
          ),
          Text(
            t.plans.perGb(price: formatPrice(plan.pricePerGb.round())),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
      onTap: () => showRunCodeSheet(
        context,
        operator: entry.operator,
        code: UssdCode(
          id: plan.id,
          label: LocalizedText({catalogLanguage: t.plans.buyLabel(volume: volume, validity: validity)}),
          code: plan.code,
          category: CodeCategory.data,
        ),
      ),
    );
  }
}

/// "1 000 F" (FCFA), with the locale's grouping.
String formatPrice(int price) => '${NumberFormat.decimalPattern(catalogLanguage).format(price)} F';

/// "850 Mo" under 1 GB, else "1,62 Go" (1 GB = 1024 MB, as operators count).
String formatVolume(int megabytes) {
  final fr = catalogLanguage == 'fr';
  if (megabytes < 1024) return '$megabytes ${fr ? 'Mo' : 'MB'}';
  final gb = NumberFormat('#,##0.##', catalogLanguage).format(megabytes / 1024);
  return '$gb ${fr ? 'Go' : 'GB'}';
}

String formatValidity(Translations t, DataPlan plan) {
  if (plan.night) return t.plans.night;
  final hours = plan.validityHours;
  return hours % 24 == 0 && hours > 24 ? t.plans.days(n: hours ~/ 24) : t.plans.hours(n: hours);
}

/// "6 octobre 2026" / "October 6, 2026", without loading intl's date data.
String formatDate(DateTime date) {
  const fr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  const en = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return catalogLanguage == 'fr' ? '${date.day} ${fr[date.month - 1]} ${date.year}' : '${en[date.month - 1]} ${date.day}, ${date.year}';
}
