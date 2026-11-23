import 'package:offmoney/domain/calendar_date.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_entry.dart';
import 'package:offmoney/domain/expense_order.dart';
import 'package:offmoney/domain/names.dart';
import 'package:offmoney/domain/payment_card.dart';

abstract final class ExpenseOrdering {
  static List<ExpenseEntry> sorted(Iterable<ExpenseEntry> entries) =>
      sortedBy(entries, orders: const {}, cards: const {});

  static List<ExpenseEntry> sortedBy(
    Iterable<ExpenseEntry> entries, {
    required Map<ExpenseCategory, ExpenseOrder> orders,
    required Map<int, PaymentCard> cards,
  }) {
    final chosen = [
      for (final category in ExpenseCategory.values)
        ExpenseOrder.chosenIn(orders, category),
    ];
    return [...entries]..sort((a, b) => _compare(a, b, chosen, cards));
  }

  static int _compare(
    ExpenseEntry a,
    ExpenseEntry b,
    List<ExpenseOrder> chosen,
    Map<int, PaymentCard> cards,
  ) {
    final category = a.expense.category;
    final byCategory = category.index.compareTo(b.expense.category.index);
    if (byCategory != 0) return byCategory;
    final byChoice = _byChosenKey(
      chosen[category.index],
      a.expense,
      b.expense,
      cards,
    );
    if (byChoice != 0) return byChoice;
    final byDefault = _byDefaultKey(a.expense, b.expense);
    return byDefault != 0 ? byDefault : a.id.compareTo(b.id);
  }

  static int _byChosenKey(
    ExpenseOrder order,
    Expense a,
    Expense b,
    Map<int, PaymentCard> cards,
  ) => switch ((order, a, b)) {
    (
      ExpenseOrder.fixedHighestAmount || ExpenseOrder.variableHighestAmount,
      _,
      _,
    ) =>
      b.amount.compareTo(a.amount),
    (
      ExpenseOrder.fixedLowestAmount || ExpenseOrder.variableLowestAmount,
      _,
      _,
    ) =>
      a.amount.compareTo(b.amount),
    (ExpenseOrder.installmentByName || ExpenseOrder.variableByName, _, _) =>
      _byName(a, b),
    (
      ExpenseOrder.installmentMostRemaining,
      InstallmentExpense(remaining: final first),
      InstallmentExpense(remaining: final second),
    ) =>
      second.compareTo(first),
    (ExpenseOrder.installmentByCard, _, _) => _presentFirst(
      cardOf(a, cards),
      cardOf(b, cards),
      _byCardName,
    ),
    (
      ExpenseOrder.variableNewestFirst,
      VariableExpense(spentOn: final first?),
      VariableExpense(spentOn: final second?),
    ) =>
      second.compareTo(first),
    _ => 0,
  };

  static int _byDefaultKey(Expense a, Expense b) => switch ((a, b)) {
    (
      InstallmentExpense(remaining: final first),
      InstallmentExpense(remaining: final second),
    ) =>
      first.compareTo(second),
    (
      VariableExpense(spentOn: final first),
      VariableExpense(spentOn: final second),
    ) =>
      _presentFirst(first, second, _oldestFirst),
    _ => _byName(a, b),
  };

  static int _byName(Expense a, Expense b) =>
      Names.key(a.name).compareTo(Names.key(b.name));

  static int _oldestFirst(CalendarDate first, CalendarDate second) =>
      first.compareTo(second);

  static int _byCardName(PaymentCard first, PaymentCard second) {
    final byName = Names.key(first.name).compareTo(Names.key(second.name));
    return byName != 0 ? byName : first.id.compareTo(second.id);
  }

  static int _presentFirst<T extends Object>(
    T? first,
    T? second,
    int Function(T, T) compare,
  ) {
    if (first == null) return second == null ? 0 : 1;
    if (second == null) return -1;
    return compare(first, second);
  }
}
