// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:rosenweg_profil/attrappe.dart';
import 'package:rosenweg_profil/bild.dart';
import 'package:rosenweg_profil/daten.dart';

void main() {
  setUpAll(() => Protokoll.nurKonsole = true);
  late Attrappe a;
  late ProfilDienst d;
  setUp(() {
    a = Attrappe();
    d = ProfilDienst(RosenwegApi(a));
  });

  test('ich: Felder aus /api/auth/me', () async {
    final u = await d.ich();
    expect(u.name, 'Erika Muster');
    expect(u.initialen, 'EM');
    expect(u.rollenText, 'Bewohner');
    expect(u.stationsKonto, isTrue);
    expect(u.gruppen, contains('waschkueche'));
    expect(a.anfragen.single.pfad, '/api/auth/me');
  });

  test('Profil speichern schickt dieselben Felder wie profil.html', () async {
    await d.profilSpeichern(ProfilAngaben(
        name: ' Erika M. ', telefon: '+41 79', stweg: '', wohnung: 'EG', strasse: 'Weg 1', plz: '4303', ort: 'Kaiseraugst'));
    final r = a.anfragen.last;
    expect(r.methode, 'PUT');
    expect(r.pfad, '/api/auth/profile');
    expect(r.koerper, {
      'name': 'Erika M.',
      'phone': '+41 79',
      'stweg': null, // leer = keine STWEG, wie im Portal
      'wohnung': 'EG',
      'strasse': 'Weg 1',
      'plz': '4303',
      'ort': 'Kaiseraugst',
    });
  });

  test('Zusatznummern: leere Zeilen fallen weg, Label nur wenn gesetzt', () async {
    await d.telefoneSpeichern([Telefon(nummer: '+41 61 1', label: ' '), Telefon(nummer: '  '), Telefon(typ: 'geschaeft', nummer: '+41 44', whatsapp: true, label: 'Büro')]);
    expect(a.anfragen.last.koerper, {
      'telefone': [
        {'typ': 'mobile2', 'nummer': '+41 61 1', 'whatsapp': false},
        {'typ': 'geschaeft', 'label': 'Büro', 'nummer': '+41 44', 'whatsapp': true},
      ]
    });
  });

  test('E-Mail-Aliasse: klein, ohne Leere', () async {
    await d.emailsSpeichern([' Erika@Example.NET ', '']);
    expect(a.anfragen.last.koerper, {
      'emails': ['erika@example.net']
    });
  });

  test('Desktop-Stil: "wie die Station" schickt null', () async {
    expect(await d.desktopStil(), '');
    expect(await d.desktopStilSetzen('mac'), contains('nächsten Anmeldung'));
    expect(await d.desktopStil(), 'mac');
    await d.desktopStilSetzen('');
    expect(a.anfragen.last.koerper, {
      'desktop': {'stil': null}
    });
  });

  test('Token: ohne Scopes = alle Rechte (Feld fehlt), Klartext einmal', () async {
    final t = await d.tokenErstellen(name: 'Test', tage: 30);
    expect(t, startsWith('rw_pat_'));
    expect(a.anfragen.last.koerper, {'name': 'Test', 'expires_days': 30});
    await d.tokenErstellen(name: 'Eng', scopes: ['me:read']);
    expect((a.anfragen.last.koerper as Map)['scopes'], ['me:read']);
    final l = await d.tokens();
    expect(l.first.name, 'Eng');
    await d.tokenWiderrufen(l.first.id, '  ');
    expect(a.anfragen.last.koerper, {'reason': null});
    expect((await d.tokens()).first.aktiv, isFalse);
  });

  test('Passwort: 403 reauth wird als KeineBerechtigung.neuAnmelden gemeldet', () async {
    a.erzwungen['POST /api/change-password'] =
        (status: 403, json: {'error': 'Bitte zur Bestätigung neu anmelden.', 'reauth': true});
    await expectLater(d.passwortAendern('sehrgeheim'),
        throwsA(isA<KeineBerechtigung>().having((e) => e.neuAnmelden, 'neuAnmelden', isTrue)));
  });

  test('WhatsApp: Fehler mit Hinweis', () async {
    a.erzwungen['PUT /api/me/whatsapp-optin'] =
        (status: 400, json: {'error': 'Keine Telefonnummer hinterlegt', 'hint': 'Bitte Nummer eintragen.'});
    await expectLater(
        d.whatsappSetzen(true), throwsA(isA<ApiFehler>().having((e) => e.feld('hint'), 'hint', 'Bitte Nummer eintragen.')));
  });

  test('Zaehler 502 vom Energy-Collector: ApiFehler, kein Absturz', () async {
    a.erzwungen['GET /api/energie/meine-zaehler'] = (status: 502, json: {'error': 'Energy-Collector nicht erreichbar'});
    await expectLater(d.zaehler(), throwsA(isA<ApiFehler>()));
  });

  test('Avatar: JPEG als data-URL', () async {
    await d.avatarSetzen(Uint8List.fromList([0xff, 0xd8, 0xff]));
    expect((a.anfragen.last.koerper as Map)['avatar'], 'data:image/jpeg;base64,/9j/');
  });

  test('Profilbild: Mitte quadratisch, 200 px, JPEG', () {
    final quer = img.Image(width: 640, height: 320);
    img.fill(quer, color: img.ColorRgb8(200, 30, 30));
    final j = profilBild(Uint8List.fromList(img.encodePng(quer)))!;
    expect(j.sublist(0, 2), [0xff, 0xd8]);
    final b = img.decodeJpg(j)!;
    expect((b.width, b.height), (200, 200));
    expect(j.length, lessThan(512 * 1024));
    expect(profilBild(Uint8List.fromList(utf8.encode('kein Bild'))), isNull);
  });

  test('avatarBild: data-URL und Adresse, sonst nichts', () {
    expect(avatarBild('data:image/png;base64,iVBORw0KGgo='), isNotNull);
    expect(avatarBild('https://example.org/a.png'), isNotNull);
    expect(avatarBild('javascript:alert(1)'), isNull);
    expect(avatarBild(null), isNull);
  });
}
