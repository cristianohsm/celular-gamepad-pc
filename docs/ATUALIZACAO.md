# Atualização

O instalador usa um AppId fixo para atualizar a mesma aplicação sem criar atalhos duplicados. Execute a nova beta sobre a instalação anterior e mantenha o tipo de instalação desejado.

`config.json` e preferências ficam em `%LOCALAPPDATA%\CelularGamepad`, fora de `Program Files`, e são preservados por atualização e desinstalação. Downgrade silencioso de uma beta mais recente para uma beta anterior é bloqueado.

Para alterar a inicialização automática, execute novamente o instalador e ajuste a tarefa **Iniciar com o Windows no modo Emuladores**. O modo XInput nunca é configurado para iniciar automaticamente.
