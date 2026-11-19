import 'package:drift/drift.dart';
import 'package:offmoney/application/change_log_entry.dart';
import 'package:offmoney/application/clock.dart';
import 'package:offmoney/data/offmoney_database.dart';

final class ChangeLogWriter {
  const ChangeLogWriter(this._db, this._clock);

  final OffMoneyDatabase _db;
  final Clock _clock;

  Future<void> call(
    ChangeAction action, {
    required int? monthId,
    required int? entityId,
    String? before,
    String? after,
  }) => _db
      .into(_db.changeLog)
      .insert(
        ChangeLogCompanion.insert(
          occurredAt: _clock(),
          monthId: Value(monthId),
          action: action.name,
          entityId: Value(entityId),
          beforeJson: Value(before),
          afterJson: Value(after),
        ),
      );
}
