# Desativação e remoção segura

`DESATIVAR_MODO_CONTROLE_VIRTUAL.bat` apenas restaura `output_mode: keyboard`. É o rollback recomendado e não requer remover componente compartilhado.

`REMOVER_COMPONENTE_CONTROLE_VIRTUAL.bat` solicita confirmação e remove todos os dispositivos virtuais HIDMaestro ativos através da API oficial. Como outra aplicação pode usar HIDMaestro, o script **preserva pacotes compartilhados e certificados** quando não consegue comprovar propriedade exclusiva.

Para desinstalação profunda, identifique primeiro consumidores e pacotes no Driver Store. Não remova certificados genéricos, pacotes ou serviços manualmente sem confirmar a origem. Não use ferramentas de terceiros.
