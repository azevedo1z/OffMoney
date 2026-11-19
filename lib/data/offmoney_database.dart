import 'package:drift/drift.dart';
import 'package:offmoney/data/offmoney_database.steps.dart';

part 'offmoney_database.g.dart';

@DataClassName('MonthRow')
@TableIndex.sql(
  "CREATE UNIQUE INDEX one_open_month ON months (status) WHERE status = 'open'",
)
class Months extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get referenceYear => integer()();

  IntColumn get referenceMonth => integer()();

  TextColumn get status => text()();

  IntColumn get incomeCents => integer().nullable()();

  DateTimeColumn get openedAt => dateTime()();

  DateTimeColumn get closedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {referenceYear, referenceMonth},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (reference_month BETWEEN 1 AND 12)',
    "CHECK (status IN ('open', 'closed'))",
    "CHECK ((status = 'open') = (closed_at IS NULL))",
    "CHECK (status = 'open' OR income_cents IS NOT NULL)",
    'CHECK (income_cents BETWEEN 0 AND 99999999999)',
  ];
}

@DataClassName('CardRow')
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  IntColumn get colorRgb => integer()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(name) BETWEEN 1 AND 20)',
    'CHECK (color_rgb BETWEEN 0 AND 16777215)',
  ];
}

@DataClassName('ExpenseRow')
@TableIndex(name: 'expenses_by_month', columns: {#monthId, #category})
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get monthId => integer().references(Months, #id)();

  TextColumn get category => text()();

  TextColumn get name => text()();

  IntColumn get amountCents => integer()();

  IntColumn get currentInstallment => integer().nullable()();

  IntColumn get totalInstallments => integer().nullable()();

  TextColumn get spentOn => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  IntColumn get cardId => integer()
      .nullable()
      .references(Cards, #id)
      .check(
        const CustomExpression(
          "card_id IS NULL OR category = 'installment'",
        ),
      )();

  @override
  List<String> get customConstraints => const [
    "CHECK (category IN ('fixed', 'installment', 'variable'))",
    'CHECK (amount_cents BETWEEN 1 AND 99999999999)',
    "CHECK ((category = 'installment') = (current_installment IS NOT NULL))",
    "CHECK ((category = 'installment') = (total_installments IS NOT NULL))",
    'CHECK (total_installments >= 2)',
    'CHECK (current_installment BETWEEN 1 AND total_installments)',
    "CHECK (category = 'variable' OR spent_on IS NULL)",
  ];
}

@DataClassName('ChangeLogRow')
class ChangeLog extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get occurredAt => dateTime()();

  IntColumn get monthId => integer().nullable().references(Months, #id)();

  TextColumn get action => text()();

  IntColumn get entityId => integer().nullable()();

  TextColumn get beforeJson => text().nullable()();

  TextColumn get afterJson => text().nullable()();
}

@DriftDatabase(tables: [Months, Cards, Expenses, ChangeLog])
class OffMoneyDatabase extends _$OffMoneyDatabase {
  OffMoneyDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) =>
        transaction(() => _upgrade(migrator, from, to)),
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );

  static final OnUpgrade _upgrade = stepByStep(
    from1To2: (migrator, schema) async {
      await migrator.createTable(schema.cards);
      await migrator.addColumn(schema.expenses, schema.expenses.cardId);
    },
  );
}
