import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:offmoney/presentation/cards/card_form_screen.dart';
import 'package:offmoney/presentation/l10n/generated/app_localizations.dart';
import 'package:offmoney/presentation/providers.dart';
import 'package:offmoney/presentation/shared/card_tag.dart';
import 'package:offmoney/presentation/shared/grouped_section.dart';
import 'package:offmoney/presentation/theme/metrics.dart';

class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageCards),
        actions: [
          IconButton(
            tooltip: l10n.addCard,
            onPressed: () => openCardForm(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: switch (ref.watch(activeCardsProvider)) {
        AsyncData(value: final cards) when cards.isEmpty => Center(
          child: Text(
            l10n.cardsEmpty,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        AsyncData(value: final cards) => ListView(
          padding: const EdgeInsets.only(top: Metrics.inset),
          children: [
            GroupedSection(
              children: [for (final card in cards) _CardTile(card: card)],
            ),
          ],
        ),
        AsyncError() => Center(child: Text(l10n.loadFailed)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Align(
      alignment: AlignmentDirectional.centerStart,
      child: CardTag.of(card),
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => openCardForm(context, card: card),
  );
}
