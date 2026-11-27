// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import 'angaben.dart';
import 'uebersicht.dart';
import 'zugang.dart';

/// Die ganze App: drei Bereiche wie die Karten von profil.html, geordnet
/// nach dem, was man sucht.
///   Übersicht — wer bin ich: Bild, Name, Gruppen, Zähler, Objekte
///   Angaben   — was ich ändere: Name, Telefon, Adresse, weitere Kontakte
///   Zugang    — wie ich hineinkomme: Passwort, Stationen, SSH, API-Tokens
/// Telefon: Leiste unten; breiter Bildschirm (Station): Leiste links.
class ProfilSeite extends StatefulWidget {
  const ProfilSeite({super.key, required this.sitzung});
  final RosenwegSitzung sitzung;

  @override
  State<ProfilSeite> createState() => _ProfilSeiteState();
}

class _ProfilSeiteState extends State<ProfilSeite> {
  late final dienst = ProfilDienst(widget.sitzung.api);
  var _bereich = 0;
  Benutzer? _ich;
  Object? _fehler;
  var _stand = 0; // erhoeht bei "Aktualisieren": Bereiche laden neu

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() => _fehler = null);
    try {
      final u = await dienst.ich();
      if (mounted) setState(() => _ich = u);
    } catch (e) {
      if (mounted) setState(() => _fehler = e);
    }
  }

  void _aktualisieren() {
    setState(() => _stand++);
    _laden();
  }

  static const _bereiche = [
    (titel: 'Übersicht', symbol: Icons.person_outline, aktiv: Icons.person),
    (titel: 'Angaben', symbol: Icons.edit_note_outlined, aktiv: Icons.edit_note),
    (titel: 'Zugang', symbol: Icons.key_outlined, aktiv: Icons.key),
  ];

  @override
  Widget build(BuildContext context) {
    final breit = MediaQuery.sizeOf(context).width >= 760;
    final inhalt = _inhalt();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Profil'),
        actions: [
          IconButton(tooltip: 'Aktualisieren', onPressed: _aktualisieren, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            tooltip: 'Mehr',
            onSelected: (w) async {
              if (w == 'ueber') await zeigeUeber(context, widget.sitzung.app);
              // Gemeinsame Seite aus rosenweg_basis: angemeldet als, womit, Abmelden (echter Stand)
              if (w == 'anmeldung' && context.mounted) await zeigeAnmeldung(context, widget.sitzung);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'anmeldung', child: Text('Anmeldung: ${widget.sitzung.name ?? 'angemeldet'}')),
              const PopupMenuItem(value: 'ueber', child: Text('Über Rosenweg Profil')),
            ],
          ),
        ],
      ),
      body: breit
          ? Row(children: [
              NavigationRail(
                selectedIndex: _bereich,
                onDestinationSelected: (i) => setState(() => _bereich = i),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final b in _bereiche)
                    NavigationRailDestination(icon: Icon(b.symbol), selectedIcon: Icon(b.aktiv), label: Text(b.titel)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: inhalt),
            ])
          : inhalt,
      bottomNavigationBar: breit
          ? null
          : NavigationBar(
              selectedIndex: _bereich,
              onDestinationSelected: (i) => setState(() => _bereich = i),
              destinations: [
                for (final b in _bereiche) NavigationDestination(icon: Icon(b.symbol), selectedIcon: Icon(b.aktiv), label: b.titel),
              ],
            ),
    );
  }

  Widget _inhalt() {
    final ich = _ich;
    if (_fehler != null && ich == null) return FehlerAnzeige(text: fehlerText(_fehler!), nochmals: _laden);
    if (ich == null) return const LadeAnzeige();
    final kinder = switch (_bereich) {
      0 => UebersichtBereich(key: ValueKey('u$_stand'), dienst: dienst, ich: ich, geaendert: _laden),
      1 => AngabenBereich(key: ValueKey('a$_stand'), dienst: dienst, ich: ich, geaendert: _laden),
      _ => ZugangBereich(key: ValueKey('z$_stand'), dienst: dienst, ich: ich, sitzung: widget.sitzung),
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: kinder),
    );
  }
}

/// Liste von Abschnitten mit Abstand, scrollbar.
class AbschnittListe extends StatelessWidget {
  const AbschnittListe({super.key, required this.kinder});
  final List<Widget> kinder;
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kinder.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, i) => kinder[i],
      );
}

/// Kleine Marke (Gruppe, Rolle, Status) wie die "Pillen" im Portal.
class Marke extends StatelessWidget {
  const Marke(this.text, {super.key, this.farbe});
  final String text;
  final Color? farbe;
  @override
  Widget build(BuildContext context) {
    final f = farbe ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: f.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: f, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

/// Laedt einmal und zeigt Warten/Fehler/Inhalt; fuer Abschnitte mit eigener Abfrage.
class Laden<T> extends StatefulWidget {
  const Laden({super.key, required this.holen, required this.zeigen, this.fehlerText});
  final Future<T> Function() holen;
  final Widget Function(T daten, VoidCallback neu) zeigen;

  /// Statt der Fehlermeldung (z. B. "Keine Zähler zugewiesen").
  final String? fehlerText;
  @override
  State<Laden<T>> createState() => _LadenState<T>();
}

class _LadenState<T> extends State<Laden<T>> {
  late Future<T> _f = widget.holen();
  void _neu() => setState(() => _f = widget.holen());
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (context, s) {
          if (s.hasError) {
            return Text(widget.fehlerText ?? fehlerText(s.error!),
                style: TextStyle(color: widget.fehlerText == null ? Theme.of(context).colorScheme.error : null));
          }
          if (!s.hasData) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
          return widget.zeigen(s.data as T, _neu);
        },
      );
}

/// Grauer Satz, wenn eine Liste leer ist.
class Leer extends StatelessWidget {
  const Leer(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic));
}
