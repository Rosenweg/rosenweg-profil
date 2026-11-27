// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../nur_mit_konto.dart';
import 'profil_seite.dart';

/// Was ich aendere: Persoenliche Daten, Adresse, WhatsApp, weitere Kontakte.
class AngabenBereich extends StatelessWidget {
  const AngabenBereich({super.key, required this.dienst, required this.ich, required this.geaendert});
  final ProfilDienst dienst;
  final Benutzer ich;
  final VoidCallback geaendert;

  @override
  Widget build(BuildContext context) => AbschnittListe(kinder: [
        _Persoenlich(dienst: dienst, ich: ich, geaendert: geaendert),
        Laden<PersonDaten>(
          holen: dienst.personDaten,
          zeigen: (p, neu) => Column(children: [
            _WhatsApp(dienst: dienst, an: ich.whatsapp || p.whatsapp),
            const SizedBox(height: 16),
            _Telefone(dienst: dienst, daten: p),
            const SizedBox(height: 16),
            _Emails(dienst: dienst, daten: p),
          ]),
        ),
      ]);
}

class _Persoenlich extends StatefulWidget {
  const _Persoenlich({required this.dienst, required this.ich, required this.geaendert});
  final ProfilDienst dienst;
  final Benutzer ich;
  final VoidCallback geaendert;
  @override
  State<_Persoenlich> createState() => _PersoenlichState();
}

class _PersoenlichState extends State<_Persoenlich> {
  late final name = TextEditingController(text: widget.ich.name);
  late final telefon = TextEditingController(text: widget.ich.telefon);
  late final wohnung = TextEditingController(text: widget.ich.wohnung);
  late final strasse = TextEditingController(text: widget.ich.strasse);
  late final plz = TextEditingController(text: widget.ich.plz);
  late final ort = TextEditingController(text: widget.ich.ort);
  late String? stweg = stwegAuswahl.containsKey(widget.ich.stweg) ? widget.ich.stweg : null;
  var _speichert = false;
  String? _meldung;
  var _gut = true;

  @override
  void dispose() {
    for (final c in [name, telefon, wohnung, strasse, plz, ort]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _speichern() async {
    setState(() {
      _speichert = true;
      _meldung = null;
    });
    try {
      await widget.dienst.profilSpeichern(ProfilAngaben(
        name: name.text,
        telefon: telefon.text,
        stweg: stweg,
        wohnung: wohnung.text,
        strasse: strasse.text,
        plz: plz.text,
        ort: ort.text,
      ));
      _gut = true;
      _meldung = 'Profil erfolgreich gespeichert.';
      widget.geaendert();
    } catch (e) {
      _gut = false;
      _meldung = fehlerHinweis(e);
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Karte/geteiltes Telefon: die API nimmt PUT /api/auth/profile nicht an
    // (nur_mit_konto.dart). Angaben zeigen, aber nicht bearbeitbar.
    final gesperrt = ProfilZugang.artVon(context).eingeschraenkt;
    Widget feld(String titel, TextEditingController c, {String? hinweis, TextInputType? art}) => TextField(
          controller: c,
          keyboardType: art,
          enabled: !gesperrt,
          decoration: InputDecoration(labelText: titel, hintText: hinweis),
        );
    final zweiSpalten = MediaQuery.sizeOf(context).width >= 600;
    Widget paar(Widget a, Widget b) => zweiSpalten
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)])
        : Column(children: [a, const SizedBox(height: 12), b]);

    return Abschnitt(
      titel: 'Persönliche Daten',
      symbol: Icons.badge_outlined,
      kind: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (gesperrt) ...[const NurMitKonto(was: 'Name, Telefon und Adresse'), const SizedBox(height: 12)],
        if (_meldung != null) ...[Hinweis(_meldung!, art: _gut ? HinweisArt.gut : HinweisArt.fehler), const SizedBox(height: 12)],
        paar(
          feld('Name', name),
          TextField(
            controller: TextEditingController(text: widget.ich.email),
            enabled: false,
            decoration: const InputDecoration(labelText: 'E-Mail', helperText: 'Wird über Authentik verwaltet'),
          ),
        ),
        const SizedBox(height: 12),
        paar(
          feld('Telefon', telefon, hinweis: '+41 …', art: TextInputType.phone),
          DropdownButtonFormField<String?>(
            initialValue: stweg,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'STWEG'),
            items: [
              const DropdownMenuItem(value: null, child: Text('– Bitte wählen –')),
              for (final e in stwegAuswahl.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: gesperrt ? null : (v) => setState(() => stweg = v),
          ),
        ),
        const SizedBox(height: 12),
        feld('Wohnung', wohnung, hinweis: 'z. B. 3. OG links'),
        const SizedBox(height: 20),
        Text('Adresse', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        feld('Strasse', strasse, hinweis: 'Rosenweg …'),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(width: 120, child: feld('PLZ', plz, hinweis: '4303', art: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: feld('Ort', ort, hinweis: 'Kaiseraugst')),
        ]),
        if (!gesperrt) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _speichert ? null : _speichern,
              icon: _speichert
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Speichern'),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Gilt sofort, ohne Speichern-Knopf (wie im Portal).
class _WhatsApp extends StatefulWidget {
  const _WhatsApp({required this.dienst, required this.an});
  final ProfilDienst dienst;
  final bool an;
  @override
  State<_WhatsApp> createState() => _WhatsAppState();
}

class _WhatsAppState extends State<_WhatsApp> {
  late bool _an = widget.an;
  var _laeuft = false;
  String? _status;
  var _fehler = false;

  Future<void> _setzen(bool an) async {
    setState(() {
      _laeuft = true;
      _an = an;
      _status = 'Wird gespeichert …';
      _fehler = false;
    });
    try {
      final nummer = await widget.dienst.whatsappSetzen(an);
      _status = an ? 'Aktiv – Nummer: ${nummer ?? '(unbekannt)'}' : 'Deaktiviert – nur E-Mail-Benachrichtigungen.';
    } catch (e) {
      _an = !an;
      _fehler = true;
      final hinweis = e is ApiFehler ? e.feld('hint') : null;
      _status = '${fehlerHinweis(e)}${hinweis != null ? ' – $hinweis' : ''}';
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) => Abschnitt(
        titel: 'WhatsApp-Benachrichtigungen',
        symbol: Icons.chat_outlined,
        kind: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _an,
            onChanged: _laeuft ? null : _setzen,
            title: const Text('Zusätzlich per WhatsApp benachrichtigen'),
            subtitle: const Text('Push-Nachrichten bei Auslagen-Statuswechseln, Reklamations-Updates und Erinnerungen.'),
          ),
          if (_status != null)
            Text(_status!,
                style: TextStyle(color: _fehler ? Theme.of(context).colorScheme.error : (_an ? RosenwegFarben.gut : null)))
          else if (_an)
            const Text('Aktiv – Benachrichtigungen werden zusätzlich per WhatsApp gesendet.', style: TextStyle(color: RosenwegFarben.gut)),
        ]),
      );
}

/// Weitere Telefonnummern: Zeilen bearbeiten, dann einmal speichern.
class _Telefone extends StatefulWidget {
  const _Telefone({required this.dienst, required this.daten});
  final ProfilDienst dienst;
  final PersonDaten daten;
  @override
  State<_Telefone> createState() => _TelefoneState();
}

class _TelefoneState extends State<_Telefone> {
  late final _liste = [for (final t in widget.daten.telefone) Telefon(typ: t.typ, label: t.label, nummer: t.nummer, whatsapp: t.whatsapp)];
  var _geaendert = false;
  var _speichert = false;

  void _aendern(VoidCallback f) => setState(() {
        f();
        _geaendert = true;
      });

  Future<void> _speichern() async {
    setState(() => _speichert = true);
    try {
      await widget.dienst.telefoneSpeichern(_liste);
      _liste.removeWhere((t) => t.nummer.trim().isEmpty);
      _geaendert = false;
      if (mounted) zeigeMeldung(context, 'Telefonnummern gespeichert.');
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerHinweis(e), fehler: true);
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final haupt = widget.daten.hauptTelefon;
    return Abschnitt(
      titel: 'Weitere Telefonnummern',
      symbol: Icons.phone_outlined,
      erklaerung: 'Das WhatsApp-Häkchen je Nummer steuert, ob diese Nummer Push-Nachrichten erhält.',
      aktion: TextButton.icon(
        onPressed: () => _aendern(() => _liste.add(Telefon())),
        icon: const Icon(Icons.add),
        label: const Text('Nummer'),
      ),
      kind: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (haupt != null) Text('Primär (oben gepflegt): $haupt', style: Theme.of(context).textTheme.bodySmall),
        if (_liste.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Leer('Noch keine Zusatznummern.')),
        for (final (i, t) in _liste.indexed)
          Padding(
            key: ObjectKey(t),
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  initialValue: Telefon.typen.containsKey(t.typ) ? t.typ : 'sonstige',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Art'),
                  items: [for (final e in Telefon.typen.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => _aendern(() => t.typ = v ?? 'sonstige'),
                ),
              ),
              SizedBox(
                width: 170,
                child: TextFormField(
                  initialValue: t.nummer,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Nummer', hintText: '+41 …'),
                  onChanged: (v) => _aendern(() => t.nummer = v),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextFormField(
                  initialValue: t.label,
                  decoration: const InputDecoration(labelText: 'Bezeichnung'),
                  onChanged: (v) => _aendern(() => t.label = v),
                ),
              ),
              FilterChip(
                label: const Text('WhatsApp'),
                selected: t.whatsapp,
                onSelected: (v) => _aendern(() => t.whatsapp = v),
              ),
              IconButton(
                tooltip: 'Nummer entfernen',
                onPressed: () => _aendern(() => _liste.removeAt(i)),
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
          ),
        if (_geaendert)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _speichert ? null : _speichern, child: const Text('Nummern speichern')),
            ),
          ),
      ]),
    );
  }
}

class _Emails extends StatefulWidget {
  const _Emails({required this.dienst, required this.daten});
  final ProfilDienst dienst;
  final PersonDaten daten;
  @override
  State<_Emails> createState() => _EmailsState();
}

class _EmailsState extends State<_Emails> {
  late final _liste = [for (final e in widget.daten.emails) TextEditingController(text: e)];
  final _entfernt = <TextEditingController>[]; // erst beim Schliessen freigeben
  var _geaendert = false;
  var _speichert = false;

  @override
  void dispose() {
    for (final c in [..._liste, ..._entfernt]) {
      c.dispose();
    }
    super.dispose();
  }

  void _aendern(VoidCallback f) => setState(() {
        f();
        _geaendert = true;
      });

  Future<void> _speichern() async {
    setState(() => _speichert = true);
    try {
      await widget.dienst.emailsSpeichern([for (final c in _liste) c.text]);
      _geaendert = false;
      if (mounted) zeigeMeldung(context, 'E-Mail-Adressen gespeichert.');
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerHinweis(e), fehler: true);
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final haupt = widget.daten.hauptEmail;
    return Abschnitt(
      titel: 'Weitere E-Mail-Adressen',
      symbol: Icons.alternate_email,
      erklaerung: 'Wird für die Zuordnung von Benachrichtigungen verwendet, falls deine Anmelde-Adresse anders ist '
          'als die hinterlegte Hauptadresse.',
      aktion: TextButton.icon(
        onPressed: () => _aendern(() => _liste.add(TextEditingController())),
        icon: const Icon(Icons.add),
        label: const Text('E-Mail'),
      ),
      kind: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (haupt != null) Text('Primär (in der Objektverwaltung): $haupt', style: Theme.of(context).textTheme.bodySmall),
        if (_liste.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Leer('Noch keine weiteren Adressen.')),
        for (final (i, c) in _liste.indexed)
          Padding(
            key: ObjectKey(c),
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: c,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-Mail'),
                  onChanged: (_) => _aendern(() {}),
                ),
              ),
              IconButton(
                tooltip: 'Adresse entfernen',
                onPressed: () => _aendern(() => _entfernt.add(_liste.removeAt(i))),
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
          ),
        if (_geaendert)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _speichert ? null : _speichern, child: const Text('Adressen speichern')),
            ),
          ),
      ]),
    );
  }
}
