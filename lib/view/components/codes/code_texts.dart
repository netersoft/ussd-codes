import 'package:flutter/material.dart';

import '../../../core/catalog/models.dart';
import '../../../core/services/i18n/translations.g.dart';

/// Language of the catalog texts to show: the app's current language.
String get catalogLanguage => LocaleSettings.instance.currentLocale.languageCode;

extension LocalizedTextX on LocalizedText {
  String get text => resolve(catalogLanguage);
}

extension CodeCategoryX on CodeCategory {
  String label(Translations t) => switch (this) {
    CodeCategory.account => t.categories.account,
    CodeCategory.recharge => t.categories.recharge,
    CodeCategory.data => t.categories.data,
    CodeCategory.transfer => t.categories.transfer,
    CodeCategory.money => t.categories.money,
    CodeCategory.help => t.categories.help,
    CodeCategory.services => t.categories.services,
    CodeCategory.device => t.categories.device,
  };

  IconData get icon => switch (this) {
    CodeCategory.account => Icons.account_balance_wallet_outlined,
    CodeCategory.recharge => Icons.add_card,
    CodeCategory.data => Icons.language,
    CodeCategory.transfer => Icons.swap_horiz,
    CodeCategory.money => Icons.payments_outlined,
    CodeCategory.help => Icons.support_agent,
    CodeCategory.services => Icons.apps,
    CodeCategory.device => Icons.smartphone,
  };
}

extension UssdCodeTextsX on UssdCode {
  /// The code with each param shown as `‹amount›`, as listed on screen.
  String displayCode(Translations t) => preview(const {}, placeholder: (param) => '‹${param.type.placeholder(t)}›');
}

extension ParamTypeX on ParamType {
  String placeholder(Translations t) => switch (this) {
    ParamType.amount => t.paramPlaceholders.amount,
    ParamType.phone => t.paramPlaceholders.phone,
    ParamType.pin => t.paramPlaceholders.pin,
    ParamType.number => t.paramPlaceholders.number,
  };

  TextInputType get keyboardType => this == ParamType.phone ? TextInputType.phone : TextInputType.number;
}

extension CountryTextsX on Country {
  String get displayName => '$flag  ${name.text}';
}

/// The code font: digits, `*` and `#` easy to tell apart.
const codeTextStyle = TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Courier'], letterSpacing: 0.5);
