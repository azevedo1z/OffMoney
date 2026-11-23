import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_order.dart';
import 'package:offmoney/presentation/providers.dart';

import '../support/app_finders.dart';
import '../support/app_harness.dart';
import '../support/app_seeds.dart';
import '../support/builders.dart';
import '../support/memory_repository.dart';

Finder sortButton(ExpenseCategory category) =>
    find.byKey(Key('sort-${category.name}'));

Finder menuItem(String label) =>
    find.widgetWithText(CheckedPopupMenuItem<ExpenseOrder>, label);

List<String> topToBottom(WidgetTester tester, List<String> names) =>
    [...names]..sort(
      (a, b) => tester
          .getTopLeft(find.text(a))
          .dy
          .compareTo(tester.getTopLeft(find.text(b)).dy),
    );

Color sortIconColor(WidgetTester tester, ExpenseCategory category) =>
    tester
        .widget<PopupMenuButton<ExpenseOrder>>(sortButton(category))
        .iconColor ??
    Colors.transparent;

ColorScheme schemeOf(WidgetTester tester) =>
    Theme.of(tester.element(sortButton(ExpenseCategory.fixed))).colorScheme;

Future<void> pick(
  AppHarness app,
  ExpenseCategory category,
  String label,
) async {
  await app.tap(sortButton(category));
  await app.tap(menuItem(label));
}

Future<void> seedTwoOfEach(MemoryRepository memory) async {
  for (final expense in [
    fixed('Academia', '120,00'),
    fixed('Condomínio', '750,00'),
    installment('Armário', '70,00', 2, 12),
    installment('Monitor', '60,00', 7, 9),
    variable('Mercado', '7,00', on: defaultToday),
    variable('Pão', '90,00', on: defaultToday),
  ]) {
    await memory.repository.addExpense(expense);
  }
}

Future<void> seedClosedFixed(MemoryRepository memory) async {
  await memory.repository.addExpense(fixed('Academia', '120,00'));
  await memory.repository.addExpense(fixed('Condomínio', '750,00'));
  await closeNovember(memory);
}

void main() {
  testApp('puts the sort button after the + of each category', (app) async {
    for (final (title, subtotal) in [
      ('Gastos Fixos', r'R$ 870,00'),
      ('Gastos Parcelados', r'R$ 130,00'),
      ('Gastos Variáveis', r'R$ 97,00'),
    ]) {
      final add = find.byTooltip('Adicionar em $title');
      final sort = find.byTooltip('Ordenar $title');

      expect(sort, findsOneWidget);
      expect(
        app.tester.getCenter(sort).dx,
        greaterThan(app.tester.getCenter(add).dx),
      );
      expect(
        app.tester.getTopRight(sort).dx,
        lessThan(app.tester.getTopLeft(find.text(subtotal)).dx),
      );
      expect(
        app.tester.getCenter(sort).dy,
        moreOrLessEquals(app.tester.getCenter(add).dy),
      );
    }
  }, seed: seedTwoOfEach);

  testApp(
    'offers the orders of each category, the current one checked',
    (
      app,
    ) async {
      for (final (category, labels) in [
        (
          ExpenseCategory.fixed,
          ['Padrão (nome A-Z)', 'Maior valor', 'Menor valor'],
        ),
        (
          ExpenseCategory.installment,
          [
            'Padrão (menos parcelas restantes)',
            'Mais parcelas restantes',
            'Nome (A-Z)',
            'Por cartão',
          ],
        ),
        (
          ExpenseCategory.variable,
          [
            'Padrão (mais antigas primeiro)',
            'Mais recentes primeiro',
            'Maior valor',
            'Menor valor',
            'Nome (A-Z)',
          ],
        ),
      ]) {
        await app.tap(sortButton(category));

        final items = app.tester.widgetList<CheckedPopupMenuItem<ExpenseOrder>>(
          find.byType(CheckedPopupMenuItem<ExpenseOrder>),
        );
        expect([for (final item in items) (item.child! as Text).data], labels);
        expect(
          [for (final item in items) item.checked],
          [
            true,
            for (var index = 1; index < labels.length; index++) false,
          ],
        );

        await app.pressBack();
      }
    },
    seed: seedTwoOfEach,
  );

  testApp('picking an order re-sorts only that category', (app) async {
    final scheme = schemeOf(app.tester);
    expect(topToBottom(app.tester, ['Condomínio', 'Academia']), [
      'Academia',
      'Condomínio',
    ]);
    expect(
      sortIconColor(app.tester, ExpenseCategory.fixed),
      scheme.onSurfaceVariant,
    );

    await pick(app, ExpenseCategory.fixed, 'Maior valor');

    expect(topToBottom(app.tester, ['Academia', 'Condomínio']), [
      'Condomínio',
      'Academia',
    ]);
    expect(sortIconColor(app.tester, ExpenseCategory.fixed), scheme.primary);
    expect(topToBottom(app.tester, ['Pão', 'Mercado']), ['Mercado', 'Pão']);
    expect(
      sortIconColor(app.tester, ExpenseCategory.variable),
      scheme.onSurfaceVariant,
    );
  }, seed: seedTwoOfEach);

  testApp('picking the default goes back to it', (app) async {
    await pick(app, ExpenseCategory.fixed, 'Maior valor');
    await app.tap(sortButton(ExpenseCategory.fixed));
    expect(
      app.tester
          .widget<CheckedPopupMenuItem<ExpenseOrder>>(menuItem('Maior valor'))
          .checked,
      isTrue,
    );

    await app.tap(menuItem('Padrão (nome A-Z)'));

    expect(topToBottom(app.tester, ['Condomínio', 'Academia']), [
      'Academia',
      'Condomínio',
    ]);
    expect(
      sortIconColor(app.tester, ExpenseCategory.fixed),
      schemeOf(app.tester).onSurfaceVariant,
    );
  }, seed: seedTwoOfEach);

  testApp(
    'hides the button under 2 items and keeps the order chosen',
    (
      app,
    ) async {
      await pick(app, ExpenseCategory.fixed, 'Menor valor');
      final open = await app.wait(app.memory.repository.openMonth());
      final academia = open.entries.firstWhere(
        (entry) => entry.expense.name == 'Academia',
      );

      await app.wait(app.memory.repository.deleteExpense(academia.id));
      await app.settle();
      expect(sortButton(ExpenseCategory.fixed), findsNothing);

      await app.wait(
        app.memory.repository.addExpense(fixed('Academia', '900,00')),
      );
      await app.settle();
      expect(topToBottom(app.tester, ['Academia', 'Condomínio']), [
        'Condomínio',
        'Academia',
      ]);
      expect(
        sortIconColor(app.tester, ExpenseCategory.fixed),
        schemeOf(app.tester).primary,
      );
    },
    seed: seedTwoOfEach,
  );

  testApp('re-sorts right after an edit', (app) async {
    await pick(app, ExpenseCategory.fixed, 'Maior valor');

    await app.tap(find.text('Academia'));
    await app.enter(field('Valor'), '80000');
    await app.tap(textButton('Salvar'));

    expect(topToBottom(app.tester, ['Condomínio', 'Academia']), [
      'Academia',
      'Condomínio',
    ]);
  }, seed: seedTwoOfEach);

  testApp(
    'a closed month shares the order chosen in the open month',
    (
      app,
    ) async {
      await pick(app, ExpenseCategory.fixed, 'Maior valor');

      await app.tap(find.byTooltip('Histórico'));
      await app.tap(find.text('nov/2026'));

      expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
      final sort = find.byTooltip('Ordenar Gastos Fixos');
      expect(sort, findsOneWidget);
      expect(
        app.tester.getTopLeft(sort).dx,
        greaterThanOrEqualTo(
          app.tester.getTopRight(find.text('Gastos Fixos')).dx,
        ),
      );
      expect(
        app.tester.getTopRight(sort).dx,
        lessThan(app.tester.getTopLeft(find.text(r'R$ 870,00').first).dx),
      );
      expect(topToBottom(app.tester, ['Academia', 'Condomínio']), [
        'Condomínio',
        'Academia',
      ]);

      await pick(app, ExpenseCategory.fixed, 'Padrão (nome A-Z)');
      await app.pressBack();
      await app.pressBack();

      expect(topToBottom(app.tester, ['Condomínio', 'Academia']), [
        'Academia',
        'Condomínio',
      ]);
    },
    seed: seedClosedFixed,
  );

  group('expenseOrdersProvider', () {
    test('starts with no order chosen', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(expenseOrdersProvider), isEmpty);
    });

    test('replaces the order of one category and keeps the others', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(expenseOrdersProvider.notifier)
        ..choose(ExpenseOrder.fixedHighestAmount)
        ..choose(ExpenseOrder.variableByName)
        ..choose(ExpenseOrder.fixedLowestAmount);

      expect(container.read(expenseOrdersProvider), {
        ExpenseCategory.fixed: ExpenseOrder.fixedLowestAmount,
        ExpenseCategory.variable: ExpenseOrder.variableByName,
      });
    });
  });
}
