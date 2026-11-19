import 'package:flutter/material.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:offmoney/presentation/l10n/generated/app_localizations.dart';
import 'package:offmoney/presentation/shared/card_tag.dart';
import 'package:offmoney/presentation/theme/metrics.dart';

class CardSelector extends StatelessWidget {
  const CardSelector({
    required this.options,
    required this.selectedId,
    required this.onChanged,
    super.key,
  });

  static const _spacing = 8.0;

  final List<PaymentCard> options;
  final int? selectedId;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Metrics.inset,
        Metrics.headerGap,
        Metrics.inset,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cardLabel,
            style: Theme.of(context).listTileTheme.titleTextStyle,
          ),
          Wrap(
            spacing: _spacing,
            children: [
              _option(
                id: null,
                tag: CardTag(label: l10n.noCard, selected: selectedId == null),
              ),
              for (final card in options)
                _option(
                  id: card.id,
                  tag: CardTag.of(card, selected: card.id == selectedId),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _option({required int? id, required CardTag tag}) {
    final onChanged = this.onChanged;
    return InkWell(
      customBorder: const StadiumBorder(),
      onTap: onChanged == null ? null : () => onChanged(id),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Metrics.rowHeight),
        child: Align(widthFactor: 1, child: tag),
      ),
    );
  }
}
