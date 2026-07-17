# Execução portátil

`INICIAR_EM_QUALQUER_PC.bat` baixa do Python.org um runtime embutido compatível com Windows x64 ou ARM64 e o mantém em `runtime/`. Não há instalação global nem dependências de terceiros. Depois do primeiro preparo, o projeto funciona offline.

Para preparar uma cópia sem internet, execute `PREPARAR_PACOTE_OFFLINE.bat` em um PC conectado e copie a pasta completa, inclusive `runtime/`, para outro Windows da mesma arquitetura. A pasta `runtime/` é local e nunca deve ser enviada ao Git.

Para iniciar com o Windows, mantenha a pasta em local fixo, crie um atalho de `iniciar.bat` e coloque apenas o atalho em `shell:startup`.

O pacote XInput experimental inclui um bridge self-contained e não depende de .NET instalado globalmente. O modo teclado continua usando os mesmos iniciadores portáteis. O modo controle virtual usa `INICIAR_MODO_CONTROLE_VIRTUAL.bat` e exige elevação na versão atual; não o coloque em inicialização automática.
