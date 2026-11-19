import 'package:flutter/material.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/presentation/shared/card_tag.dart';
import 'package:offmoney/presentation/theme/metrics.dart';

class CardSwatches extends StatelessWidget {
  const CardSwatches({required this.selected, required this.onPick, super.key});

  static final List<CardColor> presets = List.unmodifiable([
    CardColor(0x8A05BE),
    CardColor(0xE91E63),
    CardColor(0xEC0000),
    CardColor(0xFF7A00),
    CardColor(0xFFD600),
    CardColor(0x00A868),
    CardColor(0x00B8D9),
    CardColor(0x1A4FD6),
    CardColor(0x003399),
    CardColor(0x795548),
    CardColor(0x9E9E9E),
    CardColor(0x111111),
  ]);

  static const _dotSize = 28.0;
  static const _ringGap = 3.0;
  static const _ringWidth = 2.0;
  static const _spacing = 6.0;

  final CardColor? selected;
  final ValueChanged<CardColor> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Metrics.inset - _ringGap - _ringWidth,
        vertical: Metrics.headerGap,
      ),
      child: Wrap(
        spacing: _spacing,
        runSpacing: _spacing,
        children: [
          for (final color in presets)
            Tooltip(
              message: color.hex,
              child: InkResponse(
                onTap: () => onPick(color),
                child: Container(
                  padding: const EdgeInsets.all(_ringGap),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == selected
                          ? scheme.primary
                          : Colors.transparent,
                      width: _ringWidth,
                    ),
                  ),
                  child: CardDot(color: color, size: _dotSize),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
