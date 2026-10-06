import 'package:flutter/material.dart';

import '../../../core/catalog/models.dart';
import '../../modals/country_picker_sheet.dart';
import 'code_texts.dart';

/// App bar title showing the country, tapped to pick another one.
class CountryTitle extends StatelessWidget {
  final Country country;

  const CountryTitle({required this.country, super.key});

  @override
  Widget build(BuildContext context) => InkWell(
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
  );
}
