import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

Future<void> choose(AppHarness app, String menuItem) async {
  await app.tap(find.byIcon(Icons.more_horiz_rounded));
  await app.tap(find.text(menuItem));
}
