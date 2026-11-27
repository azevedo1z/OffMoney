import 'package:flutter/material.dart';
import 'package:offmoney/domain/expense.dart';
import 'package:offmoney/domain/expense_entry.dart';
import 'package:offmoney/domain/expense_order.dart';
import 'package:offmoney/domain/expense_query.dart';
import 'package:offmoney/domain/month.dart';
import 'package:offmoney/domain/payment_card.dart';
import 'package:offmoney/presentation/l10n/generated/app_localizations.dart';
import 'package:offmoney/presentation/shared/month_view.dart';

class MonthScaffold extends StatefulWidget {
  const MonthScaffold({
    required this.month,
    required this.cards,
    required this.orders,
    required this.onOrder,
    required this.actions,
    this.onEditIncome,
    this.onAdd,
    this.onEdit,
    this.onClose,
    this.floatingActionButton,
    super.key,
  });

  final Month month;
  final Map<int, PaymentCard> cards;
  final Map<ExpenseCategory, ExpenseOrder> orders;
  final ValueChanged<ExpenseOrder> onOrder;
  final List<Widget> actions;
  final VoidCallback? onEditIncome;
  final ValueChanged<ExpenseCategory>? onAdd;
  final ValueChanged<ExpenseEntry>? onEdit;
  final VoidCallback? onClose;
  final Widget? floatingActionButton;

  @override
  State<MonthScaffold> createState() => _MonthScaffoldState();
}

class _MonthScaffoldState extends State<MonthScaffold> {
  bool _searching = false;
  ExpenseQuery _query = ExpenseQuery.none;

  @override
  Widget build(BuildContext context) {
    final filtering = _query.isActive;
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: _searching ? _searchBar(context) : _monthBar(context),
        body: MonthView(
          month: widget.month,
          cards: widget.cards,
          orders: widget.orders,
          onOrder: widget.onOrder,
          onEditIncome: widget.onEditIncome,
          onAdd: filtering ? null : widget.onAdd,
          onEdit: widget.onEdit,
          onClose: filtering ? null : widget.onClose,
          query: _query,
        ),
        floatingActionButton: filtering ? null : widget.floatingActionButton,
        bottomNavigationBar: filtering
            ? null
            : AuditBar(summary: widget.month.summary),
      ),
    );
  }

  AppBar _monthBar(BuildContext context) => AppBar(
    actions: [
      IconButton(
        tooltip: AppLocalizations.of(context).search,
        onPressed: () => setState(() => _searching = true),
        icon: const Icon(Icons.search_rounded),
      ),
      ...widget.actions,
    ],
  );

  AppBar _searchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        tooltip: l10n.closeSearch,
        onPressed: _close,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: TextField(
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.searchHint,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (text) => setState(() => _query = ExpenseQuery(text)),
      ),
      actions: [
        IconButton(
          tooltip: l10n.closeSearch,
          onPressed: _close,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  void _close() => setState(() {
    _searching = false;
    _query = ExpenseQuery.none;
  });
}
