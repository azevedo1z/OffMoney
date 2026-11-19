import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/card_rules.dart';
import 'package:offmoney/domain/payment_card.dart';

import '../support/builders.dart';

final purple = CardColor(0x8A05BE);

Set<CardError> errorsOf(
  String name, {
  CardColor? color,
  List<PaymentCard> cards = const [],
  int? editingId,
}) => CardRules.errors(
  name: name,
  color: color,
  cards: cards,
  editingId: editingId,
);

void main() {
  group('CardRules.errors', () {
    test('accepts a clean name with a color', () {
      expect(errorsOf('Roxo', color: purple), isEmpty);
    });

    test('requires a name of 1 to 20 characters after cleaning', () {
      expect(errorsOf('', color: purple), {CardError.nameEmpty});
      expect(errorsOf('   ', color: purple), {CardError.nameEmpty});
      expect(errorsOf('a' * 20, color: purple), isEmpty);
      expect(errorsOf('a' * 21, color: purple), {CardError.nameTooLong});
      expect(errorsOf('  ${'a' * 10}   ${'a' * 9}  ', color: purple), isEmpty);
    });

    test('counts an emoji in the name as one character', () {
      expect(errorsOf('💳' * 20, color: purple), isEmpty);
      expect(errorsOf('💳' * 21, color: purple), {CardError.nameTooLong});
    });

    test('requires a color', () {
      expect(errorsOf('Roxo'), {CardError.colorInvalid});
    });

    test('rejects the name of an active card, ignoring case, accents and '
        'extra spaces', () {
      final cards = [card('Cartão Roxo')];

      expect(errorsOf('Cartão Roxo', color: purple, cards: cards), {
        CardError.nameTaken,
      });
      expect(errorsOf('CARTAO  roxo ', color: purple, cards: cards), {
        CardError.nameTaken,
      });
      expect(errorsOf('Cartão Laranja', color: purple, cards: cards), isEmpty);
    });

    test('lets the name of an archived card be used again', () {
      expect(
        errorsOf('Roxo', color: purple, cards: [card('Roxo', archived: true)]),
        isEmpty,
      );
    });

    test('does not compare a card being edited with itself', () {
      final cards = [card('Roxo'), card('Laranja', id: 2)];

      expect(
        errorsOf('Roxo', color: purple, cards: cards, editingId: 1),
        isEmpty,
      );
      expect(errorsOf('Laranja', color: purple, cards: cards, editingId: 1), {
        CardError.nameTaken,
      });
    });

    test('reports every problem at once', () {
      expect(errorsOf(' '), {CardError.nameEmpty, CardError.colorInvalid});
    });
  });
}
