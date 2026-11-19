import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/application/backup/backup_actions.dart';
import 'package:offmoney/application/backup/backup_codec.dart';
import 'package:offmoney/application/card_actions.dart';
import 'package:offmoney/application/change_log_entry.dart';
import 'package:offmoney/application/month_actions.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:offmoney/domain/reference_month.dart';

import '../support/backup_fixture.dart';
import '../support/builders.dart';
import '../support/memory_repository.dart';
import '../support/snapshot_description.dart';

BackupReading read(Map<String, Object?> backup) =>
    BackupCodec.decode(jsonEncode(backup), today: defaultToday);

Map<String, Object?> month(Map<String, Object?> backup, int index) =>
    (backup['months']! as List<Object?>)[index]! as Map<String, Object?>;

Matcher rejectedAs(BackupProblem problem) => isA<BackupRejected>().having(
  (rejection) => rejection.problem,
  'problem',
  problem,
);

void main() {
  test('accepts a valid file, including dateless items in closed months', () {
    final reading = read(validBackup());

    final snapshot = (reading as BackupAccepted).snapshot;
    expect(snapshot.months, hasLength(2));
    expect(snapshot.months.last.reference, ReferenceMonth(2026, 11));
    expect(
      snapshot.months.last.entries.last.expense,
      variable(
        'Pão',
        '7,00',
        on: defaultToday,
      ),
    );
    expect(snapshot.changeLog.single.action, ChangeAction.expenseCreated);
    expect(
      snapshot.months.first.entries.single.updatedAt,
      DateTime.utc(2026, 10, 3, 9, 30),
    );
  });

  group('version 1', () {
    test('has no cards and no installment on a card', () {
      final snapshot = (read(validBackup()) as BackupAccepted).snapshot;

      expect(snapshot.cards, isEmpty);
      expect(
        snapshot.months.last.entries.first.expense,
        installment('TV', '120,00', 8, 18),
      );
    });

    test('does not read a cards or cardId key', () {
      final backup = validBackup()..['cards'] = 'none';
      _expenses(backup, 1)[0]['cardId'] = 99;
      _expenses(backup, 1)[1]['cardId'] = 'none';

      final snapshot = (read(backup) as BackupAccepted).snapshot;

      expect(snapshot.cards, isEmpty);
      expect(
        snapshot.months.last.entries.first.expense,
        installment('TV', '120,00', 8, 18),
      );
    });
  });

  group('version 2', () {
    test('reads the cards, archived ones included, and the card of each '
        'installment', () {
      final snapshot =
          (read(validBackupWithCards()) as BackupAccepted).snapshot;

      expect(snapshot.cards, [
        PaymentCard(
          id: 1,
          name: 'Roxo',
          color: CardColor(0x8A05BE),
          createdAt: DateTime.utc(2026, 10, 5, 12),
          archivedAt: null,
        ),
        PaymentCard(
          id: 2,
          name: 'Laranja',
          color: CardColor(0xFF7A00),
          createdAt: DateTime.utc(2026, 10, 6, 12),
          archivedAt: DateTime.utc(2026, 10, 20, 12),
        ),
      ]);
      expect(
        snapshot.months.last.entries.first.expense,
        installment('TV', '120,00', 8, 18, cardId: 1),
      );
    });

    final accepted = <String, void Function(Map<String, Object?>)>{
      'an installment without a card': (backup) =>
          _expenses(backup, 1)[0]['cardId'] = null,
      'an installment on an archived card': (backup) =>
          _expenses(backup, 1)[0]['cardId'] = 2,
      'an archived card with the name of an active one': (backup) =>
          _cards(backup)[1]['name'] = 'Roxo',
      'two archived cards with the same name': (backup) => _cards(backup)[0]
        ..['name'] = 'Laranja'
        ..['archivedAt'] = '2026-10-21T12:00:00.000Z',
      'two cards with the same color': (backup) =>
          _cards(backup)[1]['color'] = '#8A05BE',
      'a color in lower case without the hash': (backup) =>
          _cards(backup)[0]['color'] = '8a05be',
      'no cards at all': (backup) {
        backup['cards'] = <Object?>[];
        _expenses(backup, 1)[0]['cardId'] = null;
      },
    };

    for (final MapEntry(key: description, value: change) in accepted.entries) {
      test('accepts $description', () {
        final backup = validBackupWithCards();
        change(backup);

        expect(read(backup), isA<BackupAccepted>());
      });
    }

    final rejected =
        <String, (BackupProblem, void Function(Map<String, Object?>))>{
          'cards that are missing': (
            BackupProblem.invalidStructure,
            (backup) => backup.remove('cards'),
          ),
          'cards that are not a list': (
            BackupProblem.invalidStructure,
            (backup) => backup['cards'] = 'none',
          ),
          'a card that is not an object': (
            BackupProblem.invalidStructure,
            (backup) => backup['cards'] = <Object?>['none'],
          ),
          'a card without a name': (
            BackupProblem.invalidStructure,
            (backup) => _cards(backup)[0].remove('name'),
          ),
          'a card without a color': (
            BackupProblem.invalidStructure,
            (backup) => _cards(backup)[0].remove('color'),
          ),
          'a card without a creation time': (
            BackupProblem.invalidStructure,
            (backup) => _cards(backup)[0].remove('createdAt'),
          ),
          'a card color written as a number': (
            BackupProblem.invalidStructure,
            (backup) => _cards(backup)[0]['color'] = 9045438,
          ),
          'a card archived at a time that does not exist': (
            BackupProblem.invalidStructure,
            (backup) => _cards(backup)[1]['archivedAt'] = 'yesterday',
          ),
          'a repeated card id': (
            BackupProblem.invalidStructure,
            (backup) => _cards(backup)[1]['id'] = 1,
          ),
          'a card id of zero': (
            BackupProblem.invalidStructure,
            (backup) => _cards(backup)[1]['id'] = 0,
          ),
          'a card id above the limit': (
            BackupProblem.invalidStructure,
            (backup) => _cards(backup)[1]['id'] = 2147483648,
          ),
          'a card on a Fixed item': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[2]['cardId'] = 1,
          ),
          'a card on a Variable item': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[1]['cardId'] = 1,
          ),
          'a card of an installment written as text': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[0]['cardId'] = '1',
          ),
          'an installment on a card that is not in the file': (
            BackupProblem.invalidCards,
            (backup) => _expenses(backup, 1)[0]['cardId'] = 99,
          ),
          'a card with an empty name': (
            BackupProblem.invalidCards,
            (backup) => _cards(backup)[0]['name'] = '',
          ),
          'a card name with extra spaces': (
            BackupProblem.invalidCards,
            (backup) => _cards(backup)[0]['name'] = 'Roxo ',
          ),
          'a card name above the limit': (
            BackupProblem.invalidCards,
            (backup) => _cards(backup)[0]['name'] = 'a' * 21,
          ),
          'an archived card with an invalid name': (
            BackupProblem.invalidCards,
            (backup) => _cards(backup)[1]['name'] = 'a' * 21,
          ),
          'two active cards with the same name': (
            BackupProblem.invalidCards,
            (backup) => _cards(backup)[1]
              ..['name'] = 'ROXO'
              ..['archivedAt'] = null,
          ),
          'a card color in the short form': (
            BackupProblem.invalidCards,
            (backup) => _cards(backup)[0]['color'] = '#FFF',
          ),
          'a card color with alpha': (
            BackupProblem.invalidCards,
            (backup) => _cards(backup)[0]['color'] = '#FF8A05BE',
          ),
        };

    for (final MapEntry(key: description, value: (problem, corrupt))
        in rejected.entries) {
      test('rejects $description', () {
        final backup = validBackupWithCards();
        corrupt(backup);

        expect(read(backup), rejectedAs(problem));
      });
    }
  });

  test('accepts a file saved with a byte order mark', () {
    final reading = BackupCodec.decode(
      '\uFEFF${jsonEncode(validBackup())}',
      today: defaultToday,
    );

    expect(reading, isA<BackupAccepted>());
  });

  group('rejects, without writing anything,', () {
    final cases =
        <String, (BackupProblem, void Function(Map<String, Object?>))>{
          'a file of another app': (
            BackupProblem.notOffMoneyBackup,
            (backup) => backup['format'] = 'other',
          ),
          'an unknown version': (
            BackupProblem.unknownVersion,
            (backup) => backup['version'] = 3,
          ),
          'an amount written as a decimal': (
            BackupProblem.invalidStructure,
            (backup) => month(backup, 1)['incomeCents'] = 480000.0,
          ),
          'an amount written as text': (
            BackupProblem.invalidStructure,
            (backup) => month(backup, 1)['incomeCents'] = '480000',
          ),
          'an income above the cap': (
            BackupProblem.invalidStructure,
            (backup) => month(backup, 1)['incomeCents'] = 100000000000,
          ),
          'an unknown status': (
            BackupProblem.invalidStructure,
            (backup) => month(backup, 1)['status'] = 'paused',
          ),
          'a month 13': (
            BackupProblem.invalidStructure,
            (backup) => month(backup, 1)['reference'] = '2026-13',
          ),
          'a repeated id': (
            BackupProblem.invalidStructure,
            (backup) => month(backup, 1)['id'] = 1,
          ),
          'a repeated item id': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[1]['id'] = 11,
          ),
          'a month id of zero': (
            BackupProblem.invalidStructure,
            (backup) => month(backup, 1)['id'] = 0,
          ),
          'a negative item id': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[0]['id'] = -1,
          ),
          'an id that would exhaust the database sequence': (
            BackupProblem.invalidStructure,
            (backup) => month(backup, 1)['id'] = 9223372036854775807,
          ),
          'a change id above the limit': (
            BackupProblem.invalidStructure,
            (backup) => _changes(backup).single['id'] = 2147483648,
          ),
          'a missing field': (
            BackupProblem.invalidStructure,
            (backup) => month(backup, 1).remove('openedAt'),
          ),
          'a date that does not exist': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[1]['spentOn'] = '2026-02-30',
          ),
          'counters on a variable item': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[1]['totalInstallments'] = 2,
          ),
          'no open month': (
            BackupProblem.invalidTimeline,
            (backup) => month(backup, 1)
              ..['status'] = 'closed'
              ..['closedAt'] = '2026-11-07T12:00:00.000Z',
          ),
          'a closed month without a close time': (
            BackupProblem.invalidTimeline,
            (backup) => month(backup, 0)['closedAt'] = null,
          ),
          'two open months': (
            BackupProblem.invalidTimeline,
            (backup) => month(backup, 0)
              ..['status'] = 'open'
              ..['closedAt'] = null,
          ),
          'an open month that is not the latest': (
            BackupProblem.invalidTimeline,
            (backup) => month(backup, 1)['reference'] = '2026-09',
          ),
          'a repeated reference': (
            BackupProblem.invalidTimeline,
            (backup) => month(backup, 1)['reference'] = '2026-10',
          ),
          'a closed month without income': (
            BackupProblem.invalidTimeline,
            (backup) => month(backup, 0)['incomeCents'] = null,
          ),
          'an open month with a close time': (
            BackupProblem.invalidTimeline,
            (backup) =>
                month(backup, 1)['closedAt'] = '2026-11-07T12:00:00.000Z',
          ),
          'a dateless Variable item in the open month': (
            BackupProblem.invalidExpenses,
            (backup) => _expenses(backup, 1)[1]['spentOn'] = null,
          ),
          'an installment beyond its total': (
            BackupProblem.invalidExpenses,
            (backup) => _expenses(backup, 1)[0]['currentInstallment'] = 19,
          ),
          'an item amount of zero': (
            BackupProblem.invalidExpenses,
            (backup) => _expenses(backup, 1)[0]['amountCents'] = 0,
          ),
          'an item amount above the cap': (
            BackupProblem.invalidExpenses,
            (backup) => _expenses(backup, 0)[0]['amountCents'] = 100000000000,
          ),
          'a name with extra spaces': (
            BackupProblem.invalidExpenses,
            (backup) => _expenses(backup, 1)[1]['name'] = 'Pão ',
          ),
          'a name with a line break': (
            BackupProblem.invalidExpenses,
            (backup) => _expenses(backup, 1)[1]['name'] = 'Pão\nSaldo 9.999,00',
          ),
          'months that are not a list': (
            BackupProblem.invalidStructure,
            (backup) => backup['months'] = 'none',
          ),
          'a month that is not an object': (
            BackupProblem.invalidStructure,
            (backup) => backup['months'] = <Object?>['none'],
          ),
          'a change log that is missing': (
            BackupProblem.invalidStructure,
            (backup) => backup.remove('changeLog'),
          ),
          'an unknown category': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[0]['category'] = 'other',
          ),
          'an installment missing a counter': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[0].remove('totalInstallments'),
          ),
          'a date on an installment': (
            BackupProblem.invalidStructure,
            (backup) => _expenses(backup, 1)[0]['spentOn'] = '2026-11-07',
          ),
          'an unknown change action': (
            BackupProblem.invalidStructure,
            (backup) => _changes(backup).single['action'] = 'renamed',
          ),
          'a repeated change id': (
            BackupProblem.invalidStructure,
            (backup) => (backup['changeLog']! as List<Object?>).add(
              {..._changes(backup).single},
            ),
          ),
          'a Variable item dated after today': (
            BackupProblem.invalidExpenses,
            (backup) => _expenses(backup, 1)[1]['spentOn'] = '2026-11-08',
          ),
          'a change of a month not in the file': (
            BackupProblem.invalidChangeLog,
            (backup) => _changes(backup).single['monthId'] = 99,
          ),
        };

    for (final MapEntry(key: description, value: (problem, corrupt))
        in cases.entries) {
      test(description, () {
        final backup = validBackup();
        corrupt(backup);

        expect(read(backup), rejectedAs(problem));
      });
    }

    for (final MapEntry(key: description, value: text) in {
      'text that is not JSON': 'not json',
      'JSON that is not an object': '[]',
    }.entries) {
      test(description, () {
        expect(
          (BackupCodec.decode(text, today: defaultToday) as BackupRejected)
              .problem,
          BackupProblem.invalidStructure,
        );
      });
    }
  });

  test('export then import gives back the same data', () async {
    final memory = await MemoryRepository.open();
    addTearDown(memory.close);
    final saveCard = SaveCard(memory.cards);
    await saveCard(name: 'Roxo', color: '#8A05BE');
    await saveCard(name: 'Laranja', color: '#FF7A00');
    await memory.repository.setIncome(brl('4.800,00'));
    await memory.repository.addExpense(
      installment('TV', '120,00', 8, 18, cardId: 2),
    );
    await memory.repository.addExpense(installment('Monitor', '60,00', 7, 9));
    memory.clock.advance();
    await ArchiveCard(memory.cards)(2);
    await memory.repository.applyClose(
      planOf(
        PrepareClose(memory.clock.call)(await memory.repository.openMonth()),
      ),
    );
    await memory.repository.addExpense(
      variable('Pão', '7,00', on: defaultToday),
    );
    memory.clock.advance();
    final tv = (await memory.repository.openMonth()).entries.first;
    await memory.repository.updateExpense(
      tv.id,
      installment('TV', '110,00', 9, 18, cardId: 2),
    );
    final export = ExportBackup(memory.repository, memory.clock.call);

    final reading = ImportBackup(
      memory.repository,
      memory.clock.call,
    ).read(await export());

    final original = await memory.repository.snapshot();
    final restored = (reading as BackupAccepted).snapshot;
    expect(restored.cards, original.cards);
    expect(restored.cards, hasLength(2));
    expect(describeMonths(restored), describeMonths(original));
    expect(
      describeChanges(restored.changeLog),
      describeChanges(original.changeLog),
    );
  });

  test('the file is written as version 2, with the cards and the card of '
      'each installment', () async {
    final memory = await MemoryRepository.open();
    addTearDown(memory.close);
    await SaveCard(memory.cards)(name: 'Roxo', color: '#8A05BE');
    await memory.repository.addExpense(
      installment('TV', '120,00', 8, 18, cardId: 1),
    );
    await memory.repository.addExpense(installment('Monitor', '60,00', 7, 9));
    await memory.repository.addExpense(fixed('Internet', '110,00'));

    final file =
        jsonDecode(
              await ExportBackup(memory.repository, memory.clock.call)(),
            )
            as Map<String, Object?>;

    expect(file['format'], 'gemify-backup');
    expect(file['version'], 2);
    expect(file['cards'], [
      {
        'id': 1,
        'name': 'Roxo',
        'color': '#8A05BE',
        'createdAt': '2026-11-07T12:00:00.000Z',
        'archivedAt': null,
      },
    ]);
    final [tv, monitor, internet] = _expenses(file, 0);
    expect(tv, containsPair('cardId', 1));
    expect(monitor, containsPair('cardId', null));
    expect(internet.containsKey('cardId'), isFalse);
  });

  test('the file is named after the day of the export', () async {
    final memory = await MemoryRepository.open();
    addTearDown(memory.close);

    final export = ExportBackup(memory.repository, memory.clock.call);

    expect(export.fileName(), 'offmoney-backup-2026-11-07.json');
  });

  test('rejections describe themselves for diagnostics', () {
    expect(
      const BackupRejected(BackupProblem.unknownVersion).toString(),
      contains('unknownVersion'),
    );
  });
}

List<Map<String, Object?>> _expenses(Map<String, Object?> backup, int index) =>
    [
      for (final item in month(backup, index)['expenses']! as List<Object?>)
        item! as Map<String, Object?>,
    ];

List<Map<String, Object?>> _cards(Map<String, Object?> backup) => [
  for (final item in backup['cards']! as List<Object?>)
    item! as Map<String, Object?>,
];

List<Map<String, Object?>> _changes(Map<String, Object?> backup) => [
  for (final item in backup['changeLog']! as List<Object?>)
    item! as Map<String, Object?>,
];
