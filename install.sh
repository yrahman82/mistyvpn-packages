#!/bin/sh
# MistyVPN for Linux — install or update:   curl -fsSL https://packages.mistyvpn.com/install.sh | sudo sh
# Ubuntu/Debian: adds the signed MistyVPN apt repository and installs the package, so `apt upgrade`
# keeps it current. Anything else with systemd: installs the single static binary (`misty update` later).
set -eu
BASE="${MISTY_PACKAGES:-https://packages.mistyvpn.com}"
[ "$(id -u)" -eq 0 ] || { echo "Run as root: curl -fsSL $BASE/install.sh | sudo sh" >&2; exit 1; }
case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported CPU: $(uname -m) (MistyVPN supports x86_64 and arm64)" >&2; exit 1 ;;
esac
command -v systemctl >/dev/null || { echo "MistyVPN needs systemd." >&2; exit 1; }
[ -c /dev/net/tun ] || modprobe tun 2>/dev/null || true
fetch() { if command -v curl >/dev/null; then curl -fsSL "$1" -o "$2"; else wget -qO "$2" "$1"; fi; }

if command -v apt-get >/dev/null && command -v dpkg >/dev/null && [ -z "${MISTY_NO_APT:-}" ]; then
  echo "Adding the MistyVPN apt repository…"
  fetch "$BASE/mistyvpn.asc" /usr/share/keyrings/mistyvpn.asc
  echo "deb [signed-by=/usr/share/keyrings/mistyvpn.asc] $BASE/apt stable main" > /etc/apt/sources.list.d/mistyvpn.list
  apt-get update -o Dir::Etc::sourcelist=sources.list.d/mistyvpn.list -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0 -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mistyvpn
  echo "MistyVPN $(misty version | head -1 | cut -d' ' -f2) installed. Updates come with: sudo apt update && sudo apt upgrade"
  echo "Next: misty login   (as your normal user, no sudo)"
  exit 0
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
echo "Downloading MistyVPN ($ARCH)…"
fetch "$BASE/linux/misty-linux-$ARCH" "$TMP/misty"
fetch "$BASE/linux/SHA256SUMS" "$TMP/SHA256SUMS"
WANT=$(awk -v f="misty-linux-$ARCH" '$2==f || $2=="*"f {print $1}' "$TMP/SHA256SUMS")
GOT=$(sha256sum "$TMP/misty" | awk '{print $1}')
[ -n "$WANT" ] && [ "$WANT" = "$GOT" ] || { echo "Checksum mismatch — download damaged, nothing installed." >&2; exit 1; }
chmod 755 "$TMP/misty"
"$TMP/misty" service install
