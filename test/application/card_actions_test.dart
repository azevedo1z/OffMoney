import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/application/card_actions.dart';
import 'package:offmoney/application/month_actions.dart';
import 'package:offmoney/application/rejections.dart';
import 'package:offmoney/domain/card_rules.dart';

import '../support/builders.dart';
import '../support/memory_repository.dart';

Matcher rejectsWith(Set<CardError> errors) => throwsA(
  isA<InvalidCardException>().having(
    (rejection) => rejection.errors,
    'errors',
    errors,
  ),
);

void main() {
  late MemoryRepository memory;
  late SaveCard save;
  late ArchiveCard archive;

  setUp(() async {
    memory = await MemoryRepository.open();
    save = SaveCard(memory.cards);
    archive = ArchiveCard(memory.cards);
  });
  tearDown(() => memory.close());

  Future<List<String>> describeCards() async => [
    for (final card in await memory.cards.cards())
      '${card.name} ${card.color.hex}${card.isArchived ? ' archived' : ''}',
  ];

  group('SaveCard', () {
    test(
      'stores a new card with a clean name and a normalized color',
      () async {
        await save(name: '  Cartão   Roxo ', color: '8a05be');

        expect(await describeCards(), ['Cartão Roxo #8A05BE']);
      },
    );

    test('rejects an invalid card with every error, storing nothing', () async {
      await expectLater(
        save(name: ' ', color: '#FFF'),
        rejectsWith({CardError.nameEmpty, CardError.colorInvalid}),
      );
      await expectLater(
        save(name: 'a' * 21, color: '#8A05BE'),
        rejectsWith({CardError.nameTooLong}),
      );

      expect(await describeCards(), isEmpty);
    });

    test('rejects the name of another active card', () async {
      await save(name: 'Cartão Roxo', color: '#8A05BE');

      await expectLater(
        save(name: 'cartao  ROXO', color: '#FF7A00'),
        rejectsWith({CardError.nameTaken}),
      );

      expect(await describeCards(), ['Cartão Roxo #8A05BE']);
    });

    test('lets two cards share a color', () async {
      await save(name: 'Roxo', color: '#8A05BE');
      await save(name: 'Lilás', color: '#8A05BE');

      expect(await describeCards(), ['Roxo #8A05BE', 'Lilás #8A05BE']);
    });

    test('changes a card, which may keep its own name', () async {
      await save(name: 'Roxo', color: '#8A05BE');
      await save(name: 'Laranja', color: '#FF7A00');

      await save(name: 'roxo', color: '#111111', replacingId: 1);

      expect(await describeCards(), ['roxo #111111', 'Laranja #FF7A00']);
      await expectLater(
        save(name: 'Laranja', color: '#111111', replacingId: 1),
        rejectsWith({CardError.nameTaken}),
      );
    });

    test('lets a new card take the name of an archived one', () async {
      await save(name: 'Roxo', color: '#8A05BE');
      await archive(1);

      await save(name: 'Roxo', color: '#FF7A00');

      expect(await describeCards(), [
        'Roxo #8A05BE archived',
        'Roxo #FF7A00',
      ]);
    });
  });

  group('ArchiveCard', () {
    test('archives the card and keeps it on its installments', () async {
      final saveExpense = SaveExpense(memory.repository, memory.clock.call);
      await save(name: 'Roxo', color: '#8A05BE');
      await saveExpense(installment('Monitor', '60,00', 7, 9, cardId: 1));

      await archive(1);

      expect(await describeCards(), ['Roxo #8A05BE archived']);
      final month = await memory.repository.openMonth();
      expect(
        month.entries.single.expense,
        installment('Monitor', '60,00', 7, 9, cardId: 1),
      );
    });
  });

  group('SaveExpense with cards', () {
    test(
      'an installment keeps an archived card when it is saved again',
      () async {
        final saveExpense = SaveExpense(memory.repository, memory.clock.call);
        await save(name: 'Roxo', color: '#8A05BE');
        await saveExpense(installment('Monitor', '60,00', 7, 9, cardId: 1));
        await archive(1);
        final id = (await memory.repository.openMonth()).entries.single.id;

        await saveExpense(
          installment('Monitor', '65,00', 7, 9, cardId: 1),
          replacingId: id,
        );

        final month = await memory.repository.openMonth();
        expect(
          month.entries.single.expense,
          installment('Monitor', '65,00', 7, 9, cardId: 1),
        );
      },
    );

    test('an installment is saved without a card', () async {
      final saveExpense = SaveExpense(memory.repository, memory.clock.call);

      await saveExpense(installment('Monitor', '60,00', 7, 9));

      final month = await memory.repository.openMonth();
      expect(
        month.entries.single.expense,
        installment('Monitor', '60,00', 7, 9),
      );
    });
  });
}
