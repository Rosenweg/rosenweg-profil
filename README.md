# Rosenweg Profil

Die eigenen Angaben im Rosenweg-Portal als App für Linux (Rosenweg OS) und
Android — dieselben Funktionen wie `profil.html` im Portal, gebaut auf
[rosenweg_basis](https://github.com/Rosenweg/rosenweg-basis).

Lizenz: GPL-3.0-or-later.

## Was die App kann

Drei Bereiche (Telefon: Leiste unten, Station: Leiste links):

| Bereich | Inhalt | API |
|---|---|---|
| **Übersicht** | Bild (antippen → ändern), Name, Benutzername, E-Mail, Rolle; Gruppen; Zähler (→ Dashboard); Objekte (Bearbeiten → im Portal) | `GET /api/auth/me`, `PUT /api/auth/avatar`, `GET /api/energie/meine-zaehler`, `GET /api/me/wohnungen` |
| **Angaben** | Name, Telefon, STWEG, Wohnung, Adresse (Speichern); WhatsApp-Benachrichtigung (gilt sofort); weitere Nummern und E-Mail-Adressen (je „… speichern“) | `PUT /api/auth/profile`, `PUT /api/me/whatsapp-optin`, `GET /api/me/person-data`, `PUT /api/me/phones`, `PUT /api/me/emails` |
| **Zugang** | Passwort ändern (mit „Jetzt neu anmelden“, wenn die API eine frische Anmeldung verlangt); Desktop an den Stationen und SSH-Zugang (nur mit Anmeldenamen); API-Tokens (erstellen, einmal anzeigen, widerrufen); Agent verbinden (MCP-Befehl) | `POST /api/change-password`, `GET/PUT /api/me/einstellungen`, `/api/ssh/me…`, `GET/POST/DELETE /api/me/tokens` |

Noch im Portal: das Bearbeiten eines Objekts (Kontakte, Bewohnung,
Wertquote, Adresssuche).

## Bauen

`rosenweg_basis` kommt, bis das Repo freigegeben ist, aus dem Nachbarordner:

```sh
cat > pubspec_overrides.yaml <<'EOF'
dependency_overrides:
  rosenweg_basis:
    path: ../rosenweg-basis
EOF
flutter analyze && flutter test
flutter run -d linux --dart-define=RW_ATTRAPPE=1   # ohne Server, erfundene Daten
```

- Linux-Paket: `linux/paket/im-container.sh` (Bau-Container CT 141 auf pve3,
  nimmt `../rosenweg-basis` mit) → `linux/paket/out/rosenweg-profil_<version>_amd64.deb`.
- Android: `flutter build apk --release` (vorerst mit Debug-Schlüssel signiert;
  für geteilte Telefone braucht es den Rosenweg-Schlüssel, siehe
  rosenweg-basis `docs/geteilte-telefone.md`).
- Logo: `sh ../rosenweg-basis/werkzeug/logo/erzeugen.sh . rosenweg-profil "Rosenweg Profil" ../rosenweg-basis/werkzeug/logo/zeichen/person.svg`
- Bildschirmfotos: `RW_FOTO=$HOME/Downloads flutter test test/bildschirmfoto_test.dart`

## Updates

Die App aktualisiert sich selbst (Updater aus `rosenweg_basis` ab 0.5.0, über `rosenwegStarten`): Android über den Rosenweg Updater, eigene Linux-Rechner, macOS und Windows über die Leiste „Neue Fassung … verfügbar“ (Prüfsumme aus dem Katalog wird geprüft). Aus nur auf geteilten Telefonen (Rosenweg Gerät) und auf Rosenweg-Stationen.

## Voraussetzungen ausserhalb

- Authentik `rosenweg-apps`: Rücksprung `ch.rosenweg4303.profil:/anmeldung`
  (strikt) für Android; Desktop nutzt den gemeinsamen localhost-Eintrag.
- Haupt-API muss `rosenweg-apps`-Tokens annehmen (in Arbeit); der
  Passwortwechsel braucht dort eine Frische-Prüfung für App-Tokens.
