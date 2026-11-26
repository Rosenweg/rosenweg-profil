// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bild.dart';
import '../daten.dart';
import 'profil_seite.dart';

/// Wer bin ich: Bild, Name, Gruppen, Zaehler, Objekte.
class UebersichtBereich extends StatelessWidget {
  const UebersichtBereich({super.key, required this.dienst, required this.ich, required this.geaendert});
  final ProfilDienst dienst;
  final Benutzer ich;
  final VoidCallback geaendert;

  @override
  Widget build(BuildContext context) => AbschnittListe(kinder: [
        _Kopf(dienst: dienst, ich: ich, geaendert: geaendert),
        Abschnitt(
          titel: 'Meine Gruppen',
          symbol: Icons.groups_outlined,
          kind: ich.gruppen.isEmpty
              ? const Leer('Keine Gruppen zugewiesen')
              : Wrap(spacing: 8, runSpacing: 8, children: [for (final g in ich.gruppen) Marke(g, farbe: _gruppenFarbe(g))]),
        ),
        Abschnitt(
          titel: 'Meine Zähler',
          symbol: Icons.bolt_outlined,
          kind: Laden<List<Zaehler>>(
            holen: dienst.zaehler,
            fehlerText: 'Keine Zähler zugewiesen',
            zeigen: (l, _) => l.isEmpty
                ? const Leer('Keine Zähler zugewiesen')
                : Column(children: [
                    for (final z in l)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.electric_meter_outlined),
                        title: Text(z.name),
                        subtitle: Text([z.typ ?? 'modbus', ?z.rolle].join(' · ')),
                        trailing: TextButton(
                          onPressed: () => imPortal('/energie-monitor.html'),
                          child: const Text('Dashboard'),
                        ),
                      ),
                  ]),
          ),
        ),
        Abschnitt(
          titel: 'Meine Objekte',
          symbol: Icons.home_outlined,
          kind: Laden<List<Objekt>>(
            holen: dienst.objekte,
            fehlerText: 'Wohnungsdaten nicht verfügbar.',
            zeigen: (l, _) => l.isEmpty
                ? const Leer('Du bist in der Verwaltung mit deiner E-Mail bzw. deinem Namen nicht als Kontakt einer '
                    'Wohnung erfasst. Wende dich an den Ausschuss, falls das nicht stimmt.')
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final o in l) _ObjektZeile(o),
                    // Das Bearbeiten (Kontakte, Bewohnung, Wertquote) ist ein grosses
                    // Formular mit Adresssuche; es bleibt vorerst im Portal.
                    TextButton.icon(
                      onPressed: () => imPortal('/profil.html'),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Objekte im Portal bearbeiten'),
                    ),
                  ]),
          ),
        ),
      ]);

  static Future<void> imPortal(String pfad) =>
      launchUrl(Uri.parse('${RosenwegKonfig.standard.api}$pfad'), mode: LaunchMode.externalApplication);

  static Color? _gruppenFarbe(String g) => switch (g) {
        'admin' => Colors.red.shade700,
        'technik' => Colors.purple.shade700,
        'stweg3-ausschuss' => Colors.blue.shade700,
        'verwaltung' => Colors.green.shade700,
        _ => null,
      };
}

class _Kopf extends StatefulWidget {
  const _Kopf({required this.dienst, required this.ich, required this.geaendert});
  final ProfilDienst dienst;
  final Benutzer ich;
  final VoidCallback geaendert;
  @override
  State<_Kopf> createState() => _KopfState();
}

class _KopfState extends State<_Kopf> {
  var _laedt = false;

  Future<void> _bildWaehlen() async {
    final datei = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Bilder', extensions: ['jpg', 'jpeg', 'png', 'webp'], mimeTypes: ['image/jpeg', 'image/png', 'image/webp']),
    ]);
    if (datei == null) return;
    setState(() => _laedt = true);
    try {
      final roh = await datei.readAsBytes();
      final jpeg = profilBild(roh);
      if (jpeg == null) throw ApiFehler(0, 'Das Bild lässt sich nicht lesen.');
      await widget.dienst.avatarSetzen(jpeg);
      if (mounted) zeigeMeldung(context, 'Profilbild gespeichert.');
      widget.geaendert();
    } catch (e) {
      if (mounted) zeigeMeldung(context, 'Fehler beim Hochladen: ${fehlerText(e)}', fehler: true);
    } finally {
      if (mounted) setState(() => _laedt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ich = widget.ich;
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final bild = avatarBild(ich.avatar);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Tooltip(
            message: 'Profilbild ändern',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _laedt ? null : _bildWaehlen,
              child: Stack(alignment: Alignment.bottomRight, children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: f.primaryContainer,
                  foregroundImage: bild,
                  child: _laedt
                      ? const CircularProgressIndicator()
                      : Text(ich.initialen, style: t.headlineSmall?.copyWith(color: f.onPrimaryContainer)),
                ),
                CircleAvatar(radius: 14, backgroundColor: f.primary, child: Icon(Icons.photo_camera, size: 16, color: f.onPrimary)),
              ]),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ich.name ?? 'Unbekannt', style: t.headlineSmall),
              if (ich.benutzername != null)
                Text('Benutzername: ${ich.benutzername}', style: t.bodySmall?.copyWith(fontFamily: 'monospace', color: f.onSurfaceVariant)),
              if (ich.email != null) Text(ich.email!, style: t.bodyMedium?.copyWith(color: f.onSurfaceVariant)),
              const SizedBox(height: 6),
              Marke(ich.rollenText, farbe: f.primary),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ObjektZeile extends StatelessWidget {
  const _ObjektZeile(this.o);
  final Objekt o;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final klein = t.bodySmall?.copyWith(color: f.onSurfaceVariant);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: f.outlineVariant), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('STWEG ${o.stweg} ${o.bezeichnung}', style: t.titleSmall),
          if (o.rollenText != null) Marke(o.rollenText!, farbe: o.rolle == 'eigentuemer' ? Colors.green.shade700 : null),
          if (o.typ != null && o.typ != 'Wohnung') Marke(o.typ!),
        ]),
        if (o.lage.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(o.lage)),
        Text('E-Mail: ${o.email ?? '(nicht erfasst)'}', style: klein),
        Text('Telefon: ${o.telefon ?? '(nicht erfasst)'}', style: klein),
        if (o.adresse != null) Text('Kontaktadresse: ${o.adresse}', style: klein),
      ]),
    );
  }
}
