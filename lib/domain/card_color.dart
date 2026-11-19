import 'package:meta/meta.dart';

@immutable
final class CardColor {
  CardColor(this.rgb) {
    if (rgb < 0 || rgb > maxRgb) {
      throw ArgumentError('Invalid card color: $rgb');
    }
  }

  static const maxRgb = 0xFFFFFF;
  static const hexDigits = 6;
  static const _hexRadix = 16;
  static final _hexPattern = RegExp('^#?([0-9a-fA-F]{$hexDigits})\$');

  static CardColor? tryParse(String text) {
    final digits = _hexPattern.firstMatch(text)?.group(1);
    return digits == null
        ? null
        : CardColor(int.parse(digits, radix: _hexRadix));
  }

  final int rgb;

  String get hex =>
      '#${rgb.toRadixString(_hexRadix).padLeft(hexDigits, '0').toUpperCase()}';

  @override
  bool operator ==(Object other) => other is CardColor && other.rgb == rgb;

  @override
  int get hashCode => rgb.hashCode;

  @override
  String toString() => hex;
}
