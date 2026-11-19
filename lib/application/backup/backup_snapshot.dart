import 'package:offmoney/application/change_log_entry.dart';
import 'package:offmoney/domain/month.dart';
import 'package:offmoney/domain/payment_card.dart';

final class BackupSnapshot {
  const BackupSnapshot({
    required this.cards,
    required this.months,
    required this.changeLog,
  });

  final List<PaymentCard> cards;
  final List<Month> months;
  final List<ChangeLogEntry> changeLog;
}
