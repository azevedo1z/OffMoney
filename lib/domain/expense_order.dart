import 'package:offmoney/domain/expense.dart';

enum ExpenseOrder {
  fixedByName(ExpenseCategory.fixed),
  fixedHighestAmount(ExpenseCategory.fixed),
  fixedLowestAmount(ExpenseCategory.fixed),
  installmentFewestRemaining(ExpenseCategory.installment),
  installmentMostRemaining(ExpenseCategory.installment),
  installmentByName(ExpenseCategory.installment),
  installmentByCard(ExpenseCategory.installment),
  variableOldestFirst(ExpenseCategory.variable),
  variableNewestFirst(ExpenseCategory.variable),
  variableHighestAmount(ExpenseCategory.variable),
  variableLowestAmount(ExpenseCategory.variable),
  variableByName(ExpenseCategory.variable)
  ;

  const ExpenseOrder(this.category);

  final ExpenseCategory category;

  static final List<List<ExpenseOrder>> _byCategory = List.unmodifiable([
    for (final category in ExpenseCategory.values)
      List<ExpenseOrder>.unmodifiable(
        values.where((order) => order.category == category),
      ),
  ]);

  static List<ExpenseOrder> of(ExpenseCategory category) =>
      _byCategory[category.index];

  static ExpenseOrder defaultOf(ExpenseCategory category) => of(category).first;

  static ExpenseOrder chosenIn(
    Map<ExpenseCategory, ExpenseOrder> orders,
    ExpenseCategory category,
  ) {
    final chosen = orders[category];
    return chosen != null && chosen.category == category
        ? chosen
        : defaultOf(category);
  }

  bool get isDefault => this == defaultOf(category);
}
