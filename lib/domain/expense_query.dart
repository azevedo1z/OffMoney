import 'package:meta/meta.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_entry.dart';
import 'package:offmoney/domain/names.dart';
import 'package:offmoney/domain/payment_card.dart';

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

  bool matches(Expense expense, Map<int, PaymentCard> cards) {
    final name = Names.key(expense.name);
    final card = cardOf(expense, cards);
    final cardName = card == null ? '' : Names.key(card.name);
    return _words.every(
      (word) => name.contains(word) || cardName.contains(word),
    );
  }

  List<ExpenseEntry> filter(
    Iterable<ExpenseEntry> entries,
    Map<int, PaymentCard> cards,
  ) => [
    for (final entry in entries)
      if (matches(entry.expense, cards)) entry,
  ];
}
