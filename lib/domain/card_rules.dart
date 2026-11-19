import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/names.dart';
import 'package:offmoney/domain/payment_card.dart';

enum CardError { nameEmpty, nameTooLong, nameTaken, colorInvalid }

abstract final class CardRules {
  static const nameMaxLength = 20;

  static Set<CardError> errors({
    required String name,
    required CardColor? color,
    required Iterable<PaymentCard> cards,
    int? editingId,
  }) {
    final cleaned = Names.clean(name);
    final key = Names.key(cleaned);
    return {
      if (cleaned.isEmpty) CardError.nameEmpty,
      if (cleaned.runes.length > nameMaxLength) CardError.nameTooLong,
      if (cards.any(
        (card) =>
            !card.isArchived &&
            card.id != editingId &&
            Names.key(card.name) == key,
      ))
        CardError.nameTaken,
      if (color == null) CardError.colorInvalid,
    };
  }
}
