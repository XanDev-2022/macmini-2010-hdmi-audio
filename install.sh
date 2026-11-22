#!/bin/sh
# Install or remove the mcp89-hdmi-audio service.
#   sudo ./install.sh            install and start
#   sudo ./install.sh --remove   stop and uninstall
set -e
cd "$(dirname "$0")"

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo $0 $*" >&2
  exit 1
fi

if [ "$1" = "--remove" ]; then
  systemctl disable --now mcp89-hdmi-audio 2>/dev/null || true
  rm -f /usr/local/sbin/mcp89-hdmi-audio /etc/systemd/system/mcp89-hdmi-audio.service
  systemctl daemon-reload
  echo "Removed. Reboot (or replug HDMI) to return to the driver's defaults."
  exit 0
fi

if ! command -v modetest >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y libdrm-tests
  else
    echo "modetest not found: install your distro's libdrm test utilities" >&2
    exit 1
  fi
fi

install -m 755 mcp89-hdmi-audio /usr/local/sbin/mcp89-hdmi-audio
# Fail early (before enabling anything) on unsupported hardware.
/usr/local/sbin/mcp89-hdmi-audio --status
install -m 644 mcp89-hdmi-audio.service /etc/systemd/system/mcp89-hdmi-audio.service
systemctl daemon-reload
systemctl enable --now mcp89-hdmi-audio
echo
echo "Installed. Make sure your sound server outputs to HDMI, e.g.:"
echo "  pactl list cards | grep -A1 'output:hdmi'   # find the available HDMI profile"
echo "  pactl set-card-profile <card> output:hdmi-stereo-extraN"
