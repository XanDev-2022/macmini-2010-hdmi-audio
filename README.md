# HDMI audio for the Mac mini 2010 (GeForce 320M) on Linux

On Linux, the 2010 Mac mini's HDMI port gives you a picture but **no sound**.
The open-source `nouveau` driver doesn't support HDMI audio on the NVIDIA
MCP89 / GeForce 320M, and NVIDIA's legacy 340 driver no longer builds on
current kernels. ALSA and PipeWire show an HDMI output, report it as
"running", and the TV, monitor or receiver stays silent.

This repo fixes that with a small service, with no kernel patching or
rebuilding. It watches the HDMI output, and whenever the driver sets it up
(boot, cable replug, display power-cycle, resolution change), it switches on
the hardware audio features that `nouveau` leaves off.

## Status

| Machine | Distro / kernel | Display | Result |
|---|---|---|---|
| Mac mini 2010 (Macmini4,1, `10de:08a4`) | Ubuntu 26.04.1, kernel 7.0.0 | ASUS VG34V, 1720x1440@60 over HDMI | ✅ Works |
| Mac mini 2010 (Macmini4,1) | Ubuntu 26.04.1, kernel 7.0.0 | Acer XB271HU, 1080p60 over HDMI | ❌ Silent, but only tested with the original patch's fixed 1080p values, not with this service. Retest welcome. |

Other GeForce 320M Macs (MacBook7,1, MacBookPro7,1, MacBookAir3,x) use the same
chip and should be supported, but are **untested**. Please
[open an issue](../../issues) with your results either way, and include the
output of `sudo mcp89-hdmi-audio --status`.

## Install

Debian/Ubuntu (other distros: install your libdrm test utilities for `modetest` first):

```sh
git clone https://github.com/XanDev-2022/macmini-2010-hdmi-audio
cd macmini-2010-hdmi-audio
sudo ./install.sh
```

Then point your sound server at HDMI. With PipeWire or PulseAudio:

```sh
pactl list cards | grep -E 'output:hdmi.*available: yes'
pactl set-card-profile <card-name> output:hdmi-stereo-extra2   # use the profile listed above
```

Check that it's working:

```sh
sudo mcp89-hdmi-audio --status     # "applied: True" when the fix is active
journalctl -u mcp89-hdmi-audio     # logs each time it re-applies
```

Uninstall with `sudo ./install.sh --remove`, then reboot.

## How it works

On this chip, HDMI audio needs a few things from the GPU's display engine that
`nouveau` doesn't set up:

1. **Audio Clock Regeneration (ACR)**: the sink rebuilds the audio clock
   from CTS/N values sent alongside the video. `nouveau` clears the ACR enable
   bit, so the sink never locks onto the audio. That's the main cause of the
   silence.
2. **CTS/N values for the current pixel clock**: `CTS = f_TMDS × N / (128 × fs)`.
   The service reads the active mode's pixel clock and computes CTS for
   32–192 kHz using the N values recommended by the HDMI spec.
3. **Audio InfoFrame**: it declares 2-channel audio (with the checksum
   recomputed) instead of "refer to stream header".
4. **DP audio off** on the output resource (SOR) driving HDMI.

The service polls every 2 seconds. When the driver reprograms the output and
the values are gone, it waits for the modeset to settle and re-applies them.
Expect a second or two of silence after you replug HDMI or power-cycle the display.

### Safety

The service writes directly to GPU registers through
`/sys/bus/pci/devices/*/resource0`, behind the driver's back. Before writing
anything, it checks that:

- the PCI device is an MCP89 / GeForce 320M (`10de:08a0`–`08a5`), and
- the chip's own ID register (`PMC_BOOT_0`) reports chipset `0xaf` (MCP89).

If either check fails, it refuses to run. The worst outcome I've seen during
testing is a brief flicker. Every change is reset by the next modeset or
reboot.

Requirements: root, `modetest` (libdrm), and a kernel that allows mapping PCI
BARs (no `CONFIG_IO_STRICT_DEVMEM`, no kernel lockdown). Stock Ubuntu/Debian on
these Macs qualifies.

## Credits

The register reverse-engineering comes from
[obhasashare2024-namo/nouveau-mcp89-hdmi-audio](https://github.com/obhasashare2024-namo/nouveau-mcp89-hdmi-audio),
a GPLv2 kernel patch tested on a MacBookPro7,1 through a Mini DisplayPort to
HDMI adapter. This project reuses its register sequence, with two changes:

- **CTS is computed from the live pixel clock.** The original hardcodes
  values for 1080p60 (148.5 MHz), so it goes silent at any other resolution.
  That's exactly what happened on the ASUS monitor above until CTS was
  computed.
- **It runs as a userspace service instead of a kernel patch,** so there's
  nothing to rebuild when the kernel updates.

The real long-term fix belongs in `nouveau` itself
(`drivers/gpu/drm/nouveau/nvkm/engine/disp/gt215.c`). If you're in a position
to upstream it, please do.

## License

GPL-2.0-only. See [LICENSE](LICENSE).
