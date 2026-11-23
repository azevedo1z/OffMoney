import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:offmoney/presentation/history/history_screen.dart';
import 'package:offmoney/presentation/l10n/generated/app_localizations.dart';
import 'package:offmoney/presentation/month/month_screen.dart';
import 'package:offmoney/presentation/providers.dart';
import 'package:offmoney/presentation/shared/card_tag.dart';
import 'package:offmoney/presentation/shared/month_view.dart';

import '../support/app_finders.dart';
import '../support/app_harness.dart';
import '../support/app_menu.dart';
import '../support/app_seeds.dart';
import '../support/builders.dart';
import '../support/memory_repository.dart';

const noCardsHint = 'Cadastre cartões em "Gerenciar cartões", no menu do mês.';
final Finder saveButton = textButton('Salvar');
final Finder addInstallmentButton = find.byTooltip(
  'Adicionar em Gastos Parcelados',
);

Finder tagIn(String expenseName) => find.descendant(
  of: find.widgetWithText(ListTile, expenseName),
  matching: cardTag(),
);

bool isSelected(WidgetTester tester, String option) =>
    tester.widget<CardTag>(cardTag(option)).selected;

Future<InstallmentExpense> storedInstallment(AppHarness app) async {
  final month = await app.wait(app.memory.repository.openMonth());
  return month.entries.single.expense as InstallmentExpense;
}

Future<void> seedNotebookOnPurple(MemoryRepository memory) async {
  await seedCards(memory);
  await memory.repository.addExpense(
    installment('Notebook', '250,00', 3, 10, cardId: 1),
  );
}

Future<void> seedNotebookOnArchivedPurple(MemoryRepository memory) async {
  await seedNotebookOnPurple(memory);
  await memory.cards.archiveCard(1);
}

Future<void> closeTheMonth(AppHarness app) async {
  await app.tap(find.text('Fechar mês'));
  await app.tap(button('Fechar mês'));
}

Future<void> openClosedNovember(AppHarness app) async {
  await app.tap(find.byTooltip('Histórico'));
  await app.tap(find.text('nov/2026'));
}

Widget screenWith({
  required Widget screen,
  required List<Override> overrides,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: screen,
  ),
);

void main() {
  group('the installment form', () {
    testApp('points to the cards screen while there are no cards', (app) async {
      await app.tap(addInstallmentButton);

      expect(find.text(noCardsHint), findsOneWidget);
      expect(cardTag(), findsNothing);
    });

    testApp('offers no card on Fixed and Variable items', (app) async {
      for (final section in ['Gastos Fixos', 'Gastos Variáveis']) {
        await app.tap(find.byTooltip('Adicionar em $section'));

        expect(find.text('Cartão'), findsNothing);
        expect(cardTag(), findsNothing);
        expect(find.text(noCardsHint), findsNothing);
        await app.pressBack();
      }
    }, seed: seedCards);

    testApp(
      'offers "Nenhum" and the active cards in creation order',
      (app) async {
        await app.tap(addInstallmentButton);

        final options = ['Nenhum', 'Roxo', 'Azul'];
        expect(
          [
            for (final tag in app.tester.widgetList<CardTag>(cardTag()))
              tag.label,
          ],
          options,
        );
        expect(dotOf(cardTag('Nenhum')), findsNothing);
        expect(dotColorOf(app.tester, cardTag('Roxo')), CardColor(0x8A05BE));
        expect(
          [for (final option in options) isSelected(app.tester, option)],
          [true, false, false],
        );
        expect(find.text(noCardsHint), findsNothing);
      },
      seed: (memory) async {
        await seedCards(memory);
        await memory.cards.addCard(name: 'Azul', color: CardColor(0x1A4FD6));
        await memory.cards.archiveCard(2);
      },
    );

    testApp('saves a new installment on the picked card', (app) async {
      await app.tap(addInstallmentButton);
      await app.enter(field('Nome'), 'Notebook');
      await app.enter(field('Valor da parcela'), '25000');
      await app.enter(field('Parcela atual'), '3');
      await app.enter(field('Total de parcelas'), '10');

      await app.tap(cardTag('Laranja'));
      expect(isSelected(app.tester, 'Laranja'), isTrue);
      expect(isSelected(app.tester, 'Nenhum'), isFalse);
      await app.tap(saveButton);

      expect(
        await storedInstallment(app),
        installment('Notebook', '250,00', 3, 10, cardId: 2),
      );
    }, seed: seedCards);

    testApp('saves a new installment without a card', (app) async {
      await app.tap(addInstallmentButton);
      await app.enter(field('Nome'), 'Notebook');
      await app.enter(field('Valor da parcela'), '25000');
      await app.enter(field('Parcela atual'), '3');
      await app.enter(field('Total de parcelas'), '10');

      await app.tap(saveButton);

      expect(
        await storedInstallment(app),
        installment('Notebook', '250,00', 3, 10),
      );
    }, seed: seedCards);

    testApp('opens with the card of the installment, which can be replaced '
        'or removed', (app) async {
      await app.tap(find.text('Notebook'));
      expect(isSelected(app.tester, 'Roxo'), isTrue);

      await app.tap(cardTag('Laranja'));
      await app.tap(saveButton);
      expect((await storedInstallment(app)).cardId, 2);

      await app.tap(find.text('Notebook'));
      await app.tap(cardTag('Nenhum'));
      await app.tap(saveButton);
      expect((await storedInstallment(app)).cardId, isNull);
    }, seed: seedNotebookOnPurple);

    testApp(
      'shows an archived card only while the installment keeps it',
      (app) async {
        await app.tap(find.text('Notebook'));
        expect(isSelected(app.tester, 'Roxo'), isTrue);
        expect(find.text(noCardsHint), findsNothing);

        await app.tap(cardTag('Laranja'));
        expect(cardTag('Roxo'), findsNothing);
        await app.tap(cardTag('Nenhum'));
        expect(cardTag('Roxo'), findsNothing);
      },
      seed: seedNotebookOnArchivedPurple,
    );

    testApp(
      'keeps an archived card when something else is edited',
      (app) async {
        await app.tap(find.text('Notebook'));
        await app.enter(field('Valor da parcela'), '26000');

        await app.tap(saveButton);

        expect(
          await storedInstallment(app),
          installment('Notebook', '260,00', 3, 10, cardId: 1),
        );
      },
      seed: seedNotebookOnArchivedPurple,
    );

    testApp(
      'does not offer an archived card to another installment',
      (
        app,
      ) async {
        await app.tap(addInstallmentButton);

        expect(cardTag('Roxo'), findsNothing);
        expect(cardTag('Laranja'), findsOneWidget);
      },
      seed: seedNotebookOnArchivedPurple,
    );

    testApp(
      'warns about a possible duplicate whatever the card',
      (app) async {
        await app.tap(addInstallmentButton);
        await app.enter(field('Nome'), 'notebook');
        await app.enter(field('Valor da parcela'), '1000');
        await app.enter(field('Parcela atual'), '1');
        await app.enter(field('Total de parcelas'), '2');
        await app.tap(cardTag('Laranja'));

        await app.tap(saveButton);

        expect(find.text('Possível duplicata'), findsOneWidget);
      },
      seed: seedNotebookOnPurple,
    );

    testApp(
      'the card cannot be changed while a save is in progress',
      (
        app,
      ) async {
        await app.tap(find.text('Notebook'));
        app.repository.holdWrites();
        await app.tap(saveButton);

        await app.tap(cardTag('Laranja'));

        expect(isSelected(app.tester, 'Roxo'), isTrue);
        app.repository.releaseWrites();
        await app.settle();
        expect((await storedInstallment(app)).cardId, 1);
      },
      seed: seedNotebookOnPurple,
    );
  });

  group('the installment row', () {
    testApp(
      'shows the card as a tag after the counter',
      (app) async {
        final notebook = find.widgetWithText(ListTile, 'Notebook');
        final counter = find.descendant(
          of: notebook,
          matching: find.text('3/10'),
        );

        expect(counter, findsOneWidget);
        expect(dotColorOf(app.tester, tagIn('Notebook')), CardColor(0x8A05BE));
        expect(
          app.tester.widget<CardTag>(tagIn('Notebook')).label,
          'Roxo',
        );
        expect(
          app.tester.getTopLeft(tagIn('Notebook')).dx,
          greaterThan(app.tester.getTopRight(counter).dx),
        );
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, 'Geladeira'),
            matching: find.text('10/10 · Final'),
          ),
          findsOneWidget,
        );
        expect(
          app.tester.widget<CardTag>(tagIn('Geladeira')).label,
          'Laranja',
        );
      },
      seed: (memory) async {
        await seedNotebookOnPurple(memory);
        await memory.repository.addExpense(
          installment('Geladeira', '189,90', 10, 10, cardId: 2),
        );
      },
    );

    testApp(
      'shows only the counter without a card, and no tag on other items',
      (app) async {
        expect(find.text('2/6'), findsOneWidget);
        expect(cardTag(), findsNothing);
      },
      seed: (memory) async {
        await seedCards(memory);
        await memory.repository.addExpense(installment('Sofá', '120,00', 2, 6));
        await memory.repository.addExpense(fixed('Internet', '110,00'));
        await memory.repository.addExpense(
          variable('Pão', '7,00', on: defaultToday),
        );
      },
    );

    testApp('gets the tag as soon as the card is picked', (app) async {
      await app.tap(find.text('Notebook'));
      await app.tap(cardTag('Laranja'));
      await app.tap(saveButton);

      expect(app.tester.widget<CardTag>(tagIn('Notebook')).label, 'Laranja');
    }, seed: seedNotebookOnPurple);

    testApp(
      'follows a rename and a new color, also in a closed month',
      (app) async {
        await closeTheMonth(app);
        await choose(app, 'Gerenciar cartões');
        await app.tap(cardTag('Roxo'));
        await app.enter(field('Nome'), 'Lilás');
        await app.tap(find.byTooltip('#E91E63'));
        await app.tap(saveButton);
        await app.pressBack();

        expect(app.tester.widget<CardTag>(tagIn('Notebook')).label, 'Lilás');
        expect(dotColorOf(app.tester, tagIn('Notebook')), CardColor(0xE91E63));

        await openClosedNovember(app);

        expect(find.text('3/10'), findsOneWidget);
        expect(app.tester.widget<CardTag>(tagIn('Notebook')).label, 'Lilás');
        expect(dotColorOf(app.tester, tagIn('Notebook')), CardColor(0xE91E63));
      },
      seed: (memory) async {
        await seedNotebookOnPurple(memory);
        await memory.repository.setIncome(brl('1.000,00'));
      },
    );

    testApp(
      'keeps showing an archived card in the open month, in closed months '
      'and after later closes',
      (app) async {
        await closeTheMonth(app);
        await choose(app, 'Gerenciar cartões');
        await app.tap(cardTag('Roxo'));
        await app.tap(find.text('Excluir'));
        await app.tap(find.text('Excluir').last);
        expect(cardTag('Roxo'), findsNothing);
        await app.pressBack();

        expect(find.text('4/10'), findsOneWidget);
        expect(app.tester.widget<CardTag>(tagIn('Notebook')).label, 'Roxo');

        await closeTheMonth(app);

        expect(find.text('5/10'), findsOneWidget);
        expect(app.tester.widget<CardTag>(tagIn('Notebook')).label, 'Roxo');

        await openClosedNovember(app);

        expect(find.text('3/10'), findsOneWidget);
        expect(app.tester.widget<CardTag>(tagIn('Notebook')).label, 'Roxo');
      },
      seed: (memory) async {
        await seedNotebookOnPurple(memory);
        await memory.repository.setIncome(brl('1.000,00'));
      },
    );

    testWidgets('shows no tag while its card is not among the cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MonthView(
              month: openMonth(
                items: entries([
                  installment('Notebook', '250,00', 3, 10, cardId: 9),
                ]),
              ),
              cards: {1: card('Roxo')},
              orders: const {},
              onOrder: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('3/10'), findsOneWidget);
      expect(cardTag(), findsNothing);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testApp(
        'outlines the dot of a black or white card in the ${mode.name} theme',
        (app) async {
          for (final name in ['Notebook', 'Geladeira']) {
            final dot = dotOf(tagIn(name));
            final decoration =
                app.tester
                        .widget<Container>(
                          find.descendant(
                            of: dot,
                            matching: find.byType(Container),
                          ),
                        )
                        .decoration!
                    as BoxDecoration;
            final scheme = Theme.of(app.tester.element(dot)).colorScheme;
            expect(decoration.border?.top.color, scheme.outline);
            expect(decoration.border?.top.color, isNot(decoration.color));
          }
        },
        themeMode: mode,
        seed: (memory) async {
          await memory.cards.addCard(name: 'Preto', color: CardColor(0));
          await memory.cards.addCard(
            name: 'Branco',
            color: CardColor(CardColor.maxRgb),
          );
          await memory.repository.addExpense(
            installment('Notebook', '250,00', 3, 10, cardId: 1),
          );
          await memory.repository.addExpense(
            installment('Geladeira', '189,90', 10, 10, cardId: 2),
          );
        },
      );
    }
  });

  group('a month screen', () {
    final month = openMonth(
      items: entries([installment('Notebook', '250,00', 3, 10, cardId: 1)]),
    );
    final screens = <String, (Widget, Override)>{
      'of the open month': (
        const MonthScreen(),
        openMonthProvider.overrideWith((ref) => Stream.value(month)),
      ),
      'of a closed month': (
        ClosedMonthScreen(monthId: month.id),
        monthProvider(month.id).overrideWith((ref) => Stream.value(month)),
      ),
    };

    for (final MapEntry(key: description, value: (screen, monthOverride))
        in screens.entries) {
      testWidgets('$description waits for the cards before showing the items', (
        tester,
      ) async {
        final cards = StreamController<List<PaymentCard>>();
        addTearDown(cards.close);
        await tester.pumpWidget(
          screenWith(
            screen: screen,
            overrides: [
              monthOverride,
              cardsProvider.overrideWith((ref) => cards.stream),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Notebook'), findsNothing);

        cards.add([card('Roxo')]);
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.widget<CardTag>(tagIn('Notebook')).label, 'Roxo');
      });

      testWidgets('$description says so when the cards fail to load', (
        tester,
      ) async {
        await tester.pumpWidget(
          screenWith(
            screen: screen,
            overrides: [
              monthOverride,
              cardsProvider.overrideWith(
                (ref) => Stream.error(Exception('cards')),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Erro ao carregar os dados'), findsOneWidget);
        expect(find.text('Notebook'), findsNothing);
      });
    }
  });
}
