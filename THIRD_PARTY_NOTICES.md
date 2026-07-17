# Third-party notices

## HIDMaestro

- Official project: <https://github.com/hifihedgehog/HIDMaestro>
- Version/tag: `v1.3.17`
- Commit: `a5fc8b77732e93d1bd8519eb081a6a4c4c9ff283`
- License: MIT
- Copyright: Copyright (c) 2026 HIDMaestro Contributors
- Use: `HIDMaestro.Core.dll` is consumed by the local C# bridge to create two virtual controllers with the `xbox-360-wired` profile.
- Redistributed file: `bridge/HIDMaestro.Core.dll`
- License copy: `bridge/licenses/HIDMaestro-LICENSE.txt`

The official release asset is pinned by size and SHA-256 in `dependencies.lock.json`. HIDMaestro is an independent project and is not created, endorsed, or maintained by Celular Gamepad para PC.

## Python

- Official project: <https://www.python.org/>
- Version: `3.12.10`, Windows embeddable x64 package
- License: Python Software Foundation License Version 2
- Use: private portable runtime bundled with the installer and portable package; pip is not installed.

## .NET

- Official project: <https://dotnet.microsoft.com/>
- SDK used to publish: `10.0.301`; bundled runtime: `10.0.9`
- License: MIT
- Use: self-contained `win-x64` publication of the local bridge. No system-wide .NET installation is performed.

## Inno Setup

- Official project: <https://jrsoftware.org/isinfo.php>
- Version used to compile: `6.7.1`
- License: Inno Setup License
- Use: build-time compiler only. The Inno Setup installer itself is not redistributed inside this repository or application.

## QR Code generator library (Python)

- Official project: <https://github.com/nayuki/QR-Code-generator>
- Version/tag: `v1.8.0`
- License: MIT
- Use: generates QR matrices locally in memory for the terminal and the PC-only `/connect` page. It makes no HTTP request and writes no QR image to disk.
- Redistributed files: `vendor/qrcodegen.py` and `vendor/LICENSE-qrcodegen.txt`
- Source SHA-256: `b089855caf16185c61421ea4927c1b213cf9468940d71fa8ab11ef83662dcc84`
