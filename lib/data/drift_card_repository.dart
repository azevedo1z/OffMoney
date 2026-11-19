import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:offmoney/application/backup/card_json.dart';
import 'package:offmoney/application/card_repository.dart';
import 'package:offmoney/application/change_log_entry.dart';
import 'package:offmoney/application/clock.dart';
import 'package:offmoney/data/card_rows.dart';
import 'package:offmoney/data/change_log_writer.dart';
import 'package:offmoney/data/offmoney_database.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/payment_card.dart';

final class DriftCardRepository implements CardRepository {
  DriftCardRepository(this._db, {required Clock clock})
    : _clock = clock,
      _log = ChangeLogWriter(_db, clock);

  final OffMoneyDatabase _db;
  final Clock _clock;
  final ChangeLogWriter _log;

  @override
  Stream<List<PaymentCard>> watchCards() =>
      CardRows.inCreationOrder(_db).watch().map(_cardsOf);

  @override
  Future<List<PaymentCard>> cards() async =>
      _cardsOf(await CardRows.inCreationOrder(_db).get());

  @override
  Future<void> addCard({required String name, required CardColor color}) =>
      _db.transaction(() async {
        final created = await _db
            .into(_db.cards)
            .insertReturning(
              CardsCompanion.insert(
                name: name,
                colorRgb: color.rgb,
                createdAt: _clock(),
              ),
            );
        await _log(
          ChangeAction.cardCreated,
          monthId: null,
          entityId: created.id,
          after: _cardJson(created),
        );
      });

  @override
  Future<void> updateCard(
    int id, {
    required String name,
    required CardColor color,
  }) => _db.transaction(() async {
    final before = await _cardRow(id);
    final after = await _write(
      id,
      CardsCompanion(name: Value(name), colorRgb: Value(color.rgb)),
    );
    await _log(
      ChangeAction.cardUpdated,
      monthId: null,
      entityId: id,
      before: _cardJson(before),
      after: _cardJson(after),
    );
  });

  @override
  Future<void> archiveCard(int id) => _db.transaction(() async {
    final before = await _cardRow(id);
    if (before.archivedAt != null) return;
    final after = await _write(
      id,
      CardsCompanion(archivedAt: Value(_clock())),
    );
    await _log(
      ChangeAction.cardArchived,
      monthId: null,
      entityId: id,
      before: _cardJson(before),
      after: _cardJson(after),
    );
  });

  Future<CardRow> _cardRow(int id) async {
    final row = await (_db.select(
      _db.cards,
    )..where((card) => card.id.equals(id))).getSingleOrNull();
    return row ?? (throw CardNotFoundException(id));
  }

  Future<CardRow> _write(int id, CardsCompanion changes) async {
    final written = await (_db.update(
      _db.cards,
    )..where((card) => card.id.equals(id))).writeReturning(changes);
    return written.single;
  }

  static List<PaymentCard> _cardsOf(List<CardRow> rows) => [
    for (final row in rows) CardRows.toCard(row),
  ];

  static String _cardJson(CardRow row) =>
      jsonEncode(CardJson.encode(CardRows.toCard(row)));
}
