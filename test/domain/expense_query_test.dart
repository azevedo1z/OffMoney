import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_entry.dart';
import 'package:offmoney/domain/expense_query.dart';

import '../support/builders.dart';

void main() {
  group('ExpenseQuery', () {
    bool matches(String text, Expense expense) =>
        ExpenseQuery(text).matches(expense);

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

    test('finds an installment by its own name', () {
      expect(
        matches('geladeira', installment('Geladeira', '300,00', 2, 10)),
        isTrue,
      );
    });

    test('filter keeps the matches in their input order', () {
      final items = [
        entry(3, variable('Mercado', '90,00')),
        entry(1, fixed('Aluguel', '1.100,00')),
        entry(2, installment('Mesa', '80,00', 1, 4)),
      ];

      final kept = ExpenseQuery('me').filter(items);

      expect([for (final item in kept) item.id], [3, 2]);
    });

    test('filter with none returns every entry', () {
      final items = <ExpenseEntry>[
        entry(1, fixed('Aluguel', '1.100,00')),
        entry(2, variable('Pão', '7,00')),
      ];

      expect(ExpenseQuery.none.filter(items), items);
      expect(ExpenseQuery('  ').filter(items), items);
    });
  });
}
