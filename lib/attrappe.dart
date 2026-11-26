// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Antwortet wie die Haupt-API, mit erfundenen Daten (keine echten Personen).
/// Fuer Tests, Bildschirmfotos und Entwicklung ohne Server
/// (--dart-define=RW_ATTRAPPE=1). Merkt sich Aenderungen im Speicher.
class Attrappe implements Transport {
  Attrappe({this.stationsKonto = true});
  final bool stationsKonto;

  /// Alle Anfragen in der Reihenfolge (fuer Tests).
  final anfragen = <({String methode, String pfad, Object? koerper})>[];

  /// Naechste Antwort fuer einen Pfad erzwingen (Tests), z. B. Fehler.
  final erzwungen = <String, ApiAntwort>{};

  late final Map<String, dynamic> _ich = {
    'id': 7,
    'username': stationsKonto ? 'erika.muster' : null,
    'name': 'Erika Muster',
    'email': 'erika.muster@example.org',
    'role': 'user',
    'wohnung': '2. OG links',
    'stweg': '3',
    'phone': '+41 79 000 00 00',
    'strasse': 'Musterweg 1',
    'plz': '4303',
    'ort': 'Kaiseraugst',
    'avatar_url': null,
    'isAdmin': false,
    'groups': ['stweg3-eigentuemer', 'waschkueche'],
    'whatsapp_opt_in': false,
  };
  final _telefone = <Map<String, dynamic>>[
    {'typ': 'festnetz2', 'label': 'Zuhause', 'nummer': '+41 61 000 00 00', 'whatsapp': false},
  ];
  final _emails = <String>['erika@example.net'];
  String _stil = '';
  final _tokens = <Map<String, dynamic>>[
    {
      'id': 1,
      'name': 'Skript Zählerstände',
      'token_prefix': 'rw_pat_ab12',
      'scopes': ['me:read', 'energy:read'],
      'created_at': '2026-10-02T08:15:00Z',
      'last_used_at': '2026-11-25T19:40:00Z',
      'last_used_ip': '192.0.2.10',
      'expires_at': null,
      'revoked_at': null,
    },
  ];
  final _ssh = <Map<String, dynamic>>[
    {
      'id': 3,
      'quelle': 'hand',
      'label': 'Laptop',
      'typ': 'ssh-ed25519',
      'fingerprint': 'SHA256:AbCdEfGhIjKlMnOpQrStUvWxYz0123456789abcd',
      'zuletzt_gesehen': '2026-11-20T10:00:00Z',
    },
  ];

  @override
  Future<ApiAntwort> senden(String methode, String pfad, {Object? koerper}) async {
    anfragen.add((methode: methode, pfad: pfad, koerper: koerper));
    final z = erzwungen.remove('$methode $pfad');
    if (z != null) return z;
    final k = koerper is Map ? koerper : const {};
    switch ('$methode $pfad') {
      case 'GET /api/auth/me':
        return _ok({'user': _ich});
      case 'GET /api/energie/meine-zaehler':
        return _ok([
          {'id': 'w2l', 'name': 'Wohnung 2. OG links', 'type': 'modbus', 'role': 'bezug'},
        ]);
      case 'GET /api/me/wohnungen':
        return _ok({
          'wohnungen': [
            {
              'kontakt_id': 11,
              'wohnung_id': 21,
              'stweg': 3,
              'bezeichnung': 'W 2.1',
              'rolle': 'eigentuemer',
              'typ': 'Wohnung',
              'stockwerk': '2. Obergeschoss',
              'zimmer': '4.5',
              'flaeche_m2': 104,
              'email': 'erika.muster@example.org',
              'telefon': '+41 79 000 00 00',
            },
          ]
        });
      case 'GET /api/me/person-data':
        return _ok({
          'found': true,
          'person_email': 'erika.muster@example.org',
          'primary_phone': '+41 79 000 00 00',
          'telefone': _telefone,
          'emails': _emails,
          'whatsapp_opt_in': _ich['whatsapp_opt_in'],
        });
      case 'PUT /api/auth/profile':
        _ich.addAll({
          'name': k['name'],
          'phone': k['phone'],
          'stweg': k['stweg'],
          'wohnung': k['wohnung'],
          'strasse': k['strasse'],
          'plz': k['plz'],
          'ort': k['ort'],
        });
        return _ok({'user': _ich});
      case 'PUT /api/auth/avatar':
        _ich['avatar_url'] = k['avatar'];
        return _ok({'ok': true});
      case 'PUT /api/me/phones':
        _telefone
          ..clear()
          ..addAll(((k['telefone'] as List?) ?? const []).cast<Map<String, dynamic>>());
        return _ok({'ok': true, 'telefone': _telefone});
      case 'PUT /api/me/emails':
        _emails
          ..clear()
          ..addAll(((k['emails'] as List?) ?? const []).map((e) => '$e'));
        return _ok({'ok': true, 'emails': _emails});
      case 'PUT /api/me/whatsapp-optin':
        _ich['whatsapp_opt_in'] = k['enabled'] == true;
        return _ok({'ok': true, 'enabled': k['enabled'], 'phone': '+41 79 000 00 00'});
      case 'GET /api/me/einstellungen':
        return _ok({'desktop': _stil.isEmpty ? {} : {'stil': _stil}});
      case 'PUT /api/me/einstellungen':
        _stil = ((k['desktop'] as Map?)?['stil'] as String?) ?? '';
        return _ok({
          'desktop': _stil.isEmpty ? {} : {'stil': _stil},
          'hinweis': 'Gilt ab der nächsten Anmeldung an einer Station.'
        });
      case 'POST /api/change-password':
        if ('${k['new_password']}'.length < 8) return (status: 400, json: {'error': 'Neues Passwort muss mindestens 8 Zeichen haben'});
        return _ok({'status': 'ok', 'message': 'Passwort wurde geändert'});
      case 'GET /api/me/tokens':
        return _ok({'tokens': _tokens});
      case 'POST /api/me/tokens':
        final id = _tokens.length + 1;
        _tokens.insert(0, {
          'id': id,
          'name': k['name'],
          'token_prefix': 'rw_pat_cd34',
          'scopes': k['scopes'],
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'expires_at': k['expires_days'] == null
              ? null
              : DateTime.now().add(Duration(days: k['expires_days'] as int)).toUtc().toIso8601String(),
        });
        return _ok({'id': id, 'token': 'rw_pat_cd34${'0' * 52}', 'hint': 'nur einmal'});
      case 'GET /api/ssh/me':
        return _ok({
          'schluessel': _ssh,
          'github_benutzer': null,
          'hosts': [
            {'hostname': 'werkstatt-pc', 'sudo': false},
          ],
        });
      case 'POST /api/ssh/me/schluessel':
        _ssh.add({
          'id': _ssh.length + 10,
          'quelle': 'hand',
          'label': k['label'],
          'typ': '${k['pubkey']}'.split(' ').first,
          'fingerprint': 'SHA256:neu',
        });
        return _ok({'id': 1});
    }
    if (methode == 'DELETE' && pfad.startsWith('/api/me/tokens/')) {
      final id = int.parse(pfad.split('/').last);
      final t = _tokens.firstWhere((t) => t['id'] == id);
      t['revoked_at'] = DateTime.now().toUtc().toIso8601String();
      t['revoked_reason'] = k['reason'] ?? 'manuell widerrufen';
      return _ok({'ok': true});
    }
    if (methode == 'DELETE' && pfad.startsWith('/api/ssh/me/schluessel/')) {
      _ssh.removeWhere((s) => '${s['id']}' == pfad.split('/').last);
      return _ok({'ok': true, 'wiederkehrend': false});
    }
    return (status: 404, json: {'error': 'Nicht gefunden: $methode $pfad'});
  }

  static ApiAntwort _ok(Object j) => (status: 200, json: j);
}
