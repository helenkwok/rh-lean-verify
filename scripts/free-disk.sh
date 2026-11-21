#!/usr/bin/env bash
# Free preinstalled GitHub-hosted runner tools so Lean oleans have room.
set -euo pipefail

df -h / | tee /tmp/df-before.txt
echo "::group::Freeing preinstalled tools"
sudo rm -rf \
  /usr/share/dotnet \
  /usr/local/lib/android \
  /opt/ghc \
  /opt/hostedtoolcache/CodeQL \
  /usr/share/swift \
  /usr/local/share/powershell \
  /usr/local/.ghcup \
  /usr/share/miniconda \
  /usr/share/gradle \
  /opt/az \
  /usr/share/az_* \
  /opt/microsoft \
  /usr/local/lib/node_modules \
  /opt/pipx \
  /usr/lib/jvm \
  /usr/local/share/chromium \
  /usr/share/emacs \
  /usr/share/php \
  || true

if command -v docker >/dev/null 2>&1; then
  docker system prune -af || true
fi
sudo apt-get clean || true
echo "::endgroup::"
df -h /
echo "Disk before:"
cat /tmp/df-before.txt
