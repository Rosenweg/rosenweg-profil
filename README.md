<p align="center"><img src="assets/logo/rosenweg-profil-512.png" width="96" alt="Logo"></p>
<h1 align="center">Rosenweg Profil</h1>
<p align="center">Die eigenen Angaben im Rosenweg-Portal – Kontakt, Adresse, Passwort und Zugänge.</p>
<p align="center"><a href="https://www.rosenweg4303.ch/apps">Herunterladen</a> · <a href="https://www.rosenweg4303.ch/profil.html">Im Portal</a></p>

## Inhalt

- [Überblick](#überblick)
- [Plattformen](#plattformen)
- [Bedienung](#bedienung)
- [Anmeldung](#anmeldung)
- [Mit der Karte angemeldet](#mit-der-karte-angemeldet)
- [Geteilte Rosenweg-Telefone](#geteilte-rosenweg-telefone)
- [Aufbau](#aufbau)
- [Bauen](#bauen)
- [Signieren (Android)](#signieren-android)
- [CI und Release](#ci-und-release)
- [Konfiguration](#konfiguration)
- [Offen](#offen)
- [Lizenz](#lizenz)

## Überblick

Rosenweg Profil ist `profil.html` aus dem Portal als App: dieselben Funktionen,
gebaut auf [rosenweg_basis](https://github.com/Rosenweg/rosenweg-basis)
(Anmeldung, API-Client, Thema, Rahmen). Drei Bereiche, geordnet nach dem, was
man sucht:

| Bereich | Inhalt | API |
|---|---|---|
| **Übersicht** – wer bin ich | Bild (antippen → ändern), Name, Benutzername, E-Mail, Rolle; Gruppen; Zähler (→ Dashboard); Objekte (Bearbeiten → im Portal) | `GET /api/auth/me`, `PUT /api/auth/avatar`, `GET /api/energie/meine-zaehler`, `GET /api/me/wohnungen` |
| **Angaben** – was ich ändere | Name, Telefon, STWEG, Wohnung, Adresse (Speichern); WhatsApp-Benachrichtigung (gilt sofort); weitere Nummern und E-Mail-Adressen (je „… speichern“) | `PUT /api/auth/profile`, `PUT /api/me/whatsapp-optin`, `GET /api/me/person-data`, `PUT /api/me/phones`, `PUT /api/me/emails` |
| **Zugang** – wie ich hineinkomme | Passwort ändern (mit „Jetzt neu anmelden“, wenn die API eine frische Anmeldung verlangt); Desktop an den Stationen und SSH-Zugang (nur mit Anmeldenamen); API-Tokens (erstellen, einmal anzeigen, widerrufen); Agent verbinden (MCP-Befehl) | `POST /api/change-password`, `GET/PUT /api/me/einstellungen`, `/api/ssh/me…`, `GET/POST/DELETE /api/me/tokens` |

Noch im Portal: das Bearbeiten eines Objekts (Kontakte, Bewohnung, Wertquote,
Adresssuche) – der Knopf „Bearbeiten“ öffnet es dort.

## Plattformen

| Plattform | Stand |
|---|---|
| Android | ja, APK auf [rosenweg4303.ch/apps](https://www.rosenweg4303.ch/apps) (bei Tag `v*`, mit Rosenweg-Signatur) |
| Geteilte Rosenweg-Telefone | ja, über den Katalog auf /smartphones (Katalog-Eintrag nötig, siehe unten) |
| Linux (Debian-Paket für die Stationen von Rosenweg OS) | ja, `.deb` (bei Tag `v*` an /apps; Stationen holen es vom PXE-Server) |
| macOS | ja, DMG, universal arm64 + x86_64 (bei Tag `v*` an /apps) |
| Windows | ja, Setup mit Inno Setup (bei Tag `v*` an /apps) |
| iOS | Bau ohne Signatur in der CI; nicht verteilt (braucht das Apple Developer Program) |

Version **0.1.1** (`pubspec.yaml`: `0.1.1+2`), noch ohne Tag.

## Bedienung

| Fenster | Navigation |
|---|---|
| Telefon (schmal) | Leiste unten: Übersicht · Angaben · Zugang |
| Station, Laptop, Tablet quer (ab 760 px) | Leiste links, Inhalt höchstens 820 px breit und mittig |

| Aktion | So geht’s |
|---|---|
| Profilbild | in der Übersicht aufs Bild tippen, Datei wählen (JPEG, PNG, WebP); die App schneidet es quadratisch zu und verkleinert es auf 200 × 200 |
| Angaben | Felder ändern, „Speichern“. WhatsApp gilt sofort. Weitere Nummern und Adressen haben je einen eigenen Speichern-Knopf. |
| Passwort | zweimal eingeben, „Passwort ändern“. Verlangt der Server eine frische Anmeldung, heisst der Knopf „Jetzt neu anmelden“; danach geht es direkt weiter. Gilt für Website und Netzwerk (SMB/Windows). |
| Desktop an den Stationen | Wahl gilt sofort, ab der nächsten Anmeldung an einer Station |
| SSH | Schlüssel hinterlegen oder ein GitHub-Konto eintragen; „Wo du damit hinkommst“ zeigt die freigegebenen Hosts |
| API-Token | „Neuer Token“: Name, Gültigkeit, Scopes. Der Token erscheint einmal und gleich im Agent-Befehl. |
| Aktualisieren, Über, Abmelden | oben rechts |

## Anmeldung

Alles kommt aus rosenweg_basis; die App hat keinen eigenen Anmeldecode.

| Wo | Wie |
|---|---|
| Station (Rosenweg OS, Domänenanmeldung) und Windows in der Domäne | **still** mit dem Kerberos-Ticket der Sitzung (`StilleAnmeldung`: GSS-API unter Linux, SSPI unter Windows) – kein Knopf, kein Browser. Das `.deb` hängt dafür von `libgssapi-krb5-2` ab. |
| Desktop ohne Ticket (macOS, privater Laptop) | Knopf „Mit Rosenweg-Konto anmelden“ → Browser, Rücksprung über `http://localhost:<port>/anmeldung` |
| Android (eigenes Handy) | gemeinsamer Anmeldeschirm aus commons-rosenweg (derselbe wie der Sperrbildschirm der geteilten Telefone): **Rosenweg-Karte** hinten ans Telefon halten **oder** „Mit Rosenweg-Konto anmelden“. Die QR-Code-Anmeldung kommt mit commons-rosenweg `cloud` 0.12.0 über die nächste Basis-Version. |
| Geteiltes Telefon | Rosenweg Gerät meldet an und ab; die App zeigt weder Anmeldeschirm noch „Abmelden“ |

Authentik, Client `rosenweg-apps`: Rücksprung `ch.rosenweg4303.profil:/anmeldung`
für Android – die Regex `^ch\.rosenweg4303\.[a-z]+:/anmeldung$` deckt ihn ab;
für den Desktop gilt `^http://localhost:[0-9]+/anmeldung$`.

## Mit der Karte angemeldet

Die Karte ist ein schwächerer Ausweis als das Passwort. Darum sperrt die
Haupt-API für die Karten-Sitzung (`rw_app_…`) und am geteilten Telefon alles,
womit man sich anmeldet – dieselbe Liste wie für API-Tokens (`PAT_GESPERRT`
und `requireUserLogin` in `api/middleware/auth.js`):

| Gesperrt | Endpunkt | in der App |
|---|---|---|
| Passwort ändern | `POST /api/change-password` | Erklärung statt Formular |
| API-Tokens (und Agent verbinden) | `/api/me/tokens` | Erklärung statt Liste |
| SSH-Schlüssel | `/api/ssh/me…` | Erklärung statt Liste |
| Name, Telefon, Adresse | `PUT /api/auth/profile` | Felder nur lesbar, kein „Speichern“ |
| Profilbild | `PUT /api/auth/avatar` | Hinweis beim Antippen |

Weiterhin erlaubt: weitere Nummern und E-Mail-Adressen, WhatsApp, Desktop an
den Stationen, alles Lesen.

Statt eines Fehlers steht dort **„Dafür mit dem Rosenweg-Konto anmelden“** mit
einem Knopf, der die Karte abmeldet und den Anmeldeschirm zeigt (dort „Mit
Rosenweg-Konto anmelden“ wählen). Am geteilten Telefon öffnet der Knopf
stattdessen das Portal. Lehnt die API trotzdem etwas wegen der Karte ab, zeigt
die App denselben Satz statt des Servertexts (`lib/nur_mit_konto.dart`).

## Geteilte Rosenweg-Telefone

Auf den geteilten Telefonen arbeitet die App für die Person, die gerade per
Karte am Sperrbildschirm angemeldet ist. Jede Anfrage geht über Rosenweg Gerät
und die Telefonanlage (rosenweg-basis, `docs/geteilte-telefone.md`).

| Voraussetzung | Warum |
|---|---|
| Rosenweg-Signatur | Rosenweg Gerät reicht Anfragen nur für Apps mit seiner Signatur weiter |
| Rosenweg Gerät ab v236 | bringt `portal_anfrage` |
| Katalog-Eintrag `ch.rosenweg4303.profil` | auf rosenweg4303.ch/smartphones; danach bringt jeder Release-Tag die APK auch dorthin |

## Aufbau

| Teil | Inhalt |
|---|---|
| `lib/main.dart` | App-Beschreibung (`RosenwegApp`), Start über `rosenwegStarten` |
| `lib/seiten/profil_seite.dart` | Gerüst: Leiste unten/links, die drei Bereiche |
| `lib/seiten/uebersicht.dart`, `angaben.dart`, `zugang.dart` | die Bereiche |
| `lib/daten.dart` | Datenmodell und API (`ProfilDienst` über `RosenwegApi`) |
| `lib/nur_mit_konto.dart` | Art der Anmeldung (Konto, Karte, geteiltes Telefon) und die Erklärung „Dafür mit dem Rosenweg-Konto anmelden“ |
| `lib/bild.dart` | Profilbild zuschneiden und verkleinern (JPEG) |
| `lib/attrappe.dart` | erfundene Vorführdaten ohne Server (`--dart-define=RW_ATTRAPPE=1`, Tests, Bildschirmfotos) |
| [rosenweg-basis](https://github.com/Rosenweg/rosenweg-basis) | Anmeldung, API-Client, Thema, Rahmen (privat, git-Abhängigkeit mit festem Stand in `pubspec.yaml`) |
| `android/`, `ios/`, `linux/`, `macos/`, `windows/` | Plattformprojekte; `linux/paket/` baut das Debian-Paket, `macos/installer/` das DMG, `windows/installer/` den Inno-Setup-Installer |
| `assets/logo/` | Logo aus dem Baukasten der Basis: Turm, Weg und Rose mit der Personen-Plakette (`werkzeug/logo/zeichen/person.svg`) |

## Bauen

```sh
flutter analyze
flutter test
flutter run -d macos --dart-define=RW_ATTRAPPE=1   # ohne Server, erfundene Daten
```

| Was | Befehl | Ergebnis |
|---|---|---|
| Android | `flutter build apk --release` (JDK 17) | `build/app/outputs/flutter-apk/app-release.apk` |
| macOS | `macos/installer/bauen.sh` | `build/macos-installer/Rosenweg-Profil-<version>.dmg` (ohne Developer ID ad hoc signiert) |
| Linux | `linux/paket/im-container.sh` (Bau-Container CT 141 auf pve3) | `linux/paket/out/rosenweg-profil_<version>-<bau>_amd64.deb` |
| Windows | `flutter build windows`, dann `iscc windows\installer\rosenweg-profil.iss` | `build/windows-installer/Rosenweg-Profil-<version>-Setup.exe` |
| iOS | `flutter build ios --release --no-codesign` | nur Probe |
| Logo und Symbole aller Plattformen | `sh assets/logo/erzeugen.sh [../rosenweg-basis]` | `assets/logo/`, Android-mipmaps, iOS- und macOS-AppIcon, `app_icon.ico` |
| Bildschirmfotos | `RW_FOTO=$HOME/Downloads flutter test test/bildschirmfoto_test.dart` | Telefon, Station, Anmeldung, mit Karte |

**Gegen eine lokale Basis entwickeln** (Nachbarordner `../rosenweg-basis`):
`pubspec_overrides.yaml` anlegen (steht in `.gitignore`):

```yaml
dependency_overrides:
  rosenweg_basis:
    path: ../rosenweg-basis
```

`flutter pub get` schreibt dann einen path-Eintrag in `pubspec.lock` – so
**nicht** einchecken, die CI bricht sonst ab. Vor dem Commit `git checkout
pubspec.lock`, oder bei einer neuen Basis-Version den `ref` in `pubspec.yaml`
ändern, `pubspec_overrides.yaml` kurz wegnehmen und `flutter pub get`.

Unter Android braucht die Basis `ch.rosenweg4303:cloud` (commons-rosenweg) aus
GitHub Packages (lokal: `gpr.user`/`gpr.key` in `~/.gradle/gradle.properties`)
oder aus `~/.m2` (`publishToMavenLocal`).

## Signieren (Android)

Signiert wird mit dem **Rosenweg-Schlüssel** (derselbe wie Rosenweg Telefon,
Alias `rosenweg-telefon`); nur so nehmen die geteilten Telefone und /apps die
APK an.

| Wo | Wie |
|---|---|
| CI | Secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` → Umgebung `SIGNING_*` |
| lokal | `android/keystore.properties` (nicht eingecheckt): `storeFile`, `storePassword`, `keyAlias`, `keyPassword` – Werte aus dem Ordner des Schlüssels (`LIESMICH.md` dort) |
| ohne beides | Debug-Signatur; in der CI heisst die Datei dann `…-debug-signiert.apk` und geht nicht an /apps |

## CI und Release

Alle Läufe holen die private Basis über `.github/actions/basis-zugang`
(Secret `BASIS_TOKEN`). Linux und Android laufen auf dem eigenen Runner
(Gruppe `rosenweg-privat`), macOS/iOS und Windows auf von GitHub gehosteten
Runnern.

| Workflow | Auslöser | Ergebnis | an /apps |
|---|---|---|---|
| `android.yml` | Push auf `main`, PR, Tag `v*` | `flutter analyze`, `flutter test`, APK als Artefakt | bei Tag, nur mit Rosenweg-Signatur |
| `linux.yml` | Push auf `main`, PR, Tag `v*` | `.deb` als Artefakt | bei Tag (linux-deb) |
| `macos.yml` | Tag `v*`, von Hand | DMG; iOS-Bau ohne Signatur (`.ipa` als Artefakt) | DMG bei Tag |
| `windows.yml` | Tag `v*`, von Hand | Setup-`.exe` | bei Tag |

### Release-Ablauf

1. `version` in `pubspec.yaml` erhöhen (`x.y.z+n`; `n` ist Android-`versionCode`
   und Debian-Revision und muss steigen), per PR nach `main`.
2. Nach dem Merge auf `main` taggen: `git tag v<x.y.z> && git push origin v<x.y.z>`
   – der Tag muss genau `version` ohne `+n` sein, sonst brechen die Läufe ab.
3. Die vier Workflows legen gemeinsam **ein** GitHub-Release an und laden
   APK, `.deb`, DMG und Setup hoch; über
   `Rosenweg/Website/.github/actions/apps-release` (GitHub-OIDC, kein
   Geheimnis) erscheinen sie auf [rosenweg4303.ch/apps](https://www.rosenweg4303.ch/apps),
   die APK auch im Katalog der geteilten Telefone (falls angelegt).
4. Stationen: das `.deb` in Rosenweg/os-stationen unter `pakete/` nachführen
   (wie rosenweg-salz und rosenweg-vm).

## Konfiguration

GitHub-Secrets (Settings → Secrets and variables → Actions), nur die Namen:

| Secret | Wozu |
|---|---|
| `BASIS_TOKEN` | fein granulierter Token, nur Rosenweg/rosenweg-basis, *Contents: Read-only* – ohne ihn scheitert jeder Lauf mit einer klaren Meldung |
| `BASIS_DEPLOY_KEY` | Alternative zu `BASIS_TOKEN` (Deploy-Key auf rosenweg-basis) |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Rosenweg-Signierschlüssel (optional, siehe oben) |
| `MACOS_ZERTIFIKAT_P12`, `MACOS_ZERTIFIKAT_PASSWORT`, `NOTAR_KEY_P8`, `NOTAR_KEY_ID`, `NOTAR_ISSUER` | macOS signieren und notarisieren (optional; sonst ad hoc) |

commons-rosenweg holt `android.yml` mit dem `GITHUB_TOKEN` des Laufs
(`packages: read`); dafür braucht es kein Secret.

## Offen

- Basis auf einen Tag umstellen, sobald rosenweg-basis den Stand nach #5/#8
  taggt (jetzt ein fester Commit in `pubspec.yaml`).
- Gemeinsames Desktop-Gerüst der Basis (Seitenleiste ab ~840 px) übernehmen,
  sobald es dort liegt; bis dahin die eigene Leiste links ab 760 px.
- QR-Code-Anmeldung kommt mit der nächsten Basis-Version (commons-rosenweg
  `cloud` 0.12.0).

## Lizenz

GPL-3.0-or-later, siehe [LICENSE](LICENSE).
