import 'package:offmoney/domain/payment_card.dart';

abstract final class CardJson {
  static const id = 'id';
  static const name = 'name';
  static const color = 'color';
  static const createdAt = 'createdAt';
  static const archivedAt = 'archivedAt';

  static Map<String, Object?> encode(PaymentCard card) => {
    id: card.id,
    name: card.name,
    color: card.color.hex,
    createdAt: card.createdAt.toUtc().toIso8601String(),
    archivedAt: card.archivedAt?.toUtc().toIso8601String(),
  };
}
