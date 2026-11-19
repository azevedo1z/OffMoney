import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/card_color.dart';

void main() {
  group('CardColor.tryParse', () {
    test('reads six hex digits, with or without the hash, in any case', () {
      expect(CardColor.tryParse('8a05be'), CardColor(0x8A05BE));
      expect(CardColor.tryParse('#8A05BE'), CardColor(0x8A05BE));
      expect(CardColor.tryParse('#8a05be'), CardColor(0x8A05BE));
    });

    test('rejects the short form, alpha, other characters and nothing', () {
      expect(CardColor.tryParse('#FFF'), isNull);
      expect(CardColor.tryParse('#FF8A05BE'), isNull);
      expect(CardColor.tryParse('#GGGGGG'), isNull);
      expect(CardColor.tryParse(''), isNull);
      expect(CardColor.tryParse(' #8A05BE'), isNull);
      expect(CardColor.tryParse('#8A05BE\n'), isNull);
    });
  });

  group('CardColor', () {
    test('writes itself as an upper case hex with the hash', () {
      expect(CardColor(0x8A05BE).hex, '#8A05BE');
      expect(CardColor(0).hex, '#000000');
      expect(CardColor(CardColor.maxRgb).hex, '#FFFFFF');
    });

    test('accepts only a red, green and blue value', () {
      expect(() => CardColor(-1), throwsArgumentError);
      expect(() => CardColor(CardColor.maxRgb + 1), throwsArgumentError);
    });

    test('is a value', () {
      expect({CardColor(0x8A05BE), CardColor(0x8A05BE)}, hasLength(1));
      expect(CardColor(0x8A05BE), isNot(CardColor(0xFF7A00)));
      expect(CardColor(0x8A05BE).toString(), '#8A05BE');
    });
  });
}
