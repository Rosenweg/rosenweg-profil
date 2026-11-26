// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import 'attrappe.dart';
import 'seiten/profil_seite.dart';

const profilApp = RosenwegApp(
  kennung: 'ch.rosenweg4303.profil',
  name: 'Rosenweg Profil',
  ordner: 'rosenweg-profil',
  beschreibung: 'Deine Angaben im Rosenweg-Portal: Kontakt, Adresse, Passwort und Zugänge.',
  quelle: 'https://github.com/Rosenweg/rosenweg-profil',
  logo: AssetImage('assets/logo/rosenweg-profil-512.png'),
);

/// --dart-define=RW_ATTRAPPE=1: ohne Anmeldung und ohne Server, mit
/// erfundenen Vorfuehrdaten (Entwicklung, Bildschirmfotos).
const attrappe = bool.fromEnvironment('RW_ATTRAPPE');

void main() => rosenwegStarten(
      profilApp,
      (sitzung) => ProfilSeite(sitzung: sitzung),
      sitzung: attrappe ? RosenwegSitzung(profilApp, transport: Attrappe()) : null,
    );
