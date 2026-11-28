import 'package:flutter/material.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_entry.dart';
import 'package:offmoney/domain/expense_order.dart';
import 'package:offmoney/domain/expense_ordering.dart';
import 'package:offmoney/domain/expense_query.dart';
import 'package:offmoney/domain/money.dart';
import 'package:offmoney/domain/month.dart';
import 'package:offmoney/domain/month_summary.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:offmoney/presentation/l10n/generated/app_localizations.dart';
import 'package:offmoney/presentation/shared/action_row.dart';
import 'package:offmoney/presentation/shared/card_tag.dart';
import 'package:offmoney/presentation/shared/formatters.dart';
import 'package:offmoney/presentation/shared/grouped_section.dart';
import 'package:offmoney/presentation/shared/labels.dart';
import 'package:offmoney/presentation/shared/large_title.dart';
import 'package:offmoney/presentation/theme/metrics.dart';

class MonthView extends StatelessWidget {
  const MonthView({
    required this.month,
    required this.cards,
    required this.orders,
    required this.onOrder,
    this.onEditIncome,
    this.onAdd,
    this.onEdit,
    this.onClose,
    this.query = ExpenseQuery.none,
    super.key,
  });

  static const _minimumSortableRows = 2;

  final Month month;
  final Map<int, PaymentCard> cards;
  final Map<ExpenseCategory, ExpenseOrder> orders;
  final ValueChanged<ExpenseOrder> onOrder;
  final VoidCallback? onEditIncome;
  final ValueChanged<ExpenseCategory>? onAdd;
  final ValueChanged<ExpenseEntry>? onEdit;
  final VoidCallback? onClose;
  final ExpenseQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final summary = month.summary;
    final filtering = query.isActive;
    final sorted = ExpenseOrdering.sortedBy(
      filtering ? query.filter(month.entries) : month.entries,
      orders: orders,
      cards: cards,
    );
    final matched = filtering
        ? MonthSummary.of(
            income: null,
            expenses: [for (final entry in sorted) entry.expense],
          )
        : null;
    final onClose = this.onClose;
    final totalStyle = theme.textTheme.titleMedium;
    return ListView(
      padding: const EdgeInsets.only(
        bottom: Metrics.floatingButtonClearance,
      ),
      children: [
        LargeTitle(text: formatReference(month.reference, l10n)),
        if (matched == null)
          GroupedSection(
            children: [_IncomeTile(income: month.income, onTap: onEditIncome)],
          )
        else
          _MatchLine(
            text: sorted.isEmpty
                ? l10n.noMatches
                : l10n.countAndTotal(
                    l10n.resultCount(sorted.length),
                    formatMoney(matched.totalExpenses),
                  ),
          ),
        for (final category in ExpenseCategory.values)
          if (_rowsOf(sorted, category) case final rows
              when !filtering || rows.isNotEmpty)
            _sectionOf(category, rows, summary, matched, l10n),
        if (!filtering)
          GroupedSection(
            children: [
              ListTile(
                title: Text(l10n.totalExpenses, style: totalStyle),
                trailing: Text(
                  formatMoney(summary.totalExpenses),
                  style: totalStyle,
                ),
              ),
            ],
          ),
        if (onClose != null)
          GroupedSection(
            children: [ActionRow(label: l10n.closeMonth, onTap: onClose)],
          ),
      ],
    );
  }

  Widget _sectionOf(
    ExpenseCategory category,
    List<Widget> rows,
    MonthSummary summary,
    MonthSummary? matched,
    AppLocalizations l10n,
  ) {
    final onAdd = this.onAdd;
    return GroupedSection(
      header: _SectionHeader(
        title: categoryTitle(category, l10n),
        subtotal: summary.totalOf(category),
        matched: matched?.totalOf(category),
        order: ExpenseOrder.chosenIn(orders, category),
        onAdd: onAdd == null ? null : () => onAdd(category),
        onOrder: rows.length < _minimumSortableRows ? null : onOrder,
      ),
      children: rows,
    );
  }

  List<Widget> _rowsOf(List<ExpenseEntry> sorted, ExpenseCategory category) {
    final onEdit = this.onEdit;
    return [
      for (final entry in sorted)
        if (entry.expense.category == category)
          ExpenseTile(
            expense: entry.expense,
            card: cardOf(entry.expense, cards),
            onTap: onEdit == null ? null : () => onEdit(entry),
          ),
    ];
  }
}

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    required this.expense,
    this.card,
    this.onTap,
    super.key,
  });

  static const _tagGap = 6.0;

  final Expense expense;
  final PaymentCard? card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = switch (expense) {
      FixedExpense() => null,
      final InstallmentExpense installment =>
        installment.isLast
            ? l10n.installmentCounterFinal(
                installmentCounter(installment),
                l10n.finalInstallment,
              )
            : installmentCounter(installment),
      VariableExpense(:final spentOn) =>
        spentOn == null ? null : formatDate(spentOn),
    };
    return ListTile(
      title: Text(expense.name),
      subtitle: details == null ? null : _subtitle(details),
      trailing: Text(formatMoney(expense.amount)),
      onTap: onTap,
    );
  }

  Widget _subtitle(String details) {
    final card = this.card;
    if (card == null) return Text(details);
    return Row(
      children: [
        Text(details),
        const SizedBox(width: _tagGap),
        Flexible(child: CardTag.of(card)),
      ],
    );
  }
}

class AuditBar extends StatelessWidget {
  const AuditBar({required this.summary, super.key});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final balance = summary.balance;
    final negative = balance != null && balance.isNegative;
    final labelColor = negative ? scheme.error : scheme.onSurfaceVariant;
    return Material(
      color: theme.bottomAppBarTheme.color,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(Metrics.inset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (negative) ...[
                        Icon(
                          Icons.warning_amber_rounded,
                          color: scheme.error,
                          semanticLabel: l10n.negativeBalance,
                        ),
                        const SizedBox(width: Metrics.headerGap),
                      ],
                      Expanded(
                        child: Text(
                          l10n.balanceTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: labelColor,
                          ),
                        ),
                      ),
                      if (balance == null)
                        Text(
                          l10n.incomePending,
                          key: const Key('balance'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Text(
                          formatMoney(balance),
                          key: const Key('balance'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: negative ? scheme.error : scheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                  if (balance != null)
                    Text(
                      formatAuditLine(summary),
                      key: const Key('auditLine'),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeTile extends StatelessWidget {
  const _IncomeTile({required this.income, required this.onTap});

  final Money? income;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final income = this.income;
    return ListTile(
      title: Text(l10n.incomeTitle),
      trailing: income == null ? null : Text(formatMoney(income)),
      onTap: onTap,
    );
  }
}

class _MatchLine extends StatelessWidget {
  const _MatchLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Metrics.inset * 2,
        0,
        Metrics.inset * 2,
        Metrics.sectionGap,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtotal,
    required this.matched,
    required this.order,
    required this.onAdd,
    required this.onOrder,
  });

  final String title;
  final Money subtotal;
  final Money? matched;
  final ExpenseOrder order;
  final VoidCallback? onAdd;
  final ValueChanged<ExpenseOrder>? onOrder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final onAdd = this.onAdd;
    final onOrder = this.onOrder;
    final matched = this.matched;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              if (onAdd != null)
                IconButton(
                  tooltip: l10n.addTo(title),
                  onPressed: onAdd,
                  visualDensity: VisualDensity.compact,
                  color: scheme.primary,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              if (onOrder != null)
                PopupMenuButton<ExpenseOrder>(
                  key: Key('sort-${order.category.name}'),
                  tooltip: l10n.sortSection(title),
                  initialValue: order,
                  onSelected: onOrder,
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  iconColor: order.isDefault
                      ? scheme.onSurfaceVariant
                      : scheme.primary,
                  icon: const Icon(Icons.swap_vert_rounded),
                  itemBuilder: (context) => [
                    for (final option in ExpenseOrder.of(order.category))
                      CheckedPopupMenuItem(
                        value: option,
                        checked: option == order,
                        child: Text(orderLabel(option, l10n)),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Text(
          matched == null
              ? formatMoney(subtotal)
              : l10n.partOfTotal(formatMoney(matched), formatMoney(subtotal)),
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
