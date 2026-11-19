import 'package:offmoney/application/card_repository.dart';
import 'package:offmoney/application/rejections.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/card_rules.dart';
import 'package:offmoney/domain/names.dart';

final class SaveCard {
  const SaveCard(this._repository);

  final CardRepository _repository;

  Future<void> call({
    required String name,
    required String color,
    int? replacingId,
  }) async {
    final cleaned = Names.clean(name);
    final parsed = CardColor.tryParse(color);
    final errors = CardRules.errors(
      name: cleaned,
      color: parsed,
      cards: await _repository.cards(),
      editingId: replacingId,
    );
    if (errors.isNotEmpty || parsed == null) throw InvalidCardException(errors);
    if (replacingId == null) {
      await _repository.addCard(name: cleaned, color: parsed);
    } else {
      await _repository.updateCard(replacingId, name: cleaned, color: parsed);
    }
  }
}

final class ArchiveCard {
  const ArchiveCard(this._repository);

  final CardRepository _repository;

  Future<void> call(int id) => _repository.archiveCard(id);
}
