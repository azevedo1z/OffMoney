import 'package:flutter/material.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:offmoney/presentation/theme/app_theme.dart';
import 'package:offmoney/presentation/theme/metrics.dart';

class CardDot extends StatelessWidget {
  const CardDot({required this.color, this.size = defaultSize, super.key});

  static const defaultSize = 8.0;
  static const _opaque = 0xFF000000;

  final CardColor color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Color(_opaque | color.rgb),
      shape: BoxShape.circle,
      border: Border.all(
        color: Theme.of(context).colorScheme.outline,
        width: Metrics.hairline,
      ),
    ),
  );
}

class CardTag extends StatelessWidget {
  const CardTag({
    required this.label,
    this.color,
    this.selected = false,
    super.key,
  });

  CardTag.of(PaymentCard card, {bool selected = false, Key? key})
    : this(label: card.name, color: card.color, selected: selected, key: key);

  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 3);
  static const _dotGap = 5.0;
  static const _selectedBorderWidth = 1.5;

  final String label;
  final CardColor? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = this.color;
    return Semantics(
      selected: selected,
      child: Container(
        padding: _padding,
        decoration: ShapeDecoration(
          color: AppTheme.tagBackground(scheme),
          shape: StadiumBorder(
            side: selected
                ? BorderSide(color: scheme.primary, width: _selectedBorderWidth)
                : BorderSide(
                    color: scheme.outlineVariant,
                    width: Metrics.hairline,
                  ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              CardDot(color: color),
              const SizedBox(width: _dotGap),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
