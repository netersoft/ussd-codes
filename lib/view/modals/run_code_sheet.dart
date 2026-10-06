import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalog/models.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/services/i18n/translations.g.dart';
import '../../core/services/telephony/service.dart';
import '../components/codes/code_texts.dart';

Future<void> showRunCodeSheet(BuildContext context, {required UssdCode code, Operator? operator}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => RunCodeSheet(code: code, operator: operator),
);

/// Confirms a code before running it (USSD codes can buy bundles or send
/// money), after asking for its params when it has some.
class RunCodeSheet extends ConsumerStatefulWidget {
  final UssdCode code;
  final Operator? operator;

  const RunCodeSheet({required this.code, super.key, this.operator});

  @override
  ConsumerState<RunCodeSheet> createState() => _RunCodeSheetState();
}

class _RunCodeSheetState extends ConsumerState<RunCodeSheet> {
  final _formKey = GlobalKey<FormState>();

  // Values live only in these controllers, disposed with the sheet: a PIN is
  // never stored.
  late final Map<String, TextEditingController> _controllers = {
    for (final param in widget.code.params) param.key: TextEditingController()..addListener(_refresh),
  };

  bool _dialing = false;

  /// The network's answer once the code ran in the background (null: not run
  /// yet, or run the usual way).
  String? _response;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  Map<String, String> get _values => {for (final entry in _controllers.entries) entry.key: entry.value.text.trim()};

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Runs the code in the background to show the network's answer here
  /// when possible (Android, direct mode), the usual way otherwise.
  Future<void> _dial() async {
    if (_dialing || !(_formKey.currentState?.validate() ?? true)) return;
    setState(() => _dialing = true);

    final direct = ref.read(directCallProvider);
    if (direct && !_isIOS && !widget.code.isDeviceCode) {
      final result = await ref.read(telephonyServiceProvider).sendUssd(widget.code.fill(_values));
      if (!mounted) return;
      if (result case UssdAnswered(:final text)) {
        setState(() {
          _dialing = false;
          _response = text;
        });
        return;
      }
    }
    await _runInDialer(direct: direct);
  }

  /// Runs the code through the phone app: called directly when allowed, or
  /// typed in the dialer. A menu answered in the background continues there.
  Future<void> _runInDialer({required bool direct}) async {
    setState(() => _dialing = true);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    final navigator = Navigator.of(context);

    final outcome = await ref.read(telephonyServiceProvider).dial(widget.code.fill(_values), direct: direct, isDeviceCode: widget.code.isDeviceCode);

    if (!mounted) return;
    navigator.pop();
    final message = switch (outcome) {
      DialOutcome.copied => t.codeCopiedPaste,
      DialOutcome.failed => t.dialFailed,
      _ => null,
    };
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
    }
  }

  /// Fills [param] with a number from the contacts, in the local format of
  /// the operator's country (or the selected one, for personal codes).
  Future<void> _pickContact(UssdParam param) async {
    final number = await ref.read(telephonyServiceProvider).pickPhoneNumber();
    if (number == null || !mounted) return;

    final catalog = ref.read(currentCatalogProvider).value;
    final country = catalog?.countryById(widget.operator?.countryId ?? ref.read(selectedCountryProvider));
    final local = country?.localNumber(number) ?? number.replaceAll(RegExp(r'\D'), '');
    _controllers[param.key]!.value = TextEditingValue(
      text: local,
      selection: TextSelection.collapsed(offset: local.length),
    );
  }

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    await Clipboard.setData(ClipboardData(text: widget.code.fill(_values)));
    messenger.showSnackBar(SnackBar(content: Text(t.codeCopied), behavior: SnackBarBehavior.floating));
  }

  List<Widget> _responseView(BuildContext context, String response) {
    final t = context.t;
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 20),
      Text(t.operatorResponse, style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          response.isEmpty ? t.emptyUssdResponse : response,
          style: theme.textTheme.bodyLarge?.copyWith(fontStyle: response.isEmpty ? FontStyle.italic : null),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _dialing ? null : () => _runInDialer(direct: true),
              icon: const Icon(Icons.dialpad),
              label: Text(t.continueInDialer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.closeAction)),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final params = widget.code.params;
    final hasSecret = params.any((param) => param.isSecret);
    final preview = widget.code.preview(_values, placeholder: (param) => '‹${param.type.placeholder(t)}›');
    final canPickContact = ref.read(telephonyServiceProvider).canPickContact;
    final notice = _isIOS ? t.iosNotice : (widget.code.isDeviceCode ? t.deviceCodeNotice : null);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.code.label.text, style: theme.textTheme.titleLarge),
              if (widget.operator != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(widget.operator!.displayName, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  preview,
                  textAlign: TextAlign.center,
                  style: codeTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                ),
              ),
              if (_response case final response?)
                ..._responseView(context, response)
              else ...[
                for (final (index, param) in params.indexed) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _controllers[param.key],
                    autofocus: index == 0,
                    keyboardType: param.type.keyboardType,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: param.isSecret,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: index == params.length - 1 ? TextInputAction.done : TextInputAction.next,
                    onFieldSubmitted: index == params.length - 1 ? (_) => _dial() : null,
                    decoration: InputDecoration(
                      labelText: param.label.text,
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(switch (param.type) {
                        ParamType.amount => Icons.payments_outlined,
                        ParamType.phone => Icons.phone_outlined,
                        ParamType.pin => Icons.lock_outline,
                        ParamType.number => Icons.pin_outlined,
                      }),
                      suffixIcon: param.type == ParamType.phone && canPickContact
                          ? IconButton(
                              onPressed: () => _pickContact(param),
                              icon: const Icon(Icons.contacts_outlined),
                              tooltip: t.pickContact,
                            )
                          : null,
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty) ? t.requiredField : null,
                  ),
                ],
                if (hasSecret) _Notice(icon: Icons.lock_outline, text: t.secretNotice),
                if (notice != null) _Notice(icon: Icons.info_outline, text: notice),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // A filled code holding a PIN stays out of the clipboard.
                    if (!_isIOS && !hasSecret) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _values.values.any((value) => value.isEmpty) ? null : _copy,
                          icon: const Icon(Icons.copy),
                          label: Text(t.copyCode),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _dialing ? null : _dial,
                        icon: _dialing
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_isIOS ? Icons.copy : Icons.call),
                        label: Text(_dialing && !_isIOS ? t.sendingUssd : (_isIOS ? t.copyCode : t.dial)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: style?.color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
