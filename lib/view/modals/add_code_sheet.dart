import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalog/models.dart';
import '../../core/providers/library_provider.dart';
import '../../core/services/i18n/translations.g.dart';
import '../components/codes/code_texts.dart';

Future<void> showAddCodeSheet(BuildContext context, {required Operator operator}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => AddCodeSheet(operator: operator),
);

/// Adds a personal code to an operator's list.
class AddCodeSheet extends ConsumerStatefulWidget {
  final Operator operator;

  const AddCodeSheet({required this.operator, super.key});

  @override
  ConsumerState<AddCodeSheet> createState() => _AddCodeSheetState();
}

class _AddCodeSheetState extends ConsumerState<AddCodeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    await ref.read(customCodesProvider.notifier).add(operatorId: widget.operator.id, label: _name.text, code: _code.text);
    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(SnackBar(content: Text(t.codeAdded), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
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
              Text(t.addCodeFor(operator: widget.operator.displayName), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: t.codeName, hintText: t.codeNameHint, border: const OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty) ? t.requiredField : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9*#+]'))],
                style: codeTextStyle,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(labelText: t.ussdCode, hintText: '*123#', border: const OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.isEmpty) return t.requiredField;
                  if (!UssdCode.dialablePattern.hasMatch(value)) return t.invalidCode;
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: Text(t.save)),
            ],
          ),
        ),
      ),
    );
  }
}
