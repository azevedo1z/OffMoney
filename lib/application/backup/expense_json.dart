import 'package:offmoney/domain/expense.dart';

abstract final class ExpenseJson {
  static const category = 'category';
  static const name = 'name';
  static const amountCents = 'amountCents';
  static const currentInstallment = 'currentInstallment';
  static const totalInstallments = 'totalInstallments';
  static const spentOn = 'spentOn';
  static const cardId = 'cardId';

  static Map<String, Object?> encode(Expense expense) => {
    category: expense.category.name,
    name: expense.name,
    amountCents: expense.amount.cents,
    ...switch (expense) {
      FixedExpense() => const <String, Object?>{},
      InstallmentExpense(:final current, :final total, cardId: final card) => {
        currentInstallment: current,
        totalInstallments: total,
        cardId: card,
      },
      VariableExpense(spentOn: final date) => {spentOn: date?.iso},
    },
  };
}
