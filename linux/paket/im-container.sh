#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# ============================================================================
# linux/paket/im-container.sh — das Paket im Bau-Container bauen
# ============================================================================
#   linux/paket/im-container.sh [knoten] [ct] [basis-ordner]
#   linux/paket/im-container.sh root@100.64.2.22 141 ../rosenweg-basis   (Vorgabe)
#
# Wie rosenweg-vm: der Bau-Container (CT 141, Debian 13) hat keinen Zugang zu
# GitHub; der Quellstand geht als Archiv ueber den Knoten hinein ('pct push'),
# das .deb auf demselben Weg zurueck. Mitgeschickt wird der Arbeitsstand,
# auch Ungespeichertes (eigener Index, .gitignore gilt) — und rosenweg-basis
# aus dem Nachbarordner, dessen Pfad pubspec_overrides.yaml im Container
# eintraegt.
# ============================================================================
# shellcheck disable=SC2029
set -euo pipefail

KNOTEN="${1:-root@100.64.2.22}"
CTID="${2:-141}"
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WURZEL="$(cd "$HIER/../.." && pwd)"
BASIS="$(cd "${3:-$WURZEL/../rosenweg-basis}" && pwd)"
cd "$WURZEL"

archiv() { # <repo> <datei> -> Stand
    local repo="$1" ziel="$2" index baum stand
    stand="$(git -C "$repo" rev-parse --short=12 HEAD)"
    index="$(mktemp "${TMPDIR:-/tmp}/rw-index.XXXXXX")"
    cp "$(git -C "$repo" rev-parse --git-path index)" "$index" 2>/dev/null || rm -f "$index"
    baum="$(cd "$repo" && GIT_INDEX_FILE="$index" git add -A && GIT_INDEX_FILE="$index" git write-tree)"
    rm -f "$index"
    [ "$baum" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] || stand="$stand+geaendert"
    git -C "$repo" archive --format=tar.gz -o "$ziel" "$baum"
    echo "$stand"
}

T="$(mktemp -d "${TMPDIR:-/tmp}/rw-profil.XXXXXX")"
trap 'rm -rf "$T"' EXIT
STAND="$(archiv "$WURZEL" "$T/profil.tar.gz")"
BSTAND="$(archiv "$BASIS" "$T/basis.tar.gz")"
EPOCH="$(git log -1 --format=%ct)"

ZW="/tmp/rosenweg-profil-bau.$$"
ssh "$KNOTEN" "rm -rf $ZW && mkdir -p $ZW"
scp -q "$T/profil.tar.gz" "$T/basis.tar.gz" "$KNOTEN:$ZW/"
ssh "$KNOTEN" "pct exec $CTID -- rm -rf /root/bau/rosenweg-profil /root/bau/rosenweg-basis \
    && pct exec $CTID -- mkdir -p /root/bau/rosenweg-profil /root/bau/rosenweg-basis \
    && pct push $CTID $ZW/profil.tar.gz /root/bau/rosenweg-profil.tar.gz \
    && pct push $CTID $ZW/basis.tar.gz /root/bau/rosenweg-basis.tar.gz \
    && pct exec $CTID -- tar -xzf /root/bau/rosenweg-profil.tar.gz -C /root/bau/rosenweg-profil \
    && pct exec $CTID -- tar -xzf /root/bau/rosenweg-basis.tar.gz -C /root/bau/rosenweg-basis \
    && pct exec $CTID -- sh -c 'printf \"dependency_overrides:\\n  rosenweg_basis:\\n    path: ../rosenweg-basis\\n\" > /root/bau/rosenweg-profil/pubspec_overrides.yaml' \
    && pct exec $CTID -- env RW_STAND=$STAND.basis-$BSTAND SOURCE_DATE_EPOCH=$EPOCH \
         bash /root/bau/rosenweg-profil/linux/paket/bauen.sh"

DATEI="$(ssh "$KNOTEN" "pct exec $CTID -- cat /root/bau/rosenweg-profil/linux/paket/out/DATEI")"
mkdir -p "$HIER/out"
ssh "$KNOTEN" "pct pull $CTID /root/bau/rosenweg-profil/linux/paket/out/$DATEI $ZW/$DATEI"
scp -q "$KNOTEN:$ZW/$DATEI" "$HIER/out/$DATEI"
ssh "$KNOTEN" "rm -rf $ZW"

echo
echo "Zurückgeholt: $HIER/out/$DATEI"
cd "$HIER/out"
shasum -a 256 "$DATEI" 2>/dev/null || sha256sum "$DATEI"
