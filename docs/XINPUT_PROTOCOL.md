# Protocolo de controle virtual

Versão atual: `2`.

## Navegador → servidor

O WebSocket autenticado aceita `gamepad_state` somente do jogador reservado. A mensagem contém sequência monotônica, timestamp, dez botões lógicos, quatro direções e seis eixos (`lx`, `ly`, `rx`, `ry`, `lt`, `rt`). Sticks usam `-1.0..1.0`; gatilhos usam `0.0..1.0`.

O servidor rejeita protocolo incompatível, jogador divergente, NaN/Infinity, tipos incorretos, campos desconhecidos e mensagens acima de 64 KiB. Valores finitos fora da faixa são limitados. Sequências antigas são descartadas e cada cliente é limitado a no máximo 120 estados aceitos por segundo; a interface envia no máximo 60 Hz e coalesce mudanças.

## Servidor → bridge

JSON Lines por stdin/stdout, máximo 16 KiB por linha, sem shell e sem TCP:

- `bridge_ready`: versão e capacidades.
- `hello`: handshake v2.
- `create`: criação dos dois slots.
- `state`: estado sanitizado mais recente de um jogador.
- `neutralize`: neutralização imediata de um slot.
- `shutdown`: encerramento limpo.
- `error`: falha controlada sem PIN.

O bridge descarta sequência atrasada e neutraliza após 750 ms sem estado válido. O servidor mantém apenas o estado mais recente por jogador, sem fila crescente.
