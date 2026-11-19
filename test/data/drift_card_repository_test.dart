import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/application/card_repository.dart';
import 'package:offmoney/application/change_log_entry.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/app_seeds.dart';
import '../support/memory_repository.dart';

final purple = CardColor(0x8A05BE);
final orange = CardColor(0xFF7A00);

void main() {
  late MemoryRepository memory;

  setUp(() async => memory = await MemoryRepository.open());
  tearDown(() => memory.close());

  Future<List<ChangeLogEntry>> changeLog() async =>
      (await memory.repository.snapshot()).changeLog;

  group('cards', () {
    test('are listed in creation order, archived ones included', () async {
      await memory.cards.addCard(name: 'Roxo', color: purple);
      memory.clock.advance();
      await memory.cards.addCard(name: 'Laranja', color: orange);
      await memory.cards.archiveCard(1);

      final cards = await memory.cards.cards();

      expect([for (final card in cards) card.name], ['Roxo', 'Laranja']);
      expect([for (final card in cards) card.isArchived], [true, false]);
      expect(await memory.cards.watchCards().first, cards);
    });

    test('a new card is stored and logged', () async {
      await memory.cards.addCard(name: 'Roxo', color: purple);

      final created = PaymentCard(
        id: 1,
        name: 'Roxo',
        color: purple,
        createdAt: memory.clock.now,
        archivedAt: null,
      );
      expect(await memory.cards.cards(), [created]);
      final log = (await changeLog()).single;
      expect(log.action, ChangeAction.cardCreated);
      expect(log.monthId, isNull);
      expect(log.entityId, created.id);
      expect(log.occurredAt, memory.clock.now);
      expect(log.before, isNull);
      expect(jsonDecode(log.after!), {
        'id': 1,
        'name': 'Roxo',
        'color': '#8A05BE',
        'createdAt': '2026-11-07T12:00:00.000Z',
        'archivedAt': null,
      });
    });

    test('a rename and a new color are stored and logged', () async {
      await memory.cards.addCard(name: 'Roxo', color: purple);

      await memory.cards.updateCard(1, name: 'Laranja', color: orange);

      final card = (await memory.cards.cards()).single;
      expect(card.name, 'Laranja');
      expect(card.color, orange);
      final log = (await changeLog()).last;
      expect(log.action, ChangeAction.cardUpdated);
      expect(log.entityId, card.id);
      expect(
        jsonDecode(log.before!),
        allOf(containsPair('name', 'Roxo'), containsPair('color', '#8A05BE')),
      );
      expect(
        jsonDecode(log.after!),
        allOf(
          containsPair('name', 'Laranja'),
          containsPair('color', '#FF7A00'),
        ),
      );
    });

    test('archiving keeps the card, with the time, and logs it', () async {
      await memory.cards.addCard(name: 'Roxo', color: purple);
      memory.clock.advance();

      await memory.cards.archiveCard(1);

      final card = (await memory.cards.cards()).single;
      expect(card.archivedAt, memory.clock.now);
      final log = (await changeLog()).last;
      expect(log.action, ChangeAction.cardArchived);
      expect(log.entityId, card.id);
      expect(jsonDecode(log.before!), containsPair('archivedAt', isNull));
      expect(
        jsonDecode(log.after!),
        containsPair('archivedAt', '2026-11-07T12:01:00.000Z'),
      );
    });

    test('archiving twice changes nothing and logs nothing', () async {
      await memory.cards.addCard(name: 'Roxo', color: purple);
      await memory.cards.archiveCard(1);
      final archived = await memory.cards.cards();
      final logged = (await changeLog()).length;
      memory.clock.advance();

      await memory.cards.archiveCard(1);

      expect(await memory.cards.cards(), archived);
      expect(await changeLog(), hasLength(logged));
    });

    test('a card that does not exist cannot be changed', () async {
      final notFound = throwsA(isA<CardNotFoundException>());

      await expectLater(
        memory.cards.updateCard(9, name: 'Roxo', color: purple),
        notFound,
      );
      await expectLater(memory.cards.archiveCard(9), notFound);
    });

    test('a failure after a card write leaves neither card nor log', () async {
      await memory.cards.addCard(name: 'Roxo', color: purple);
      await failingOn('change_log')(memory);
      final failure = throwsA(isA<SqliteException>());

      await expectLater(
        memory.cards.addCard(name: 'Laranja', color: orange),
        failure,
      );
      await expectLater(
        memory.cards.updateCard(1, name: 'Laranja', color: orange),
        failure,
      );
      await expectLater(memory.cards.archiveCard(1), failure);

      final card = (await memory.cards.cards()).single;
      expect(card.name, 'Roxo');
      expect(card.color, purple);
      expect(card.isArchived, isFalse);
    });
  });
}
