import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offmoney/application/rejections.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/card_rules.dart';
import 'package:offmoney/domain/names.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:offmoney/presentation/cards/card_swatches.dart';
import 'package:offmoney/presentation/l10n/generated/app_localizations.dart';
import 'package:offmoney/presentation/providers.dart';
import 'package:offmoney/presentation/shared/action_row.dart';
import 'package:offmoney/presentation/shared/card_tag.dart';
import 'package:offmoney/presentation/shared/confirm_dialog.dart';
import 'package:offmoney/presentation/shared/form_action.dart';
import 'package:offmoney/presentation/shared/grouped_section.dart';
import 'package:offmoney/presentation/theme/metrics.dart';

Future<void> openCardForm(BuildContext context, {PaymentCard? card}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CardFormScreen(card: card)),
    );

class CardFormScreen extends ConsumerStatefulWidget {
  const CardFormScreen({this.card, super.key});

  final PaymentCard? card;

  @override
  ConsumerState<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends ConsumerState<CardFormScreen> {
  static final _hexCharacters = RegExp('[#0-9a-fA-F]');

  late final _name = TextEditingController(text: widget.card?.name);
  late final _color = TextEditingController(text: widget.card?.color.hex);
  late final _preview = Listenable.merge([_name, _color]);
  Set<CardError> _errors = const {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    await _run(
      doneMessage: widget.card == null ? l10n.cardAdded : l10n.cardUpdated,
      () async {
        try {
          await ref
              .read(saveCardProvider)
              .call(
                name: _name.text,
                color: _color.text,
                replacingId: widget.card?.id,
              );
        } on InvalidCardException catch (rejection) {
          if (mounted) setState(() => _errors = rejection.errors);
          return false;
        }
        return true;
      },
    );
  }

  Future<void> _archive(PaymentCard card) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteCardTitle,
      action: l10n.delete,
      destructive: true,
      content: Text(l10n.deleteCardMessage(card.name)),
    );
    if (!confirmed || !mounted) return;
    await _run(doneMessage: l10n.cardDeleted, () async {
      await ref.read(archiveCardProvider).call(card.id);
      return true;
    });
  }

  Future<void> _run(
    Future<bool> Function() action, {
    required String doneMessage,
  }) => runFormAction(
    context,
    action: action,
    doneMessage: doneMessage,
    onBusyChanged: (busy) => setState(() => _busy = busy),
  );

  String? _errorText(Set<CardError> relevant, AppLocalizations l10n) =>
      switch (_errors.where(relevant.contains).firstOrNull) {
        null => null,
        CardError.nameEmpty => l10n.errorNameEmpty,
        CardError.nameTooLong => l10n.errorNameTooLong(CardRules.nameMaxLength),
        CardError.nameTaken => l10n.errorCardNameTaken,
        CardError.colorInvalid => l10n.errorCardColorInvalid,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final card = widget.card;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(card == null ? l10n.newCard : l10n.editCard),
          actions: [
            TextButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: Metrics.inset),
          children: [
            GroupedSection(
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.nameLabel,
                    errorText: _errorText({
                      CardError.nameEmpty,
                      CardError.nameTooLong,
                      CardError.nameTaken,
                    }, l10n),
                  ),
                ),
                ListenableBuilder(
                  listenable: _color,
                  builder: (context, _) => CardSwatches(
                    selected: CardColor.tryParse(_color.text),
                    onPick: (color) => _color.text = color.hex,
                  ),
                ),
                TextField(
                  controller: _color,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(_hexCharacters),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.cardColorLabel,
                    hintText: l10n.cardColorHint,
                    errorText: _errorText({CardError.colorInvalid}, l10n),
                  ),
                ),
                ListTile(
                  title: Text(l10n.cardPreview),
                  trailing: ListenableBuilder(
                    listenable: _preview,
                    builder: (context, _) => CardTag(
                      label: Names.clean(_name.text),
                      color: CardColor.tryParse(_color.text),
                    ),
                  ),
                ),
              ],
            ),
            if (card != null)
              GroupedSection(
                children: [
                  ActionRow(
                    label: l10n.delete,
                    destructive: true,
                    onTap: () => _archive(card),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
