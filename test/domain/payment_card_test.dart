import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/payment_card.dart';

import '../support/builders.dart';

void main() {
  group('PaymentCard', () {
    test('is archived once it has an archive time', () {
      expect(card('Roxo').isArchived, isFalse);
      expect(card('Roxo', archived: true).isArchived, isTrue);
    });

    test('is a value', () {
      expect({card('Roxo'), card('Roxo')}, hasLength(1));
      expect(card('Roxo'), isNot(card('Roxo', id: 2)));
      expect(card('Roxo'), isNot(card('Laranja')));
      expect(card('Roxo'), isNot(card('Roxo', color: '#FF7A00')));
      expect(card('Roxo'), isNot(card('Roxo', archived: true)));
    });

    test('describes itself for diagnostics', () {
      expect(card('Roxo', id: 3).toString(), contains('#3'));
      expect(card('Roxo').toString(), contains('Roxo'));
    });
  });

  group('cardOf', () {
    final cards = {1: card('Roxo')};

    test('finds the card of an installment', () {
      expect(
        cardOf(installment('Notebook', '250,00', 3, 10, cardId: 1), cards),
        card('Roxo'),
      );
    });

    test('finds none for an installment without a card', () {
      expect(cardOf(installment('Notebook', '250,00', 3, 10), cards), isNull);
    });

    test('finds none when the card is not among the cards', () {
      expect(
        cardOf(installment('Notebook', '250,00', 3, 10, cardId: 9), cards),
        isNull,
      );
    });

    test('finds none for other categories', () {
      expect(cardOf(fixed('Aluguel', '1.100,00'), cards), isNull);
    });
  });
}
