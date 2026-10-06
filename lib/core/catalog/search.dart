import 'models.dart';

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', //
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', //
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o', //
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
  'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae', //
  '’': "'",
};

/// Lowercase, without accents: "Crédit" and "credit" match.
String foldText(String text) => text.toLowerCase().split('').map((char) => _accents[char] ?? char).join();

/// Whether every word of [query] appears in the code's labels (any language),
/// its code, or its operator's name.
bool matchesQuery({required UssdCode code, required String query, Operator? operator}) {
  final words = foldText(query).split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  if (words.isEmpty) return false;

  final haystack = foldText(
    [
      ...code.label.values.values,
      code.code,
      if (operator != null) operator.name,
      ?operator?.formerName,
    ].join(' '),
  );
  return words.every(haystack.contains);
}
