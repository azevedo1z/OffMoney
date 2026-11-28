import 'package:meta/meta.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_entry.dart';
import 'package:offmoney/domain/names.dart';

@immutable
final class ExpenseQuery {
  factory ExpenseQuery(String text) => ExpenseQuery._(
    List.unmodifiable(
      Names.key(text).split(' ').where((word) => word.isNotEmpty),
    ),
  );

  const ExpenseQuery._(this._words);

  static const none = ExpenseQuery._([]);

  final List<String> _words;

  bool get isActive => _words.isNotEmpty;

  bool matches(Expense expense) {
    final name = Names.key(expense.name);
    return _words.every(name.contains);
  }

  List<ExpenseEntry> filter(Iterable<ExpenseEntry> entries) => [
    for (final entry in entries)
      if (matches(entry.expense)) entry,
  ];
}
