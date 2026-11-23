import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/calendar_date.dart';
import 'package:offmoney/domain/expense_entry.dart';
import 'package:offmoney/domain/expense_order.dart';
import 'package:offmoney/domain/expense_ordering.dart';
import 'package:offmoney/domain/payment_card.dart';

import '../support/builders.dart';

List<int> idsOf(List<ExpenseEntry> entries) => [
  for (final entry in entries) entry.id,
];

void main() {
  group('ExpenseOrdering', () {
    test('groups by category in the fixed order', () {
      final sorted = ExpenseOrdering.sorted([
        entry(1, variable('Pão', '7,00', on: defaultToday)),
        entry(2, installment('Monitor', '60,00', 7, 9)),
        entry(3, fixed('Condomínio', '750,00')),
      ]);

      expect(idsOf(sorted), [3, 2, 1]);
    });

    test('sorts Fixed alphabetically, ignoring case and accents', () {
      final sorted = ExpenseOrdering.sorted([
        entry(1, fixed('Energia', '180,00')),
        entry(2, fixed('aluguel', '1.100,00')),
        entry(3, fixed('Água', '85,00')),
      ]);

      expect(idsOf(sorted), [3, 2, 1]);
    });

    test('sorts Installments by how many are left, ending soonest first', () {
      final sorted = ExpenseOrdering.sorted([
        entry(1, installment('Armário', '70,00', 2, 12)),
        entry(2, installment('Notebook', '150,00', 10, 10)),
        entry(3, installment('Monitor', '60,00', 7, 9)),
      ]);

      expect(idsOf(sorted), [2, 3, 1]);
    });

    test('sorts Variable by date, oldest first, with the undated last', () {
      final sorted = ExpenseOrdering.sorted([
        entry(1, variable('Mercado', '1,00', on: CalendarDate(2026, 11, 7))),
        entry(2, variable('Sem data', '1,00')),
        entry(3, variable('Pão', '1,00', on: CalendarDate(2026, 11, 5))),
      ]);

      expect(idsOf(sorted), [3, 1, 2]);
    });

    test('breaks a tie by id, oldest entry first', () {
      final sorted = ExpenseOrdering.sorted([
        entry(8, variable('Sem data', '1,00')),
        entry(7, variable('Sem data', '1,00')),
        entry(6, variable('Pão', '7,00', on: defaultToday)),
        entry(5, variable('Pão', '7,00', on: defaultToday)),
        entry(4, installment('Monitor', '60,00', 7, 9)),
        entry(3, installment('Armário', '70,00', 1, 3)),
        entry(2, fixed('Academia', '120,00')),
        entry(1, fixed('academia', '120,00')),
      ]);

      expect(idsOf(sorted), [1, 2, 3, 4, 5, 6, 7, 8]);
    });
  });

  group('ExpenseOrdering.sortedBy', () {
    List<int> sortedIds(
      List<ExpenseEntry> entries,
      ExpenseOrder order, {
      Map<int, PaymentCard> cards = const {},
    }) => idsOf(
      ExpenseOrdering.sortedBy(
        entries,
        orders: {order.category: order},
        cards: cards,
      ),
    );

    test('sorts Fixed by highest amount', () {
      final fixedItems = [
        entry(1, fixed('Energia', '180,00')),
        entry(2, fixed('Aluguel', '1.100,00')),
        entry(3, fixed('Água', '85,00')),
      ];

      expect(sortedIds(fixedItems, ExpenseOrder.fixedHighestAmount), [
        2,
        1,
        3,
      ]);
    });

    test('sorts Fixed by lowest amount', () {
      final fixedItems = [
        entry(1, fixed('Energia', '180,00')),
        entry(2, fixed('Aluguel', '1.100,00')),
        entry(3, fixed('Água', '85,00')),
      ];

      expect(sortedIds(fixedItems, ExpenseOrder.fixedLowestAmount), [3, 1, 2]);
    });

    test('breaks an amount tie by the default order, then by id', () {
      final fixedItems = [
        entry(1, fixed('Energia', '100,00')),
        entry(2, fixed('Academia', '100,00')),
        entry(3, fixed('academia', '100,00')),
        entry(4, fixed('Água', '85,00')),
      ];

      expect(sortedIds(fixedItems, ExpenseOrder.fixedHighestAmount), [
        2,
        3,
        1,
        4,
      ]);
    });

    test('sorts Installments by most left first', () {
      final installments = [
        entry(1, installment('Armário', '70,00', 2, 12)),
        entry(2, installment('Notebook', '150,00', 10, 10)),
        entry(3, installment('Monitor', '60,00', 7, 9)),
        entry(4, installment('Cadeira', '90,00', 1, 3)),
      ];

      expect(sortedIds(installments, ExpenseOrder.installmentMostRemaining), [
        1,
        3,
        4,
        2,
      ]);
    });

    test('sorts Installments by name, ignoring case and accents', () {
      final installments = [
        entry(1, installment('Notebook', '150,00', 2, 10)),
        entry(2, installment('ármário', '70,00', 2, 12)),
        entry(3, installment('Monitor', '60,00', 7, 9)),
        entry(4, installment('Armario', '70,00', 11, 12)),
      ];

      expect(sortedIds(installments, ExpenseOrder.installmentByName), [
        4,
        2,
        3,
        1,
      ]);
    });

    test('groups Installments by card name, with no card last', () {
      final cards = {
        1: card('Roxo'),
        2: card('laranja', id: 2),
        3: card('Roxo', id: 3, archived: true),
      };
      final installments = [
        entry(1, installment('Sem cartão', '10,00', 1, 2)),
        entry(2, installment('Notebook', '150,00', 2, 10, cardId: 1)),
        entry(3, installment('Monitor', '60,00', 7, 9, cardId: 2)),
        entry(4, installment('Cadeira', '90,00', 1, 3, cardId: 3)),
        entry(5, installment('Celular', '80,00', 1, 12, cardId: 9)),
        entry(6, installment('Fone', '30,00', 8, 10, cardId: 1)),
      ];

      expect(
        sortedIds(installments, ExpenseOrder.installmentByCard, cards: cards),
        [3, 6, 2, 4, 1, 5],
      );
    });

    test('sorts Variable by newest first, with the undated last', () {
      final variables = [
        entry(1, variable('Mercado', '1,00', on: CalendarDate(2026, 11, 5))),
        entry(2, variable('Sem data', '1,00')),
        entry(3, variable('Pão', '1,00', on: CalendarDate(2026, 11, 7))),
        entry(4, variable('Outro sem data', '1,00')),
        entry(5, variable('Feira', '1,00', on: CalendarDate(2026, 11, 7))),
      ];

      expect(sortedIds(variables, ExpenseOrder.variableNewestFirst), [
        3,
        5,
        1,
        2,
        4,
      ]);
    });

    test('sorts Variable by highest amount, undated or not', () {
      final variables = [
        entry(1, variable('Pão', '7,00', on: CalendarDate(2026, 11, 7))),
        entry(2, variable('Sem data', '90,00')),
        entry(3, variable('Mercado', '90,00', on: CalendarDate(2026, 11, 5))),
      ];

      expect(sortedIds(variables, ExpenseOrder.variableHighestAmount), [
        3,
        2,
        1,
      ]);
    });

    test('sorts Variable by lowest amount', () {
      final variables = [
        entry(1, variable('Mercado', '90,00', on: CalendarDate(2026, 11, 5))),
        entry(2, variable('Pão', '7,00', on: CalendarDate(2026, 11, 7))),
      ];

      expect(sortedIds(variables, ExpenseOrder.variableLowestAmount), [2, 1]);
    });

    test('sorts Variable by name', () {
      final variables = [
        entry(1, variable('Pão', '7,00', on: CalendarDate(2026, 11, 7))),
        entry(2, variable('mercado', '90,00', on: CalendarDate(2026, 11, 5))),
      ];

      expect(sortedIds(variables, ExpenseOrder.variableByName), [2, 1]);
    });

    test('keeps the categories and the other orders apart', () {
      final month = [
        entry(1, variable('Pão', '7,00', on: CalendarDate(2026, 11, 7))),
        entry(2, variable('Mercado', '90,00', on: CalendarDate(2026, 11, 5))),
        entry(3, fixed('Energia', '180,00')),
        entry(4, fixed('Aluguel', '1.100,00')),
        entry(5, installment('Armário', '70,00', 2, 12)),
        entry(6, installment('Monitor', '60,00', 7, 9)),
      ];

      expect(sortedIds(month, ExpenseOrder.fixedLowestAmount), [
        3,
        4,
        6,
        5,
        2,
        1,
      ]);
    });
  });
}
