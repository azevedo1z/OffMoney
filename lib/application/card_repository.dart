import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/payment_card.dart';

final class CardNotFoundException implements Exception {
  const CardNotFoundException(this.cardId);

  final int cardId;

  @override
  String toString() => 'Card $cardId does not exist';
}

abstract interface class CardRepository {
  Stream<List<PaymentCard>> watchCards();

  Future<List<PaymentCard>> cards();

  Future<void> addCard({required String name, required CardColor color});

  Future<void> updateCard(
    int id, {
    required String name,
    required CardColor color,
  });

  Future<void> archiveCard(int id);
}
