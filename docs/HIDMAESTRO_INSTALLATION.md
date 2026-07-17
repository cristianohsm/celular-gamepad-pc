# Instalação do HIDMaestro

Dependência validada: HIDMaestro `v1.3.17`, commit `a5fc8b77732e93d1bd8519eb081a6a4c4c9ff283`, MIT. O SHA-256 do asset oficial é `3a3685fb3325744778198c1fbd773d0cae5902c9aedb42227812187acb9957f0`; o DLL redistribuído é verificado contra `a176bf7457d3b884b6ccc9a10da4d72d9d52df3dbf676df2c7e36ba7b7427a5c`.

1. Extraia todo o pacote experimental.
2. Execute `INSTALAR_MODO_CONTROLE_VIRTUAL.bat`.
3. Leia o resumo, digite `S` e aceite o UAC.
4. O script verifica o DLL antes de executar o bridge elevado.
5. O SDK extrai seus payloads incorporados, cria um certificado local, adiciona-o aos stores Root e TrustedPublisher, assina os pacotes UMDF2 e registra-os com `pnputil`.

Não são instalados PadForge, ViGEmBus ou programas extras. O script não altera Secure Boot, Test Signing, antivírus, política permanente do PowerShell nem inicialização automática.

A instalação real não foi executada automaticamente durante o desenvolvimento; precisa de consentimento explícito do usuário.
