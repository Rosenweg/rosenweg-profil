// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

/// Profilbild wie im Portal: Mitte quadratisch ausschneiden, auf 200×200
/// verkleinern, JPEG 85 % (~30 KB). Der Server nimmt hoechstens 512 KB.
/// null = kein lesbares Bild.
Uint8List? profilBild(Uint8List roh, {int groesse = 200}) {
  final b = img.decodeImage(roh);
  if (b == null) return null;
  final gedreht = img.bakeOrientation(b);
  final seite = gedreht.width < gedreht.height ? gedreht.width : gedreht.height;
  final quadrat = img.copyCrop(gedreht,
      x: (gedreht.width - seite) ~/ 2, y: (gedreht.height - seite) ~/ 2, width: seite, height: seite);
  final klein = img.copyResize(quadrat, width: groesse, height: groesse, interpolation: img.Interpolation.average);
  return Uint8List.fromList(img.encodeJpg(klein, quality: 85));
}

/// avatar_url aus /api/auth/me: eingebettetes Bild (data:) oder Adresse.
ImageProvider? avatarBild(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:image/')) {
    try {
      return MemoryImage(UriData.parse(url).contentAsBytes());
    } catch (_) {
      return null;
    }
  }
  if (RegExp(r'^https?://').hasMatch(url)) return NetworkImage(url);
  return null;
}
