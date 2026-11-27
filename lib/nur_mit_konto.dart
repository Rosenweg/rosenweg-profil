// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:url_launcher/url_launcher.dart';

/// Womit die Person in der App angemeldet ist.
///
/// Die Haupt-API sperrt fuer die Karten-Sitzung (`rw_app_…`) und am geteilten
/// Telefon (Anlage-Token) alles, womit man sich anmeldet — wie fuer API-Tokens
/// (`PAT_GESPERRT` und `requireUserLogin` in api/middleware/auth.js):
/// Passwort, API-Tokens, Passkeys, SSH-Schluessel und alles unter `/api/auth/`
/// ausser dem Lesen von `auth/me` — also auch Profilangaben und Profilbild
/// (`PUT /api/auth/profile`, `PUT /api/auth/avatar`). Die Karte ist ein
/// schwaecherer Ausweis als das Passwort. Statt eines Fehlers erklaert die App
/// das vorher und bietet den Weg zum Rosenweg-Konto an.
enum Zugangsart {
  /// Rosenweg-Konto (Browser oder still per Kerberos): alles erlaubt.
  konto,

  /// Android, mit der Rosenweg-Karte angemeldet.
  karte,

  /// Geteiltes Telefon (Rosenweg Geraet meldet an und ab).
  geteiltesTelefon;

  static Zugangsart von(RosenwegSitzung s) {
    if (s.geteiltesTelefon) return Zugangsart.geteiltesTelefon;
    if (s.android?.mitKarte ?? false) return Zugangsart.karte;
    return Zugangsart.konto;
  }

  bool get eingeschraenkt => this != Zugangsart.konto;
}

/// Hat die API eine Aenderung abgelehnt, weil die Anmeldung dafuer zu schwach
/// ist (Karte, geteiltes Telefon, Token)? Rueckfall fuer den Fall, dass die App
/// die Art der Anmeldung nicht kennt; die Texte stammen aus
/// api/middleware/auth.js.
bool istNurMitKonto(Object e) =>
    e is KeineBerechtigung &&
    !e.neuAnmelden &&
    RegExp(r'Karte|geteilten Telefon|Browser-Login|Zugangstoken', caseSensitive: false).hasMatch(e.text);

/// Wie [fehlerText] der Basis, aber eine Sperre fuer die Karte wird zum
/// verstaendlichen Satz.
String fehlerHinweis(Object e) =>
    istNurMitKonto(e) ? 'Dafür mit dem Rosenweg-Konto anmelden – mit der Karte geht das nicht.' : fehlerText(e);

/// Gibt die Sitzung an die Bereiche weiter, ohne sie durch jede Ebene zu reichen.
class ProfilZugang extends InheritedWidget {
  const ProfilZugang({super.key, required this.sitzung, required super.child});
  final RosenwegSitzung sitzung;

  Zugangsart get art => Zugangsart.von(sitzung);

  static ProfilZugang? vielleicht(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ProfilZugang>();

  /// Ohne [ProfilZugang] darueber (Tests einzelner Bereiche): Rosenweg-Konto.
  static Zugangsart artVon(BuildContext context) => vielleicht(context)?.art ?? Zugangsart.konto;

  @override
  bool updateShouldNotify(ProfilZugang alt) => alt.sitzung != sitzung;
}

/// Erklaerung statt eines Formulars, das die API ohnehin ablehnen wuerde.
/// [was]: z. B. "Das Passwort" — wird zu "Das Passwort änderst du nur …".
class NurMitKonto extends StatelessWidget {
  const NurMitKonto({super.key, required this.was});
  final String was;

  @override
  Widget build(BuildContext context) {
    final zugang = ProfilZugang.vielleicht(context);
    final art = zugang?.art ?? Zugangsart.konto;
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final (titel, text) = switch (art) {
      Zugangsart.geteiltesTelefon => (
          'Dafür mit dem Rosenweg-Konto anmelden',
          '$was änderst du nur mit deinem Rosenweg-Konto, nicht am geteilten Telefon – '
              'im Portal an einer Station oder auf deinem eigenen Gerät.',
        ),
      _ => (
          'Dafür mit dem Rosenweg-Konto anmelden',
          'Du bist mit der Rosenweg-Karte angemeldet. $was änderst du nur mit deinem Rosenweg-Konto: '
              'die Karte allein ist dafür nicht sicher genug.',
        ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: f.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.badge_outlined, color: f.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(titel, style: t.titleSmall?.copyWith(color: f.onSecondaryContainer))),
        ]),
        const SizedBox(height: 6),
        Text(text, style: t.bodyMedium),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: art == Zugangsart.geteiltesTelefon
              ? TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('${RosenwegKonfig.standard.api}/profil.html'),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Im Portal öffnen'),
                )
              : FilledButton.tonalIcon(
                  onPressed: zugang == null ? null : () => kontoStattKarte(context, zugang.sitzung),
                  icon: const Icon(Icons.login),
                  label: const Text('Mit Rosenweg-Konto anmelden'),
                ),
        ),
      ]),
    );
  }
}

/// Von der Karte zum Rosenweg-Konto: abmelden, dann zeigt die Basis den
/// Anmeldeschirm (Karte oder Rosenweg-Konto) wieder.
Future<void> kontoStattKarte(BuildContext context, RosenwegSitzung sitzung) async {
  if (await frage(
    context,
    'Mit dem Rosenweg-Konto anmelden?',
    'Die App meldet die Karte ab. Wähle dann auf dem Anmeldeschirm „Mit Rosenweg-Konto anmelden“.',
    ja: 'Weiter',
  )) {
    await sitzung.abmelden();
  }
}
