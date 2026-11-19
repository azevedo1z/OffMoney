import 'package:meta/meta.dart';
import 'package:offmoney/domain/card_color.dart';

@immutable
final class PaymentCard {
  const PaymentCard({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.archivedAt,
  });

  final int id;
  final String name;
  final CardColor color;
  final DateTime createdAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  @override
  bool operator ==(Object other) =>
      other is PaymentCard &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.createdAt == createdAt &&
      other.archivedAt == archivedAt;

  @override
  int get hashCode => Object.hash(id, name, color, createdAt, archivedAt);

  @override
  String toString() => 'PaymentCard(#$id, $name, $color)';
}
