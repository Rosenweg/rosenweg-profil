// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../nur_mit_konto.dart';
import 'profil_seite.dart';

/// Wie ich hineinkomme: Passwort, Desktop an den Stationen, SSH, API-Tokens,
/// Agent verbinden. Desktop und SSH nur mit Anmeldenamen fuer die Stationen
/// (wie profil.html).
class ZugangBereich extends StatelessWidget {
  const ZugangBereich({super.key, required this.dienst, required this.ich, required this.sitzung});
  final ProfilDienst dienst;
  final Benutzer ich;
  final RosenwegSitzung sitzung;

  @override
  Widget build(BuildContext context) {
    // Mit der Karte oder am geteilten Telefon sperrt die API Passwort, SSH und
    // Tokens (nur_mit_konto.dart): erklaeren statt Formulare, die scheitern.
    // Die Desktop-Wahl an den Stationen geht weiterhin.
    if (Zugangsart.von(sitzung).eingeschraenkt) {
      return AbschnittListe(kinder: [
        const _NurMitKontoAbschnitt('Passwort ändern', Icons.lock_outline, 'Das Passwort'),
        if (ich.stationsKonto) _DesktopStil(dienst: dienst),
        if (ich.stationsKonto) const _NurMitKontoAbschnitt('SSH-Zugang', Icons.terminal, 'SSH-Schlüssel'),
        const _NurMitKontoAbschnitt('API-Tokens', Icons.token_outlined, 'API-Tokens (und damit Agents)'),
      ]);
    }
    return AbschnittListe(kinder: [
      _Passwort(dienst: dienst, sitzung: sitzung),
      if (ich.stationsKonto) _DesktopStil(dienst: dienst),
      if (ich.stationsKonto) _Ssh(dienst: dienst),
      _Tokens(dienst: dienst),
    ]);
  }
}

class _NurMitKontoAbschnitt extends StatelessWidget {
  const _NurMitKontoAbschnitt(this.titel, this.symbol, this.was);
  final String titel;
  final IconData symbol;
  final String was;
  @override
  Widget build(BuildContext context) => Abschnitt(titel: titel, symbol: symbol, kind: NurMitKonto(was: was));
}

// ── Passwort ─────────────────────────────────────────────────────────────────

class _Passwort extends StatefulWidget {
  const _Passwort({required this.dienst, required this.sitzung});
  final ProfilDienst dienst;
  final RosenwegSitzung sitzung;
  @override
  State<_Passwort> createState() => _PasswortState();
}

class _PasswortState extends State<_Passwort> {
  final _neu = TextEditingController();
  final _wieder = TextEditingController();
  var _laeuft = false;
  var _bestaetigen = false; // Server verlangt frische Anmeldung
  String? _meldung;
  var _art = HinweisArt.info;

  @override
  void dispose() {
    _neu.dispose();
    _wieder.dispose();
    super.dispose();
  }

  void _melden(String t, HinweisArt a) => setState(() {
        _meldung = t;
        _art = a;
      });

  Future<void> _aendern() async {
    if (_neu.text.length < 8) return _melden('Mindestens 8 Zeichen.', HinweisArt.fehler);
    if (_neu.text != _wieder.text) return _melden('Neue Passwörter stimmen nicht überein.', HinweisArt.fehler);
    setState(() => _laeuft = true);
    try {
      await widget.dienst.passwortAendern(_neu.text);
      _neu.clear();
      _wieder.clear();
      _bestaetigen = false;
      _melden('Passwort wurde erfolgreich geändert.', HinweisArt.gut);
    } on KeineBerechtigung catch (e) {
      if (e.neuAnmelden && !widget.sitzung.geteiltesTelefon) {
        _bestaetigen = true;
        _melden('${e.text} Danach geht es hier direkt weiter.', HinweisArt.warnung);
      } else {
        _melden(e.text, HinweisArt.fehler);
      }
    } catch (e) {
      _melden(fehlerHinweis(e), HinweisArt.fehler);
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  /// Frische Anmeldung im Browser, dann den Wechsel gleich nochmals versuchen.
  Future<void> _neuAnmelden() async {
    setState(() => _laeuft = true);
    final ok = await widget.sitzung.bestaetigen();
    if (!mounted) return;
    setState(() => _laeuft = false);
    if (ok) await _aendern();
  }

  @override
  Widget build(BuildContext context) => Abschnitt(
        titel: 'Passwort ändern',
        symbol: Icons.lock_outline,
        erklaerung: 'Ändert das Passwort für Website und Netzwerk-Zugang (SMB/Windows) gleichzeitig.',
        kind: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_meldung != null) ...[Hinweis(_meldung!, art: _art), const SizedBox(height: 12)],
            TextField(
              controller: _neu,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Neues Passwort', helperText: 'Mindestens 8 Zeichen'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wieder,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Neues Passwort bestätigen'),
              onSubmitted: (_) => _aendern(),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _bestaetigen
                  ? FilledButton.icon(
                      onPressed: _laeuft ? null : _neuAnmelden,
                      icon: const Icon(Icons.login),
                      label: const Text('Jetzt neu anmelden'),
                    )
                  : FilledButton(
                      onPressed: _laeuft ? null : _aendern,
                      child: Text(_laeuft ? 'Wird geändert …' : 'Passwort ändern'),
                    ),
            ),
          ]),
        ),
      );
}

// ── Desktop an den Stationen ─────────────────────────────────────────────────

class _DesktopStil extends StatefulWidget {
  const _DesktopStil({required this.dienst});
  final ProfilDienst dienst;
  @override
  State<_DesktopStil> createState() => _DesktopStilState();
}

class _DesktopStilState extends State<_DesktopStil> {
  String? _stil;
  String? _meldung;
  var _gut = true;
  var _fehlt = false;

  static const _wahl = [
    ('', 'Wie die Station', 'Was das Gerät vorgibt – heute die Windows-Anordnung.'),
    ('windows', 'Windows-Anordnung', 'Eine Leiste unten, Menü links unten, Fensterknöpfe rechts.'),
    ('mac', 'Mac-Anordnung', 'Menüleiste oben, Dock unten, Fensterknöpfe links.'),
  ];

  @override
  void initState() {
    super.initState();
    widget.dienst.desktopStil().then((s) {
      if (mounted) setState(() => _stil = s);
    }, onError: (_) {
      // Ohne Antwort bleibt die Karte weg (wie profil.html).
      if (mounted) setState(() => _fehlt = true);
    });
  }

  /// Eine einzelne Wahl, die sofort gilt — kein Speichern-Knopf.
  Future<void> _setzen(String s) async {
    final vorher = _stil;
    setState(() => _stil = s);
    try {
      _meldung = await widget.dienst.desktopStilSetzen(s);
      _gut = true;
    } catch (e) {
      _stil = vorher;
      _meldung = 'Konnte nicht gespeichert werden: ${fehlerHinweis(e)}';
      _gut = false;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_fehlt) return const SizedBox.shrink();
    return Abschnitt(
      titel: 'Desktop an den Stationen',
      symbol: Icons.desktop_windows_outlined,
      erklaerung: 'Wie der Bildschirm aufgeteilt ist, wenn du dich an einem Gerät im Haus anmeldest. '
          'Die Wahl gilt an allen Stationen und nur für dich.',
      kind: _stil == null
          ? const LinearProgressIndicator()
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_meldung != null) ...[Hinweis(_meldung!, art: _gut ? HinweisArt.gut : HinweisArt.fehler), const SizedBox(height: 8)],
              RadioGroup<String>(
                groupValue: _stil,
                onChanged: (v) => _setzen(v ?? ''),
                child: Column(children: [
                  for (final (wert, titel, text) in _wahl)
                    RadioListTile<String>(contentPadding: EdgeInsets.zero, value: wert, title: Text(titel), subtitle: Text(text)),
                ]),
              ),
              Text(
                'Gilt ab der nächsten Anmeldung – ein laufender Desktop wird nicht umgestellt. Gemeint ist die Aufteilung '
                'des Linux-Desktops, nicht das Betriebssystem: ein echtes Windows wählt man beim Start des Geräts.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
    );
  }
}

// ── SSH ──────────────────────────────────────────────────────────────────────

class _Ssh extends StatefulWidget {
  const _Ssh({required this.dienst});
  final ProfilDienst dienst;
  @override
  State<_Ssh> createState() => _SshState();
}

class _SshState extends State<_Ssh> {
  SshZugang? _z;
  var _fehlt = false;
  String? _meldung;
  var _gut = true;
  final _github = TextEditingController();

  @override
  void initState() {
    super.initState();
    _laden();
  }

  @override
  void dispose() {
    _github.dispose();
    super.dispose();
  }

  Future<void> _laden() async {
    try {
      final z = await widget.dienst.ssh();
      if (!mounted) return;
      setState(() {
        _z = z;
        _github.text = z.github ?? '';
      });
    } catch (_) {
      if (mounted) setState(() => _fehlt = true);
    }
  }

  Future<void> _tun(Future<String> Function() f) async {
    try {
      _meldung = await f();
      _gut = true;
      await _laden();
    } catch (e) {
      _meldung = fehlerHinweis(e);
      _gut = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _hinzufuegen() async {
    final schluessel = TextEditingController();
    final bez = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Schlüssel hinterlegen'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: schluessel,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(labelText: 'Öffentlicher Schlüssel', hintText: 'ssh-ed25519 AAAA… name@gerät'),
            ),
            const SizedBox(height: 12),
            TextField(controller: bez, decoration: const InputDecoration(labelText: 'Bezeichnung', hintText: 'z. B. Laptop')),
            const SizedBox(height: 8),
            const Text('Der öffentliche Schlüssel – der Inhalt von ~/.ssh/id_ed25519.pub. Der private bleibt auf deinem Gerät.'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hinterlegen')),
        ],
      ),
    );
    if (ok == true && schluessel.text.trim().isNotEmpty) {
      await _tun(() async {
        await widget.dienst.sshHinzufuegen(schluessel.text, bez.text);
        return 'Schlüssel hinterlegt.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fehlt) return const SizedBox.shrink();
    final z = _z;
    final t = Theme.of(context).textTheme;
    return Abschnitt(
      titel: 'SSH-Zugang',
      symbol: Icons.terminal,
      erklaerung: 'Öffentliche Schlüssel für die Anmeldung an den Hosts im Haus. Von Hand hinterlegen, aus einem '
          'GitHub-Konto holen lassen – oder beides. Wohin du damit kommst, entscheidet die Zugriffsmatrix.',
      aktion: TextButton.icon(onPressed: _hinzufuegen, icon: const Icon(Icons.add), label: const Text('Schlüssel')),
      kind: z == null
          ? const LinearProgressIndicator()
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_meldung != null) ...[Hinweis(_meldung!, art: _gut ? HinweisArt.gut : HinweisArt.fehler), const SizedBox(height: 8)],
              if (z.schluessel.isEmpty) const Leer('Noch kein Schlüssel hinterlegt.'),
              for (final k in z.schluessel)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(k.github ? Icons.cloud_outlined : Icons.vpn_key_outlined),
                  title: Text(k.titel),
                  subtitle: Text('${k.fingerabdruck}\n${k.typ} · ${k.zuletzt == null ? 'noch nie benutzt' : 'zuletzt benutzt ${datum(k.zuletzt)}'}'
                      '${k.github ? ' · GitHub' : ''}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Entfernen',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (!await frage(context, 'Schlüssel entfernen?', 'Anmeldungen damit sind sofort nicht mehr möglich.',
                          ja: 'Entfernen', gefaehrlich: true)) {
                        return;
                      }
                      await _tun(() async => await widget.dienst.sshEntfernen(k.id)
                          ? 'Entfernt – dieser Schlüssel stammt aus GitHub und kehrt beim nächsten Abgleich zurück. '
                              'Dauerhaft: dort entfernen oder das Konto hier lösen.'
                          : 'Schlüssel entfernt.');
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Text('GitHub-Konto', style: t.titleSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _github, decoration: const InputDecoration(labelText: 'GitHub-Benutzername'))),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _tun(() async {
                    final d = await widget.dienst.sshGithubSetzen(_github.text);
                    return _github.text.trim().isEmpty
                        ? 'GitHub-Konto gelöst, die von dort geholten Schlüssel sind entfernt.'
                        : '${d['gefunden'] ?? 0} Schlüssel bei GitHub gefunden, ${d['uebernommen'] ?? 0} neu übernommen.';
                  }),
                  child: const Text('Übernehmen'),
                ),
                if (z.github != null)
                  IconButton(
                    tooltip: 'Jetzt neu holen',
                    icon: const Icon(Icons.sync),
                    onPressed: () => _tun(() async {
                      final d = await widget.dienst.sshGithubAbgleichen();
                      return '${d['gefunden'] ?? 0} Schlüssel bei GitHub, ${d['uebernommen'] ?? 0} neu, ${d['entfernt'] ?? 0} entfallen.';
                    }),
                  ),
              ]),
              const SizedBox(height: 4),
              Text('Wir holen die öffentlichen Schlüssel dieses Kontos stündlich. Leeren und übernehmen entfernt sie wieder.',
                  style: t.bodySmall),
              const SizedBox(height: 12),
              Text('Wo du damit hinkommst', style: t.titleSmall),
              const SizedBox(height: 8),
              if (z.schluessel.isEmpty)
                const Leer('Erst mit einem hinterlegten Schlüssel wird daraus ein Zugang.')
              else if (z.hosts.isEmpty)
                const Leer('Für dich ist zurzeit kein Host freigegeben. Das regelt die Technik über die Zugriffsmatrix.')
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final h in z.hosts) Chip(label: Text(h.sudo ? '${h.name} · sudo' : h.name)),
                ]),
            ]),
    );
  }
}

// ── API-Tokens + Agent ───────────────────────────────────────────────────────

class _Tokens extends StatefulWidget {
  const _Tokens({required this.dienst});
  final ProfilDienst dienst;
  @override
  State<_Tokens> createState() => _TokensState();
}

class _TokensState extends State<_Tokens> {
  late Future<List<ApiToken>> _f = widget.dienst.tokens();

  /// Nur solange die App offen ist (wie im Portal).
  String? _neu;

  void _neuLaden() => setState(() => _f = widget.dienst.tokens());

  Future<void> _erstellen() async {
    final r = await showDialog<({String name, int? tage, List<String> scopes})>(context: context, builder: (_) => const _TokenDialog());
    if (r == null) return;
    try {
      final t = await widget.dienst.tokenErstellen(name: r.name, tage: r.tage, scopes: r.scopes);
      setState(() => _neu = t);
      _neuLaden();
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerHinweis(e), fehler: true);
    }
  }

  Future<void> _widerrufen(ApiToken t) async {
    final grund = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('„${t.name}“ widerrufen?'),
        content: TextField(controller: grund, decoration: const InputDecoration(labelText: 'Grund (freiwillig)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Widerrufen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.dienst.tokenWiderrufen(t.id, grund.text);
      _neuLaden();
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerHinweis(e), fehler: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final neu = _neu;
    return Column(children: [
      Abschnitt(
        titel: 'API-Tokens',
        symbol: Icons.token_outlined,
        erklaerung: 'Persönliche Zugriffstokens für KI-Agents, Apps oder eigene Skripte. Ein Token handelt in deinem Namen '
            'mit deinen Rechten – sicher behandeln, wie ein Passwort.',
        aktion: TextButton.icon(onPressed: _erstellen, icon: const Icon(Icons.add), label: const Text('Neuer Token')),
        kind: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (neu != null) ...[
            Hinweis('Token erstellt – jetzt kopieren, er wird nur einmal angezeigt!', art: HinweisArt.gut),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: SelectableText(neu, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
              IconButton(
                tooltip: 'Kopieren',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: neu));
                  if (context.mounted) zeigeMeldung(context, 'In die Zwischenablage kopiert.');
                },
              ),
            ]),
            TextButton(onPressed: () => setState(() => _neu = null), child: const Text('Verstanden, ausblenden')),
            const SizedBox(height: 8),
          ],
          FutureBuilder<List<ApiToken>>(
            future: _f,
            builder: (context, s) {
              if (s.hasError) return Text('Fehler beim Laden: ${fehlerHinweis(s.error!)}', style: TextStyle(color: f.error));
              if (!s.hasData) return const LinearProgressIndicator();
              final l = s.data!;
              if (l.isEmpty) return const Leer('Noch keine API-Tokens erstellt.');
              return Column(children: [for (final tok in l) _TokenZeile(tok, widerrufen: () => _widerrufen(tok))]);
            },
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Abschnitt(
        titel: 'Agent verbinden',
        symbol: Icons.smart_toy_outlined,
        erklaerung: 'Claude und andere Assistenten können das Portal über mcp.rosenweg4303.ch bedienen – mit deinem Token, '
            'in deinen Rechten. Alles, was sendet, öffnet oder löscht, fragt zuerst.',
        kind: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Claude Code:', style: t.bodySmall),
          _Code('claude mcp add rosenweg --transport http https://mcp.rosenweg4303.ch '
              '--header "Authorization: Bearer ${neu ?? 'rw_pat_…'}"'),
          const SizedBox(height: 8),
          Text('Claude Desktop / andere Clients (mcpServers):', style: t.bodySmall),
          _Code('{ "rosenweg": { "type": "http", "url": "https://mcp.rosenweg4303.ch",\n'
              '  "headers": { "Authorization": "Bearer ${neu ?? 'rw_pat_…'}" } } }'),
          const SizedBox(height: 8),
          Text('Erstellst du oben einen Token, erscheint er hier eingesetzt – nur solange die App offen ist.', style: t.bodySmall),
        ]),
      ),
    ]);
  }
}

class _Code extends StatelessWidget {
  const _Code(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
          IconButton(
            tooltip: 'Kopieren',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) zeigeMeldung(context, 'Kopiert.');
            },
          ),
        ]),
      );
}

class _TokenZeile extends StatelessWidget {
  const _TokenZeile(this.t, {required this.widerrufen});
  final ApiToken t;
  final VoidCallback widerrufen;
  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).colorScheme;
    final klein = Theme.of(context).textTheme.bodySmall?.copyWith(color: f.onSurfaceVariant);
    final (status, farbe) = t.widerrufen != null
        ? ('widerrufen', f.error)
        : t.abgelaufen()
            ? ('abgelaufen', RosenwegFarben.warnung)
            : ('aktiv', RosenwegFarben.gut);
    return Opacity(
      opacity: t.aktiv ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: f.outlineVariant), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(t.name, style: Theme.of(context).textTheme.titleSmall),
                Marke(status, farbe: farbe),
              ]),
            ),
            if (t.widerrufen == null) TextButton(onPressed: widerrufen, child: const Text('Widerrufen')),
          ]),
          Text('${t.praefix}…', style: klein?.copyWith(fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (t.scopes.isEmpty) const Marke('alle Rechte') else for (final s in t.scopes) Marke(s, farbe: Colors.purple.shade600),
          ]),
          const SizedBox(height: 6),
          Text('Erstellt: ${datumZeit(t.erstellt)} · Letzte Nutzung: ${datumZeit(t.zuletzt)}'
              '${t.zuletztIp != null ? ' · ${t.zuletztIp}' : ''} · Ablauf: ${t.ablauf == null ? 'nie' : datumZeit(t.ablauf)}',
              style: klein),
          if (t.widerrufen != null)
            Text('Widerrufen ${datumZeit(t.widerrufen)}${t.widerrufGrund != null ? ' · ${t.widerrufGrund}' : ''}',
                style: klein?.copyWith(color: f.error)),
        ]),
      ),
    );
  }
}

class _TokenDialog extends StatefulWidget {
  const _TokenDialog();
  @override
  State<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends State<_TokenDialog> {
  final _name = TextEditingController();
  int? _tage;
  final _scopes = <String>{};
  String? _fehler;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Neuen API-Token erstellen'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'z. B. MCP-Claude, eigenes Skript',
                  helperText: 'Damit du später weisst, wofür der Token ist.',
                  errorText: _fehler,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: _tage,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Gültigkeit'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Unbegrenzt (bis Widerruf)')),
                  DropdownMenuItem(value: 7, child: Text('7 Tage')),
                  DropdownMenuItem(value: 30, child: Text('30 Tage')),
                  DropdownMenuItem(value: 90, child: Text('90 Tage')),
                  DropdownMenuItem(value: 365, child: Text('1 Jahr')),
                ],
                onChanged: (v) => setState(() => _tage = v),
              ),
              const SizedBox(height: 16),
              Text('Rechte (Scopes) – leer heisst: alle deine Rechte', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final e in tokenScopes.entries)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _scopes.contains(e.key),
                  title: Text(e.key, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  subtitle: e.value.isEmpty ? null : Text(e.value),
                  onChanged: (v) => setState(() => v == true ? _scopes.add(e.key) : _scopes.remove(e.key)),
                ),
              Text('Der Server lehnt Anfragen ohne passenden Scope ab.', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              if (_name.text.trim().length < 2) return setState(() => _fehler = 'Bitte einen Namen (mindestens 2 Zeichen).');
              Navigator.pop(context, (name: _name.text.trim(), tage: _tage, scopes: _scopes.toList()));
            },
            child: const Text('Token erstellen'),
          ),
        ],
      );
}
