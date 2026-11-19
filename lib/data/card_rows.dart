import 'package:drift/drift.dart';
import 'package:offmoney/data/offmoney_database.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/payment_card.dart';

abstract final class CardRows {
  static SimpleSelectStatement<$CardsTable, CardRow> inCreationOrder(
    OffMoneyDatabase db,
  ) => db.select(db.cards)..orderBy([(card) => OrderingTerm.asc(card.id)]);

  static PaymentCard toCard(CardRow row) => PaymentCard(
    id: row.id,
    name: row.name,
    color: CardColor(row.colorRgb),
    createdAt: row.createdAt,
    archivedAt: row.archivedAt,
  );

  static CardsCompanion toInsert(PaymentCard card) => CardsCompanion.insert(
    id: Value(card.id),
    name: card.name,
    colorRgb: card.color.rgb,
    createdAt: card.createdAt,
    archivedAt: Value(card.archivedAt),
  );
}
