import 'package:flutter_test/flutter_test.dart';

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
}
