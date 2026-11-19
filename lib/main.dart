import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:offmoney/application/clock.dart';
import 'package:offmoney/data/drift_card_repository.dart';
import 'package:offmoney/data/drift_month_repository.dart';
import 'package:offmoney/data/offmoney_database.dart';
import 'package:offmoney/presentation/startup.dart';
import 'package:offmoney/presentation/theme/font_licenses.dart';
import 'package:offmoney/presentation/theme/theme_preference.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  runApp(
    await startApp(
      openRepositories: () {
        final database = OffMoneyDatabase(driftDatabase(name: 'gemify'));
        return (
          months: DriftMonthRepository(database, clock: systemClock),
          cards: DriftCardRepository(database, clock: systemClock),
        );
      },
      openThemeModeStore: PreferencesThemeModeStore.open,
      clock: systemClock,
    ),
  );
}
