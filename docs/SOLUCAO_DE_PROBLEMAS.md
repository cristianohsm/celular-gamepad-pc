# Solução de problemas

## A página não abre

Confirme que PC e celular estão na mesma Wi-Fi, marque a rede do Windows como Privada, execute `LIBERAR_FIREWALL_PRIMEIRO_USO.bat` e desative temporariamente VPNs ou isolamento de clientes do roteador.

## O jogo não recebe comandos

Evite executar somente o jogo como administrador. Servidor e jogo precisam do mesmo nível de privilégio; prefira ambos sem elevação. Refazer o mapeamento de teclado no jogo também pode ser necessário.

## O servidor não inicia

Execute `DIAGNOSTICO.bat`. Verifique se outro processo usa a porta 8765 e se o runtime existe. Com internet disponível, `INICIAR_EM_QUALQUER_PC.bat` pode baixar novamente o runtime oficial.

## Teclas ficam pressionadas

A versão atual libera as teclas ao desconectar ou perder foco. Se o processo for encerrado à força, reabra e feche o aplicativo/jogo ou pressione e solte a tecla afetada no teclado físico.

## “Controle virtual não instalado”

O servidor voltou automaticamente ao teclado. Confirme Windows 11 build 26100+, execute `INSTALAR_MODO_CONTROLE_VIRTUAL.bat` com consentimento e depois use `INICIAR_MODO_CONTROLE_VIRTUAL.bat`. Rode `VERIFICAR_CONTROLE_VIRTUAL.bat` para consultar o componente.

## Somente um controle aparece

Feche o jogo, confirme dois jogadores conectados, abra `joy.cpl` e pressione botões nos dois celulares. Reinicie o modo controle virtual antes de reabrir o jogo. Não altere arquivos do jogo.

## O comando para após menos de um segundo

Atualize para uma versão que inclua o refresh XInput de 200 ms. Enquanto houver uma entrada ativa, o celular reenvia o estado completo em baixa frequência para que o watchdog de 750 ms não neutralize um comando ainda pressionado. Ao soltar ou desconectar, a neutralização continua imediata e isolada por jogador.
