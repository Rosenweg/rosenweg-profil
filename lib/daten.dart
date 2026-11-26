// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Alles, was die Profil-Seite des Portals (profil.html) mit der API spricht,
/// an einer Stelle. Die Oberflaeche kennt nur diese Klasse, nicht die Pfade.
class ProfilDienst {
  ProfilDienst(this.api);
  final RosenwegApi api;

  // ── Kopf, Gruppen ────────────────────────────────────────────────────────

  Future<Benutzer> ich() async {
    final j = await api.objekt('/api/auth/me');
    return Benutzer.aus((j['user'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  // ── Zaehler, Objekte ─────────────────────────────────────────────────────

  Future<List<Zaehler>> zaehler() async =>
      (await api.liste('/api/energie/meine-zaehler')).whereType<Map>().map((m) => Zaehler.aus(m.cast())).toList();

  Future<List<Objekt>> objekte() async {
    final j = await api.objekt('/api/me/wohnungen');
    return ((j['wohnungen'] as List?) ?? const []).whereType<Map>().map((m) => Objekt.aus(m.cast())).toList();
  }

  // ── Persoenliche Daten ───────────────────────────────────────────────────

  Future<void> profilSpeichern(ProfilAngaben a) => api.put('/api/auth/profile', a.json());

  /// Bild ist schon quadratisch verkleinert (bild.dart), JPEG.
  Future<void> avatarSetzen(Uint8List jpeg) =>
      api.put('/api/auth/avatar', {'avatar': 'data:image/jpeg;base64,${base64Encode(jpeg)}'});

  Future<PersonDaten> personDaten() async => PersonDaten.aus(await api.objekt('/api/me/person-data'));

  Future<void> telefoneSpeichern(List<Telefon> t) =>
      api.put('/api/me/phones', {'telefone': t.where((x) => x.nummer.trim().isNotEmpty).map((x) => x.json()).toList()});

  Future<void> emailsSpeichern(List<String> e) =>
      api.put('/api/me/emails', {'emails': e.map((x) => x.trim().toLowerCase()).where((x) => x.isNotEmpty).toList()});

  /// Liefert die Nummer, an die WhatsApp-Nachrichten gehen (null beim Abschalten).
  Future<String?> whatsappSetzen(bool an) async {
    final j = await api.put('/api/me/whatsapp-optin', {'enabled': an});
    return j is Map ? j['phone'] as String? : null;
  }

  // ── Desktop an den Stationen ─────────────────────────────────────────────

  /// '' = wie die Station, 'windows', 'mac'.
  Future<String> desktopStil() async {
    final j = await api.objekt('/api/me/einstellungen');
    return ((j['desktop'] as Map?)?['stil'] as String?) ?? '';
  }

  /// Liefert den Hinweis des Servers ("Gilt ab der naechsten Anmeldung …").
  Future<String> desktopStilSetzen(String stil) async {
    final j = await api.put('/api/me/einstellungen', {
      'desktop': {'stil': stil.isEmpty ? null : stil}
    });
    return (j is Map ? j['hinweis'] as String? : null) ?? 'Gespeichert.';
  }

  // ── Passwort ─────────────────────────────────────────────────────────────

  /// Wirft [KeineBerechtigung] mit `neuAnmelden`, wenn der Server eine
  /// frische Anmeldung verlangt.
  Future<void> passwortAendern(String neu) => api.post('/api/change-password', {'new_password': neu});

  // ── API-Tokens ───────────────────────────────────────────────────────────

  Future<List<ApiToken>> tokens() async {
    final j = await api.objekt('/api/me/tokens');
    return ((j['tokens'] as List?) ?? const []).whereType<Map>().map((m) => ApiToken.aus(m.cast())).toList();
  }

  /// Liefert das Token im Klartext — nur dieses eine Mal.
  Future<String> tokenErstellen({required String name, int? tage, List<String> scopes = const []}) async {
    final j = await api.post('/api/me/tokens', {
      'name': name,
      'expires_days': tage,
      if (scopes.isNotEmpty && !scopes.contains('*')) 'scopes': scopes,
    });
    final t = j is Map ? j['token'] as String? : null;
    if (t == null) throw ApiFehler(200, 'Der Server hat kein Token geliefert.', j);
    return t;
  }

  Future<void> tokenWiderrufen(int id, String? grund) =>
      api.delete('/api/me/tokens/$id', {'reason': (grund ?? '').trim().isEmpty ? null : grund!.trim()});

  // ── SSH ──────────────────────────────────────────────────────────────────

  Future<SshZugang> ssh() async => SshZugang.aus(await api.objekt('/api/ssh/me'));

  Future<void> sshHinzufuegen(String schluessel, String? bezeichnung) => api.post('/api/ssh/me/schluessel', {
        'pubkey': schluessel.trim(),
        'label': (bezeichnung ?? '').trim().isEmpty ? null : bezeichnung!.trim(),
      });

  /// true = stammt aus GitHub und kehrt beim naechsten Abgleich zurueck.
  Future<bool> sshEntfernen(int id) async {
    final j = await api.delete('/api/ssh/me/schluessel/$id');
    return j is Map && j['wiederkehrend'] == true;
  }

  Future<Map<String, dynamic>> sshGithubSetzen(String? benutzer) async {
    final j = await api.put('/api/ssh/me/github', {'benutzer': (benutzer ?? '').trim().isEmpty ? null : benutzer!.trim()});
    return j is Map<String, dynamic> ? j : const {};
  }

  Future<Map<String, dynamic>> sshGithubAbgleichen() async {
    final j = await api.post('/api/ssh/me/github/abgleich');
    return j is Map<String, dynamic> ? j : const {};
  }
}

// ── Daten ──────────────────────────────────────────────────────────────────

String? _t(Object? v) => v == null ? null : (v is String ? v : '$v');

class Benutzer {
  Benutzer({
    this.id,
    this.benutzername,
    this.name,
    this.email,
    this.rolle,
    this.wohnung,
    this.stweg,
    this.telefon,
    this.strasse,
    this.plz,
    this.ort,
    this.avatar,
    this.istAdmin = false,
    this.gruppen = const [],
    this.whatsapp = false,
  });

  factory Benutzer.aus(Map<String, dynamic> u) => Benutzer(
        id: u['id'] is int ? u['id'] as int : null,
        benutzername: _t(u['username']),
        name: _t(u['name']),
        email: _t(u['email']),
        rolle: _t(u['role']),
        wohnung: _t(u['wohnung']),
        stweg: _t(u['stweg']),
        telefon: _t(u['phone']),
        strasse: _t(u['strasse']),
        plz: _t(u['plz']),
        ort: _t(u['ort']),
        avatar: _t(u['avatar_url']),
        istAdmin: u['isAdmin'] == true,
        gruppen: ((u['groups'] as List?) ?? const []).map((g) => '$g').toList(),
        whatsapp: u['whatsapp_opt_in'] == true,
      );

  final int? id;
  final String? benutzername, name, email, rolle, wohnung, stweg, telefon, strasse, plz, ort, avatar;
  final bool istAdmin;
  final List<String> gruppen;
  final bool whatsapp;

  /// Wie im Portal: "Administrator" oder "Bewohner".
  String get rollenText => istAdmin ? 'Administrator' : 'Bewohner';

  /// Hat einen Anmeldenamen fuer die Stationen (AD) — sonst gibt es weder
  /// Desktop-Stil noch SSH (profil.html blendet die Karten dann aus).
  bool get stationsKonto => (benutzername ?? '').isNotEmpty;

  String get initialen {
    final teile = (name ?? '?').trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final s = teile.map((t) => t[0]).join().toUpperCase();
    return s.isEmpty ? '?' : (s.length > 2 ? s.substring(0, 2) : s);
  }
}

/// Was "Speichern" in "Persoenliche Daten" schickt (PUT /api/auth/profile).
class ProfilAngaben {
  ProfilAngaben({
    required this.name,
    required this.telefon,
    required this.stweg,
    required this.wohnung,
    required this.strasse,
    required this.plz,
    required this.ort,
  });
  final String name, telefon, wohnung, strasse, plz, ort;
  final String? stweg;

  Map<String, Object?> json() => {
        'name': name.trim(),
        'phone': telefon.trim(),
        'stweg': (stweg ?? '').isEmpty ? null : stweg,
        'wohnung': wohnung.trim(),
        'strasse': strasse.trim(),
        'plz': plz.trim(),
        'ort': ort.trim(),
      };
}

/// STWEG-Auswahl wie im Portal.
const stwegAuswahl = <String, String>{
  '1': 'STWEG 1',
  '2': 'STWEG 2',
  '3': 'STWEG 3',
  '4': 'STWEG 4',
  '5': 'STWEG 5',
  '6': 'STWEG 6',
  '7': 'STWEG 7',
  '8': 'MEG (Tiefeinstellhalle)',
};

class Zaehler {
  Zaehler({required this.id, required this.name, this.typ, this.rolle});
  factory Zaehler.aus(Map<String, dynamic> m) =>
      Zaehler(id: _t(m['id']) ?? '', name: _t(m['name']) ?? _t(m['id']) ?? '', typ: _t(m['type']), rolle: _t(m['role']));
  final String id, name;
  final String? typ, rolle;
}

class Objekt {
  Objekt({
    required this.stweg,
    required this.bezeichnung,
    this.rolle,
    this.typ,
    this.stockwerk,
    this.zimmer,
    this.flaeche,
    this.email,
    this.telefon,
    this.adresse,
  });
  factory Objekt.aus(Map<String, dynamic> w) => Objekt(
        stweg: _t(w['stweg']) ?? '',
        bezeichnung: _t(w['bezeichnung']) ?? '',
        rolle: _t(w['rolle']),
        typ: _t(w['typ']),
        stockwerk: _t(w['stockwerk']),
        zimmer: _t(w['zimmer']),
        flaeche: _t(w['flaeche_m2']),
        email: _t(w['email']),
        telefon: _t(w['telefon']),
        adresse: _t(w['adresse']),
      );
  final String stweg, bezeichnung;
  final String? rolle, typ, stockwerk, zimmer, flaeche, email, telefon, adresse;

  static const rollen = {'eigentuemer': 'Eigentümer', 'mieter': 'Mieter', 'verwalter': 'Verwalter', 'vertreter': 'Vertreter'};
  String? get rollenText => rolle == null ? null : (rollen[rolle] ?? rolle);

  /// "3. Obergeschoss · 3.5 Zi. · 75 m²"
  String get lage => [
        ?stockwerk,
        if (zimmer != null) '$zimmer Zi.',
        if (flaeche != null) '$flaeche m²',
      ].join(' · ');
}

class Telefon {
  Telefon({this.typ = 'mobile2', this.label = '', this.nummer = '', this.whatsapp = false});
  factory Telefon.aus(Map<String, dynamic> m) => Telefon(
        typ: _t(m['typ']) ?? 'sonstige',
        label: _t(m['label']) ?? '',
        nummer: _t(m['nummer']) ?? '',
        whatsapp: m['whatsapp'] == true,
      );
  String typ, label, nummer;
  bool whatsapp;

  Map<String, Object?> json() => {'typ': typ, if (label.trim().isNotEmpty) 'label': label.trim(), 'nummer': nummer.trim(), 'whatsapp': whatsapp};

  static const typen = {'mobile2': 'Mobil', 'festnetz2': 'Festnetz', 'geschaeft': 'Geschäft', 'sonstige': 'Sonstige'};
}

class PersonDaten {
  PersonDaten({this.gefunden = false, this.hauptEmail, this.hauptTelefon, this.telefone = const [], this.emails = const [], this.whatsapp = false});
  factory PersonDaten.aus(Map<String, dynamic> j) => PersonDaten(
        gefunden: j['found'] == true,
        hauptEmail: _t(j['person_email']),
        hauptTelefon: _t(j['primary_phone']),
        telefone: ((j['telefone'] as List?) ?? const []).whereType<Map>().map((m) => Telefon.aus(m.cast())).toList(),
        emails: ((j['emails'] as List?) ?? const []).map((e) => '$e').toList(),
        whatsapp: j['whatsapp_opt_in'] == true,
      );
  final bool gefunden;
  final String? hauptEmail, hauptTelefon;
  final List<Telefon> telefone;
  final List<String> emails;
  final bool whatsapp;
}

class ApiToken {
  ApiToken({
    required this.id,
    required this.name,
    required this.praefix,
    this.scopes = const [],
    this.erstellt,
    this.zuletzt,
    this.zuletztIp,
    this.ablauf,
    this.widerrufen,
    this.widerrufGrund,
  });
  factory ApiToken.aus(Map<String, dynamic> t) => ApiToken(
        id: (t['id'] as num).toInt(),
        name: _t(t['name']) ?? '',
        praefix: _t(t['token_prefix']) ?? '',
        scopes: ((t['scopes'] as List?) ?? const []).map((s) => '$s').toList(),
        erstellt: DateTime.tryParse(_t(t['created_at']) ?? ''),
        zuletzt: DateTime.tryParse(_t(t['last_used_at']) ?? ''),
        zuletztIp: _t(t['last_used_ip']),
        ablauf: DateTime.tryParse(_t(t['expires_at']) ?? ''),
        widerrufen: DateTime.tryParse(_t(t['revoked_at']) ?? ''),
        widerrufGrund: _t(t['revoked_reason']),
      );
  final int id;
  final String name, praefix;
  final List<String> scopes;
  final DateTime? erstellt, zuletzt, ablauf, widerrufen;
  final String? zuletztIp, widerrufGrund;

  bool abgelaufen([DateTime? jetzt]) => ablauf != null && ablauf!.isBefore(jetzt ?? DateTime.now());
  bool get aktiv => widerrufen == null && !abgelaufen();
}

/// Scopes wie im Portal (profil.html), mit Erklaerung.
const tokenScopes = <String, String>{
  'vollmachten:read': '',
  'vollmachten:write': '',
  'auslagen:read': '',
  'auslagen:write': '',
  'reklamationen:read': '',
  'reklamationen:write': '',
  'personen:read': '',
  'wohnungen:read': '',
  'handwerker:read': '',
  'documents:read': '',
  'docs:read': 'MCP: Portal-Dokumentation',
  'me:read': 'immer empfohlen',
  'me:write': 'Telefon, Adressmutation',
  'dashboard:read': 'Übersicht',
  'wasch:read': '',
  'wasch:write': 'reservieren',
  'zähler:read': 'Zählerdaten',
  'energy:read': 'Energie/Solar: Live, Verlauf, meine Zähler',
  'zaehler-technik:read': 'technische Zählerübersicht',
  'zev:read': 'Rechnungen',
  'telefonbuch:read': '',
  'ki-search:write': 'Suche',
  'isp/vpn-accounts:read': 'nur mein VPN',
};

class SshSchluessel {
  SshSchluessel({required this.id, required this.titel, required this.fingerabdruck, required this.typ, this.github = false, this.zuletzt});
  factory SshSchluessel.aus(Map<String, dynamic> k) => SshSchluessel(
        id: (k['id'] as num).toInt(),
        titel: _t(k['label']) ?? _t(k['kommentar']) ?? _t(k['typ']) ?? '',
        fingerabdruck: _t(k['fingerprint']) ?? '',
        typ: _t(k['typ']) ?? '',
        github: k['quelle'] == 'github',
        zuletzt: DateTime.tryParse(_t(k['zuletzt_gesehen']) ?? ''),
      );
  final int id;
  final String titel, fingerabdruck, typ;
  final bool github;
  final DateTime? zuletzt;
}

class SshZugang {
  SshZugang({this.schluessel = const [], this.github, this.hosts = const []});
  factory SshZugang.aus(Map<String, dynamic> d) => SshZugang(
        schluessel: ((d['schluessel'] as List?) ?? const []).whereType<Map>().map((m) => SshSchluessel.aus(m.cast())).toList(),
        github: _t(d['github_benutzer']),
        hosts: ((d['hosts'] as List?) ?? const [])
            .whereType<Map>()
            .map((h) => (name: _t(h['hostname']) ?? '', sudo: h['sudo'] == true))
            .toList(),
      );
  final List<SshSchluessel> schluessel;
  final String? github;
  final List<({String name, bool sudo})> hosts;
}

/// Datum wie im Portal (de-CH): 26.11.2026, 14:05
String datumZeit(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String z(int n) => n.toString().padLeft(2, '0');
  return '${z(l.day)}.${z(l.month)}.${l.year}, ${z(l.hour)}:${z(l.minute)}';
}

String datum(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String z(int n) => n.toString().padLeft(2, '0');
  return '${z(l.day)}.${z(l.month)}.${l.year}';
}
