import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/catalog/models.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/i18n/translations.g.dart';
import '../components/codes/code_texts.dart';

Future<void> showCodeActionsSheet(BuildContext context, {required UssdCode code, Operator? operator, bool isCustom = false}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => CodeActionsSheet(code: code, operator: operator, isCustom: isCustom),
);

/// Asks before deleting a personal code, then confirms with a snackbar.
/// Returns whether the code was deleted.
Future<bool> confirmDeleteCustomCode(BuildContext context, WidgetRef ref, String id, {required ScaffoldMessengerState messenger}) async {
  final t = context.t;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(t.deleteCodeConfirm),
      actions: [
        TextButton(onPressed: () => context.pop(false), child: Text(t.cancel)),
        TextButton(onPressed: () => context.pop(true), child: Text(t.delete)),
      ],
    ),
  );
  if (confirmed != true) return false;
  await ref.read(customCodesProvider.notifier).remove(id);
  messenger.showSnackBar(SnackBar(content: Text(t.codeDeleted), behavior: SnackBarBehavior.floating));
  return true;
}

/// Secondary actions on a code (long press): copy, share, report, delete.
class CodeActionsSheet extends ConsumerWidget {
  final UssdCode code;
  final Operator? operator;
  final bool isCustom;

  const CodeActionsSheet({required this.code, super.key, this.operator, this.isCustom = false});

  String _summary(Translations t) => [
    code.label.text,
    code.displayCode(t),
    if (operator != null) operator!.displayName,
  ].join('\n');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final messenger = ScaffoldMessenger.of(context);

    void done(String? message) {
      context.pop();
      if (message != null) messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(code.label.text, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(code.displayCode(t), style: codeTextStyle),
          ),
          const Divider(height: 1),
          if (!code.hasParams)
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(t.copyCode),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: code.code));
                done(t.codeCopied);
              },
            ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(t.share),
            onTap: () async {
              done(null);
              await SharePlus.instance.share(ShareParams(text: _summary(t)));
            },
          ),
          if (!isCustom && Settings.contactEmail.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(t.reportError),
              onTap: () async {
                done(null);
                await ref
                    .read(settingsProvider.notifier)
                    .sendEmail(
                      subject: t.reportSubject(code: code.id),
                      body: t.reportBody(details: '${_summary(t)}\n(${code.id})'),
                    );
              },
            ),
          if (isCustom)
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text(t.delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                final deleted = await confirmDeleteCustomCode(context, ref, code.id, messenger: messenger);
                if (deleted && context.mounted) context.pop();
              },
            ),
        ],
      ),
    );
  }
}
