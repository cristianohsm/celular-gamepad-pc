# Phone Gamepad for PC

[Português](README.md) | [English](README.en.md)

Use one or two phones as local-network gamepads for Windows games and emulators. Each phone runs the controller in a modern browser; the dependency-free Python server converts WebSocket messages to keyboard input through Win32 `SendInput`.

> Experimental `1.4.0-beta.2` adds a Windows installer, a portable package, and an optional dual virtual-controller/XInput mode. The v1.3 keyboard mode remains available for emulators.

## Highlights and requirements

- Independent Player 1 and Player 2 slots.
- No mobile app installation; **Retro 16-bit** and **Modern Dual-Stick** layouts.
- Temporary PIN and local-network-only communication.
- Portable Python runtime downloaded from Python.org on first preparation; works offline afterward.
- Windows 10 or 11 64-bit, phones and PC on the same trusted network, and a modern browser.

## Quick start

1. Extract the complete folder.
2. Run `LIBERAR_FIREWALL_PRIMEIRO_USO.bat` once.
3. Run `INICIAR_EM_QUALQUER_PC.bat`.
4. Open a displayed address on each phone, enter the temporary PIN, and choose Player 1 or Player 2.

`iniciar.bat` prefers `runtime\python.exe`, falls back to an installed `py`/`python`, and invokes the portable launcher when neither is available. To start with Windows, keep the full folder in a fixed location and place only a shortcut to `iniciar.bat` in `shell:startup`.

## Compatibility and safety

The tested setup includes Snes9x keyboard mapping; configure `Joypad #1` and `Joypad #2` with their respective phones. Output is keyboard input—not HID or XInput—and virtual sticks become keyboard directions.

Use only on a trusted local network. Never forward TCP port 8765 or expose the server directly to the internet. The temporary PIN is not sufficient authentication for public exposure.

## Experimental virtual-controller mode

The optional mode starts a local C# bridge over stdin/stdout and uses the pinned official HIDMaestro `v1.3.17` SDK to create two Xbox 360/XInput-profile devices. It opens no additional network port and falls back to keyboard mode when unavailable.

Current requirements are 64-bit Windows 11 build 26100+, an explicitly approved UAC installation, and elevation while creating controllers. Modern Dual-Stick provides real sticks and triggers; Retro 16-bit is incomplete for many 3D games. It Takes Two compatibility has not been confirmed and requires the user's manual test.

The `1.4.0-beta.2` prerelease includes a single Windows installer with an embedded Python runtime and a self-contained .NET bridge. It creates separate **Emulators — Keyboard** and **PC Games — Virtual controller** shortcuts. Download only from the official `cristianohsm/celular-gamepad-pc` GitHub releases and verify the published SHA-256 checksum.

Run tests with `python -m py_compile server.py test_server.py` and `python -m unittest -v`. See the Portuguese [README](README.md) and the files under [`docs/`](docs/) for complete instructions.

## License and trademarks

Licensed under the [MIT License](LICENSE).

This is an independent project and is not endorsed by, approved by, or affiliated with Nintendo, Sony, PlayStation, or other manufacturers. Mentioned trademarks belong to their respective owners.
