# Changelog

Todas as mudanças relevantes deste projeto serão registradas aqui.

## [1.4.0-beta.2] - 2026-07-16

- Instalador único para Windows com Python embeddable e bridge .NET self-contained.
- Atalhos separados para Emuladores (teclado) e Jogos de PC (XInput).
- Dados mutáveis da instalação em `%LOCALAPPDATA%\CelularGamepad`.
- Pacote portátil completo para testes em outro computador.
- Modo experimental e opcional com dois controles virtuais XInput via HIDMaestro fixado.
- Bridge C# local por JSON Lines, sem nova porta de rede.
- Analógicos e gatilhos reais, sequência, rate limit, coalescimento e watchdog.
- Refresh do estado XInput completo a cada 200 ms enquanto houver entrada ativa, preservando comandos mantidos e a proteção do watchdog.
- Backend falso para testes sem instalar dispositivos.
- Modo teclado preservado como padrão e fallback.

## [1.3.0] - 2026-07-16

Lançamento público inicial:

- Dois jogadores independentes.
- Layouts Retro 16-bit e Modern Dual-Stick.
- WebSocket na rede local com PIN temporário.
- Runtime Python portátil.
- Correção das estruturas Win32 `SendInput` em 64 bits.
- Liberação automática de teclas ao desconectar.
