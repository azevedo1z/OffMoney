import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/payment_card.dart';

PaymentCard? cardOf(Expense expense, Map<int, PaymentCard> cards) =>
    switch (expense) {
      InstallmentExpense(:final cardId?) => cards[cardId],
      _ => null,
    };
