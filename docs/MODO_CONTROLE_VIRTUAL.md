# Modo Controle virtual / Jogos de PC

Status: **experimental (`1.4.0-beta.1`)**. O modo padrão continua sendo **Teclado / Emuladores**.

## Diferenças

O modo teclado converte cada botão em uma tecla e funciona sem componente adicional. O modo controle virtual envia estado analógico versionado ao bridge C# local, que cria dois dispositivos com perfil Xbox 360/XInput através do HIDMaestro.

- Celular 1 controla somente o dispositivo virtual 1.
- Celular 2 controla somente o dispositivo virtual 2.
- O bridge usa stdin/stdout e não abre porta de rede.
- O watchdog neutraliza o jogador que ficar sem estado válido por 750 ms.
- Retro 16-bit oferece D-pad, A/B/X/Y, LB/RB, Menu e View; pode ser insuficiente para jogos 3D.
- Modern Dual-Stick oferece dois analógicos, D-pad, botões, gatilhos LT/RT, LB/RB, View/Menu e cliques dos analógicos.

## Requisitos experimentais

- Windows 11 de 64 bits, build 26100 ou posterior.
- Pacote experimental completo.
- Instalação inicial autorizada com UAC.
- Execução elevada enquanto o modo XInput estiver ativo, limitação declarada pelo SDK atual.

Windows 10 e versões anteriores do Windows 11 continuam compatíveis com o modo teclado.

## Uso

1. Leia [Instalação do HIDMaestro](HIDMAESTRO_INSTALLATION.md).
2. Execute `INSTALAR_MODO_CONTROLE_VIRTUAL.bat` e confirme o UAC.
3. Execute `INICIAR_MODO_CONTROLE_VIRTUAL.bat`.
4. Conecte os dois celulares, escolhendo Jogador 1 e Jogador 2.
5. Abra `TESTAR_CONTROLES_VIRTUAIS.bat` ou `joy.cpl` para inspeção manual.

Para voltar sem remover componentes, execute `DESATIVAR_MODO_CONTROLE_VIRTUAL.bat`. Não encaminhe a porta 8765 e não exponha o servidor à internet.

Não há compatibilidade comprovada com It Takes Two, todos os jogos ou anti-cheat. Rumble não é encaminhado nesta etapa.
