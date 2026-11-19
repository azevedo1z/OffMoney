import 'package:meta/meta.dart';
import 'package:offmoney/domain/calendar_date.dart';
import 'package:offmoney/domain/money.dart';

enum ExpenseCategory { fixed, installment, variable }

@immutable
sealed class Expense {
  const Expense({required this.name, required this.amount});

  final String name;
  final Money amount;

  ExpenseCategory get category;

  Expense withName(String name);
}

final class FixedExpense extends Expense {
  const FixedExpense({required super.name, required super.amount});

  @override
  ExpenseCategory get category => ExpenseCategory.fixed;

  @override
  FixedExpense withName(String name) =>
      FixedExpense(name: name, amount: amount);

  @override
  bool operator ==(Object other) =>
      other is FixedExpense && other.name == name && other.amount == amount;

  @override
  int get hashCode => Object.hash(category, name, amount);

  @override
  String toString() => 'FixedExpense($name, $amount)';
}

final class InstallmentExpense extends Expense {
  const InstallmentExpense({
    required super.name,
    required super.amount,
    required this.current,
    required this.total,
    this.cardId,
  });

  final int current;
  final int total;
  final int? cardId;

  bool get isLast => current == total;

  int get remaining => total - current;

  @override
  ExpenseCategory get category => ExpenseCategory.installment;

  @override
  InstallmentExpense withName(String name) => InstallmentExpense(
    name: name,
    amount: amount,
    current: current,
    total: total,
    cardId: cardId,
  );

  InstallmentExpense advanced() => InstallmentExpense(
    name: name,
    amount: amount,
    current: current + 1,
    total: total,
    cardId: cardId,
  );

  @override
  bool operator ==(Object other) =>
      other is InstallmentExpense &&
      other.name == name &&
      other.amount == amount &&
      other.current == current &&
      other.total == total &&
      other.cardId == cardId;

  @override
  int get hashCode =>
      Object.hash(category, name, amount, current, total, cardId);

  @override
  String toString() =>
      'InstallmentExpense($name, $amount, $current/$total, card $cardId)';
}

final class VariableExpense extends Expense {
  const VariableExpense({
    required super.name,
    required super.amount,
    required this.spentOn,
  });

  final CalendarDate? spentOn;

  @override
  ExpenseCategory get category => ExpenseCategory.variable;

  @override
  VariableExpense withName(String name) =>
      VariableExpense(name: name, amount: amount, spentOn: spentOn);

  @override
  bool operator ==(Object other) =>
      other is VariableExpense &&
      other.name == name &&
      other.amount == amount &&
      other.spentOn == spentOn;

  @override
  int get hashCode => Object.hash(category, name, amount, spentOn);

  @override
  String toString() => 'VariableExpense($name, $amount, $spentOn)';
}
