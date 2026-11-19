import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/application/change_log_entry.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/app_finders.dart';
import '../support/app_harness.dart';
import '../support/app_menu.dart';
import '../support/app_seeds.dart';

const manageCards = 'Gerenciar cartões';
const noCards = 'Nenhum cartão cadastrado';
const hexLabel = 'Cor em hexadecimal';
final Finder saveButton = textButton('Salvar');
final Finder addCardButton = find.byTooltip('Adicionar cartão');
final Finder preview = find.descendant(
  of: find.widgetWithText(ListTile, 'Prévia'),
  matching: cardTag(),
);

Future<void> openCards(AppHarness app) => choose(app, manageCards);

Future<List<PaymentCard>> storedCards(AppHarness app) =>
    app.wait(app.memory.cards.cards());

void main() {
  testApp('the menu offers the cards right after the reference', (app) async {
    await app.tap(find.byIcon(Icons.more_horiz_rounded));

    final items = [
      for (final item in app.tester.widgetList<PopupMenuItem<Object?>>(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ))
        (item.child! as Text).data,
    ];
    expect(items.take(2), ['Alterar mês de referência', manageCards]);
  });

  group('the cards screen', () {
    testApp('says so when there are no cards', (app) async {
      await openCards(app);

      expect(find.widgetWithText(AppBar, manageCards), findsOneWidget);
      expect(find.text(noCards), findsOneWidget);
    });

    testApp(
      'lists the active cards in creation order, each with its color',
      (app) async {
        await openCards(app);

        final names = ['Roxo', 'Azul'];
        final positions = [
          for (final name in names) app.tester.getTopLeft(cardTag(name)).dy,
        ];
        expect(positions, [...positions]..sort());
        expect(positions.toSet(), hasLength(names.length));
        expect(dotColorOf(app.tester, cardTag('Roxo')), CardColor(0x8A05BE));
        expect(dotColorOf(app.tester, cardTag('Azul')), CardColor(0x1A4FD6));
        expect(cardTag('Laranja'), findsNothing);
        expect(find.text(noCards), findsNothing);
      },
      seed: (memory) async {
        await seedCards(memory);
        await memory.cards.addCard(name: 'Azul', color: CardColor(0x1A4FD6));
        await memory.cards.archiveCard(2);
      },
    );
  });

  group('a new card', () {
    testApp('is added with a name and a preset color', (app) async {
      await openCards(app);
      await app.tap(addCardButton);
      expect(find.widgetWithText(AppBar, 'Novo cartão'), findsOneWidget);
      await app.enter(field('Nome'), '  Roxo ');
      await app.tap(find.byTooltip('#8A05BE'));

      await app.tap(saveButton);

      expect(
        find.widgetWithText(SnackBar, 'Cartão adicionado'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppBar, manageCards), findsOneWidget);
      expect(dotColorOf(app.tester, cardTag('Roxo')), CardColor(0x8A05BE));
      final stored = (await storedCards(app)).single;
      expect(stored.name, 'Roxo');
      expect(stored.color, CardColor(0x8A05BE));
    });

    testApp('takes a typed hex without the hash, in any case', (app) async {
      await openCards(app);
      await app.tap(addCardButton);
      await app.enter(field('Nome'), 'Lilás');
      await app.enter(field(hexLabel), 'c8a2c8');

      await app.tap(saveButton);

      expect((await storedCards(app)).single.color, CardColor(0xC8A2C8));
    });

    testApp('a preset fills the hex field, which can still be edited', (
      app,
    ) async {
      await openCards(app);
      await app.tap(addCardButton);
      await app.enter(field('Nome'), 'Lilás');

      await app.tap(find.byTooltip('#8A05BE'));
      expect(
        app.tester.widget<TextField>(field(hexLabel)).controller?.text,
        '#8A05BE',
      );
      await app.enter(field(hexLabel), '#8A05BF');
      await app.tap(saveButton);

      expect((await storedCards(app)).single.color, CardColor(0x8A05BF));
    });

    testApp('shows a live preview of the tag', (app) async {
      await openCards(app);
      await app.tap(addCardButton);
      expect(dotOf(preview), findsNothing);

      await app.enter(field('Nome'), 'Roxo');
      await app.enter(field(hexLabel), '8a05b');
      expect(
        find.descendant(of: preview, matching: find.text('Roxo')),
        findsOneWidget,
      );
      expect(dotOf(preview), findsNothing);

      await app.enter(field(hexLabel), '8a05be');
      expect(dotColorOf(app.tester, preview), CardColor(0x8A05BE));
    });

    testApp('rejects a color with alpha, typed or pasted', (app) async {
      await openCards(app);
      await app.tap(addCardButton);
      await app.enter(field('Nome'), 'Roxo');
      await app.enter(field(hexLabel), '#FF8A05BE');

      await app.tap(saveButton);

      expect(
        app.tester.widget<TextField>(field(hexLabel)).controller?.text,
        '#FF8A05BE',
      );
      expect(find.text('Use o formato #RRGGBB'), findsOneWidget);
      expect(await storedCards(app), isEmpty);
    });

    testApp('shows what is wrong and stores nothing', (app) async {
      await openCards(app);
      await app.tap(addCardButton);

      await app.tap(saveButton);
      expect(find.text('Informe o nome'), findsOneWidget);
      expect(find.text('Use o formato #RRGGBB'), findsOneWidget);

      await app.enter(field('Nome'), 'a' * 21);
      await app.enter(field(hexLabel), '#FFF');
      await app.tap(saveButton);
      expect(find.text('Máximo de 20 caracteres'), findsOneWidget);
      expect(find.text('Use o formato #RRGGBB'), findsOneWidget);

      expect(find.widgetWithText(AppBar, 'Novo cartão'), findsOneWidget);
      expect(await storedCards(app), isEmpty);
    });

    testApp('cannot take the name of an active card', (app) async {
      await openCards(app);
      await app.tap(addCardButton);
      await app.enter(field('Nome'), 'roxo');
      await app.tap(find.byTooltip('#00A868'));

      await app.tap(saveButton);

      expect(find.text('Já existe um cartão com esse nome'), findsOneWidget);
      expect(await storedCards(app), hasLength(2));
    }, seed: seedCards);

    testApp('a double tap on save stores the card once', (app) async {
      await openCards(app);
      await app.tap(addCardButton);
      await app.enter(field('Nome'), 'Roxo');
      await app.tap(find.byTooltip('#8A05BE'));

      await app.tester.tap(saveButton);
      await app.tester.tap(saveButton, warnIfMissed: false);
      await app.settle();

      expect(await storedCards(app), hasLength(1));
    });

    testApp(
      'a failed save says so and keeps the form open',
      (app) async {
        await openCards(app);
        await app.tap(addCardButton);
        await app.enter(field('Nome'), 'Roxo');
        await app.tap(find.byTooltip('#8A05BE'));

        await app.tap(saveButton);

        expect(app.tester.takeException(), isA<SqliteException>());
        expect(find.text('Erro. Nada foi alterado.'), findsOneWidget);
        expect(find.text('Cartão adicionado'), findsNothing);
        expect(find.widgetWithText(AppBar, 'Novo cartão'), findsOneWidget);
        expect(isEnabled(app.tester, saveButton), isTrue);
      },
      seed: failingOn('cards'),
    );
  });

  group('an existing card', () {
    testApp('opens with its name and color and can be changed', (app) async {
      await openCards(app);
      await app.tap(cardTag('Roxo'));
      expect(find.widgetWithText(AppBar, 'Cartão'), findsOneWidget);
      expect(
        app.tester.widget<TextField>(field(hexLabel)).controller?.text,
        '#8A05BE',
      );
      await app.enter(field('Nome'), 'Lilás');
      await app.tap(find.byTooltip('#E91E63'));

      await app.tap(saveButton);

      expect(
        find.widgetWithText(SnackBar, 'Cartão atualizado'),
        findsOneWidget,
      );
      expect(dotColorOf(app.tester, cardTag('Lilás')), CardColor(0xE91E63));
      expect(cardTag('Roxo'), findsNothing);
      expect(
        [for (final card in await storedCards(app)) card.name],
        ['Lilás', 'Laranja'],
      );
    }, seed: seedCards);

    testApp('keeps its own name when only the color changes', (app) async {
      await openCards(app);
      await app.tap(cardTag('Roxo'));
      await app.tap(find.byTooltip('#E91E63'));

      await app.tap(saveButton);

      expect(dotColorOf(app.tester, cardTag('Roxo')), CardColor(0xE91E63));
    }, seed: seedCards);

    testApp('is archived by "Excluir" only when confirmed', (app) async {
      await openCards(app);
      await app.tap(cardTag('Roxo'));
      await app.tap(find.text('Excluir'));
      expect(find.text('Excluir cartão?'), findsOneWidget);
      expect(
        find.text(
          'Os parcelados que já usam Roxo continuam mostrando o cartão.',
        ),
        findsOneWidget,
      );
      await app.tap(find.text('Cancelar'));
      expect(find.widgetWithText(AppBar, 'Cartão'), findsOneWidget);

      await app.tap(find.text('Excluir'));
      await app.tap(find.text('Excluir').last);

      expect(find.widgetWithText(SnackBar, 'Cartão excluído'), findsOneWidget);
      expect(find.widgetWithText(AppBar, manageCards), findsOneWidget);
      expect(cardTag('Roxo'), findsNothing);
      expect(cardTag('Laranja'), findsOneWidget);
      expect(
        [for (final card in await storedCards(app)) card.isArchived],
        [true, false],
      );
      final log = (await app.wait(app.memory.repository.snapshot())).changeLog;
      expect(log.last.action, ChangeAction.cardArchived);
    }, seed: seedCards);

    testApp('a new card has nothing to exclude', (app) async {
      await openCards(app);
      await app.tap(addCardButton);

      expect(find.text('Excluir'), findsNothing);
    });
  });
}
