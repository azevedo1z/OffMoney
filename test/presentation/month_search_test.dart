import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/calendar_date.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_order.dart';

import '../support/app_finders.dart';
import '../support/app_harness.dart';
import '../support/app_seeds.dart';
import '../support/builders.dart';
import '../support/memory_repository.dart';

const searchHint = 'Buscar gastos';
const noMatches = 'Nenhum gasto encontrado';
const matchedFixed = r'R$ 45,00 de R$ 945,00';
const matchedVariable = r'R$ 35,80 de R$ 185,80';

final Finder searchButton = find.byTooltip('Buscar');
final Finder searchField = find.descendant(
  of: find.byType(AppBar),
  matching: find.byType(TextField),
);
final Finder backArrow = find.descendant(
  of: find.byType(AppBar),
  matching: find.byIcon(Icons.arrow_back_rounded),
);
final Finder clearButton = find.descendant(
  of: find.byType(AppBar),
  matching: find.byIcon(Icons.close_rounded),
);
final Finder balance = find.byKey(const Key('balance'));

Finder sortButton(ExpenseCategory category) =>
    find.byKey(Key('sort-${category.name}'));

Future<void> seedSearchMonth(MemoryRepository memory) async {
  await seedCards(memory);
  await memory.repository.setIncome(brl('3.000,00'));
  for (final expense in [
    fixed('Aluguel', '900,00'),
    fixed('Farmácia Central', '45,00'),
    installment('Geladeira', '300,00', 2, 10, cardId: 1),
    installment('Óculos', '120,00', 1, 3, cardId: 2),
    variable('Mercado', '150,00', on: defaultToday),
    variable('Farmácia', '23,50', on: defaultToday),
    variable('Farmacinha', '12,30', on: CalendarDate(2026, 11, 3)),
  ]) {
    await memory.repository.addExpense(expense);
  }
}

Future<void> seedClosedSearchMonth(MemoryRepository memory) async {
  await seedSearchMonth(memory);
  await closeNovember(memory);
}

Future<void> search(AppHarness app, String text) async {
  await app.tap(searchButton);
  await app.enter(searchField, text);
}

String searchText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(of: searchField, matching: find.byType(EditableText)),
    )
    .controller
    .text;

List<String> topToBottom(WidgetTester tester, List<String> names) =>
    [...names]..sort(
      (a, b) => tester
          .getTopLeft(find.text(a))
          .dy
          .compareTo(tester.getTopLeft(find.text(b)).dy),
    );

void expectWholeOpenMonth() {
  expect(find.text('Entrada Mensal'), findsOneWidget);
  expect(find.text('Aluguel'), findsOneWidget);
  expect(find.text('Geladeira'), findsOneWidget);
  expect(find.text('Mercado'), findsOneWidget);
  expect(find.text('Total de Gastos'), findsOneWidget);
  expect(find.text('Fechar mês'), findsOneWidget);
  expect(find.byTooltip('Adicionar em Gastos Fixos'), findsOneWidget);
  expect(find.byType(FloatingActionButton), findsOneWidget);
  expect(balance, findsOneWidget);
}

Future<void> openClosedNovember(AppHarness app) async {
  await app.tap(find.byTooltip('Histórico'));
  await app.tap(find.text('nov/2026'));
}

void main() {
  group('opening and closing', () {
    testApp('the search icon comes first on the open month', (app) async {
      final searchX = app.tester.getCenter(searchButton).dx;

      expect(
        searchX,
        lessThan(app.tester.getCenter(find.byTooltip('Histórico')).dx),
      );
      expect(
        app.tester.getCenter(searchButton).dy,
        moreOrLessEquals(
          app.tester.getCenter(find.byTooltip('Histórico')).dy,
        ),
      );
    }, seed: seedSearchMonth);

    testApp(
      'the search icon comes before Share on a closed month',
      (
        app,
      ) async {
        await openClosedNovember(app);

        expect(
          app.tester.getCenter(searchButton).dx,
          lessThan(app.tester.getCenter(find.byTooltip('Compartilhar')).dx),
        );
      },
      seed: seedClosedSearchMonth,
    );

    testApp(
      'opening turns the app bar into a field with the keyboard',
      (
        app,
      ) async {
        await app.tap(searchButton);

        expect(find.widgetWithText(TextField, searchHint), findsOneWidget);
        expect(app.tester.testTextInput.isVisible, isTrue);
        expect(backArrow, findsOneWidget);
        expect(clearButton, findsOneWidget);
        expect(find.byTooltip('Fechar busca'), findsNWidgets(2));
        expect(searchButton, findsNothing);
        expect(find.byTooltip('Histórico'), findsNothing);
        expect(find.byTooltip('Compartilhar'), findsNothing);
        expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      },
      seed: seedSearchMonth,
    );

    testApp('an empty or blank field shows the whole month', (app) async {
      await app.tap(searchButton);
      expectWholeOpenMonth();

      await app.enter(searchField, '   ');

      expectWholeOpenMonth();
      expect(find.text(noMatches), findsNothing);
    }, seed: seedSearchMonth);

    for (final (name, closer) in [
      ('the back arrow', backArrow),
      ('the X', clearButton),
    ]) {
      testApp('$name closes the search and brings the month back', (
        app,
      ) async {
        await search(app, 'farm');

        await app.tap(closer);

        expect(searchField, findsNothing);
        expect(searchButton, findsOneWidget);
        expect(find.byTooltip('Histórico'), findsOneWidget);
        expectWholeOpenMonth();
      }, seed: seedSearchMonth);
    }

    testApp(
      'Android back closes the search and keeps the open month',
      (
        app,
      ) async {
        await search(app, 'farm');

        await app.pressBack();

        expect(searchField, findsNothing);
        expect(find.text('nov/2026'), findsOneWidget);
        expectWholeOpenMonth();
      },
      seed: seedSearchMonth,
    );

    testApp('reopening the search starts with an empty field', (app) async {
      await search(app, 'farm');
      await app.tap(clearButton);

      await app.tap(searchButton);

      expect(searchText(app.tester), isEmpty);
      expectWholeOpenMonth();
    }, seed: seedSearchMonth);

    testApp(
      'on a closed month, back closes the search, then returns to History',
      (app) async {
        await openClosedNovember(app);
        await search(app, 'farm');
        expect(find.text(r'3 resultados · R$ 80,80'), findsOneWidget);
        expect(balance, findsNothing);
        expect(find.byTooltip('Compartilhar'), findsNothing);

        await app.pressBack();
        expect(searchField, findsNothing);
        expect(find.text('Aluguel'), findsOneWidget);
        expect(balance, findsOneWidget);
        expect(find.byTooltip('Compartilhar'), findsOneWidget);

        await app.pressBack();
        expect(find.widgetWithText(AppBar, 'Histórico'), findsOneWidget);
      },
      seed: seedClosedSearchMonth,
    );

    testApp(
      'a month closed while the search is open starts without search',
      (app) async {
        await app.tap(searchButton);

        await app.tap(find.text('Fechar mês'));
        await app.tap(button('Fechar mês'));

        expect(find.text('dez/2026'), findsOneWidget);
        expect(searchField, findsNothing);
        expect(searchButton, findsOneWidget);
      },
      seed: seedSearchMonth,
    );
  });

  group('the filtered month', () {
    testApp('shows only the matches, with their count and sum', (app) async {
      await search(app, 'farm');

      expect(find.text('nov/2026'), findsOneWidget);
      expect(find.text(r'3 resultados · R$ 80,80'), findsOneWidget);
      for (final name in ['Farmácia Central', 'Farmácia', 'Farmacinha']) {
        expect(find.text(name), findsOneWidget);
      }
      for (final name in ['Aluguel', 'Geladeira', 'Óculos', 'Mercado']) {
        expect(find.text(name), findsNothing);
      }
    }, seed: seedSearchMonth);

    testApp(
      'hides the income, empty categories, totals and actions',
      (
        app,
      ) async {
        await search(app, 'farm');

        expect(find.text('Entrada Mensal'), findsNothing);
        expect(find.text('Gastos Fixos'), findsOneWidget);
        expect(find.text('Gastos Parcelados'), findsNothing);
        expect(find.text('Gastos Variáveis'), findsOneWidget);
        expect(find.text('Total de Gastos'), findsNothing);
        expect(find.text('Fechar mês'), findsNothing);
        expect(find.byTooltip('Adicionar em Gastos Fixos'), findsNothing);
        expect(find.byTooltip('Adicionar em Gastos Variáveis'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(balance, findsNothing);
      },
      seed: seedSearchMonth,
    );

    testApp(
      'shows each subtotal as the matches of the whole category',
      (
        app,
      ) async {
        await search(app, 'farm');

        expect(find.text(matchedFixed), findsOneWidget);
        expect(find.text(matchedVariable), findsOneWidget);
      },
      seed: seedSearchMonth,
    );

    testApp('says "1 resultado" for a single match', (app) async {
      await search(app, 'aluguel');

      expect(find.text(r'1 resultado · R$ 900,00'), findsOneWidget);
    }, seed: seedSearchMonth);

    testApp('finds an installment by a word of its card name', (app) async {
      await search(app, 'roxo GELADEIRA');

      expect(find.text(r'1 resultado · R$ 300,00'), findsOneWidget);
      expect(find.text('Geladeira'), findsOneWidget);
      expect(find.text(r'R$ 300,00 de R$ 420,00'), findsOneWidget);
    }, seed: seedSearchMonth);

    testApp(
      'finds an installment by the name of an archived card',
      (
        app,
      ) async {
        await app.wait(app.memory.cards.archiveCard(2));
        await app.settle();

        await search(app, 'laranja');

        expect(find.text('Óculos'), findsOneWidget);
        expect(find.text(r'1 resultado · R$ 120,00'), findsOneWidget);
      },
      seed: seedSearchMonth,
    );

    testApp('says so when nothing matches and shows no category', (
      app,
    ) async {
      await search(app, 'farm xyz');

      expect(find.text(noMatches), findsOneWidget);
      expect(find.textContaining('resultado'), findsNothing);
      for (final title in [
        'Gastos Fixos',
        'Gastos Parcelados',
        'Gastos Variáveis',
      ]) {
        expect(find.text(title), findsNothing);
      }
    }, seed: seedSearchMonth);

    testApp('updates on every change of the text', (app) async {
      await search(app, 'f');
      expect(find.text(r'3 resultados · R$ 80,80'), findsOneWidget);

      await app.enter(searchField, 'farmaci');
      expect(find.text(r'3 resultados · R$ 80,80'), findsOneWidget);

      await app.enter(searchField, 'farmacia');
      expect(find.text(r'2 resultados · R$ 68,50'), findsOneWidget);
      expect(find.text('Farmacinha'), findsNothing);
    }, seed: seedSearchMonth);
  });

  group('sorting the matches', () {
    testApp('shows the sort button only with 2 or more matches', (
      app,
    ) async {
      await search(app, 'farm');

      expect(sortButton(ExpenseCategory.fixed), findsNothing);
      expect(sortButton(ExpenseCategory.variable), findsOneWidget);
    }, seed: seedSearchMonth);

    testApp('keeps the chosen order and re-sorts while filtering', (
      app,
    ) async {
      await search(app, 'farm');
      expect(topToBottom(app.tester, ['Farmácia', 'Farmacinha']), [
        'Farmacinha',
        'Farmácia',
      ]);

      await app.tap(sortButton(ExpenseCategory.variable));
      await app.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<ExpenseOrder>,
          'Maior valor',
        ),
      );

      expect(topToBottom(app.tester, ['Farmacinha', 'Farmácia']), [
        'Farmácia',
        'Farmacinha',
      ]);
      expect(searchText(app.tester), 'farm');
      expect(find.text(r'3 resultados · R$ 80,80'), findsOneWidget);
    }, seed: seedSearchMonth);
  });

  group('editing a match', () {
    testApp('coming back from the edit form keeps the search', (app) async {
      await search(app, 'farm');

      await app.tap(find.text('Farmácia Central'));
      expect(find.text('Gasto fixo'), findsOneWidget);
      await app.tap(find.byType(BackButton));

      expect(searchText(app.tester), 'farm');
      expect(find.text(r'3 resultados · R$ 80,80'), findsOneWidget);
      expect(find.text('Aluguel'), findsNothing);
    }, seed: seedSearchMonth);

    testApp('a match renamed out of the search leaves the list', (app) async {
      await search(app, 'farm');

      await app.tap(find.text('Farmácia Central'));
      await app.enter(field('Nome'), 'Drogaria');
      await app.tap(textButton('Salvar'));

      expect(find.text('Drogaria'), findsNothing);
      expect(find.text('Gastos Fixos'), findsNothing);
      expect(find.text(r'2 resultados · R$ 35,80'), findsOneWidget);
      expect(searchText(app.tester), 'farm');
    }, seed: seedSearchMonth);

    testApp('deleting matches updates the line, down to no match', (
      app,
    ) async {
      Future<void> delete(String name) async {
        await app.tap(find.text(name));
        await app.tap(find.text('Excluir'));
        await app.tap(find.text('Excluir').last);
      }

      await search(app, 'farm');
      await delete('Farmácia Central');
      expect(find.text(r'2 resultados · R$ 35,80'), findsOneWidget);

      await app.enter(searchField, 'farmacia');
      await delete('Farmácia');

      expect(find.text(noMatches), findsOneWidget);
    }, seed: seedSearchMonth);

    testApp(
      'the + round trip with an empty field keeps the search open',
      (
        app,
      ) async {
        await app.tap(searchButton);

        await app.tap(find.byTooltip('Adicionar em Gastos Fixos'));
        expect(find.text('Novo gasto fixo'), findsOneWidget);
        await app.tap(find.byType(BackButton));

        expect(searchField, findsOneWidget);
        expect(searchText(app.tester), isEmpty);
        expectWholeOpenMonth();
      },
      seed: seedSearchMonth,
    );
  });
}
