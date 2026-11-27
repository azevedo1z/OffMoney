import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_entry.dart';
import 'package:offmoney/domain/expense_query.dart';

import '../support/builders.dart';

void main() {
  group('ExpenseQuery', () {
    final cards = {
      1: card('Roxo'),
      2: card('Antigo', id: 2, archived: true),
    };

    bool matches(String text, Expense expense) =>
        ExpenseQuery(text).matches(expense, cards);

    test('is inactive for a blank or spaces-only text', () {
      expect(ExpenseQuery('').isActive, isFalse);
      expect(ExpenseQuery('   ').isActive, isFalse);
      expect(ExpenseQuery.none.isActive, isFalse);
      expect(ExpenseQuery('a').isActive, isTrue);
    });

    test('ignores case, accents and repeated spaces', () {
      final pharmacy = fixed('Farmácia São João', '40,00');

      expect(matches('  FARMÁCIA  sao ', pharmacy), isTrue);
      expect(matches('farmacia', pharmacy), isTrue);
    });

    test('matches part of a word', () {
      expect(matches('merc', variable('Supermercado', '90,00')), isTrue);
    });

    test('needs every word, each in any order', () {
      final pharmacy = fixed('Farmácia São João', '40,00');

      expect(matches('joao farm', pharmacy), isTrue);
      expect(matches('farmacia padaria', pharmacy), isFalse);
    });

    test('finds one word in the name and the other in the card name', () {
      final fridge = installment('Geladeira', '300,00', 2, 10, cardId: 1);

      expect(matches('geladeira roxo', fridge), isTrue);
      expect(matches('roxo', fridge), isTrue);
    });

    test('never matches a word across the name and the card name', () {
      final fridge = installment('Geladeira', '300,00', 2, 10, cardId: 1);

      expect(matches('rar', fridge), isFalse);
    });

    test('finds an installment by the name of its archived card', () {
      final sofa = installment('Sofá', '200,00', 1, 5, cardId: 2);

      expect(matches('antigo', sofa), isTrue);
    });

    test('uses only the name for an installment without a known card', () {
      final noCard = installment('Monitor', '60,00', 7, 9);
      final missingCard = installment('Monitor', '60,00', 7, 9, cardId: 9);

      expect(matches('monitor', noCard), isTrue);
      expect(matches('roxo', noCard), isFalse);
      expect(matches('roxo', missingCard), isFalse);
    });

    test('never matches a fixed or variable expense by a card name', () {
      expect(matches('roxo', fixed('Aluguel', '1.100,00')), isFalse);
      expect(matches('roxo', variable('Pão', '7,00')), isFalse);
    });

    test('filter keeps the matches in their input order', () {
      final items = [
        entry(3, variable('Mercado', '90,00')),
        entry(1, fixed('Aluguel', '1.100,00')),
        entry(2, installment('Mesa', '80,00', 1, 4)),
      ];

      final kept = ExpenseQuery('me').filter(items, cards);

      expect([for (final item in kept) item.id], [3, 2]);
    });

    test('filter with none returns every entry', () {
      final items = <ExpenseEntry>[
        entry(1, fixed('Aluguel', '1.100,00')),
        entry(2, variable('Pão', '7,00')),
      ];

      expect(ExpenseQuery.none.filter(items, cards), items);
      expect(ExpenseQuery('  ').filter(items, cards), items);
    });
  });
}
