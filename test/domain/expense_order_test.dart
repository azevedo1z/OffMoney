import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_order.dart';

void main() {
  group('ExpenseOrder', () {
    test('offers the Fixed orders with the default first', () {
      expect(ExpenseOrder.of(ExpenseCategory.fixed), [
        ExpenseOrder.fixedByName,
        ExpenseOrder.fixedHighestAmount,
        ExpenseOrder.fixedLowestAmount,
      ]);
    });

    test('offers the Installment orders with the default first', () {
      expect(ExpenseOrder.of(ExpenseCategory.installment), [
        ExpenseOrder.installmentFewestRemaining,
        ExpenseOrder.installmentMostRemaining,
        ExpenseOrder.installmentByName,
        ExpenseOrder.installmentByCard,
      ]);
    });

    test('offers the Variable orders with the default first', () {
      expect(ExpenseOrder.of(ExpenseCategory.variable), [
        ExpenseOrder.variableOldestFirst,
        ExpenseOrder.variableNewestFirst,
        ExpenseOrder.variableHighestAmount,
        ExpenseOrder.variableLowestAmount,
        ExpenseOrder.variableByName,
      ]);
    });

    test('keeps the offered orders read-only', () {
      expect(
        () => ExpenseOrder.of(ExpenseCategory.fixed).clear(),
        throwsUnsupportedError,
      );
    });

    test('names the default of each category', () {
      expect(
        ExpenseOrder.defaultOf(ExpenseCategory.fixed),
        ExpenseOrder.fixedByName,
      );
      expect(
        ExpenseOrder.defaultOf(ExpenseCategory.installment),
        ExpenseOrder.installmentFewestRemaining,
      );
      expect(
        ExpenseOrder.defaultOf(ExpenseCategory.variable),
        ExpenseOrder.variableOldestFirst,
      );
    });

    test('tells whether an order is the default of its category', () {
      expect(ExpenseOrder.fixedByName.isDefault, isTrue);
      expect(ExpenseOrder.fixedHighestAmount.isDefault, isFalse);
      expect(ExpenseOrder.variableNewestFirst.isDefault, isFalse);
    });

    group('chosenIn', () {
      test('returns the order chosen for the category', () {
        final orders = {
          ExpenseCategory.installment: ExpenseOrder.installmentByCard,
        };

        expect(
          ExpenseOrder.chosenIn(orders, ExpenseCategory.installment),
          ExpenseOrder.installmentByCard,
        );
      });

      test('falls back to the default when nothing was chosen', () {
        expect(
          ExpenseOrder.chosenIn(const {}, ExpenseCategory.variable),
          ExpenseOrder.variableOldestFirst,
        );
      });

      test('falls back to the default when the order is of another '
          'category', () {
        final orders = {
          ExpenseCategory.fixed: ExpenseOrder.variableNewestFirst,
        };

        expect(
          ExpenseOrder.chosenIn(orders, ExpenseCategory.fixed),
          ExpenseOrder.fixedByName,
        );
      });
    });
  });
}
