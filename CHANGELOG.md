# Changelog

Todas as mudanças relevantes deste projeto serão registradas aqui.

## [1.4.0-beta.1] - Não lançado

- Modo experimental e opcional com dois controles virtuais XInput via HIDMaestro fixado.
- Bridge C# local por JSON Lines, sem nova porta de rede.
- Analógicos e gatilhos reais, sequência, rate limit, coalescimento e watchdog.
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
