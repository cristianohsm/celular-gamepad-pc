# Decisão técnica: modo de controle virtual XInput

Status: experimental — versão `1.4.0-beta.1`.

## Contexto e decisão

Jogos modernos normalmente esperam dispositivos XInput, enquanto a versão 1.3 envia teclas e atende bem emuladores como o Snes9x. O modo **Teclado / Emuladores** continuará sendo o padrão e não depende de componentes adicionais. O modo opcional **Controle virtual / Jogos de PC** usará o SDK oficial HIDMaestro por meio de um bridge C# local.

ViGEmBus, vgamepad/ViGEm, SCPToolkit e drivers obtidos de terceiros não serão usados. ViGEmBus está aposentado e exige driver de kernel; HIDMaestro oferece dispositivos UMDF2 em user mode, perfil Xbox 360/XInput, múltiplos controles e remoção individual.

## Dependência fixada

- Projeto oficial: <https://github.com/hifihedgehog/HIDMaestro>
- Release/tag: `v1.3.17`
- Commit: `a5fc8b77732e93d1bd8519eb081a6a4c4c9ff283`
- Asset: `HIDMaestro-v1.3.17.zip` — 21.457.772 bytes
- SHA-256: `3a3685fb3325744778198c1fbd773d0cae5902c9aedb42227812187acb9957f0`
- Licença: MIT, copyright 2026 HIDMaestro Contributors

O arquivo `dependencies.lock.json` é a fonte de pinagem. O restore baixa somente o asset oficial e rejeita qualquer hash ou tamanho divergente. Não há atualização silenciosa.

## Arquitetura

O servidor Python preserva HTTP, PIN, WebSocket, slots de jogadores, modo teclado e segurança da rede local. Em modo XInput, ele inicia `PhoneGamepad.Bridge.exe` como processo filho e troca JSON Lines por `stdin`/`stdout`. O bridge não escuta TCP, não cria HTTP e não aceita comandos de shell.

O protocolo local possui handshake, capacidades, estados versionados, limite de linha, sequência monotônica, confirmação, erros controlados, neutralização e encerramento. O bridge mantém no máximo dois slots e usa um watchdog para neutralizar um jogador sem afetar o outro.

## Privilégios e instalação

O upstream declara que `HMContext.InstallDriver()` e `CreateController()` exigem `SeLoadDriverPrivilege`. A primeira instalação extrai payloads incorporados, cria um certificado de assinatura local, confia esse certificado nos stores Root e TrustedPublisher da máquina, assina os pacotes e os registra com `pnputil`. Não ativa Test Signing, não altera Secure Boot e não requer reinicialização segundo a documentação oficial.

Como a criação do dispositivo também exige administrador, o modo XInput precisa de uma execução elevada nesta versão experimental. O modo teclado continua funcionando sem elevação. Nenhum serviço, tarefa automática ou elevação silenciosa será criado.

## Compatibilidade comprovada e limitações

O SDK oficial tem target `net10.0-windows10.0.26100.0` e o upstream documenta validação em Windows 11 build 26200. Portanto, esta integração limita o XInput experimental a Windows 11 build 26100 ou posterior até novos testes. Windows 10/11 anteriores continuam suportados no modo teclado.

Não há alegação de compatibilidade com It Takes Two, todos os jogos ou jogos com anti-cheat. O layout Retro 16-bit não oferece todos os comandos necessários para jogos 3D. Rumble não será encaminhado nesta etapa.

## Remoção, compartilhamento e rollback

Ao fechar, cada `HMController` e o contexto são descartados, removendo os dispositivos criados. Uma limpeza explícita pode chamar `HMContext.RemoveAllVirtualControllers()`, mas isso afeta todos os dispositivos HIDMaestro e, por isso, exige confirmação clara. A remoção do componente compartilhado/certificado não será automatizada quando não for possível provar propriedade exclusiva.

Rollback seguro: definir `output_mode` como `keyboard`, fechar o bridge, neutralizar/remover os controles desta sessão e manter o componente compartilhado instalado. O código 1.3 permanece disponível na `main` e na release `v1.3.0`.

## Riscos e controles

- Certificado local confiado e pacotes de dispositivo alteram o Windows; consentimento e UAC são obrigatórios.
- Falha/crash pode deixar dispositivo órfão; o SDK executa limpeza defensiva na próxima instalação e o projeto fornece comando explícito.
- Bridge lento ou travado: watchdog entre 500 e 1000 ms neutraliza entradas.
- Cliente malformado: validação estrita, 64 KiB máximo no WebSocket, 16 KiB máximo por linha local, rate limit e descarte de sequência antiga.
- Nenhuma nova porta é aberta; somente o WebSocket existente na porta configurada continua acessível à rede local.
