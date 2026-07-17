# Segurança da rede local

O servidor escuta a rede local para que os celulares alcancem o PC. Use-o somente em redes confiáveis e mantenha o perfil do Firewall limitado a redes Privadas ou de Domínio.

- Não encaminhe a porta TCP 8765 no roteador.
- Não exponha o servidor diretamente na internet.
- Não compartilhe PINs nem capturas que revelem endereços locais.
- O PIN muda a cada execução, mas não é autenticação adequada para um serviço público.
- Feche o servidor quando terminar de jogar.
- O QR contém uma credencial temporária local: escaneie apenas em rede confiável. O PIN é removido da URL do celular após o carregamento e não é persistido em logs, configuração ou artefatos.
- A página `/connect` é aceita somente pelo PC local, usa `Cache-Control: no-store` e não carrega CDN, analytics ou serviços externos.
