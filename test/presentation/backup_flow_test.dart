import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offmoney/domain/card_color.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/app_finders.dart';
import '../support/app_harness.dart';
import '../support/app_menu.dart';
import '../support/app_seeds.dart';
import '../support/backup_fixture.dart';

const importConfirmation = 'Arquivo com 2 meses, mês aberto nov/2026.';

void main() {
  group('export', () {
    testApp('saves the data to the chosen file', (app) async {
      await choose(app, 'Exportar backup');

      expect(find.text('Backup salvo'), findsOneWidget);
      final saved = jsonDecode(app.files.saved.single) as Map<String, Object?>;
      expect(saved['format'], 'gemify-backup');
    }, seed: seedRent);

    testApp('canceling the file choice says nothing', (app) async {
      app.files.cancelSave = true;

      await choose(app, 'Exportar backup');

      expect(find.byType(SnackBar), findsNothing);
    });

    testApp('a write failure says so', (app) async {
      app.files.saveFailure = const FileSystemException('disk full');

      await choose(app, 'Exportar backup');

      expect(app.tester.takeException(), isA<FileSystemException>());
      expect(find.text('Erro ao salvar o backup'), findsOneWidget);
    });
  });

  group('import', () {
    testApp('canceling the file choice changes nothing', (app) async {
      await choose(app, 'Importar backup');

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Condomínio'), findsOneWidget);
    }, seed: seedRent);

    testApp('an unreadable file says so', (app) async {
      app.files.openFailure = const FileSystemException('denied');

      await choose(app, 'Importar backup');

      expect(app.tester.takeException(), isA<FileSystemException>());
      expect(find.text('Não foi possível ler o arquivo.'), findsOneWidget);
    });

    testApp('an invalid file is rejected without changes', (app) async {
      app.files.fileToOpen = '{"format": "other"}';

      await choose(app, 'Importar backup');

      expect(
        find.text('Arquivo inválido: não é um backup do OffMoney'),
        findsOneWidget,
      );
      expect(find.text('Condomínio'), findsOneWidget);
    }, seed: seedRent);

    testApp('a valid file replaces the data only when confirmed', (app) async {
      app.files.fileToOpen = jsonEncode(validBackup());

      await choose(app, 'Importar backup');
      expect(find.text(importConfirmation), findsOneWidget);
      await app.tap(find.text('Cancelar'));
      expect(find.text('Condomínio'), findsOneWidget);

      await choose(app, 'Importar backup');
      await app.tap(find.text('Substituir'));

      expect(find.text('Backup importado'), findsOneWidget);
      expect(find.text('Condomínio'), findsNothing);
      expect(find.text('TV'), findsOneWidget);
    }, seed: seedRent);

    testApp(
      'a file with cards brings them to the rows and to the cards '
      'screen',
      (app) async {
        app.files.fileToOpen = jsonEncode(validBackupWithCards());

        await choose(app, 'Importar backup');
        await app.tap(find.text('Substituir'));

        final tv = find.descendant(
          of: find.widgetWithText(ListTile, 'TV'),
          matching: cardTag('Roxo'),
        );
        expect(tv, findsOneWidget);
        await choose(app, 'Gerenciar cartões');
        expect(cardTag('Roxo'), findsOneWidget);
        expect(cardTag('Laranja'), findsNothing);
        expect(cardTag('Verde'), findsNothing);
      },
      seed: (memory) async {
        await seedRent(memory);
        await memory.cards.addCard(name: 'Verde', color: CardColor(0x00A868));
      },
    );

    testApp('a file with an invalid card is rejected without changes', (
      app,
    ) async {
      final backup = validBackupWithCards();
      ((backup['cards']! as List<Object?>).first!
              as Map<String, Object?>)['color'] =
          '#FFF';
      app.files.fileToOpen = jsonEncode(backup);

      await choose(app, 'Importar backup');

      expect(
        find.text('Arquivo inválido: cartões inválidos'),
        findsOneWidget,
      );
      expect(find.text('Condomínio'), findsOneWidget);
    }, seed: seedRent);

    testApp(
      'a failed import says so and keeps the data',
      (app) async {
        app.files.fileToOpen = jsonEncode(validBackup());

        await choose(app, 'Importar backup');
        await app.tap(find.text('Substituir'));

        expect(app.tester.takeException(), isA<SqliteException>());
        expect(
          find.text('Erro ao importar. Nada foi alterado.'),
          findsOneWidget,
        );
        expect(find.text('Condomínio'), findsOneWidget);
      },
      seed: failingOn('change_log', seedRent),
    );
  });
}
