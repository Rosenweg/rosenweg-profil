// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Android, mit der Rosenweg-Karte angemeldet (statt des Kanals zu commons-rosenweg).
class KartenKonto implements AndroidKonto {
  final aufrufe = <String>[];
  @override
  String? name = 'Erika Muster';
  @override
  String? email = 'erika.muster@example.org';
  @override
  bool mitKarte = true;
  @override
  Future<bool> get angemeldet async => true;
  @override
  Future<bool> anmeldeSchirm() async {
    aufrufe.add('anmeldeSchirm');
    return false;
  }

  @override
  Future<bool> bestaetigen() async => false;
  @override
  Future<void> abmelden() async {
    aufrufe.add('abmelden');
    mitKarte = false;
  }

  @override
  Future<String?> zugangsToken() async => 'rw_app_test';
  @override
  void zugangUngueltig() {}
}
