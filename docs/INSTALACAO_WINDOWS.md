# Instalação no Windows

Baixe `CelularGamepad-Setup-v1.4.0-beta.2.exe` somente da prerelease oficial no GitHub e confira o SHA-256 publicado ao lado do arquivo.

1. Execute o instalador e aceite o UAC.
2. Escolha **Instalação padrão** para Emuladores e Jogos de PC, ou **Somente Emuladores** para não instalar HIDMaestro.
3. Opcionalmente marque os atalhos da Área de Trabalho. A inicialização com o Windows vem desmarcada.
4. Abra **Celular Gamepad — Emuladores** ou **Celular Gamepad — Jogos de PC** no Menu Iniciar.
5. Use o endereço e o PIN temporário exibidos na janela.

Arquivos imutáveis ficam em `C:\Program Files\Celular Gamepad`. Configuração e logs técnicos ficam em `%LOCALAPPDATA%\CelularGamepad`. Nenhum PIN, IP ou credencial é salvo permanentemente.

O modo Jogos de PC é experimental, requer Windows 11 64 bits build 26100+ no estado atual do HIDMaestro e pode solicitar elevação ao iniciar. O modo Emuladores continua disponível se o componente XInput não for instalado.
