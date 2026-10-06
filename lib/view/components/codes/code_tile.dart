import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/catalog/models.dart';
import '../../../core/providers/catalog_provider.dart';
import '../../../core/providers/library_provider.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../modals/code_actions_sheet.dart';
import '../../modals/run_code_sheet.dart';
import 'code_texts.dart';

class CodeTile extends ConsumerWidget {
  final UssdCode code;
  final Operator? operator;
  final bool isCustom;

  /// Shows which operator the code belongs to (favorites, search results).
  final bool showOperator;

  const CodeTile({
    required this.code,
    super.key,
    this.operator,
    this.isCustom = false,
    this.showOperator = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider.select((ids) => ids.contains(code.id)));
    final colors = Theme.of(context).colorScheme;

    String? source;
    if (showOperator) {
      final country = ref.watch(currentCatalogProvider).value?.countryById(operator?.countryId);
      source = operator == null ? context.t.phoneCodes : '${country?.flag ?? ''} ${operator!.displayName}'.trim();
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colors.primary.withValues(alpha: 0.1),
        foregroundColor: colors.primary,
        child: Icon(isCustom ? Icons.person_outline : code.category.icon, size: 20),
      ),
      title: Text(code.label.text),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: code.displayCode(context.t),
              style: codeTextStyle.copyWith(color: colors.primary),
            ),
            if (source != null) TextSpan(text: '\n$source'),
          ],
        ),
      ),
      isThreeLine: source != null,
      trailing: IconButton(
        tooltip: isFavorite ? context.t.removeFromFavorites : context.t.addToFavorites,
        icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? Colors.amber.shade700 : null),
        onPressed: () => ref.read(favoritesProvider.notifier).toggle(code.id),
      ),
      onTap: () => showRunCodeSheet(context, code: code, operator: operator),
      onLongPress: () => showCodeActionsSheet(context, code: code, operator: operator, isCustom: isCustom),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}
