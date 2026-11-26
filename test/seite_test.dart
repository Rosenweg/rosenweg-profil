// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:rosenweg_profil/attrappe.dart';
import 'package:rosenweg_profil/main.dart';
import 'package:rosenweg_profil/seiten/profil_seite.dart';

Future<(Attrappe, RosenwegSitzung)> starten(WidgetTester t, {bool stationsKonto = true, Size groesse = const Size(420, 900)}) async {
  t.view.physicalSize = groesse * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final a = Attrappe(stationsKonto: stationsKonto);
  final s = RosenwegSitzung(profilApp, transport: a);
  await s.starten();
  await t.pumpWidget(RosenwegRahmen(sitzung: s, inhalt: (_) => ProfilSeite(sitzung: s)));
  await t.pumpAndSettle();
  return (a, s);
}

/// Die Liste der Abschnitte (nicht die Scrollables in Textfeldern).
final _liste = find.byType(Scrollable).first;

void main() {
  setUpAll(() => Protokoll.nurKonsole = true);

  testWidgets('Übersicht: Name, Rolle, Gruppen, Zähler, Objekte', (t) async {
    await starten(t);
    expect(find.text('Erika Muster'), findsOneWidget);
    expect(find.text('Bewohner'), findsOneWidget);
    expect(find.text('waschkueche'), findsOneWidget);
    await t.scrollUntilVisible(scrollable: _liste, find.text('STWEG 3 W 2.1'), 200);
    expect(find.text('Wohnung 2. OG links'), findsOneWidget);
    expect(find.text('Eigentümer'), findsOneWidget);
  });

  testWidgets('Angaben: Speichern schickt den geänderten Namen', (t) async {
    final (a, _) = await starten(t);
    await t.tap(find.text('Angaben'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Name'), 'Erika Beispiel');
    await t.ensureVisible(find.text('Speichern'));
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    final r = a.anfragen.lastWhere((r) => r.pfad == '/api/auth/profile');
    expect((r.koerper as Map)['name'], 'Erika Beispiel');
    expect(find.text('Profil erfolgreich gespeichert.'), findsOneWidget);
  });

  testWidgets('Angaben: Nummer hinzufügen erst mit „Nummern speichern“', (t) async {
    final (a, _) = await starten(t);
    await t.tap(find.text('Angaben'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(scrollable: _liste, find.text('Weitere Telefonnummern'), 200);
    expect(find.text('Nummern speichern'), findsNothing);
    await t.ensureVisible(find.text('Nummer').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Nummer').first); // Knopf im Titel, vor den Feldern
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Nummern speichern'));
    await t.pumpAndSettle();
    expect(find.text('Nummern speichern'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, 'Nummer').last, '+41 79 111 11 11');
    await t.tap(find.text('Nummern speichern'));
    await t.pumpAndSettle();
    final r = a.anfragen.lastWhere((r) => r.pfad == '/api/me/phones');
    expect(((r.koerper as Map)['telefone'] as List).length, 2);
  });

  testWidgets('Zugang: Passwort verlangt frische Anmeldung → Knopf „Jetzt neu anmelden“', (t) async {
    final (a, _) = await starten(t);
    a.erzwungen['POST /api/change-password'] =
        (status: 403, json: {'error': 'Bitte zur Bestätigung neu anmelden und das Passwort danach innert 15 Minuten ändern.', 'reauth': true});
    await t.tap(find.text('Zugang'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Neues Passwort'), 'einlangespasswort');
    await t.enterText(find.widgetWithText(TextField, 'Neues Passwort bestätigen'), 'einlangespasswort');
    await t.tap(find.widgetWithText(FilledButton, 'Passwort ändern'));
    await t.pumpAndSettle();
    expect(find.text('Jetzt neu anmelden'), findsOneWidget);
    expect(find.textContaining('innert 15 Minuten'), findsOneWidget);
  });

  testWidgets('Zugang: Passwörter ungleich → keine Anfrage', (t) async {
    final (a, _) = await starten(t);
    await t.tap(find.text('Zugang'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Neues Passwort'), 'einlangespasswort');
    await t.enterText(find.widgetWithText(TextField, 'Neues Passwort bestätigen'), 'anderespasswort');
    await t.tap(find.widgetWithText(FilledButton, 'Passwort ändern'));
    await t.pumpAndSettle();
    expect(find.text('Neue Passwörter stimmen nicht überein.'), findsOneWidget);
    expect(a.anfragen.where((r) => r.pfad == '/api/change-password'), isEmpty);
  });

  testWidgets('Zugang ohne Stationskonto: kein Desktop-Stil, kein SSH', (t) async {
    await starten(t, stationsKonto: false);
    await t.tap(find.text('Zugang'));
    await t.pumpAndSettle();
    expect(find.text('Desktop an den Stationen'), findsNothing);
    expect(find.text('SSH-Zugang'), findsNothing);
    expect(find.text('API-Tokens'), findsOneWidget);
  });

  testWidgets('Zugang: Desktop-Stil gilt sofort', (t) async {
    final (a, _) = await starten(t);
    await t.tap(find.text('Zugang'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(scrollable: _liste, find.text('Mac-Anordnung'), 200);
    await t.tap(find.text('Mac-Anordnung'));
    await t.pumpAndSettle();
    expect(a.anfragen.lastWhere((r) => r.methode == 'PUT').koerper, {
      'desktop': {'stil': 'mac'}
    });
    expect(find.text('Gilt ab der nächsten Anmeldung an einer Station.'), findsOneWidget);
  });

  testWidgets('Zugang: Token erstellen zeigt ihn einmal und setzt ihn in den Agent-Befehl', (t) async {
    await starten(t);
    await t.tap(find.text('Zugang'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(scrollable: _liste, find.text('Neuer Token'), 200);
    await t.tap(find.text('Neuer Token'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Name'), 'Mein Agent');
    await t.tap(find.text('Token erstellen'));
    await t.pumpAndSettle();
    expect(find.textContaining('nur einmal angezeigt'), findsOneWidget);
    expect(find.textContaining('Bearer rw_pat_cd34'), findsNWidgets(2));
    expect(find.text('Mein Agent'), findsOneWidget);
  });

  testWidgets('breiter Bildschirm (Station): Leiste links statt unten', (t) async {
    await starten(t, groesse: const Size(1200, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Server weg beim Start: Fehler mit Nochmals', (t) async {
    t.view.physicalSize = const Size(840, 1800);
    addTearDown(t.view.reset);
    final a = Attrappe()..erzwungen['GET /api/auth/me'] = (status: 500, json: {'error': 'Benutzerdaten konnten nicht geladen werden'});
    final s = RosenwegSitzung(profilApp, transport: a);
    await s.starten();
    await t.pumpWidget(RosenwegRahmen(sitzung: s, inhalt: (_) => ProfilSeite(sitzung: s)));
    await t.pumpAndSettle();
    expect(find.text('Benutzerdaten konnten nicht geladen werden'), findsOneWidget);
    await t.tap(find.text('Nochmals'));
    await t.pumpAndSettle();
    expect(find.text('Erika Muster'), findsOneWidget);
  });
}
