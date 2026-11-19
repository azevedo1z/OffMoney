import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/data/offmoney_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

const _october = '2026-10-01T12:00:00.000Z';
const _november = '2026-11-01T12:00:00.000Z';

const _monthsAtV1 = [
  v1.MonthsData(
    id: 1,
    referenceYear: 2026,
    referenceMonth: 10,
    status: 'closed',
    incomeCents: 500000,
    openedAt: _october,
    closedAt: _november,
  ),
  v1.MonthsData(
    id: 2,
    referenceYear: 2026,
    referenceMonth: 11,
    status: 'open',
    incomeCents: 480000,
    openedAt: _november,
  ),
];

const _expensesAtV1 = [
  v1.ExpensesData(
    id: 1,
    monthId: 1,
    category: 'installment',
    name: 'TV',
    amountCents: 12000,
    currentInstallment: 7,
    totalInstallments: 18,
    createdAt: _october,
    updatedAt: _october,
  ),
  v1.ExpensesData(
    id: 2,
    monthId: 2,
    category: 'fixed',
    name: 'Internet',
    amountCents: 11000,
    createdAt: _november,
    updatedAt: _november,
  ),
  v1.ExpensesData(
    id: 3,
    monthId: 2,
    category: 'installment',
    name: 'TV',
    amountCents: 12000,
    currentInstallment: 8,
    totalInstallments: 18,
    createdAt: _november,
    updatedAt: _november,
  ),
  v1.ExpensesData(
    id: 4,
    monthId: 2,
    category: 'variable',
    name: 'Pão',
    amountCents: 700,
    spentOn: '2026-11-07',
    createdAt: _november,
    updatedAt: _november,
  ),
];

const _changeLogAtV1 = [
  v1.ChangeLogData(
    id: 1,
    occurredAt: _november,
    monthId: 2,
    action: 'expenseCreated',
    entityId: 4,
    afterJson: '{"name":"Pão"}',
  ),
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('a version 1 database migrates to the schema of a new one', () async {
    final schema = await verifier.schemaAt(1);
    final database = OffMoneyDatabase(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 2);
  });

  test('the migration keeps every row and leaves installments without a '
      'card', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: OffMoneyDatabase.new,
      createItems: (batch, old) => batch
        ..insertAll(old.months, _monthsAtV1)
        ..insertAll(old.expenses, _expensesAtV1)
        ..insertAll(old.changeLog, _changeLogAtV1),
      validateItems: (migrated) async {
        expect(
          [
            for (final month in await migrated.select(migrated.months).get())
              month.toJson(),
          ],
          [for (final month in _monthsAtV1) month.toJson()],
        );
        expect(
          [
            for (final expense
                in await migrated.select(migrated.expenses).get())
              expense.toJson(),
          ],
          [
            for (final expense in _expensesAtV1)
              {...expense.toJson(), 'cardId': null},
          ],
        );
        expect(
          [
            for (final change
                in await migrated.select(migrated.changeLog).get())
              change.toJson(),
          ],
          [for (final change in _changeLogAtV1) change.toJson()],
        );
        expect(await migrated.select(migrated.cards).get(), isEmpty);
      },
    );
  });
}
