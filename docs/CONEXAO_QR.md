# Conexão rápida por QR Code

Na beta `1.4.0-beta.3`, o terminal continua visível para diagnóstico e mostra um QR Code de **Conexão automática**. Escaneie-o com a câmera do celular, confirme o jogador e toque em **Conectar**. Nenhuma conexão é feita apenas por abrir o QR.

O aplicativo gera, a cada execução, um PIN aleatório de seis dígitos mantido somente na memória. Os QRs usam URLs locais no formato `http://IP_PRIVADO:PORTA/?pin=PIN&player=auto`, `player=1` ou `player=2`. O primeiro QR seleciona o próximo slot livre; os QRs específicos recusam claramente um slot ocupado, sem desconectar outro celular.

Após ler o QR, o navegador valida os parâmetros, preenche PIN e jogador em memória e remove o PIN da barra de endereços com `history.replaceState`. O PIN não é salvo no navegador, em `config.json`, logs, artefatos ou QR permanente.

Por padrão, o PC também abre uma única página local em `http://127.0.0.1:8765/connect` com QR automático, Jogador 1 e Jogador 2. Essa rota só aceita acesso local no PC, usa `Cache-Control: no-store`, não carrega CDN, analytics ou recurso externo e é encerrada junto com a sessão.

## Configuração

No `config.json` do usuário, o bloco opcional abaixo preserva compatibilidade com configurações antigas:

```json
"connection_ui": {
  "show_terminal_qr": true,
  "open_local_qr_page": true,
  "show_player_specific_qr": true,
  "manual_ipv4": ""
}
```

Defina `open_local_qr_page` como `false` para não abrir a página do PC. A detecção usa somente adaptadores ativos com IPv4 privado RFC1918, priorizando Wi-Fi e Ethernet; ignora loopback, APIPA e IP público. Se não encontrar uma rede válida, conecte-se a uma rede privada ou informe um IPv4 privado em `manual_ipv4`.
